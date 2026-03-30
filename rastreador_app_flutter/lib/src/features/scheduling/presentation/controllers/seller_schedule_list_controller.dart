import 'package:flutter/foundation.dart';

import '../../../../core/network/api_client.dart';
import '../../data/schedule_repository.dart';
import '../../domain/installation_schedule.dart';
import '../../domain/schedule_status.dart';

class SellerScheduleListController extends ChangeNotifier {
  SellerScheduleListController(this._repository, this._sellerId);

  final ScheduleRepository _repository;
  final int _sellerId;

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
      schedules = await _repository.fetchSellerSchedules(_sellerId);
    } catch (error) {
      errorMessage = resolveErrorMessage(error);
    } finally {
      isLoading = false;
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
