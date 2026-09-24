import 'user_preferences.dart';

/// The backend's internal user record for the signed-in identity — mirrors
/// `UserResponse` (`types/user.ts`) on the web client, trimmed to what the
/// app needs.
class CurrentUser {
  const CurrentUser({
    required this.id,
    required this.username,
    required this.displayName,
    required this.email,
    required this.preferences,
  });

  final String id;
  final String username;
  final String displayName;
  final String email;
  final UserPreferences preferences;

  factory CurrentUser.fromJson(Map<String, dynamic> json) => CurrentUser(
        id: json['id'] as String,
        username: json['username'] as String,
        displayName: json['displayName'] as String,
        email: json['email'] as String,
        preferences: UserPreferences.fromJson(json['preferences'] as Map<String, dynamic>),
      );

  CurrentUser copyWith({UserPreferences? preferences}) => CurrentUser(
        id: id,
        username: username,
        displayName: displayName,
        email: email,
        preferences: preferences ?? this.preferences,
      );
}
