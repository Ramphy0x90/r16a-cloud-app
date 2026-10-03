import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/model/file_item.dart';
import '../../../core/session/session_providers.dart';
import '../../../core/session/user_preferences.dart';
import '../domain/file_sort.dart';
import 'files_providers.dart';
import 'files_state.dart';

/// Listing, navigation, selection and mutations of the web `FilesPage`
/// (`pages/files/files.ts`): folder stack, My files / Shared tabs, sort,
/// cursor paging guarded by a generation counter so a stale "load more"
/// never lands after a navigation or sort change, and create / rename /
/// share / delete with folder-cache invalidation.
///
/// Mutation methods throw `ApiException` on failure so the screen can
/// report it; the list is left as it was.
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
    state = state.copyWith(
      tab: tab,
      breadcrumbs: const [],
      selectionMode: false,
      selectedIds: const {},
    );
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
      // Skips items already shown, e.g. a folder created locally that
      // sorts into a page loaded later.
      final shown = {for (final f in state.items) f.id};
      state = state.copyWith(
        items: [
          ...state.items,
          ...page.content.where((f) => !shown.contains(f.id)),
        ],
        hasMore: page.hasMore,
        nextCursor: page.nextCursor,
        loadingMore: false,
      );
    } catch (_) {
      if (!ref.mounted || gen != _generation) return;
      state = state.copyWith(loadingMore: false);
    }
  }

  // ── Selection ───────────────────────────────────────────────────────────

  void setSelectionMode(bool enabled) {
    state = state.copyWith(
      selectionMode: enabled,
      selectedIds: enabled ? state.selectedIds : const {},
    );
  }

  /// Enters selection mode with [file] already selected (long-press flow).
  void startSelection(FileItem file) {
    state = state.copyWith(selectionMode: true, selectedIds: {file.id});
  }

  void toggleSelected(FileItem file) {
    final next = {...state.selectedIds};
    if (!next.remove(file.id)) next.add(file.id);
    state = state.copyWith(selectedIds: next);
  }

  void cancelSelection() => setSelectionMode(false);

  // ── Mutations ───────────────────────────────────────────────────────────

  /// Inserts the new folder in place (folders first, then the active sort),
  /// like the web's `createFolder()`, without reloading.
  Future<void> createFolder(String name) async {
    final user = await ref.read(currentUserProvider.future);
    final parentId = state.currentFolder?.id;
    final folder = await ref
        .read(filesApiProvider)
        .createFolder(ownerId: user.id, name: name.trim(), parentId: parentId);
    _invalidate(user.id, parentId);
    if (!ref.mounted || state.currentFolder?.id != parentId) return;
    state = state.copyWith(items: _sorted([...state.items, folder]));
  }

  Future<void> rename(FileItem file, String name) async {
    final updated = await ref
        .read(filesApiProvider)
        .rename(file.id, name.trim());
    _afterUpdate(updated);
  }

  Future<void> updateSharing(FileItem file, List<String> sharedWithIds) async {
    final updated = await ref
        .read(filesApiProvider)
        .updateSharing(file.id, sharedWithIds);
    _afterUpdate(updated);
  }

  Future<void> delete(FileItem file) => _deleteAll([file]);

  /// Something outside this controller changed [parentId] (uploads; later
  /// delta sync): drop its cached pages and, if it is still the open
  /// folder, reload it in place — the web's
  /// `refreshCurrentFolderAfterMutation()`.
  Future<void> folderChanged(String? parentId) async {
    final user = await ref.read(currentUserProvider.future);
    _invalidate(user.id, parentId);
    if (!ref.mounted ||
        state.tab != FilesTab.mine ||
        state.currentFolder?.id != parentId) {
      return;
    }
    await _load(silent: true).catchError((_) {});
  }

  /// Bulk delete of the selection — mirrors `confirmBulkDelete()`: on any
  /// failure the folder is reloaded so the list shows what really remains.
  Future<void> deleteSelected() async {
    final files = state.selectedFiles;
    if (files.isEmpty) return;
    try {
      await _deleteAll(files);
    } catch (_) {
      if (ref.mounted) {
        cancelSelection();
        _loadSafely();
      }
      rethrow;
    }
  }

  Future<void> _deleteAll(List<FileItem> files) async {
    final api = ref.read(filesApiProvider);
    final user = await ref.read(currentUserProvider.future);
    final parentId = state.currentFolder?.id;
    try {
      await Future.wait(files.map((f) => api.delete(f.id)));
    } finally {
      // Also on partial failure: some items may be gone already.
      _invalidate(user.id, parentId);
      // A deleted folder's own listing must not be served from cache either.
      for (final folder in files.where((f) => f.isDirectory)) {
        _invalidate(user.id, folder.id);
      }
    }
    if (!ref.mounted) return;

    final ids = {for (final f in files) f.id};
    state = state.copyWith(
      items: state.items.where((f) => !ids.contains(f.id)).toList(),
      selectionMode: false,
      selectedIds: const {},
    );
  }

  /// Swaps in the server's copy, leaves selection mode and reloads quietly
  /// so the order reflects the change (the web reloads with a spinner).
  void _afterUpdate(FileItem updated) {
    if (!ref.mounted) return;
    _invalidate(updated.ownerId, updated.parentId);
    state = state.copyWith(
      items: [for (final f in state.items) f.id == updated.id ? updated : f],
      selectionMode: false,
      selectedIds: const {},
    );
    _load(silent: true).catchError((_) {});
  }

  void _invalidate(String ownerId, String? parentId) =>
      ref.read(filesCacheProvider).invalidateFolder(ownerId, parentId);

  /// Folders first, then the active sort field and direction.
  List<FileItem> _sorted(List<FileItem> items) {
    final dir = state.sortDirection == FileSortDirection.asc ? 1 : -1;
    final byName = state.sortField == FileSortField.name;
    return [...items]..sort((a, b) {
      if (a.isDirectory != b.isDirectory) return a.isDirectory ? -1 : 1;
      final c = byName
          ? a.name.compareTo(b.name)
          : a.updatedAt.compareTo(b.updatedAt);
      return c * dir;
    });
  }

  void _navigate(List<FileItem> breadcrumbs) {
    state = state.copyWith(
      breadcrumbs: breadcrumbs,
      selectionMode: false,
      selectedIds: const {},
    );
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
