import 'package:flutter/material.dart';

import '../files_state.dart';

/// "My files" | "Shared" — the web toolbar's `filter-tabs`, shown at root.
class FilesTabSwitcher extends StatelessWidget {
  const FilesTabSwitcher({
    super.key,
    required this.tab,
    required this.onChanged,
  });

  final FilesTab tab;
  final ValueChanged<FilesTab> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<FilesTab>(
      showSelectedIcon: false,
      segments: const [
        ButtonSegment(
          value: FilesTab.mine,
          icon: Icon(Icons.cloud_outlined),
          label: Text('My files'),
        ),
        ButtonSegment(
          value: FilesTab.shared,
          icon: Icon(Icons.people_outline),
          label: Text('Shared'),
        ),
      ],
      selected: {tab},
      onSelectionChanged: (selection) => onChanged(selection.single),
    );
  }
}
