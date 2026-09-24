import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/dio_client.dart';
import 'current_user.dart';
import 'session_api.dart';
import 'user_preferences.dart';

final sessionApiProvider = Provider((ref) => SessionApi(ref.watch(dioProvider)));

/// The signed-in internal user — mirrors the web client's
/// `UserService.currentUser$`. Shared across features: anything that needs
/// the owner id, display identity, or preferences reads this rather than
/// calling [SessionApi] directly.
class CurrentUserController extends AsyncNotifier<CurrentUser> {
  @override
  Future<CurrentUser> build() => ref.watch(sessionApiProvider).getCurrentUser();

  /// Reflects a change immediately, ahead of the network round-trip —
  /// callers that debounce a save (see `ProfileSaveController`) use this so
  /// the UI responds instantly instead of waiting on the PATCH.
  void setOptimistic(CurrentUser user) {
    state = AsyncData(user);
  }

  /// Sends the full preferences triple to the backend (mirrors the web
  /// client's `saveUserPreferences()`, which always PATCHes all three
  /// fields together) and adopts the server's response as the new state.
  Future<void> updatePreferences(UserPreferences preferences) async {
    final updated = await ref.read(sessionApiProvider).updatePreferences(preferences);
    state = AsyncData(updated);
  }
}

final currentUserProvider = AsyncNotifierProvider<CurrentUserController, CurrentUser>(
  CurrentUserController.new,
);
