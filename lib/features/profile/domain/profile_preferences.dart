/// Mirrors the web client's `Theme` type (`types/theme.ts`).
enum AppThemePreference {
  light,
  dark;

  String get label => switch (this) {
        AppThemePreference.light => 'Light',
        AppThemePreference.dark => 'Dark',
      };
}

/// Mirrors the web client's `ViewMode` type (`types/file.ts`).
enum DefaultFileView {
  grid,
  list;

  String get label => switch (this) {
        DefaultFileView.grid => 'Grid',
        DefaultFileView.list => 'List',
      };
}

/// Mirrors the web client's `UserPreferences` (`types/user.ts`).
class ProfilePreferences {
  const ProfilePreferences({
    required this.theme,
    required this.defaultViewMode,
    required this.encryptFilesByDefault,
  });

  final AppThemePreference theme;
  final DefaultFileView defaultViewMode;
  final bool encryptFilesByDefault;

  ProfilePreferences copyWith({
    AppThemePreference? theme,
    DefaultFileView? defaultViewMode,
    bool? encryptFilesByDefault,
  }) {
    return ProfilePreferences(
      theme: theme ?? this.theme,
      defaultViewMode: defaultViewMode ?? this.defaultViewMode,
      encryptFilesByDefault: encryptFilesByDefault ?? this.encryptFilesByDefault,
    );
  }
}
