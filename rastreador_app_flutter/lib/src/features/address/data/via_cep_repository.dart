import 'package:dio/dio.dart';

import '../domain/cep_lookup_result.dart';

class ViaCepRepository {
  ViaCepRepository()
      : _dio = Dio(
          BaseOptions(
            baseUrl: 'https://viacep.com.br/ws',
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 10),
          ),
        );

  final Dio _dio;

  Future<CepLookupResult?> lookupByCep(String cep) async {
    final digits = cep.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 8) {
      throw ViaCepException('Informe um CEP com 8 dígitos.');
    }

    try {
      final response = await _dio.get<dynamic>('/$digits/json/');
      final data = response.data;
      if (data is! Map) {
        throw ViaCepException('Resposta inválida do ViaCEP.');
      }

      final json = data.cast<String, dynamic>();
      if (json['erro'] == true) {
        return null;
      }

      return CepLookupResult.fromJson(json);
    } on DioException {
      throw ViaCepException(
        'Não foi possível consultar o CEP agora. Tente novamente em instantes.',
      );
    }
  }
}

class ViaCepException implements Exception {
  ViaCepException(this.message);

  final String message;

  @override
  String toString() => message;
}
