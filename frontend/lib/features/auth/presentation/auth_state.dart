import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../../core/config/app_config.dart';
import '../../../data/api/api_client.dart';
import '../../../data/api/api_exception.dart';
import '../../../data/api/api_paths.dart';
import '../domain/auth_models.dart';
import '../data/auth_api.dart';
import 'auth_http_client.dart';

/// Central authentication/session controller.
///
/// Owns the in-memory session (access token + refresh token + current user)
/// and the explicit [AuthStatus] lifecycle. The access token is never
/// persisted and never logged; on a browser reload the session is forgotten
/// and the user must sign in again — the safest practical strategy for a
/// public web client without synthetic credentials.
///
/// [AuthState] also builds the app's HTTP transport:
/// - [apiClient] is the transport-backed [ApiClient] used by every feature.
///   Public auth paths pass through untouched; protected paths get the bearer
///   header and a transparent 401 → refresh → retry cycle (see
///   [AuthenticatedHttpClient]).
/// - The refresh request itself and the repository calls made *by* the auth
///   flow use the raw injected client (`_http`), never the authenticated
///   transport, so a single stale `401` can never re-enter the refresh path.
///
/// Token refresh is deduplicated: concurrent `401`s share one in-flight
/// refresh ([attemptRefresh]), so the backend's single-use refresh token can
/// never be rotated twice by a single wave of parallel requests.
class AuthState extends ChangeNotifier {
  AuthState({String? apiBaseUrl, http.Client? httpClient})
    : _apiBaseUrl = _trimBaseUrl(apiBaseUrl ?? AppConfig.apiBaseUrl),
      _http = httpClient ?? http.Client() {
    _apiClient = ApiClient(
      baseUrl: _apiBaseUrl,
      httpClient: AuthenticatedHttpClient(authState: this, inner: _http),
    );
    _authApi = AuthApi(_apiClient);
  }

  final String _apiBaseUrl;

  /// The raw (unauthenticated) transport used for refresh + the auth calls.
  /// Never wrapped by [AuthenticatedHttpClient], so refreshing can never
  /// trigger another refresh.
  final http.Client _http;

  late final ApiClient _apiClient;
  late final AuthApi _authApi;

  AuthStatus _status = AuthStatus.unknown;
  String? _accessToken;
  String? _refreshToken;
  CurrentUser? _user;

  /// In-flight refresh future — the serialization point for concurrent 401s.
  Future<bool>? _pendingRefresh;

  String? _lastError;

  AuthStatus get status => _status;
  CurrentUser? get user => _user;
  String? get username => _user?.username;

  /// The authenticated [ApiClient] shared by every feature repository.
  ApiClient get apiClient => _apiClient;

  AuthApi get api => _authApi;

  /// The short-lived access token, in memory only.
  String? get accessToken => _accessToken;

  /// The opaque refresh token, in memory only. Exposed for logout/refresh but
  /// never rendered in the UI and never logged.
  String? get refreshToken => _refreshToken;

  bool get isAuthenticated => _status == AuthStatus.authenticated;
  bool get isUnknown => _status == AuthStatus.unknown;
  bool get hasTokens => _accessToken != null && _refreshToken != null;
  bool get hasRefreshToken => _refreshToken != null;

  /// Resolves whether a usable session exists at startup.
  ///
  /// With the in-memory strategy there is nothing to restore across reloads,
  /// so the caller immediately reports unauthenticated. If tokens happen to
  /// still be in memory (e.g. hot restart during development) the session is
  /// re-validated with `/auth/me` and a refresh if needed.
  Future<void> initialise() async {
    if (!hasTokens) {
      _lastError = null;
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return;
    }
    _status = AuthStatus.refreshing;
    notifyListeners();

    if (await _refreshIfNeeded()) {
      await _loadCurrentUser();
    } else {
      _clear();
    }
  }

  /// Attempts a login and loads the caller identity on success.
  Future<bool> login({
    required String username,
    required String password,
  }) async {
    try {
      _status = AuthStatus.refreshing;
      notifyListeners();

      final tokens = await api.login(username: username, password: password);
      _accessToken = tokens.accessToken;
      _refreshToken = tokens.refreshToken;
      return await _loadCurrentUser();
    } on ApiException catch (error) {
      _lastError = _friendlyLoginError(error);
      _clear();
      return false;
    } catch (_) {
      _lastError = 'Could not reach the server. Please try again.';
      _clear();
      return false;
    }
  }

  /// Registers a new account, then returns to the login flow.
  Future<bool> register({
    required String username,
    required String email,
    required String password,
  }) async {
    try {
      _status = AuthStatus.refreshing;
      notifyListeners();
      await api.register(username: username, email: email, password: password);
      _status = AuthStatus.unauthenticated;
      _lastError = null;
      notifyListeners();
      return true;
    } on ApiException catch (error) {
      _lastError = _friendlyRegisterError(error);
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return false;
    } catch (_) {
      _lastError = 'Could not reach the server. Please try again.';
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return false;
    }
  }

  /// Reveals the last user-facing auth error. Safe for on-screen rendering.
  String? get lastError => _lastError;

  /// Best-effort logout: revokes the refresh session server-side when one
  /// exists, then clears local state regardless of the outcome.
  Future<void> logout() async {
    final refresh = _refreshToken;
    if (refresh != null) {
      try {
        await api.logout(refresh);
      } catch (_) {
        // Backend logout is best-effort; local state must still be cleared.
      }
    }
    _clear();
  }

  /// Clears local auth state; always safe to call.
  void clearSession() => _clear();

  /// Attempts a single refresh, serializing concurrent callers onto one
  /// in-flight rotation. Returns `true` when a fresh token pair was stored.
  ///
  /// Prefer this over inline refresh logic everywhere a `401` is observed so
  /// the single-use refresh token is never raced by parallel requests.
  Future<bool> attemptRefresh() async {
    if (_pendingRefresh != null) {
      return _pendingRefresh!;
    }
    _pendingRefresh = _doRefresh();
    try {
      return await _pendingRefresh!;
    } finally {
      _pendingRefresh = null;
    }
  }

  Future<bool> _refreshIfNeeded() async {
    if (!hasRefreshToken) {
      return false;
    }
    final ok = await attemptRefresh();
    if (!ok) {
      _clear();
    }
    return ok;
  }

  Future<bool> _doRefresh() async {
    final refresh = _refreshToken;
    if (refresh == null) {
      return false;
    }

    _status = AuthStatus.refreshing;
    notifyListeners();

    try {
      final response = await _http
          .post(
            Uri.parse('$_apiBaseUrl${ApiPaths.authRefresh}'),
            headers: const {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'refreshToken': refresh}),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic> && decoded['success'] == true) {
          final data = decoded['data'];
          if (data is Map<String, dynamic>) {
            final tokens = TokenResponse.fromJson(data);
            _accessToken = tokens.accessToken;
            _refreshToken = tokens.refreshToken;
            notifyListeners();
            return true;
          }
        }
      }
    } catch (_) {
      // Network/timeout — refresh failed; the session must be cleared.
    }
    _clear();
    return false;
  }

  Future<bool> _loadCurrentUser() async {
    try {
      final user = await api.me();
      _user = user;
      _lastError = null;
      _status = AuthStatus.authenticated;
      notifyListeners();
      return true;
    } on ApiException catch (error) {
      _lastError = _friendlySessionError(error);
      _clear();
      return false;
    } catch (_) {
      _lastError = 'Could not reach the server. Please try again.';
      _clear();
      return false;
    }
  }

  void _clear() {
    _accessToken = null;
    _refreshToken = null;
    _user = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  @override
  void dispose() {
    _pendingRefresh = null;
    _http.close();
    super.dispose();
  }

  static String _trimBaseUrl(String baseUrl) =>
      baseUrl.trim().replaceFirst(RegExp(r'/+$'), '');

  // -------------------------------------------------------------------------
  // Error translation — never exposes internals, tokens or stack traces.
  // -------------------------------------------------------------------------

  static String _friendlyLoginError(ApiException error) {
    return switch (error.code) {
      'AUTHENTICATION_FAILED' =>
        'Invalid username or password. Please try again.',
      'ACCOUNT_DISABLED' => 'This account has been disabled.',
      'ACCOUNT_LOCKED' => 'This account has been locked.',
      'VALIDATION_ERROR' => _formatValidation(error),
      _ => _genericError(error),
    };
  }

  static String _friendlyRegisterError(ApiException error) {
    return switch (error.code) {
      'USERNAME_ALREADY_TAKEN' =>
        'That username is already taken. Choose another.',
      'EMAIL_ALREADY_TAKEN' => 'That email address is already registered.',
      'ACCOUNT_ALREADY_EXISTS' =>
        'An account with those details already exists.',
      'VALIDATION_ERROR' => _formatValidation(error),
      'MALFORMED_REQUEST' => 'The submission was not valid. Please try again.',
      _ => _genericError(error),
    };
  }

  static String _friendlySessionError(ApiException error) {
    return switch (error.code) {
      'REFRESH_TOKEN_EXPIRED' =>
        'Your session has expired. Please sign in again.',
      'REFRESH_TOKEN_INVALID' =>
        'Your session is no longer valid. Please sign in again.',
      _ => 'Your session could not be restored. Please sign in again.',
    };
  }

  static String _formatValidation(ApiException error) {
    if (error.details.isEmpty) {
      return 'Some details are not valid. Please check the form.';
    }
    final messages = error.details
        .map((detail) => detail.message ?? 'Invalid value')
        .where((m) => m.isNotEmpty)
        .toList();
    if (messages.isEmpty) {
      return 'Some details are not valid. Please check the form.';
    }
    return messages.join(' ');
  }

  static String _genericError(ApiException error) {
    if (error.isNetworkError) {
      return 'Could not reach the server. Please check your connection.';
    }
    if (error.isTimeout) {
      return 'The server took too long to respond. Please try again.';
    }
    return 'Something went wrong. Please try again.';
  }
}
