import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:r16a_cloud_app/features/profile/presentation/widgets/profile_delete_account_card.dart';

void main() {
  Future<void> pumpCard(
    WidgetTester tester,
    Future<void> Function() onDelete,
  ) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: ProfileDeleteAccountCard(onDeleteAccount: onDelete),
        ),
      ),
    ),
  );

  Finder confirmButton() => find.widgetWithText(FilledButton, 'Delete account');

  testWidgets('deletes only after typing the confirmation word', (
    tester,
  ) async {
    var calls = 0;
    await pumpCard(tester, () async => calls++);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Delete account'));
    await tester.pumpAndSettle();
    expect(find.text('Delete account?'), findsOneWidget);
    expect(tester.widget<FilledButton>(confirmButton()).onPressed, isNull);

    await tester.enterText(find.byType(TextField), 'delete');
    await tester.pump();
    expect(tester.widget<FilledButton>(confirmButton()).onPressed, isNull);

    await tester.enterText(find.byType(TextField), 'DELETE');
    await tester.pump();
    await tester.tap(confirmButton());
    await tester.pumpAndSettle();

    expect(calls, 1);
  });

  testWidgets('cancelling deletes nothing', (tester) async {
    var calls = 0;
    await pumpCard(tester, () async => calls++);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Delete account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(calls, 0);
  });

  testWidgets('a failure is reported and the button comes back', (
    tester,
  ) async {
    await pumpCard(tester, () async => throw Exception('offline'));

    await tester.tap(find.widgetWithText(OutlinedButton, 'Delete account'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'DELETE');
    await tester.pump();
    await tester.tap(confirmButton());
    await tester.pumpAndSettle();

    expect(
      find.text('Could not delete your account. Please try again.'),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(OutlinedButton, 'Delete account'),
      findsOneWidget,
    );
  });
}
