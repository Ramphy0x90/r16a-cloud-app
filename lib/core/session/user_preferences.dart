/// Mirrors the web client's `Theme` type (`types/theme.ts`) and the
/// backend's `UserPreferences.preferredTheme` (`light` | `dark`).
enum AppThemePreference {
  light,
  dark;

  String get label => switch (this) {
        AppThemePreference.light => 'Light',
        AppThemePreference.dark => 'Dark',
      };

  static AppThemePreference fromJson(String value) => switch (value.toLowerCase()) {
        'dark' => AppThemePreference.dark,
        _ => AppThemePreference.light,
      };
}

/// Mirrors the web client's `ViewMode` type (`types/file.ts`) and the
/// backend's `UserPreferences.defaultViewMode` (`grid` | `list`).
enum DefaultFileView {
  grid,
  list;

  String get label => switch (this) {
        DefaultFileView.grid => 'Grid',
        DefaultFileView.list => 'List',
      };

  static DefaultFileView fromJson(String value) => switch (value.toLowerCase()) {
        'list' => DefaultFileView.list,
        _ => DefaultFileView.grid,
      };
}

/// Mirrors the web client's `UserPreferences` (`types/user.ts`) — nested
/// under `UserResponse.preferences` on the backend.
class UserPreferences {
  const UserPreferences({
    required this.theme,
    required this.defaultViewMode,
    required this.encryptFilesByDefault,
  });

  final AppThemePreference theme;
  final DefaultFileView defaultViewMode;
  final bool encryptFilesByDefault;

  factory UserPreferences.fromJson(Map<String, dynamic> json) => UserPreferences(
        theme: AppThemePreference.fromJson(json['preferredTheme'] as String),
        defaultViewMode: DefaultFileView.fromJson(json['defaultViewMode'] as String),
        encryptFilesByDefault: json['encryptFilesByDefault'] as bool,
      );

  UserPreferences copyWith({
    AppThemePreference? theme,
    DefaultFileView? defaultViewMode,
    bool? encryptFilesByDefault,
  }) {
    return UserPreferences(
      theme: theme ?? this.theme,
      defaultViewMode: defaultViewMode ?? this.defaultViewMode,
      encryptFilesByDefault: encryptFilesByDefault ?? this.encryptFilesByDefault,
    );
  }
}
