import 'package:flutter/material.dart';
import 'package:flutter_blurhash/flutter_blurhash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_view/photo_view.dart';

import '../../../app/theme/app_colors.dart';
import '../domain/file_item.dart';
import 'file_images.dart';
import 'files_providers.dart';

/// Full-screen image viewer — the native take on the web's
/// `image-preview-modal`: thumbnail / blurhash placeholder while the full
/// image loads, plus pinch-zoom and swiping between the folder's images.
class FileViewerScreen extends ConsumerStatefulWidget {
  const FileViewerScreen({
    super.key,
    required this.files,
    required this.initialIndex,
  });

  /// Images of the current listing, in listing order.
  final List<FileItem> files;
  final int initialIndex;

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
    final api = ref.watch(filesApiProvider);
    final thumbnails = ref.watch(thumbnailCacheProvider);

    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: AppColors.darkBackground.withValues(alpha: 0.6),
        foregroundColor: AppColors.darkForeground,
        title: Text(
          widget.files[_index].name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close_rounded),
          tooltip: 'Close image',
        ),
      ),
      body: PhotoViewGestureDetectorScope(
        axis: Axis.horizontal,
        child: PageView.builder(
          controller: _pageController,
          itemCount: widget.files.length,
          onPageChanged: (index) => setState(() => _index = index),
          itemBuilder: (context, index) {
            final file = widget.files[index];
            final placeholder = _Placeholder(
              file: file,
              thumbnail: FileThumbnailImage(file.id, thumbnails),
            );

            return PhotoView(
              key: ValueKey(file.id),
              imageProvider: FilePreviewImage(file, api),
              backgroundDecoration: const BoxDecoration(
                color: AppColors.darkBackground,
              ),
              minScale: PhotoViewComputedScale.contained,
              maxScale: PhotoViewComputedScale.covered * 4,
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

/// What the web modal shows while `loading`: the cached thumbnail if any,
/// else the blurhash, with a spinner on top.
class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.file, required this.thumbnail});

  final FileItem file;
  final ImageProvider thumbnail;

  @override
  Widget build(BuildContext context) {
    final hash = file.blurHash;

    return Stack(
      fit: StackFit.expand,
      children: [
        if (hash != null) BlurHash(hash: hash, imageFit: BoxFit.contain),
        Image(
          image: thumbnail,
          fit: BoxFit.contain,
          gaplessPlayback: true,
          errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
        ),
        const Center(
          child: CircularProgressIndicator(color: AppColors.darkForeground),
        ),
      ],
    );
  }
}
