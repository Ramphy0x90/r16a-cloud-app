import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/session/session_providers.dart';
import '../../../core/session/user_preferences.dart';

/// Save status for the Profile screen's preferences form — separate from
/// [currentUserProvider]'s own loading/error, which represents the initial
/// fetch, not a save in flight. Mirrors `profile.ts`'s `errorMessage` field.
class ProfileSaveState {
  const ProfileSaveState({this.saving = false, this.errorMessage});

  final bool saving;
  final String? errorMessage;
}

/// Debounces preference edits (300ms, same as the web client) before
/// PATCHing them, so rapid picker taps don't fire a request each.
class ProfileSaveController extends Notifier<ProfileSaveState> {
  Timer? _debounce;

  @override
  ProfileSaveState build() {
    ref.onDispose(() => _debounce?.cancel());
    return const ProfileSaveState();
  }

  void schedule(UserPreferences preferences) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () => _save(preferences));
  }

  Future<void> _save(UserPreferences preferences) async {
    state = const ProfileSaveState(saving: true);
    try {
      await ref.read(currentUserProvider.notifier).updatePreferences(preferences);
      state = const ProfileSaveState();
    } catch (_) {
      state = const ProfileSaveState(
        errorMessage: 'Could not save preferences. Please try again.',
      );
    }
  }
}

final profileSaveControllerProvider =
    NotifierProvider<ProfileSaveController, ProfileSaveState>(ProfileSaveController.new);
