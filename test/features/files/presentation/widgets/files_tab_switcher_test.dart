import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:r16a_cloud_app/app/theme/app_theme.dart';
import 'package:r16a_cloud_app/features/files/presentation/files_state.dart';
import 'package:r16a_cloud_app/features/files/presentation/widgets/files_tab_switcher.dart';

void main() {
  late List<FilesTab> changes;

  Future<void> pump(WidgetTester tester, FilesTab tab) async {
    changes = [];
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: FilesTabSwitcher(tab: tab, onChanged: changes.add),
        ),
      ),
    );
  }

  Color? labelColor(WidgetTester tester, String label) =>
      tester.widget<Text>(find.text(label)).style?.color;

  testWidgets('the selected tab is in the primary color', (tester) async {
    await pump(tester, FilesTab.mine);
    final scheme = AppTheme.light.colorScheme;

    expect(labelColor(tester, 'My files'), scheme.primary);
    expect(labelColor(tester, 'Shared'), scheme.onSurfaceVariant);
  });

  testWidgets('tapping the other tab reports it; the current one does not', (
    tester,
  ) async {
    await pump(tester, FilesTab.mine);

    await tester.tap(find.text('My files'));
    await tester.tap(find.text('Shared'));

    expect(changes, [FilesTab.shared]);
  });
}
