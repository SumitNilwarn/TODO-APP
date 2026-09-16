import '../../../data/api/api_client.dart';
import '../../../data/api/api_paths.dart';
import '../domain/auth_models.dart';

/// Typed access to the backend authentication endpoints.
///
/// Generated through [ApiClient], which parses the envelope and throws an
/// [ApiException] on every non-success status. Screen code never talks to
/// HTTP directly; it goes through [AuthApi] (or [AuthState]).
class AuthApi {
  const AuthApi(this._client);

  final ApiClient _client;

  static CurrentUser _parseUser(dynamic data) =>
      CurrentUser.fromJson((data as Map).cast<String, dynamic>());

  static TokenResponse _parseTokens(dynamic data) =>
      TokenResponse.fromJson((data as Map).cast<String, dynamic>());

  static RegisterResult _parseRegister(dynamic data) =>
      RegisterResult.fromJson((data as Map).cast<String, dynamic>());

  /// POST /auth/login — returns the token pair for the session.
  Future<TokenResponse> login({
    required String username,
    required String password,
  }) async {
    final response = await _client.post<TokenResponse>(
      ApiPaths.authLogin,
      body: {'username': username, 'password': password},
      dataParser: _parseTokens,
    );
    return response.data!;
  }

  /// POST /auth/register — creates the account and returns its stable
  /// identity. The caller then proceeds to login for credentials.
  Future<RegisterResult> register({
    required String username,
    required String email,
    required String password,
  }) async {
    final response = await _client.post<RegisterResult>(
      ApiPaths.authRegister,
      body: {'username': username, 'email': email, 'password': password},
      dataParser: _parseRegister,
    );
    return response.data!;
  }

  /// POST /auth/refresh — rotates the opaque refresh token.
  Future<TokenResponse> refresh(String refreshToken) async {
    final response = await _client.post<TokenResponse>(
      ApiPaths.authRefresh,
      body: {'refreshToken': refreshToken},
      dataParser: _parseTokens,
    );
    return response.data!;
  }

  /// POST /auth/logout — revokes the server-side refresh session.
  /// Idempotent: the backend always answers 200 for the caller.
  Future<void> logout(String refreshToken) async {
    await _client.post<void>(
      ApiPaths.authLogout,
      body: {'refreshToken': refreshToken},
      dataParser: (_) {},
    );
  }

  /// GET /auth/me — the authenticated caller's identity.
  Future<CurrentUser> me() async {
    final response = await _client.get<CurrentUser>(
      ApiPaths.authMe,
      dataParser: _parseUser,
    );
    return response.data!;
  }
}
