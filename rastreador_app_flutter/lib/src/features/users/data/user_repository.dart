import '../../../core/network/api_client.dart';
import '../domain/app_user.dart';
import '../domain/technician_workload.dart';

class UserRepository {
  UserRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<List<AppUser>> fetchAllUsers() async {
    final response = await _apiClient.getJson('/users');
    final list = (response['users'] as List?) ?? const [];
    return list
        .map((item) => AppUser.fromJson((item as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<List<AppUser>> fetchPendingUsers() async {
    try {
      final response = await _apiClient.getJson('/pending-users');
      final list = (response['users'] as List?) ?? const [];
      return list
          .map((item) => AppUser.fromJson((item as Map).cast<String, dynamic>()))
          .toList();
    } on ApiException catch (error) {
      if (error.isNotFound) {
        return const [];
      }
      rethrow;
    }
  }

  Future<void> approveUser(int userId) async {
    try {
      await _apiClient.putJson('/approve-user/$userId');
    } on ApiException catch (error) {
      if (error.isNotFound) {
        throw ApiException(
          'Seu backend atual ainda não suporta aprovação de usuários por esta rota.',
          error.statusCode,
        );
      }
      rethrow;
    }
  }

  Future<List<AppUser>> fetchTechnicians() async {
    final response = await _apiClient.getJson('/users/technicians');
    final list = (response['technicians'] as List?) ?? const [];
    return list
        .map((item) => AppUser.fromJson((item as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<List<TechnicianWorkload>> fetchTechnicianWorkloads() async {
    try {
      final response = await _apiClient.getJson('/reports/tech-summary');
      final rows = (response['rows'] as List?) ?? const [];
      return rows
          .map(
            (item) => TechnicianWorkload.fromJson(
              (item as Map).cast<String, dynamic>(),
            ),
          )
          .toList();
    } on ApiException catch (error) {
      if (error.isNotFound) {
        return const [];
      }
      rethrow;
    }
  }
}
