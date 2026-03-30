import 'package:flutter/foundation.dart';

import '../../../../core/network/api_client.dart';
import '../../../users/data/user_repository.dart';
import '../../../users/domain/app_user.dart';
import '../../data/schedule_repository.dart';
import '../../domain/installation_schedule.dart';
import '../../domain/schedule_status.dart';

class AdminScheduleBoardController extends ChangeNotifier {
  AdminScheduleBoardController(this._scheduleRepository, this._userRepository);

  final ScheduleRepository _scheduleRepository;
  final UserRepository _userRepository;

  bool isLoading = false;
  String? errorMessage;
  List<InstallationSchedule> schedules = const [];
  List<AppUser> technicians = const [];
  ScheduleStatus? selectedStatus;
  String searchQuery = '';

  Future<void> load() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _scheduleRepository.fetchAdminSchedules(),
        _userRepository.fetchTechnicians(),
      ]);

      schedules = results[0] as List<InstallationSchedule>;
      technicians = results[1] as List<AppUser>;
    } catch (error) {
      errorMessage = resolveErrorMessage(error);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void updateStatusFilter(ScheduleStatus? status) {
    selectedStatus = status;
    notifyListeners();
  }

  void updateSearch(String value) {
    searchQuery = value.trim().toLowerCase();
    notifyListeners();
  }

  Future<void> approve({
    required int scheduleId,
    required int technicianId,
  }) async {
    try {
      await _scheduleRepository.approveSchedule(
        scheduleId: scheduleId,
        technicianId: technicianId,
      );
      await load();
    } on ApiException catch (error) {
      errorMessage = error.message;
      notifyListeners();
    }
  }

  Future<void> reject(int scheduleId) async {
    try {
      await _scheduleRepository.rejectSchedule(scheduleId);
      await load();
    } on ApiException catch (error) {
      errorMessage = error.message;
      notifyListeners();
    }
  }

  List<InstallationSchedule> get filteredSchedules {
    return schedules.where((schedule) {
      final matchesStatus =
          selectedStatus == null || schedule.status == selectedStatus;
      final haystack = [
        schedule.protocol,
        schedule.title,
        schedule.customer.name,
        schedule.address.fullText,
        schedule.installer?.name ?? '',
      ].join(' ').toLowerCase();
      final matchesSearch =
          searchQuery.isEmpty || haystack.contains(searchQuery);

      return matchesStatus && matchesSearch;
    }).toList();
  }
}
