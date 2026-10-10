import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/api_exception.dart';
import '../network/dio_client.dart';
import '../network/network_status.dart';
import 'current_user.dart';
import 'current_user_store.dart';
import 'session_api.dart';
import 'user_preferences.dart';

final sessionApiProvider = Provider(
  (ref) => SessionApi(ref.watch(dioProvider)),
);

/// The signed-in user kept on the device. In-memory by default (tests);
/// `main()` overrides it with the Hive store once Hive is initialized.
final currentUserStoreProvider = Provider<CurrentUserStore>(
  (ref) => MemoryCurrentUserStore(),
);

/// The signed-in internal user — mirrors the web client's
/// `UserService.currentUser$`. Shared across features: anything that needs
/// the owner id, display identity, or preferences reads this rather than
/// calling [SessionApi] directly.
///
/// Mobile-only: when the server can't be reached, the last stored user is
/// served instead (so cached listings still open offline), and `/user/me`
/// is asked again once the app is back online.
class CurrentUserController extends AsyncNotifier<CurrentUser> {
  CurrentUserStore get _store => ref.read(currentUserStoreProvider);

  @override
  Future<CurrentUser> build() async {
    try {
      final user = await ref.watch(sessionApiProvider).getCurrentUser();
      await _store.save(user);
      return user;
    } on ApiException catch (e) {
      // An HTTP status means the server answered: that error is real.
      if (e.statusCode != null) rethrow;
      final stored = await _store.read();
      if (stored == null) rethrow;
      ref.listen(networkStatusProvider, (_, next) {
        if (next == NetworkStatus.online) ref.invalidateSelf();
      });
      return stored;
    }
  }

  /// Reflects a change immediately, ahead of the network round-trip —
  /// callers that debounce a save (see `ProfileSaveController`) use this so
  /// the UI responds instantly instead of waiting on the PATCH.
  void setOptimistic(CurrentUser user) {
    state = AsyncData(user);
    _store.save(user);
  }

  /// Sends all preferences to the backend (mirrors the web client's
  /// `saveUserPreferences()`, which always PATCHes every field together)
  /// and adopts the server's response as the new state.
  Future<void> updatePreferences(UserPreferences preferences) async {
    final updated = await ref
        .read(sessionApiProvider)
        .updatePreferences(preferences);
    state = AsyncData(updated);
    await _store.save(updated);
  }
}

final currentUserProvider =
    AsyncNotifierProvider<CurrentUserController, CurrentUser>(
      CurrentUserController.new,
    );
