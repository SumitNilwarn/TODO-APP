import '../../../data/api/api_client.dart';
import '../../../data/api/api_exception.dart';
import '../../../data/api/api_paths.dart';
import '../domain/profile_models.dart';

/// Typed access to the backend profile endpoints.
///
/// Mirrors the exact `ProfileResponse`/`ProfileUpdateRequest` wire contract.
/// Identity/ownership always comes from the backend principal — the client
/// never sends a user id.
class ProfileApi {
  const ProfileApi(this._client);

  final ApiClient _client;

  static ProfileResponse _parseProfile(dynamic data) =>
      ProfileResponse.fromJson((data as Map).cast<String, dynamic>());

  /// GET /profile — the caller's profile.
  ///
  /// Throws [ApiException] with `PROFILE_NOT_FOUND` (404) when the profile
  /// has not been created yet.
  Future<ProfileResponse> getProfile() async {
    final response = await _client.get<ProfileResponse>(
      ApiPaths.profile,
      dataParser: _parseProfile,
    );
    return response.data!;
  }

  /// PUT /profile — full replacement; creates the profile on first use.
  ///
  /// Every editable field is sent (a `null` value clears it server-side).
  Future<ProfileResponse> updateProfile(ProfileUpdateRequest request) async {
    final response = await _client.put<ProfileResponse>(
      ApiPaths.profile,
      body: request.toJson(),
      dataParser: _parseProfile,
    );
    return response.data!;
  }

  /// PATCH /profile — partial update following the backend's patch protocol:
  ///
  /// only keys in [request] are sent at all; a **string** value sets the
  /// field, an explicit **`null`** clears it, and a key never provided is
  /// left unchanged. This matches the wire contract exactly, so clearing a
  /// user-emptied field is just `{'firstName': null}`.
  Future<ProfileResponse> patchProfile(ProfilePatchRequest request) async {
    final response = await _client.patch<ProfileResponse>(
      ApiPaths.profile,
      body: request.toJson(),
      dataParser: _parseProfile,
    );
    return response.data!;
  }
}

/// Full-replacement body (PUT /profile). Absent fields are treated as `null`
/// by the backend, which clears them.
class ProfileUpdateRequest {
  const ProfileUpdateRequest({
    this.firstName,
    this.lastName,
    this.displayName,
    this.timezone,
    this.profileImageUrl,
  });

  final String? firstName;
  final String? lastName;
  final String? displayName;
  final String? timezone;
  final String? profileImageUrl;

  Map<String, dynamic> toJson() => {
    'firstName': firstName,
    'lastName': lastName,
    'displayName': displayName,
    'timezone': timezone,
    'profileImageUrl': profileImageUrl,
  };

  static const Iterable<String> fieldNames = [
    'firstName',
    'lastName',
    'displayName',
    'timezone',
    'profileImageUrl',
  ];
}

/// Partial-update body (PATCH /profile).
///
/// Only the fields present in [changes] are sent: each key's value is written
/// verbatim — a `null` clears the field, a string sets it. A field the user
/// left untouched is simply absent from the map and stays unchanged.
class ProfilePatchRequest {
  const ProfilePatchRequest(this.changes);

  /// Wire field name → new value (`null` = clear). Preserves insertion order.
  final Map<String, String?> changes;

  Map<String, dynamic> toJson() => {
    for (final entry in changes.entries) entry.key: entry.value,
  };
}
