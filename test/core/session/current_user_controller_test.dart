import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:r16a_cloud_app/core/network/api_exception.dart';
import 'package:r16a_cloud_app/core/network/network_status.dart';
import 'package:r16a_cloud_app/core/session/current_user.dart';
import 'package:r16a_cloud_app/core/session/current_user_store.dart';
import 'package:r16a_cloud_app/core/session/session_api.dart';
import 'package:r16a_cloud_app/core/session/session_providers.dart';
import 'package:r16a_cloud_app/core/session/user_preferences.dart';

CurrentUser _user(String id) => CurrentUser(
  id: id,
  username: id,
  displayName: id,
  email: '$id@example.com',
  preferences: const UserPreferences(
    theme: AppThemePreference.dark,
    defaultViewMode: DefaultFileView.list,
  ),
);

/// `/user/me` answers [user], or throws [error] when set.
class _SessionApi extends SessionApi {
  _SessionApi() : super(Dio());

  CurrentUser user = _user('fresh');
  Object? error;
  var calls = 0;

  @override
  Future<CurrentUser> getCurrentUser() async {
    calls++;
    if (error case final e?) throw e;
    return user;
  }
}

const _unreachable = ApiException('Could not reach the server.');

void main() {
  late _SessionApi api;
  late MemoryCurrentUserStore store;
  late ProviderContainer container;

  setUp(() {
    api = _SessionApi();
    store = MemoryCurrentUserStore();
    // Built per test (on first use) so each test configures the fakes first.
    container = ProviderContainer(
      // No automatic retry: a failure must surface as-is.
      retry: (_, _) => null,
      overrides: [
        sessionApiProvider.overrideWithValue(api),
        currentUserStoreProvider.overrideWithValue(store),
      ],
    );
  });

  tearDown(() => container.dispose());

  Future<CurrentUser> read() {
    container.listen(currentUserProvider, (_, _) {});
    return container.read(currentUserProvider.future);
  }

  test('stores the user /user/me returns', () async {
    expect((await read()).id, 'fresh');
    expect(store.user?.id, 'fresh');
  });

  test('server unreachable: serves the stored user', () async {
    store.user = _user('stored');
    api.error = _unreachable;

    expect((await read()).id, 'stored');
  });

  test('server unreachable and nothing stored: fails', () async {
    api.error = _unreachable;

    await expectLater(read(), throwsA(isA<ApiException>()));
  });

  test('an HTTP error is not hidden by the stored user', () async {
    store.user = _user('stored');
    api.error = const ApiException('Server error', statusCode: 500);

    await expectLater(read(), throwsA(isA<ApiException>()));
  });

  test('asks /user/me again once back online', () async {
    store.user = _user('stored');
    api.error = _unreachable;
    container.read(networkStatusProvider.notifier).reportUnreachable();
    await read();

    api.error = null;
    container.read(networkStatusProvider.notifier).reportReachable();

    expect((await read()).id, 'fresh');
    expect(api.calls, 2);
  });

  test('preference changes are stored', () async {
    await read();
    final changed = _user('fresh').copyWith(
      preferences: const UserPreferences(
        theme: AppThemePreference.light,
        defaultViewMode: DefaultFileView.grid,
      ),
    );

    container.read(currentUserProvider.notifier).setOptimistic(changed);
    await Future<void>.delayed(Duration.zero);

    expect(store.user?.preferences.theme, AppThemePreference.light);
  });

  test('round-trips through JSON', () {
    final user = _user('a');
    final back = CurrentUser.fromJson(user.toJson());

    expect(back.id, 'a');
    expect(back.email, 'a@example.com');
    expect(back.preferences.theme, AppThemePreference.dark);
    expect(back.preferences.defaultViewMode, DefaultFileView.list);
  });
}
