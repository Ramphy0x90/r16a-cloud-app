import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/session/session_providers.dart';
import '../../../core/session/user_preferences.dart';
import '../domain/file_item.dart';
import '../domain/file_sort.dart';
import 'files_providers.dart';
import 'files_state.dart';

/// Listing + navigation logic of the web `FilesPage` (`pages/files/files.ts`):
/// folder stack, My files / Shared tabs, sort, and cursor paging guarded by
/// a generation counter so a stale "load more" never lands after a
/// navigation or sort change.
class FilesController extends Notifier<FilesState> {
  /// Bumps on each full list refresh — mirrors `fileListGeneration`.
  int _generation = 0;

  @override
  FilesState build() {
    Future.microtask(_loadSafely);
    return const FilesState();
  }

  void openFolder(FileItem folder) {
    if (!folder.isDirectory || state.readOnly) return;
    _navigate([...state.breadcrumbs, folder]);
  }

  /// Pops one folder level. Returns `false` when already at root.
  bool goUp() {
    if (state.breadcrumbs.isEmpty) return false;
    _navigate(state.breadcrumbs.sublist(0, state.breadcrumbs.length - 1));
    return true;
  }

  void goToRoot() {
    if (state.breadcrumbs.isEmpty) return;
    _navigate(const []);
  }

  /// Exits subfolders when switching tabs — shared files are a flat list.
  void setTab(FilesTab tab) {
    if (state.tab == tab) return;
    state = state.copyWith(tab: tab, breadcrumbs: const []);
    _loadSafely();
  }

  /// Picking a field resets the direction to ascending, like the web.
  void setSortField(FileSortField field) {
    state = state.copyWith(
      sortField: field,
      sortDirection: FileSortDirection.asc,
    );
    _loadSafely();
  }

  void setSortDirection(FileSortDirection direction) {
    if (state.sortDirection == direction) return;
    state = state.copyWith(sortDirection: direction);
    _loadSafely();
  }

  void setViewMode(DefaultFileView mode) {
    state = state.copyWith(viewMode: mode);
  }

  /// Retry after a failed load.
  void retry() => _loadSafely();

  /// Pull-to-refresh: drops the folder's cached pages and reloads in place,
  /// keeping the current list visible. Throws on failure so the caller can
  /// report it.
  Future<void> refresh() async {
    if (state.tab == FilesTab.mine) {
      final user = await ref.read(currentUserProvider.future);
      ref
          .read(filesCacheProvider)
          .invalidateFolder(user.id, state.currentFolder?.id);
    }
    await _load(silent: true);
  }

  /// Infinite-scroll trigger — mirrors `loadMoreFiles()`.
  Future<void> loadMore() async {
    final s = state;
    final cursor = s.nextCursor;
    if (s.tab != FilesTab.mine ||
        s.loading ||
        s.loadingMore ||
        !s.hasMore ||
        cursor == null) {
      return;
    }

    final gen = _generation;
    state = s.copyWith(loadingMore: true);
    try {
      final user = await ref.read(currentUserProvider.future);
      final page = await ref
          .read(filesCacheProvider)
          .getNextPage(
            ownerId: user.id,
            parentId: s.currentFolder?.id,
            cursor: cursor,
            sortField: s.sortField,
            sortDirection: s.sortDirection,
          );
      if (!ref.mounted || gen != _generation) return;
      state = state.copyWith(
        items: [...state.items, ...page.content],
        hasMore: page.hasMore,
        nextCursor: page.nextCursor,
        loadingMore: false,
      );
    } catch (_) {
      if (!ref.mounted || gen != _generation) return;
      state = state.copyWith(loadingMore: false);
    }
  }

  void _navigate(List<FileItem> breadcrumbs) {
    state = state.copyWith(breadcrumbs: breadcrumbs);
    _loadSafely();
  }

  /// A full load whose failure lands in [FilesState.error] instead of
  /// escaping.
  Future<void> _loadSafely() => _load(silent: false).catchError((_) {});

  Future<void> _load({required bool silent}) async {
    final gen = ++_generation;
    final s = state;
    if (!silent) {
      state = s.copyWith(loading: true, error: null, loadingMore: false);
    }

    try {
      final List<FileItem> items;
      var hasMore = false;
      String? nextCursor;

      if (s.tab == FilesTab.shared) {
        items = await ref
            .read(filesApiProvider)
            .getFilesSharedWithMe(
              sortField: s.sortField,
              sortDirection: s.sortDirection,
            );
      } else {
        final user = await ref.read(currentUserProvider.future);
        final page = await ref
            .read(filesCacheProvider)
            .getFirstPage(
              ownerId: user.id,
              parentId: s.currentFolder?.id,
              sortField: s.sortField,
              sortDirection: s.sortDirection,
            );
        items = page.content;
        hasMore = page.hasMore;
        nextCursor = page.nextCursor;
      }

      if (!ref.mounted || gen != _generation) return;
      state = state.copyWith(
        items: items,
        hasMore: hasMore,
        nextCursor: nextCursor,
        loading: false,
        loadingMore: false,
        error: null,
      );
    } catch (e) {
      if (!ref.mounted || gen != _generation) return;
      if (silent) rethrow;
      state = state.copyWith(loading: false, error: e);
    }
  }
}
