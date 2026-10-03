import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/session/user_preferences.dart';
import '../domain/file_item.dart';
import 'file_viewer_screen.dart';
import 'files_providers.dart';
import 'files_state.dart';
import 'widgets/file_grid.dart';
import 'widgets/file_list.dart';
import 'widgets/file_options_sheet.dart';
import 'widgets/files_message.dart';
import 'widgets/files_tab_switcher.dart';

/// Ported from the web client's `pages/files` + `files-toolbar`: My files /
/// Shared tabs, folder navigation, grid/list views and cursor paging.
class FilesScreen extends ConsumerStatefulWidget {
  const FilesScreen({super.key});

  @override
  ConsumerState<FilesScreen> createState() => _FilesScreenState();
}

class _FilesScreenState extends ConsumerState<FilesScreen> {
  /// How close to the end (in px) the next page is requested — stands in
  /// for the web's `inViewport` load-more sentinel.
  static const _loadMoreExtent = 600.0;

  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_maybeLoadMore);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _maybeLoadMore() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.extentAfter < _loadMoreExtent) {
      ref.read(filesControllerProvider.notifier).loadMore();
    }
  }

  void _onFileTap(FileItem file) {
    if (file.isDirectory) {
      ref.read(filesControllerProvider.notifier).openFolder(file);
      return;
    }
    if (file.isImage) {
      final images = ref
          .read(filesControllerProvider)
          .items
          .where((f) => f.isImage)
          .toList();
      // Root navigator: the viewer covers the dock.
      Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute<void>(
          builder: (_) => FileViewerScreen(
            files: images,
            initialIndex: images.indexWhere((f) => f.id == file.id),
          ),
        ),
      );
    }
    // Videos and other files open once downloads land (transfer step).
  }

  Future<void> _refresh() async {
    try {
      await ref.read(filesControllerProvider.notifier).refresh();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not refresh files.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(filesControllerProvider);
    final viewMode = ref.watch(filesViewModeProvider);
    final controller = ref.read(filesControllerProvider.notifier);

    // A short first page never scrolls, so check after layout too.
    ref.listen(filesControllerProvider.select((s) => s.items.length), (_, _) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _maybeLoadMore());
    });

    return PopScope(
      canPop: state.breadcrumbs.isEmpty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) controller.goUp();
      },
      child: Scaffold(
        appBar: _buildAppBar(context, state),
        body: _buildBody(state, viewMode),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, FilesState state) {
    final controller = ref.read(filesControllerProvider.notifier);
    final folder = state.currentFolder;
    final actions = [
      IconButton(
        onPressed: () => showFileOptionsSheet(context),
        icon: const Icon(Icons.more_vert_rounded),
        tooltip: 'Options',
      ),
    ];

    if (folder == null) {
      return AppBar(
        title: FilesTabSwitcher(tab: state.tab, onChanged: controller.setTab),
        actions: actions,
      );
    }

    // Web `breadcrumb.html`: a single back chip naming where it leads.
    final crumbs = state.breadcrumbs;
    final backLabel = crumbs.length == 1
        ? 'Home'
        : crumbs[crumbs.length - 2].name;
    return AppBar(
      automaticallyImplyLeading: false,
      titleSpacing: 8,
      title: Row(
        children: [
          _BackChip(
            label: backLabel,
            onTap: controller.goUp,
            onLongPress: controller.goToRoot,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              folder.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      actions: actions,
    );
  }

  Widget _buildBody(FilesState state, DefaultFileView viewMode) {
    if (state.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final Widget content;
    if (state.items.isEmpty) {
      final message = state.error != null
          ? FilesMessage(
              icon: Icons.error_outline_rounded,
              title: 'Something went wrong',
              message: 'Could not load files right now.',
              isError: true,
              onRetry: ref.read(filesControllerProvider.notifier).retry,
            )
          : state.tab == FilesTab.shared
          ? const FilesMessage(
              icon: Icons.people_outline,
              title: 'Nothing shared with you yet',
              message: 'Files other users share with you will appear here',
            )
          : const FilesMessage(
              icon: Icons.cloud_outlined,
              title: 'No files yet',
              message: 'Upload files or create a folder to get started',
            );
      content = SliverFillRemaining(
        hasScrollBody: false,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 120),
          child: Center(child: message),
        ),
      );
    } else {
      final showSharedFrom = state.tab == FilesTab.shared;
      content = SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        sliver: viewMode == DefaultFileView.grid
            ? FileGrid(
                files: state.items,
                showSharedFrom: showSharedFrom,
                onTap: _onFileTap,
              )
            : FileList(
                files: state.items,
                showSharedFrom: showSharedFrom,
                onTap: _onFileTap,
              ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: CustomScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          content,
          if (state.loadingMore)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(
                  'Loading more…',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          // Clears the floating dock.
          if (state.items.isNotEmpty)
            const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ),
    );
  }
}

class _BackChip extends StatelessWidget {
  const _BackChip({
    required this.label,
    required this.onTap,
    required this.onLongPress,
  });

  final String label;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Tooltip(
      message: 'Back to $label',
      child: Material(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onTap,
          onLongPress: onLongPress,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 140),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(6, 6, 12, 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.chevron_left_rounded, size: 20),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
