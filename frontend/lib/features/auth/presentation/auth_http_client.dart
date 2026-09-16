import 'package:http/http.dart' as http;

import '../../../data/api/api_paths.dart';
import 'auth_state.dart';

/// HTTP transport that injects the bearer access token and transparently
/// recovers from `401`s by rotating the refresh token once.
///
/// Responsibilities:
/// - attach `Authorization: Bearer <accessToken>` to every request when a
///   token exists (public auth endpoints are left alone),
/// - on a `401`, trigger a single, serialized refresh (see [AuthState.
///   attemptRefresh]) and retry the original request exactly once with the new
///   token,
/// - when the refresh fails, clear the session so the `401` propagates as an
///   ordinary API error,
/// - never log access/refresh tokens.
class AuthenticatedHttpClient extends http.BaseClient {
  AuthenticatedHttpClient({required AuthState authState, http.Client? inner})
    : _auth = authState,
      _inner = inner ?? http.Client();

  final AuthState _auth;
  final http.Client _inner;

  /// Paths that are always public and must never receive the bearer header or
  /// a 401-refresh retry.
  static const _publicPaths = <String>{
    '/api/v1/auth/login',
    '/api/v1/auth/register',
    '/api/v1/auth/refresh',
    '/api/v1/auth/logout',
  };

  static const _retriedMarker = 'x-auth-retried';

  /// Public health endpoints (server-side `permitAll`). Distinct from the auth
  /// paths because `/api/v1/health/...` is a prefix family, not a single path.
  static const _healthPrefix = '${ApiPaths.v1}/health';

  bool _isPublic(http.BaseRequest request) {
    final path = request.url.path;
    return _publicPaths.any(path.endsWith) || path.startsWith(_healthPrefix);
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final public = _isPublic(request);
    if (!public && _auth.accessToken != null) {
      request.headers['Authorization'] = 'Bearer ${_auth.accessToken}';
    }

    final first = await _inner.send(request);
    if (public ||
        first.statusCode != 401 ||
        _auth.accessToken == null ||
        request.headers.containsKey(_retriedMarker)) {
      return first;
    }

    // A 401 on a protected request — try a single refresh, then retry once.
    final refreshed = await _auth.attemptRefresh();
    if (refreshed && _auth.accessToken != null) {
      final retry = http.Request(request.method, request.url)
        ..headers.addAll(request.headers)
        ..headers['Authorization'] = 'Bearer ${_auth.accessToken}'
        ..headers[_retriedMarker] = 'true';
      if (request is http.Request) {
        retry.body = request.body;
      }
      return _inner.send(retry);
    }

    // Refresh failed — session already cleared; surface the original 401.
    return first;
  }
}
