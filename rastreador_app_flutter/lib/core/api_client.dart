import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'api_config.dart';

typedef TokenProvider = String? Function();
typedef UnauthorizedHandler = FutureOr<void> Function();

/// API client único do app (Dio + Retry + Erros padronizados).
class ApiClient {
  final Dio _dio;

  ApiClient({
    TokenProvider? tokenProvider,
    UnauthorizedHandler? onUnauthorized,
  }) : _dio = Dio(BaseOptions(
          baseUrl: apiBaseUrl,
          connectTimeout: apiTimeout,
          receiveTimeout: apiTimeout,
          sendTimeout: apiTimeout,
          headers: {'Content-Type': 'application/json'},
        )) {
    _dio.interceptors.add(_AuthInterceptor(tokenProvider, onUnauthorized));
    _dio.interceptors.add(_RetryInterceptor(_dio));
    _dio.interceptors.add(LogInterceptor(
      requestBody: kDebugMode,
      responseBody: kDebugMode,
      logPrint: (o) => debugPrint(o.toString()),
    ));
  }

  Future<Map<String, dynamic>> getJson(String path,
      {Map<String, dynamic>? query}) async {
    final res = await _safeRequest(() => _dio.get(path, queryParameters: query));
    return _decodeJsonMap(res.data);
  }

  Future<List<dynamic>> getJsonList(String path,
      {Map<String, dynamic>? query}) async {
    final res = await _safeRequest(() => _dio.get(path, queryParameters: query));
    return _decodeJsonList(res.data);
  }

  Future<Map<String, dynamic>> postJson(String path,
      {Map<String, dynamic>? body}) async {
    final res = await _safeRequest(() => _dio.post(path, data: body ?? {}));
    return _decodeJsonMap(res.data);
  }

  Future<Map<String, dynamic>> putJson(String path,
      {Map<String, dynamic>? body}) async {
    final res = await _safeRequest(() => _dio.put(path, data: body ?? {}));
    return _decodeJsonMap(res.data);
  }

  Future<void> delete(String path) async {
    await _safeRequest(() => _dio.delete(path));
  }

  Future<Response<dynamic>> _safeRequest(
      Future<Response<dynamic>> Function() request) async {
    try {
      return await request();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    } catch (e) {
      throw ApiException('Erro inesperado: $e');
    }
  }

  Map<String, dynamic> _decodeJsonMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is String) return (jsonDecode(data) as Map).cast<String, dynamic>();
    throw ApiException('Resposta inválida do servidor.');
  }

  List<dynamic> _decodeJsonList(dynamic data) {
    if (data is List) return data;
    if (data is String) return jsonDecode(data) as List<dynamic>;
    throw ApiException('Resposta inválida do servidor.');
  }
}

class ApiException implements Exception {
  final String message;
  final int statusCode;

  ApiException(this.message, [this.statusCode = 0]);

  factory ApiException.fromDio(DioException e) {
    final status = e.response?.statusCode ?? 0;

    String msg = 'Falha na comunicação com o servidor.';
    final data = e.response?.data;
    if (data is Map && data['message'] != null) {
      msg = data['message'].toString();
    } else if (data is String && data.trim().isNotEmpty) {
      msg = data;
    } else if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout) {
      msg = 'Tempo de conexão esgotado. Tente novamente.';
    } else if (e.type == DioExceptionType.connectionError) {
      msg = 'Sem internet ou servidor indisponível.';
    } else if (status == 401) {
      msg = 'Sessão expirada. Faça login novamente.';
    } else if (status >= 500) {
      msg = 'Erro interno no servidor. Tente mais tarde.';
    }

    return ApiException(msg, status);
  }

  @override
  String toString() => 'ApiException($statusCode): $message';
}

class _AuthInterceptor extends Interceptor {
  final TokenProvider? _tokenProvider;
  final UnauthorizedHandler? _onUnauthorized;

  _AuthInterceptor(this._tokenProvider, this._onUnauthorized);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final token = _tokenProvider?.call();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401) {
      await _onUnauthorized?.call();
    }
    handler.next(err);
  }
}

/// Retry simples para falhas de rede/timeout (máx. 2 tentativas).
class _RetryInterceptor extends Interceptor {
  final Dio _dio;
  _RetryInterceptor(this._dio);

  static const int _maxRetries = 2;

  bool _shouldRetry(DioException e) {
    final t = e.type;
    return t == DioExceptionType.connectionTimeout ||
        t == DioExceptionType.receiveTimeout ||
        t == DioExceptionType.sendTimeout ||
        t == DioExceptionType.connectionError;
  }

  @override
  Future<void> onError(
      DioException err, ErrorInterceptorHandler handler) async {
    final req = err.requestOptions;
    final retries = (req.extra['retries'] as int?) ?? 0;

    if (retries < _maxRetries && _shouldRetry(err)) {
      req.extra['retries'] = retries + 1;
      final delayMs = 250 * (1 << retries);
      await Future.delayed(Duration(milliseconds: delayMs));

      try {
        final response = await _dio.fetch(req);
        handler.resolve(response);
        return;
      } catch (_) {}
    }

    handler.next(err);
  }
}
