import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/session/user_preferences.dart';
import '../../domain/file_sort.dart';
import '../files_providers.dart';

/// Select / view / sort menu — the native equivalent of the web
/// `file-options` dropdown. View and sort update in place; "Select" closes
/// the sheet, like the web menu.
Future<void> showFileOptionsSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => const SafeArea(
      child: SingleChildScrollView(child: _FileOptionsContent()),
    ),
  );
}

class _FileOptionsContent extends ConsumerWidget {
  const _FileOptionsContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final viewMode = ref.watch(filesViewModeProvider);
    final sortField = ref.watch(
      filesControllerProvider.select((s) => s.sortField),
    );
    final sortDirection = ref.watch(
      filesControllerProvider.select((s) => s.sortDirection),
    );
    final controller = ref.read(filesControllerProvider.notifier);
    final readOnly = ref.watch(
      filesControllerProvider.select((s) => s.readOnly),
    );
    final selectionMode = ref.watch(
      filesControllerProvider.select((s) => s.selectionMode),
    );

    Widget sectionLabel(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(text, style: Theme.of(context).textTheme.labelLarge),
      ),
    );

    Widget viewTile(DefaultFileView mode, IconData icon) => ListTile(
      leading: Icon(icon),
      title: Text(mode.label),
      trailing: mode == viewMode
          ? Icon(Icons.check_rounded, color: scheme.primary)
          : null,
      onTap: () => controller.setViewMode(mode),
    );

    // Same rule as `FileOptions.setSortField`: tapping the active field
    // flips the direction, another field switches to it.
    Widget sortTile(FileSortField field, IconData icon) => ListTile(
      leading: Icon(icon),
      title: Text(field.label),
      trailing: field == sortField
          ? Icon(
              sortDirection == FileSortDirection.asc
                  ? Icons.arrow_upward_rounded
                  : Icons.arrow_downward_rounded,
              color: scheme.primary,
            )
          : null,
      onTap: () => field == sortField
          ? controller.setSortDirection(sortDirection.flipped)
          : controller.setSortField(field),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Shared tab: selection only enables download, which isn't in yet.
        if (!readOnly) ...[
          ListTile(
            leading: Icon(
              selectionMode
                  ? Icons.cancel_outlined
                  : Icons.check_circle_outline_rounded,
            ),
            title: Text(selectionMode ? 'Cancel selection' : 'Select'),
            onTap: () {
              controller.setSelectionMode(!selectionMode);
              Navigator.of(context).pop();
            },
          ),
          const Divider(),
        ],
        sectionLabel('View'),
        viewTile(DefaultFileView.grid, Icons.grid_view_rounded),
        viewTile(DefaultFileView.list, Icons.view_list_rounded),
        const Divider(),
        sectionLabel('Sort by'),
        sortTile(FileSortField.name, Icons.sort_by_alpha_rounded),
        sortTile(FileSortField.updatedAt, Icons.calendar_today_outlined),
        const SizedBox(height: 8),
      ],
    );
  }
}
