import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'api_config.dart';

typedef TokenProvider = String? Function();
typedef UnauthorizedHandler = FutureOr<void> Function();

class ApiClient {
  ApiClient({
    TokenProvider? tokenProvider,
    UnauthorizedHandler? onUnauthorized,
  }) : _dio = Dio(
          BaseOptions(
            baseUrl: apiBaseUrl,
            connectTimeout: apiTimeout,
            receiveTimeout: apiTimeout,
            sendTimeout: apiTimeout,
            headers: const {'Content-Type': 'application/json'},
          ),
        ) {
    _dio.interceptors.add(_AuthInterceptor(tokenProvider, onUnauthorized));
    _dio.interceptors.add(_RetryInterceptor(_dio));
    _dio.interceptors.add(
      LogInterceptor(
        requestBody: kDebugMode,
        responseBody: kDebugMode,
        logPrint: (value) => debugPrint(value.toString()),
      ),
    );
  }

  final Dio _dio;

  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    final response = await _request(() => _dio.get(path, queryParameters: query));
    return _decodeMap(response.data);
  }

  Future<Map<String, dynamic>> postJson(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final response = await _request(() => _dio.post(path, data: body ?? {}));
    return _decodeMap(response.data);
  }

  Future<Map<String, dynamic>> putJson(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final response = await _request(() => _dio.put(path, data: body ?? {}));
    return _decodeMap(response.data);
  }

  Future<Response<dynamic>> _request(
    Future<Response<dynamic>> Function() request,
  ) async {
    try {
      return await request();
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    } catch (error) {
      throw ApiException('Erro inesperado na comunicação: $error');
    }
  }

  Map<String, dynamic> _decodeMap(dynamic data) {
    if (data is Map<String, dynamic>) {
      return data;
    }

    if (data is String && data.isNotEmpty) {
      return (jsonDecode(data) as Map).cast<String, dynamic>();
    }

    throw ApiException('Resposta inválida do servidor.');
  }
}

class ApiException implements Exception {
  ApiException(this.message, [this.statusCode = 0]);

  final String message;
  final int statusCode;

  bool get isNotFound => statusCode == 404;

  bool get isUnauthorized => statusCode == 401 || statusCode == 403;

  factory ApiException.fromDio(DioException error) {
    final statusCode = error.response?.statusCode ?? 0;
    final responseData = error.response?.data;

    if (responseData is Map && responseData['message'] != null) {
      return ApiException(responseData['message'].toString(), statusCode);
    }

    if (responseData is Map && responseData['error'] != null) {
      return ApiException(responseData['error'].toString(), statusCode);
    }

    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout) {
      return ApiException(
        'O servidor demorou para responder. Tente novamente.',
        statusCode,
      );
    }

    if (error.type == DioExceptionType.connectionError) {
      return ApiException('Sem internet ou API indisponível.', statusCode);
    }

    if (statusCode == 401) {
      return ApiException('Sua sessão expirou. Faça login novamente.', statusCode);
    }

    if (statusCode >= 500) {
      return ApiException('Erro interno no servidor.', statusCode);
    }

    return ApiException('Falha ao processar a solicitação.', statusCode);
  }

  @override
  String toString() => message;
}

String resolveErrorMessage(Object error) {
  if (error is ApiException) {
    return error.message;
  }

  return error.toString();
}

class _AuthInterceptor extends Interceptor {
  _AuthInterceptor(this._tokenProvider, this._onUnauthorized);

  final TokenProvider? _tokenProvider;
  final UnauthorizedHandler? _onUnauthorized;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final token = _tokenProvider?.call();

    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }

    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (err.response?.statusCode == 401) {
      await _onUnauthorized?.call();
    }

    handler.next(err);
  }
}

class _RetryInterceptor extends Interceptor {
  _RetryInterceptor(this._dio);

  final Dio _dio;
  static const _maxRetries = 2;

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final shouldRetry = err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.receiveTimeout ||
        err.type == DioExceptionType.sendTimeout ||
        err.type == DioExceptionType.connectionError;

    final retries = (err.requestOptions.extra['retries'] as int?) ?? 0;

    if (shouldRetry && retries < _maxRetries) {
      err.requestOptions.extra['retries'] = retries + 1;
      await Future<void>.delayed(Duration(milliseconds: 250 * (1 << retries)));

      try {
        final response = await _dio.fetch(err.requestOptions);
        handler.resolve(response);
        return;
      } catch (_) {
        // segue o fluxo normal de erro
      }
    }

    handler.next(err);
  }
}
