import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../../firebase_options.dart';
import '../../features/scheduling/data/schedule_repository.dart';
import '../../features/users/data/user_repository.dart';
import '../../features/users/domain/user_role.dart';
import '../session/app_session_controller.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
}

class PushNotificationService with WidgetsBindingObserver {
  PushNotificationService({
    required AppSessionController sessionController,
    required UserRepository userRepository,
    required ScheduleRepository scheduleRepository,
    bool enabled = true,
  })  : _sessionController = sessionController,
        _userRepository = userRepository,
        _scheduleRepository = scheduleRepository,
        _enabled = enabled;

  final AppSessionController _sessionController;
  final UserRepository _userRepository;
  final ScheduleRepository _scheduleRepository;
  final bool _enabled;

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _serviceChannel =
      AndroidNotificationChannel(
    'tracker_services',
    'Serviços Tracker Carsat',
    description: 'Avisos de novos serviços e atualizações operacionais.',
    importance: Importance.max,
  );

  StreamSubscription<RemoteMessage>? _foregroundMessageSubscription;
  StreamSubscription<String>? _tokenRefreshSubscription;
  Timer? _technicianPollingTimer;

  bool _initialized = false;
  int? _activeTechnicianId;
  final Map<int, String> _knownScheduleSnapshot = <int, String>{};
  final Map<int, DateTime> _recentlyNotifiedSchedules = <int, DateTime>{};

  bool get _supportsNotifications {
    if (kIsWeb) {
      return false;
    }

    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  Future<void> initialize() async {
    _sessionController.addListener(_handleSessionChanged);
    WidgetsBinding.instance.addObserver(this);

    if (!_enabled || !_supportsNotifications || _initialized) {
      return;
    }

    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    await _initializeLocalNotifications();
    await _requestPermissions();

    _foregroundMessageSubscription =
        FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    _tokenRefreshSubscription =
        FirebaseMessaging.instance.onTokenRefresh.listen(_handleTokenRefresh);

    _initialized = true;
    await _synchronizeWithSession();
  }

  Future<void> dispose() async {
    WidgetsBinding.instance.removeObserver(this);
    _sessionController.removeListener(_handleSessionChanged);
    _technicianPollingTimer?.cancel();
    await _foregroundMessageSubscription?.cancel();
    await _tokenRefreshSubscription?.cancel();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_refreshTechnicianAssignments(notifyNewAssignments: true));
    }
  }

  void _handleSessionChanged() {
    unawaited(_synchronizeWithSession());
  }

  Future<void> _initializeLocalNotifications() async {
    const initializationSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );

    await _localNotifications.initialize(settings: initializationSettings);

    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(_serviceChannel);
    await androidPlugin?.requestNotificationsPermission();
  }

  Future<void> _requestPermissions() async {
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  Future<void> _synchronizeWithSession() async {
    final currentUser = _sessionController.currentUser;
    if (currentUser == null) {
      _stopTechnicianPolling();
      _activeTechnicianId = null;
      _knownScheduleSnapshot.clear();
      return;
    }

    if (_initialized) {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null && token.isNotEmpty) {
        await _userRepository.updateDeviceToken(token);
      }
    }

    if (currentUser.role != UserRole.technician) {
      _stopTechnicianPolling();
      _activeTechnicianId = null;
      _knownScheduleSnapshot.clear();
      return;
    }

    final technicianChanged = _activeTechnicianId != currentUser.id;
    _activeTechnicianId = currentUser.id;

    if (technicianChanged || _knownScheduleSnapshot.isEmpty) {
      await _refreshTechnicianAssignments(notifyNewAssignments: false);
    }

    _startTechnicianPolling();
  }

  void _handleTokenRefresh(String token) {
    unawaited(_userRepository.updateDeviceToken(token));
  }

  void _startTechnicianPolling() {
    _technicianPollingTimer?.cancel();
    _technicianPollingTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => unawaited(
        _refreshTechnicianAssignments(notifyNewAssignments: true),
      ),
    );
  }

  void _stopTechnicianPolling() {
    _technicianPollingTimer?.cancel();
    _technicianPollingTimer = null;
  }

  Future<void> _refreshTechnicianAssignments({
    required bool notifyNewAssignments,
  }) async {
    final technicianId = _activeTechnicianId;
    if (technicianId == null) {
      return;
    }

    try {
      final schedules =
          await _scheduleRepository.fetchTechnicianSchedules(technicianId);
      final nextSnapshot = <int, String>{};

      for (final schedule in schedules) {
        nextSnapshot[schedule.id] = schedule.status.name;

        final isNewAssignment = !_knownScheduleSnapshot.containsKey(schedule.id);
        if (!notifyNewAssignments || !isNewAssignment) {
          continue;
        }

        if (_wasRecentlyNotified(schedule.id)) {
          continue;
        }

        _markAsRecentlyNotified(schedule.id);
        await _showLocalNotification(
          id: schedule.id,
          title: 'Novo serviço atribuído',
          body: '${schedule.title} • ${schedule.customer.name}',
          payload: schedule.id.toString(),
        );
      }

      _knownScheduleSnapshot
        ..clear()
        ..addAll(nextSnapshot);
    } catch (_) {
      // polling é fallback silencioso
    }
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    final title =
        message.notification?.title ?? 'Atualização Tracker Carsat';
    final body = message.notification?.body ??
        'Você recebeu uma nova atualização operacional.';
    final ticketId = int.tryParse(message.data['ticket_id']?.toString() ?? '');

    if (ticketId != null) {
      _markAsRecentlyNotified(ticketId);
    }

    await _showLocalNotification(
      id: ticketId ?? DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: title,
      body: body,
      payload: ticketId?.toString(),
    );
  }

  Future<void> _showLocalNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _serviceChannel.id,
        _serviceChannel.name,
        channelDescription: _serviceChannel.description,
        importance: Importance.max,
        priority: Priority.high,
      ),
      iOS: const DarwinNotificationDetails(),
    );

    await _localNotifications.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: details,
      payload: payload,
    );
  }

  void _markAsRecentlyNotified(int scheduleId) {
    _recentlyNotifiedSchedules[scheduleId] = DateTime.now();
    _cleanupRecentlyNotified();
  }

  bool _wasRecentlyNotified(int scheduleId) {
    _cleanupRecentlyNotified();
    final timestamp = _recentlyNotifiedSchedules[scheduleId];
    if (timestamp == null) {
      return false;
    }

    return DateTime.now().difference(timestamp) < const Duration(minutes: 10);
  }

  void _cleanupRecentlyNotified() {
    final now = DateTime.now();
    _recentlyNotifiedSchedules.removeWhere(
      (_, timestamp) => now.difference(timestamp) > const Duration(minutes: 10),
    );
  }
}
