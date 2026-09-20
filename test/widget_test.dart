import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:r16a_cloud_app/app/app.dart';
import 'package:r16a_cloud_app/core/auth/token_store.dart';

/// In-memory stand-in so the test never touches the real secure-storage
/// platform channel (which has no handler registered in a plain widget
/// test and would hang forever).
class _FakeTokenStore implements TokenStore {
  StoredTokens? _tokens;

  @override
  Future<StoredTokens?> read() async => _tokens;

  @override
  Future<void> save(StoredTokens tokens) async => _tokens = tokens;

  @override
  Future<void> clear() async => _tokens = null;
}

void main() {
  testWidgets('unauthenticated launch lands on the login screen', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [tokenStoreProvider.overrideWithValue(_FakeTokenStore())],
        child: const R16aCloudApp(),
      ),
    );

    // No stored session -> session restore resolves to unauthenticated
    // once its async work settles.
    await tester.pumpAndSettle();

    expect(find.text('R16a Cloud'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);

    // The authenticated shell (dock + tabs) must not be reachable yet.
    expect(find.text('Dashboard'), findsNothing);
  });
}
