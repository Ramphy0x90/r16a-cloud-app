import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/model/file_item.dart';
import '../../../core/session/user_preferences.dart';
import 'file_actions.dart';
import 'file_delta_sync.dart';
import 'files_providers.dart';
import 'files_state.dart';
import 'widgets/file_grid.dart';
import 'widgets/file_list.dart';
import 'widgets/file_options_sheet.dart';
import 'widgets/files_message.dart';
import 'widgets/files_tab_switcher.dart';
import 'widgets/upload_banners.dart';

/// Ported from the web client's `pages/files` + `files-toolbar`: My files /
/// Shared tabs, folder navigation, grid/list views, cursor paging, and the
/// selection toolbar. Prompts and error reporting live in [FileActions].
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

  // Delta sync runs only while this tab is shown and the app is foreground.
  late final AppLifecycleListener _lifecycle;
  late final ProviderSubscription<FileDeltaSync> _syncSubscription;
  var _appActive = true;
  var _tabVisible = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_maybeLoadMore);
    final appState = WidgetsBinding.instance.lifecycleState;
    _appActive = appState == null || appState == AppLifecycleState.resumed;
    _lifecycle = AppLifecycleListener(
      onStateChange: (state) {
        _appActive = state == AppLifecycleState.resumed;
        _updateSync();
      },
    );
    // Keeps the auto-disposed sync alive for the screen's lifetime.
    _syncSubscription = ref.listenManual(fileDeltaSyncProvider, (_, _) {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The shell disables tickers on hidden tabs.
    _tabVisible = TickerMode.valuesOf(context).enabled;
    _updateSync();
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _syncSubscription.close();
    _scrollController.dispose();
    super.dispose();
  }

  void _updateSync() {
    final sync = _syncSubscription.read();
    if (_appActive && _tabVisible) {
      sync.start();
    } else {
      sync.stop();
    }
  }

  void _maybeLoadMore() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.extentAfter < _loadMoreExtent) {
      ref.read(filesControllerProvider.notifier).loadMore();
    }
  }

  FileActions get _actions => FileActions(context, ref);

  /// In selection mode a tap toggles, like the web's `onFileAction`.
  void _onFileTap(FileItem file) {
    final controller = ref.read(filesControllerProvider.notifier);
    if (ref.read(filesControllerProvider).selectionMode) {
      controller.toggleSelected(file);
    } else if (file.isDirectory) {
      controller.openFolder(file);
    } else {
      _actions.open(file);
    }
  }

  void _onFileLongPress(FileItem file) {
    if (ref.read(filesControllerProvider).selectionMode) {
      ref.read(filesControllerProvider.notifier).toggleSelected(file);
    } else {
      _actions.showMenu(file);
    }
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

    // System back leaves selection mode first, then pops a folder level.
    return PopScope(
      canPop: state.breadcrumbs.isEmpty && !state.selectionMode,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (state.selectionMode) {
          controller.cancelSelection();
        } else {
          controller.goUp();
        }
      },
      child: Scaffold(
        appBar: _buildAppBar(context, state),
        body: Column(
          children: [
            const _UploadBanners(),
            Expanded(child: _buildBody(state, viewMode)),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, FilesState state) {
    final controller = ref.read(filesControllerProvider.notifier);
    if (state.selectionMode) return _buildSelectionAppBar(state);

    final folder = state.currentFolder;
    final actions = [
      if (!state.readOnly) ...[
        IconButton(
          onPressed: _actions.createFolder,
          icon: const Icon(Icons.create_new_folder_outlined),
          tooltip: 'New folder',
        ),
        IconButton(
          // One batch at a time, like the web overlay.
          onPressed:
              ref.watch(uploadControllerProvider.select((s) => s.uploading))
              ? null
              : _actions.upload,
          icon: const Icon(Icons.upload_rounded),
          tooltip: 'Upload',
        ),
      ],
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

  /// Web `files-toolbar` in selection mode: cancel, count, and the actions
  /// valid for the selection (share / rename need exactly one item; only
  /// download on the read-only Shared tab).
  PreferredSizeWidget _buildSelectionAppBar(FilesState state) {
    final controller = ref.read(filesControllerProvider.notifier);
    final selected = state.selectedFiles;
    final single = selected.length == 1 ? selected.single : null;

    return AppBar(
      leading: IconButton(
        onPressed: controller.cancelSelection,
        icon: const Icon(Icons.close_rounded),
        tooltip: 'Cancel selection',
      ),
      title: Text('${selected.length} selected'),
      actions: [
        if (selected.isNotEmpty)
          IconButton(
            onPressed: () => _actions.download(selected),
            icon: const Icon(Icons.download_rounded),
            tooltip: 'Download',
          ),
        if (!state.readOnly && single != null) ...[
          IconButton(
            onPressed: () => _actions.share(single),
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Share',
          ),
          IconButton(
            onPressed: () => _actions.rename(single),
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Rename',
          ),
        ],
        if (!state.readOnly && selected.isNotEmpty)
          IconButton(
            onPressed: _actions.deleteSelected,
            icon: Icon(
              Icons.delete_outline_rounded,
              color: Theme.of(context).colorScheme.error,
            ),
            tooltip: 'Delete',
          ),
      ],
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
                selectionMode: state.selectionMode,
                selectedIds: state.selectedIds,
                onTap: _onFileTap,
                onLongPress: _onFileLongPress,
              )
            : FileList(
                files: state.items,
                showSharedFrom: showSharedFrom,
                selectionMode: state.selectionMode,
                selectedIds: state.selectedIds,
                onTap: _onFileTap,
                onLongPress: _onFileLongPress,
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

/// Upload progress / failures — watched on their own so progress ticks
/// don't rebuild the file list.
class _UploadBanners extends ConsumerWidget {
  const _UploadBanners();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final upload = ref.watch(uploadControllerProvider);
    final progress = upload.progress;

    return Column(
      children: [
        if (progress != null) UploadProgressBanner(progress: progress),
        if (upload.errors.isNotEmpty)
          UploadErrorsBanner(
            errors: upload.errors,
            onDismiss: ref
                .read(uploadControllerProvider.notifier)
                .dismissErrors,
          ),
      ],
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
