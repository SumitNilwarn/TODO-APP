import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import '../../core/config/app_config.dart';
import 'api_envelope.dart';
import 'api_exception.dart';
import 'api_interceptor.dart';
import 'api_response.dart';

/// Thin HTTP/JSON client for the Todo App backend.
///
/// Responsibilities (foundation only — no feature endpoints yet):
///
/// - resolve the base URL from [AppConfig.apiBaseUrl] (overridable for tests),
/// - send `GET`/`POST`/`PUT`/`PATCH`/`DELETE` requests with JSON defaults,
/// - run registered [ApiInterceptor]s around the request lifecycle,
/// - parse the backend `ApiResponse`/`ApiError` envelopes and return typed
///   [ApiResponse]s or throw [ApiException]s.
///
/// Feature repositories (auth, profile, tasks, dashboard) are added in later
/// phases on top of this client; no feature endpoint exists here.
class ApiClient {
  ApiClient({
    String? baseUrl,
    http.Client? httpClient,
    List<ApiInterceptor>? interceptors,
    this.timeout = const Duration(seconds: 20),
  }) : baseUrl = _normalizeBaseUrl(baseUrl ?? AppConfig.apiBaseUrl),
       _http = httpClient ?? http.Client(),
       _interceptors = List.unmodifiable(interceptors ?? const []);

  /// Normalized backend origin (no trailing slash).
  final String baseUrl;

  final Duration timeout;

  final http.Client _http;
  final List<ApiInterceptor> _interceptors;

  static const Map<String, String> _defaultHeaders = {
    'Accept': 'application/json',
    'Content-Type': 'application/json',
  };

  /// Request header and query the backend's [CorrelationIdFilter] reads/mirrors
  /// so a web request can be joined to the server's log line.
  static const String correlationIdHeader = 'X-Correlation-Id';

  static const int _correlationIdBytes = 16;

  /// Perform a `GET` and decode the envelope `data` with [dataParser].
  Future<ApiResponse<T>> get<T>(
    String path, {
    Map<String, String>? queryParameters,
    Map<String, String>? headers,
    required T Function(dynamic data) dataParser,
  }) {
    return _send<T>(
      method: 'GET',
      path: path,
      queryParameters: queryParameters,
      body: null,
      headers: headers,
      dataParser: dataParser,
    );
  }

  /// Perform a `POST` (JSON body) and decode the envelope `data`.
  Future<ApiResponse<T>> post<T>(
    String path, {
    Object? body,
    Map<String, String>? headers,
    required T Function(dynamic data) dataParser,
  }) {
    return _send<T>(
      method: 'POST',
      path: path,
      body: body,
      headers: headers,
      dataParser: dataParser,
    );
  }

  /// Perform a `PUT` (JSON body) and decode the envelope `data`.
  Future<ApiResponse<T>> put<T>(
    String path, {
    Object? body,
    Map<String, String>? headers,
    required T Function(dynamic data) dataParser,
  }) {
    return _send<T>(
      method: 'PUT',
      path: path,
      body: body,
      headers: headers,
      dataParser: dataParser,
    );
  }

  /// Perform a `PATCH` (JSON body) and decode the envelope `data`.
  Future<ApiResponse<T>> patch<T>(
    String path, {
    Object? body,
    Map<String, String>? headers,
    required T Function(dynamic data) dataParser,
  }) {
    return _send<T>(
      method: 'PATCH',
      path: path,
      body: body,
      headers: headers,
      dataParser: dataParser,
    );
  }

  /// Perform a `DELETE` and decode the envelope `data`.
  Future<ApiResponse<T>> delete<T>(
    String path, {
    Map<String, String>? headers,
    required T Function(dynamic data) dataParser,
  }) {
    return _send<T>(
      method: 'DELETE',
      path: path,
      headers: headers,
      dataParser: dataParser,
    );
  }

  Future<ApiResponse<T>> _send<T>({
    required String method,
    required String path,
    Map<String, String>? queryParameters,
    Object? body,
    Map<String, String>? headers,
    required T Function(dynamic data) dataParser,
  }) async {
    final uri = _resolveUri(path, queryParameters);
    final requestHeaders = <String, String>{..._defaultHeaders, ...?headers}
      ..putIfAbsent(correlationIdHeader, _generateCorrelationId);
    final request = ApiRequestData(
      method: method,
      uri: uri,
      headers: requestHeaders,
      body: body,
    );

    final http.Request wireRequest;
    try {
      for (final interceptor in _interceptors) {
        await interceptor.onRequest(request);
      }

      wireRequest = http.Request(request.method, request.uri)
        ..headers.addAll(request.headers);
      final payload = request.body;
      if (payload != null &&
          request.method != 'GET' &&
          request.method != 'DELETE') {
        wireRequest.body = payload is String ? payload : jsonEncode(payload);
      }

      final streamed = await _http.send(wireRequest).timeout(timeout);
      // `send()` completes once response headers arrive; the body may still be
      // streaming, so the read is covered by the same timeout budget.
      final bodyText = await streamed.stream.bytesToString().timeout(timeout);

      final response = ApiResponseData(
        statusCode: streamed.statusCode,
        headers: streamed.headers,
        body: bodyText,
        correlationId: streamed.headers['x-correlation-id'],
      );
      for (final interceptor in _interceptors) {
        await interceptor.onResponse(request, response);
      }

      return _decode<T>(response, dataParser);
    } on TimeoutException catch (error) {
      final api = ApiException.timeout(error);
      await _notifyError(request, api);
      throw api;
    } on http.ClientException catch (error) {
      final api = ApiException.network(error);
      await _notifyError(request, api);
      throw api;
    } on FormatException catch (error) {
      final api = ApiException.invalid(cause: error);
      await _notifyError(request, api);
      throw api;
    } on ApiException catch (error) {
      await _notifyError(request, error);
      rethrow;
    } catch (error) {
      final api = ApiException(
        kind: ApiExceptionKind.unexpected,
        code: 'REQUEST_FAILED',
        cause: error,
      );
      await _notifyError(request, api);
      throw api;
    }
  }

  Future<void> _notifyError(ApiRequestData request, Object error) async {
    for (final interceptor in _interceptors) {
      try {
        await interceptor.onError(request, error);
      } catch (_) {
        // Interceptor failures must never mask the original API error.
      }
    }
  }

  ApiResponse<T> _decode<T>(
    ApiResponseData response,
    T Function(dynamic data) dataParser,
  ) {
    final body = response.body;

    // Empty body on success (e.g. 204) carries no `data`.
    if (_isSuccess(response.statusCode) && body.trim().isEmpty) {
      return ApiResponse<T>.success(null);
    }

    // Any response must be a JSON envelope according to the API contract.
    final Object decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      if (_isSuccess(response.statusCode)) {
        throw ApiException.invalid(statusCode: response.statusCode);
      }
      // Non-JSON error body (e.g. a gateway page) — surface the HTTP status.
      throw ApiException(
        kind: ApiExceptionKind.invalid,
        statusCode: response.statusCode,
        code: 'HTTP_${response.statusCode}',
        message: 'The server returned HTTP ${response.statusCode}.',
      );
    }
    if (decoded is! Map<String, dynamic>) {
      throw ApiException.invalid(statusCode: response.statusCode);
    }

    final envelope = ApiEnvelope.fromJson(decoded);

    if (_isSuccess(response.statusCode)) {
      return ApiResponse<T>.fromEnvelope(envelope, dataParser: dataParser);
    }

    if (envelope.hasError) {
      throw ApiException.fromError(
        envelope.error!,
        statusCode: response.statusCode,
        path: envelope.path,
        timestamp: envelope.timestamp,
        correlationId: response.correlationId,
      );
    }

    // Non-2xx without a parseable error envelope — surface a generic failure.
    throw ApiException(
      kind: ApiExceptionKind.invalid,
      statusCode: response.statusCode,
      code: 'HTTP_${response.statusCode}',
      message: 'The server returned HTTP ${response.statusCode}.',
    );
  }

  Uri _resolveUri(String path, Map<String, String>? queryParameters) {
    final normalized = path.startsWith('/') ? path : '/$path';
    final uri = Uri.parse('$baseUrl$normalized');
    if (queryParameters == null || queryParameters.isEmpty) {
      return uri;
    }
    return uri.replace(queryParameters: queryParameters);
  }

  bool _isSuccess(int statusCode) => statusCode >= 200 && statusCode < 300;

  /// Generates a compact random hex token the backend will echo.
  static String _generateCorrelationId() {
    final random = Random.secure();
    final bytes = List<int>.generate(
      _correlationIdBytes,
      (_) => random.nextInt(256),
    );
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  static String _normalizeBaseUrl(String baseUrl) {
    return baseUrl.trim().replaceFirst(RegExp(r'/+$'), '');
  }
}
