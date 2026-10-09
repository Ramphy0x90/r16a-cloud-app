import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:r16a_cloud_app/core/config/app_version.dart';
import 'package:r16a_cloud_app/features/profile/presentation/widgets/app_version_label.dart';

void main() {
  testWidgets('shows the installed version', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appVersionProvider.overrideWith((ref) async => '1.0.0 (3)'),
        ],
        child: const MaterialApp(home: Scaffold(body: AppVersionLabel())),
      ),
    );
    await tester.pump();

    expect(find.text('Version 1.0.0 (3)'), findsOneWidget);
  });
}
