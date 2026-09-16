/// Profile data returned by the backend profile endpoints.
class ProfileResponse {
  const ProfileResponse({
    required this.userId,
    this.firstName,
    this.lastName,
    this.displayName,
    this.timezone,
    this.profileImageUrl,
    this.createdAt,
    this.updatedAt,
    this.version,
  });

  factory ProfileResponse.fromJson(Map<String, dynamic> json) {
    return ProfileResponse(
      userId: json['userId'] as String,
      firstName: json['firstName'] as String?,
      lastName: json['lastName'] as String?,
      displayName: json['displayName'] as String?,
      timezone: json['timezone'] as String?,
      profileImageUrl: json['profileImageUrl'] as String?,
      createdAt: json['createdAt'] as String?,
      updatedAt: json['updatedAt'] as String?,
      version: json['version'] as int?,
    );
  }

  final String userId;
  final String? firstName;
  final String? lastName;
  final String? displayName;
  final String? timezone;
  final String? profileImageUrl;
  final String? createdAt;
  final String? updatedAt;
  final int? version;

  Map<String, dynamic> toJson() => {
    if (firstName != null) 'firstName': firstName,
    if (lastName != null) 'lastName': lastName,
    if (displayName != null) 'displayName': displayName,
    if (timezone != null) 'timezone': timezone,
    if (profileImageUrl != null) 'profileImageUrl': profileImageUrl,
    if (createdAt != null) 'createdAt': createdAt,
    if (updatedAt != null) 'updatedAt': updatedAt,
    if (version != null) 'version': version,
  };

  ProfileResponse copyWith({
    String? userId,
    String? Function()? firstName,
    String? Function()? lastName,
    String? Function()? displayName,
    String? Function()? timezone,
    String? Function()? profileImageUrl,
  }) {
    return ProfileResponse(
      userId: userId ?? this.userId,
      firstName: firstName != null ? firstName() : this.firstName,
      lastName: lastName != null ? lastName() : this.lastName,
      displayName: displayName != null ? displayName() : this.displayName,
      timezone: timezone != null ? timezone() : this.timezone,
      profileImageUrl: profileImageUrl != null
          ? profileImageUrl()
          : this.profileImageUrl,
      createdAt: createdAt,
      updatedAt: updatedAt,
      version: version,
    );
  }

  /// Fields editable by the user as a map of label → value.
  Map<String, String?> get editableFields => {
    'First name': firstName,
    'Last name': lastName,
    'Display name': displayName,
    'Timezone': timezone,
    'Profile image URL': profileImageUrl,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProfileResponse &&
          runtimeType == other.runtimeType &&
          userId == other.userId &&
          firstName == other.firstName &&
          lastName == other.lastName &&
          displayName == other.displayName &&
          timezone == other.timezone &&
          profileImageUrl == other.profileImageUrl;

  @override
  int get hashCode => Object.hash(
    userId,
    firstName,
    lastName,
    displayName,
    timezone,
    profileImageUrl,
  );
}
