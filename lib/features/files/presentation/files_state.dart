import '../../../core/session/user_preferences.dart';
import '../domain/file_item.dart';
import '../domain/file_sort.dart';

/// The web toolbar's `filter-tabs`: "My files" | "Shared".
enum FilesTab { mine, shared }

const _unset = Object();

/// Browse state of the Files screen — mirrors the fields `FilesPage`
/// (`pages/files/files.ts`) keeps for listing and navigation.
class FilesState {
  const FilesState({
    this.tab = FilesTab.mine,
    this.breadcrumbs = const [],
    this.sortField = FileSortField.name,
    this.sortDirection = FileSortDirection.asc,
    this.viewMode,
    this.items = const [],
    this.loading = true,
    this.error,
    this.hasMore = false,
    this.nextCursor,
    this.loadingMore = false,
    this.selectionMode = false,
    this.selectedIds = const {},
  });

  final FilesTab tab;

  /// Folders from root to the current one; empty at root.
  final List<FileItem> breadcrumbs;
  final FileSortField sortField;
  final FileSortDirection sortDirection;

  /// `null` until the user picks one in the options sheet — until then the
  /// screen follows `UserPreferences.defaultViewMode`, like the web.
  final DefaultFileView? viewMode;

  final List<FileItem> items;

  /// Full (non-silent) load in progress.
  final bool loading;

  /// Last full load failure; cleared on the next load.
  final Object? error;
  final bool hasMore;
  final String? nextCursor;
  final bool loadingMore;

  /// Multi-select mode — mirrors `selectionMode` / `selectedFileIds`.
  final bool selectionMode;
  final Set<String> selectedIds;

  /// Selected items in listing order.
  List<FileItem> get selectedFiles =>
      items.where((f) => selectedIds.contains(f.id)).toList();

  FileItem? get currentFolder => breadcrumbs.isEmpty ? null : breadcrumbs.last;

  /// Shared-with-me is read-only, like the web toolbar's `readOnly`.
  bool get readOnly => tab == FilesTab.shared;

  FilesState copyWith({
    FilesTab? tab,
    List<FileItem>? breadcrumbs,
    FileSortField? sortField,
    FileSortDirection? sortDirection,
    DefaultFileView? viewMode,
    List<FileItem>? items,
    bool? loading,
    Object? error = _unset,
    bool? hasMore,
    Object? nextCursor = _unset,
    bool? loadingMore,
    bool? selectionMode,
    Set<String>? selectedIds,
  }) => FilesState(
    tab: tab ?? this.tab,
    breadcrumbs: breadcrumbs ?? this.breadcrumbs,
    sortField: sortField ?? this.sortField,
    sortDirection: sortDirection ?? this.sortDirection,
    viewMode: viewMode ?? this.viewMode,
    items: items ?? this.items,
    loading: loading ?? this.loading,
    error: identical(error, _unset) ? this.error : error,
    hasMore: hasMore ?? this.hasMore,
    nextCursor: identical(nextCursor, _unset)
        ? this.nextCursor
        : nextCursor as String?,
    loadingMore: loadingMore ?? this.loadingMore,
    selectionMode: selectionMode ?? this.selectionMode,
    selectedIds: selectedIds ?? this.selectedIds,
  );
}
