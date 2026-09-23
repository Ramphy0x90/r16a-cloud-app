import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/profile_preferences.dart';

/// Holds the Profile screen's preferences in memory — mirrors the web
/// client's `preferredTheme` / `defaultViewMode` / `encryptFilesByDefault`
/// form fields on `pages/profile`.
class ProfilePreferencesController extends Notifier<ProfilePreferences> {
  @override
  ProfilePreferences build() {
    return const ProfilePreferences(
      theme: AppThemePreference.light,
      defaultViewMode: DefaultFileView.grid,
      encryptFilesByDefault: false,
    );
  }

  void setTheme(AppThemePreference theme) {
    state = state.copyWith(theme: theme);
  }

  void setDefaultViewMode(DefaultFileView mode) {
    state = state.copyWith(defaultViewMode: mode);
  }

  void setEncryptFilesByDefault(bool value) {
    state = state.copyWith(encryptFilesByDefault: value);
  }
}

final profilePreferencesControllerProvider =
    NotifierProvider<ProfilePreferencesController, ProfilePreferences>(
  ProfilePreferencesController.new,
);
