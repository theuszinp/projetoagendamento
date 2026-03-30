import 'package:flutter/foundation.dart';

import '../../../../core/network/api_client.dart';
import '../../data/schedule_repository.dart';
import '../../domain/installation_schedule.dart';
import '../../domain/schedule_status.dart';

class TechnicianAgendaController extends ChangeNotifier {
  TechnicianAgendaController(this._repository, this._technicianId);

  final ScheduleRepository _repository;
  final int _technicianId;

  bool isLoading = false;
  String? errorMessage;
  List<InstallationSchedule> schedules = const [];
  ScheduleStatus? selectedStatus;
  String searchQuery = '';

  Future<void> load() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      schedules = await _repository.fetchTechnicianSchedules(_technicianId);
    } catch (error) {
      errorMessage = resolveErrorMessage(error);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> startJob(int scheduleId) async {
    try {
      await _repository.startService(scheduleId);
      await load();
    } on ApiException catch (error) {
      errorMessage = error.message;
      notifyListeners();
    }
  }

  Future<void> completeJob(int scheduleId) async {
    try {
      await _repository.completeService(scheduleId);
      await load();
    } on ApiException catch (error) {
      errorMessage = error.message;
      notifyListeners();
    }
  }

  void updateStatus(ScheduleStatus? status) {
    selectedStatus = status;
    notifyListeners();
  }

  void updateSearch(String value) {
    searchQuery = value.trim().toLowerCase();
    notifyListeners();
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
      ].join(' ').toLowerCase();
      final matchesSearch =
          searchQuery.isEmpty || haystack.contains(searchQuery);

      return matchesStatus && matchesSearch;
    }).toList();
  }
}
