/// Another user as listed by `GET /api/user` — mirrors the fields of
/// `UserResponse` (`types/user.ts`) the share picker shows.
class UserSummary {
  const UserSummary({
    required this.id,
    required this.username,
    required this.displayName,
    required this.email,
  });

  final String id;
  final String username;
  final String? displayName;
  final String email;

  /// Same fallback as the web share modal: `displayName || username`.
  String get label {
    final name = displayName;
    return name == null || name.isEmpty ? username : name;
  }

  factory UserSummary.fromJson(Map<String, dynamic> json) => UserSummary(
    id: json['id'] as String,
    username: json['username'] as String,
    displayName: json['displayName'] as String?,
    email: json['email'] as String,
  );
}
