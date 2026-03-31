import '../../../core/network/api_client.dart';
import '../domain/customer_lookup_result.dart';

class CustomerRepository {
  CustomerRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<CustomerLookupResult?> lookupByIdentifier(String identifier) async {
    try {
      final response = await _apiClient.getJson(
        '/clients/search',
        query: <String, dynamic>{'identifier': identifier},
      );
      final client = response['client'];
      if (client is! Map) {
        return null;
      }

      final json = client.cast<String, dynamic>();
      return CustomerLookupResult(
        id: int.tryParse((json['id'] ?? 0).toString()) ?? 0,
        name: (json['name'] ?? '').toString(),
        document: (json['identifier'] ?? '').toString(),
        phone: (json['phoneNumber'] ?? '').toString(),
        address: (json['address'] ?? '').toString(),
      );
    } on ApiException catch (error) {
      if (error.isNotFound) {
        return null;
      }
      rethrow;
    }
  }
}
