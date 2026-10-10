import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/session/user_preferences.dart';
import '../../domain/file_sort.dart';
import '../files_providers.dart';
import 'package:flutter_svg/flutter_svg.dart';

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

    Widget viewTile(DefaultFileView mode, String iconPath) => ListTile(
      leading: SvgPicture.asset(
        iconPath,
        colorFilter: ColorFilter.mode(scheme.onSurfaceVariant, BlendMode.srcIn),
      ),
      title: Text(mode.label),
      trailing: mode == viewMode
          ? SvgPicture.asset(
              'assets/icons/check.svg',
              colorFilter: ColorFilter.mode(scheme.primary, BlendMode.srcIn),
            )
          : null,
      onTap: () => controller.setViewMode(mode),
    );

    // Same rule as `FileOptions.setSortField`: tapping the active field
    // flips the direction, another field switches to it.
    Widget sortTile(FileSortField field, String iconPath) => ListTile(
      leading: SvgPicture.asset(
        iconPath,
        colorFilter: ColorFilter.mode(scheme.onSurfaceVariant, BlendMode.srcIn),
      ),
      title: Text(field.label),
      trailing: field == sortField
          ? SvgPicture.asset(
              sortDirection == FileSortDirection.asc
                  ? 'assets/icons/arrow-narrow-up.svg'
                  : 'assets/icons/arrow-narrow-down.svg',
              colorFilter: ColorFilter.mode(scheme.primary, BlendMode.srcIn),
            )
          : null,
      onTap: () => field == sortField
          ? controller.setSortDirection(sortDirection.flipped)
          : controller.setSortField(field),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          leading: SvgPicture.asset(
            selectionMode
                ? 'assets/icons/circle-x.svg'
                : 'assets/icons/circle-check.svg',
            colorFilter: ColorFilter.mode(scheme.primary, BlendMode.srcIn),
          ),
          title: Text(selectionMode ? 'Cancel selection' : 'Select'),
          onTap: () {
            controller.setSelectionMode(!selectionMode);
            Navigator.of(context).pop();
          },
        ),
        const Divider(),
        sectionLabel('View'),
        viewTile(DefaultFileView.grid, 'assets/icons/layout-grid.svg'),
        viewTile(DefaultFileView.list, 'assets/icons/list-details.svg'),
        const Divider(),
        sectionLabel('Sort by'),
        sortTile(FileSortField.name, 'assets/icons/sort-a-z.svg'),
        sortTile(FileSortField.updatedAt, 'assets/icons/calendar-clock.svg'),
        const SizedBox(height: 8),
      ],
    );
  }
}
