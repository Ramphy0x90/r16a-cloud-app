import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:r16a_cloud_app/core/config/env.dart';
import 'package:r16a_cloud_app/core/util/link_opener.dart';
import 'package:r16a_cloud_app/core/widgets/privacy_policy_link.dart';

void main() {
  Future<List<Uri>> pumpAndTap(
    WidgetTester tester, {
    required bool opens,
  }) async {
    final opened = <Uri>[];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          linkOpenerProvider.overrideWithValue((uri) async {
            opened.add(uri);
            return opens;
          }),
        ],
        child: const MaterialApp(home: Scaffold(body: PrivacyPolicyLink())),
      ),
    );
    await tester.tap(find.text('Privacy policy'));
    await tester.pump();
    return opened;
  }

  testWidgets('opens the published policy', (tester) async {
    final opened = await pumpAndTap(tester, opens: true);

    expect(opened, [Uri.parse(Env.privacyPolicyUrl)]);
    expect(opened.single.toString(), 'https://domovoi.cloud/privacy');
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('says so when no browser can open it', (tester) async {
    await pumpAndTap(tester, opens: false);

    expect(find.text('Could not open the privacy policy.'), findsOneWidget);
  });
}
