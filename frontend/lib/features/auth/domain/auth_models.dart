/// Authentication session status.
enum AuthStatus {
  /// Checking whether a valid session exists (startup).
  unknown,

  /// No valid session; the user must log in.
  unauthenticated,

  /// Actively refreshing tokens.
  refreshing,

  /// Authenticated with a valid access token.
  authenticated,
}

/// Token pair returned by login and refresh.
class TokenResponse {
  const TokenResponse({
    required this.accessToken,
    required this.refreshToken,
    this.tokenType = 'Bearer',
    this.expiresIn,
  });

  factory TokenResponse.fromJson(Map<String, dynamic> json) {
    return TokenResponse(
      accessToken: json['accessToken'] as String,
      refreshToken: json['refreshToken'] as String,
      tokenType: (json['tokenType'] as String?) ?? 'Bearer',
      expiresIn: json['expiresIn'] as int?,
    );
  }

  final String accessToken;
  final String refreshToken;
  final String tokenType;
  final int? expiresIn;

  Map<String, dynamic> toJson() => {
    'accessToken': accessToken,
    'refreshToken': refreshToken,
    'tokenType': tokenType,
    'expiresIn': expiresIn,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TokenResponse &&
          runtimeType == other.runtimeType &&
          accessToken == other.accessToken &&
          refreshToken == other.refreshToken;

  @override
  int get hashCode => Object.hash(accessToken, refreshToken);
}

/// Result of a successful registration.
class RegisterResult {
  const RegisterResult({required this.userId, required this.username});

  factory RegisterResult.fromJson(Map<String, dynamic> json) {
    return RegisterResult(
      userId: json['userId'] as String,
      username: json['username'] as String,
    );
  }

  final String userId;
  final String username;

  Map<String, dynamic> toJson() => {'userId': userId, 'username': username};
}

/// Identity of the authenticated caller.
class CurrentUser {
  const CurrentUser({
    required this.userId,
    required this.username,
    required this.email,
  });

  factory CurrentUser.fromJson(Map<String, dynamic> json) {
    return CurrentUser(
      userId: json['userId'] as String,
      username: json['username'] as String,
      email: json['email'] as String,
    );
  }

  final String userId;
  final String username;
  final String email;

  Map<String, dynamic> toJson() => {
    'userId': userId,
    'username': username,
    'email': email,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CurrentUser &&
          runtimeType == other.runtimeType &&
          userId == other.userId &&
          username == other.username &&
          email == other.email;

  @override
  int get hashCode => Object.hash(userId, username, email);
}
