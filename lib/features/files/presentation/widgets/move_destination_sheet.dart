import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/media/widgets/file_type_icon.dart';
import '../../../../core/model/file_item.dart';
import '../files_providers.dart';

/// Folder browser for "Move" (no web equivalent): starts at the root and
/// resolves to the folder picked with "Move here", `null` when dismissed.
///
/// Can't pick the root (the backend can't move there yet) or the folder
/// the items already sit in ([sourceFolderId]). The moved folders
/// themselves are hidden, so nothing can move into itself or below.
Future<FileItem?> showMoveDestinationSheet({
  required BuildContext context,
  required List<FileItem> files,
  required String? sourceFolderId,
}) {
  return showModalBottomSheet<FileItem>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) =>
        _MoveDestinationSheet(files: files, sourceFolderId: sourceFolderId),
  );
}

class _MoveDestinationSheet extends ConsumerStatefulWidget {
  const _MoveDestinationSheet({
    required this.files,
    required this.sourceFolderId,
  });

  final List<FileItem> files;
  final String? sourceFolderId;

  @override
  ConsumerState<_MoveDestinationSheet> createState() =>
      _MoveDestinationSheetState();
}

class _MoveDestinationSheetState extends ConsumerState<_MoveDestinationSheet> {
  /// Folders opened inside the sheet; empty = root.
  final _path = <FileItem>[];

  late final _movedIds = {for (final f in widget.files) f.id};

  FileItem? get _current => _path.isEmpty ? null : _path.last;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final current = _current;
    final folders = ref.watch(folderChildrenProvider(current?.id));
    final canMoveHere = current != null && current.id != widget.sourceFolderId;
    final subject = widget.files.length == 1
        ? widget.files.single.name
        : '${widget.files.length} items';

    Widget message(String text) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Text(text, style: TextStyle(color: scheme.onSurfaceVariant)),
      ),
    );

    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.7,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text.rich(
                  TextSpan(
                    text: 'Move ',
                    children: [
                      TextSpan(
                        text: subject,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleMedium,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  if (current != null)
                    IconButton(
                      onPressed: () => setState(_path.removeLast),
                      icon: const Icon(Icons.arrow_back_rounded),
                      tooltip: 'Back',
                    )
                  else
                    const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      current?.name ?? 'My files',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodyLarge?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(height: 1),
              Expanded(
                child: folders.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (_, _) => Center(
                    child: TextButton.icon(
                      onPressed: () =>
                          ref.invalidate(folderChildrenProvider(current?.id)),
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Could not load folders. Retry'),
                    ),
                  ),
                  data: (all) {
                    final shown = all
                        .where((f) => !_movedIds.contains(f.id))
                        .toList();
                    if (shown.isEmpty) return message('No folders here');
                    return ListView.builder(
                      itemCount: shown.length,
                      itemBuilder: (context, i) => ListTile(
                        leading: FileTypeIcon(file: shown[i], size: 24),
                        title: Text(
                          shown[i].name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => setState(() => _path.add(shown[i])),
                      ),
                    );
                  },
                ),
              ),
              if (current == null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: Text(
                    'Open a folder to move into it.',
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: canMoveHere
                        ? () => Navigator.of(context).pop(current)
                        : null,
                    child: const Text('Move here'),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
