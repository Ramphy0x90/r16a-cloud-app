import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:r16a_cloud_app/features/profile/presentation/widgets/profile_storage_card.dart';

void main() {
  testWidgets('clears, shows progress, then confirms', (tester) async {
    final done = Completer<void>();
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProfileStorageCard(
            onClearCache: () {
              calls++;
              return done.future;
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Clear cache'));
    await tester.pump();
    expect(calls, 1);
    expect(find.text('Clearing…'), findsOneWidget);

    done.complete();
    await tester.pumpAndSettle();
    expect(find.text('Cache cleared'), findsOneWidget);
    expect(find.text('Clear cache'), findsOneWidget);
  });
}
