import 'package:flutter/material.dart';

import '../../../../core/media/widgets/file_thumbnail.dart';
import '../../../../core/model/file_item.dart';
import '../files_state.dart';
import 'selection_check.dart';

/// One card of the grid view — mirrors `.file-card` in `grid-view.html`:
/// media area, a name footer with the shared badge, and the selection
/// marker in selection mode.
class FileGridTile extends StatelessWidget {
  const FileGridTile({
    super.key,
    required this.file,
    required this.showSharedBadge,
    required this.selectionMode,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
  });

  final FileItem file;
  final bool showSharedBadge;
  final bool selectionMode;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: scheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: selected
            ? BorderSide(color: scheme.primary, width: 2)
            : BorderSide.none,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: FileThumbnail(
                    file: file,
                    iconSize: 44,
                    heroTag: '$filesHeroPrefix${file.id}',
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          file.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      if (showSharedBadge && file.isShared) ...[
                        const SizedBox(width: 4),
                        Icon(
                          Icons.people_rounded,
                          size: 14,
                          color: scheme.primary,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            if (selectionMode)
              Positioned(
                top: 8,
                left: 8,
                child: SelectionCheck(selected: selected),
              ),
          ],
        ),
      ),
    );
  }
}
