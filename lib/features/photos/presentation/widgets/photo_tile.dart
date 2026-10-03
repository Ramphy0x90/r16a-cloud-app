import 'package:flutter/material.dart';

import '../../../../core/media/widgets/file_thumbnail.dart';
import '../../../../core/model/file_item.dart';
import '../photos_state.dart';

/// Square grid cell — mirrors `.photo-item` in `photos.html`: thumbnail,
/// else blurhash, plus the play badge on videos and the "shared with you"
/// badge on other users' photos.
class PhotoTile extends StatelessWidget {
  const PhotoTile({
    super.key,
    required this.file,
    required this.shared,
    required this.onTap,
  });

  final FileItem file;
  final bool shared;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Semantics(
      label: file.name,
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: ColoredBox(
          color: scheme.surfaceContainerHighest,
          child: Stack(
            fit: StackFit.expand,
            children: [
              FileThumbnail(
                file: file,
                iconSize: 32,
                heroTag: '$photosHeroPrefix${file.id}',
              ),
              if (shared)
                Positioned(
                  top: 4,
                  right: 4,
                  child: Tooltip(
                    message: file.ownerDisplayName,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: scheme.surface.withValues(alpha: 0.85),
                        shape: BoxShape.circle,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(3),
                        child: Icon(
                          Icons.people_rounded,
                          size: 14,
                          color: scheme.primary,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
