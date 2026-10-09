import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_view/photo_view.dart';

import '../../app/theme/app_colors.dart';
import '../model/file_item.dart';
import 'media_actions.dart';
import 'media_images.dart';
import 'media_providers.dart';
import 'widgets/video_page.dart';
import 'widgets/viewer_placeholder.dart';

/// Full-screen media viewer — the native take on the web's
/// `image-preview-modal`: thumbnail / blurhash placeholder while the full
/// image loads, pinch-zoom, swiping between the given images and videos
/// (videos play in place, see [VideoPage]), and download / share-via
/// actions for the one on screen.
class FileViewerScreen extends ConsumerStatefulWidget {
  const FileViewerScreen({
    super.key,
    required this.files,
    required this.initialIndex,
    this.heroTagPrefix,
  });

  /// Images and videos of the current listing, in listing order.
  final List<FileItem> files;
  final int initialIndex;

  /// Tiles that opened the viewer tag their thumbnail `'$prefix$fileId'`;
  /// pages use the same tag so the thumbnail flies in and back out.
  final String? heroTagPrefix;

  @override
  ConsumerState<FileViewerScreen> createState() => _FileViewerScreenState();
}

class _FileViewerScreenState extends ConsumerState<FileViewerScreen> {
  late final _pageController = PageController(initialPage: widget.initialIndex);
  late int _index = widget.initialIndex;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final api = ref.watch(mediaApiProvider);
    final thumbnails = ref.watch(thumbnailCacheProvider);

    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: AppColors.darkBackground.withValues(alpha: 0.6),
        foregroundColor: AppColors.darkForeground,
        // The theme's title style carries its own (light-theme) color,
        // which would win over foregroundColor on this always-dark bar.
        titleTextStyle: Theme.of(
          context,
        ).appBarTheme.titleTextStyle?.copyWith(color: AppColors.darkForeground),
        title: Text(
          widget.files[_index].name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close_rounded),
          tooltip: 'Close',
        ),
        actions: [
          IconButton(
            onPressed: () => shareMediaFile(context, ref, widget.files[_index]),
            icon: const Icon(Icons.ios_share_rounded),
            tooltip: 'Share via…',
          ),
          IconButton(
            onPressed: () =>
                saveMediaFiles(context, ref, [widget.files[_index]]),
            icon: const Icon(Icons.download_rounded),
            tooltip: 'Download',
          ),
        ],
      ),
      body: PhotoViewGestureDetectorScope(
        axis: Axis.horizontal,
        child: PageView.builder(
          controller: _pageController,
          itemCount: widget.files.length,
          onPageChanged: (index) => setState(() => _index = index),
          itemBuilder: (context, index) {
            final file = widget.files[index];
            final prefix = widget.heroTagPrefix;
            final heroTag = prefix == null ? null : '$prefix${file.id}';
            final placeholder = ViewerPlaceholder(
              file: file,
              thumbnail: FileThumbnailImage(file.id, thumbnails),
              heroTag: heroTag,
            );

            if (file.isVideo) {
              return VideoPage(
                key: ValueKey(file.id),
                file: file,
                active: index == _index,
                placeholder: placeholder,
                onOpenWith: () => openWithOtherApp(context, ref, file),
              );
            }

            return PhotoView(
              key: ValueKey(file.id),
              imageProvider: FilePreviewImage(file, api),
              backgroundDecoration: const BoxDecoration(
                color: AppColors.darkBackground,
              ),
              minScale: PhotoViewComputedScale.contained,
              maxScale: PhotoViewComputedScale.covered * 4,
              // The placeholder (thumbnail) and the loaded image are never
              // on screen together, so they can share the hero tag.
              heroAttributes: heroTag == null
                  ? null
                  : PhotoViewHeroAttributes(tag: heroTag),
              loadingBuilder: (context, event) => placeholder,
              errorBuilder: (context, error, stackTrace) => const Center(
                child: Text(
                  'Could not load image preview.',
                  style: TextStyle(color: AppColors.darkForeground),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
