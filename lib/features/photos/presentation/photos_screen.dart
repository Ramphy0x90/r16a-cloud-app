import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/media/media_actions.dart';
import '../../../core/model/file_item.dart';
import 'photos_providers.dart';
import 'photos_state.dart';
import 'widgets/photo_placeholder_tile.dart';
import 'widgets/photo_tile.dart';
import 'widgets/year_header.dart';

/// Ported from the web client's `pages/photos`: a timeline of year
/// sections, each a square grid that loads its photos as it scrolls into
/// view. Images open in the viewer (swiping through the year's loaded
/// images); videos open in another app.
class PhotosScreen extends ConsumerWidget {
  const PhotosScreen({super.key});

  /// Web breakpoints (`photos.css`): 3 columns, 4 from 480px wide.
  static int columnsFor(double width) => width >= 480 ? 4 : 3;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(photosControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Photos')),
      body: switch (state) {
        PhotosState(loading: true) => const Center(
          child: CircularProgressIndicator(),
        ),
        PhotosState(error: != null) => _Message(
          icon: Icons.error_outline_rounded,
          title: 'Something went wrong',
          message: 'Could not load photos right now.',
          onRetry: ref.read(photosControllerProvider.notifier).retry,
        ),
        PhotosState(sections: []) => _refreshable(
          context,
          ref,
          slivers: const [
            SliverFillRemaining(
              hasScrollBody: false,
              child: _Message(
                icon: Icons.photo_library_outlined,
                title: 'No photos yet',
                message: 'Upload photos or videos to see them here',
              ),
            ),
          ],
        ),
        _ => _refreshable(
          context,
          ref,
          slivers: [
            for (final section in state.sections)
              ..._sectionSlivers(context, ref, section),
            // Clears the floating dock.
            const SliverToBoxAdapter(child: SizedBox(height: 120)),
          ],
        ),
      },
    );
  }

  Widget _refreshable(
    BuildContext context,
    WidgetRef ref, {
    required List<Widget> slivers,
  }) {
    return RefreshIndicator(
      onRefresh: () async {
        try {
          await ref.read(photosControllerProvider.notifier).refresh();
        } catch (_) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              const SnackBar(content: Text('Could not refresh photos.')),
            );
        }
      },
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: slivers,
      ),
    );
  }

  List<Widget> _sectionSlivers(
    BuildContext context,
    WidgetRef ref,
    PhotoYearSection section,
  ) {
    final controller = ref.read(photosControllerProvider.notifier);
    final columns = columnsFor(MediaQuery.sizeOf(context).width);
    final ownLoaded = section.own.length;
    final sharedStart = ownLoaded + section.pendingOwn;

    void open(FileItem file) =>
        openMediaFile(context, ref, file, gallery: section.loaded);

    return [
      SliverToBoxAdapter(
        child: YearHeader(year: section.year, count: section.totalCount),
      ),
      SliverGrid.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          mainAxisSpacing: 2,
          crossAxisSpacing: 2,
        ),
        itemCount: section.tileCount,
        itemBuilder: (context, index) {
          if (index < ownLoaded) {
            final file = section.own[index];
            return PhotoTile(
              key: ValueKey(file.id),
              file: file,
              shared: false,
              onTap: () => open(file),
            );
          }
          if (index >= sharedStart) {
            final file = section.shared[index - sharedStart];
            return PhotoTile(
              key: ValueKey(file.id),
              file: file,
              shared: true,
              onTap: () => open(file),
            );
          }
          // Keyed by how much is loaded: after each page the placeholders
          // still on screen are fresh widgets and ask for the next one.
          return PhotoPlaceholderTile(
            key: ValueKey((section.year, ownLoaded, index)),
            failed: section.failed,
            onVisible: () => controller.loadMore(section.year),
          );
        },
      ),
    ];
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.title,
    required this.message,
    this.onRetry,
  });

  final IconData icon;
  final String title;
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        // Keep content clear of the floating dock.
        padding: const EdgeInsets.fromLTRB(32, 0, 32, 120),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 56,
              color: onRetry != null ? scheme.error : scheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 12),
              TextButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ],
        ),
      ),
    );
  }
}
