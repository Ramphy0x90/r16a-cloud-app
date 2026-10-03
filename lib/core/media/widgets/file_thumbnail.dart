import 'package:flutter/material.dart';
import 'package:flutter_blurhash/flutter_blurhash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../model/file_item.dart';
import '../media_images.dart';
import '../media_providers.dart';
import 'file_type_icon.dart';

/// Media slot of a file tile — mirrors `.file-card-media` in
/// `grid-view.html`: the thumbnail when loaded, else the blurhash, else the
/// type icon; videos get a play badge. Thumbnails are only requested once
/// the tile is built, i.e. scrolled into view (the web's `inViewport`).
class FileThumbnail extends ConsumerWidget {
  const FileThumbnail({
    super.key,
    required this.file,
    required this.iconSize,
    this.includeVideo = true,
  });

  final FileItem file;
  final double iconSize;

  /// The web list view only previews images; the grid previews videos too.
  final bool includeVideo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasPreview = file.isImage || (includeVideo && file.isVideo);
    if (!hasPreview) {
      return Center(
        child: FileTypeIcon(file: file, size: iconSize),
      );
    }

    final hash = file.blurHash;
    final fallback = hash != null
        ? BlurHash(hash: hash, imageFit: BoxFit.cover)
        : Center(
            child: FileTypeIcon(file: file, size: iconSize),
          );

    return Stack(
      fit: StackFit.expand,
      children: [
        Image(
          image: FileThumbnailImage(file.id, ref.watch(thumbnailCacheProvider)),
          fit: BoxFit.cover,
          gaplessPlayback: true,
          frameBuilder: (context, child, frame, wasSynchronouslyLoaded) =>
              frame == null ? fallback : child,
          errorBuilder: (context, error, stackTrace) => fallback,
        ),
        if (file.isVideo && includeVideo)
          Center(
            child: Icon(
              Icons.play_circle_fill_rounded,
              size: iconSize * 0.7,
              color: Theme.of(
                context,
              ).colorScheme.surface.withValues(alpha: 0.9),
            ),
          ),
      ],
    );
  }
}
