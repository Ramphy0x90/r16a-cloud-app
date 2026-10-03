import '../domain/file_page.dart';
import '../domain/file_sort.dart';
import 'files_api.dart';
import 'listing_store.dart';

class _CacheEntry {
  const _CacheEntry(this.expiresAt, this.page);

  final DateTime expiresAt;
  final Future<FileCursorPage> page;
}

/// Port of the web client's `FilesCacheService`
/// (`services/files-cache.service.ts`): listing pages kept in memory for
/// 60s, keyed like the web, tracked per folder so a mutation can evict a
/// whole folder; in-flight requests shared like the web's `shareReplay`.
///
/// First pages are also persisted in a [ListingStore] (the web's IndexedDB
/// layer) and served from it for [persistTtl] without touching the network.
/// Beyond that, unlike the web, the stored copy is revalidated with its
/// ETag, so an unchanged folder costs a `304` instead of a full listing.
///
/// The backend's folder ETag is `max(updatedAt)` of the children, which a
/// delete or move-out doesn't change. That is safe here only because every
/// such change goes through [invalidateFolder] (own mutations and delta
/// sync's events), which drops the stored copy and its ETag together.
class FilesCache {
  FilesCache(this._api, {ListingStore? store, DateTime Function()? now})
    : _store = store ?? MemoryListingStore(),
      _now = now ?? DateTime.now;

  static const ttl = Duration(seconds: 60);

  /// `ENTRY_TTL_MS` of the web's `FileListingDbService`.
  static const persistTtl = Duration(minutes: 5);

  final FilesApi _api;
  final ListingStore _store;
  final DateTime Function() _now;
  final _entriesByKey = <String, _CacheEntry>{};
  final _keysByFolder = <String, Set<String>>{};

  /// Bumped per folder on invalidation, so a fetch that started before it
  /// doesn't persist a now-stale copy.
  final _folderGenerations = <String, int>{};

  /// Pending store deletions; reads wait for them.
  Future<void> _storeWrites = Future.value();

  Future<FileCursorPage> getFirstPage({
    required String ownerId,
    String? parentId,
    FileSortField sortField = FileSortField.name,
    FileSortDirection sortDirection = FileSortDirection.asc,
    int limit = FilesApi.pageSize,
  }) {
    final key = [
      ownerId,
      parentId ?? 'root',
      sortField.name,
      sortDirection.name,
      limit,
    ].join('::');
    final folderKey = _folderKey(ownerId, parentId);
    return _getOrFetch(
      key,
      folderKey,
      () => _loadFirstPage(
        key,
        folderKey,
        (ifNoneMatch) => _api.getFilesRevalidating(
          ownerId: ownerId,
          parentId: parentId,
          sortField: sortField,
          sortDirection: sortDirection,
          limit: limit,
          ifNoneMatch: ifNoneMatch,
        ),
      ),
    );
  }

  Future<FileCursorPage> getNextPage({
    required String ownerId,
    String? parentId,
    required String cursor,
    required FileSortField sortField,
    required FileSortDirection sortDirection,
    int limit = FilesApi.pageSize,
  }) {
    return _getOrFetch(
      'cursor::$cursor',
      _folderKey(ownerId, parentId),
      () => _api.getFiles(
        ownerId: ownerId,
        parentId: parentId,
        sortField: sortField,
        sortDirection: sortDirection,
        cursor: cursor,
        limit: limit,
      ),
    );
  }

  void invalidateFolder(String ownerId, String? parentId) {
    final folderKey = _folderKey(ownerId, parentId);
    _folderGenerations[folderKey] = (_folderGenerations[folderKey] ?? 0) + 1;
    // Trailing separator: 'owner::root' must not match 'owner::rootX'.
    _storeWrites = _storeWrites.then(
      (_) => _store.deleteByPrefix('$folderKey::'),
    );
    final keys = _keysByFolder.remove(folderKey);
    if (keys == null) return;
    for (final key in keys) {
      _entriesByKey.remove(key);
    }
  }

  /// Everything, persisted copies included (sign-out).
  Future<void> clear() {
    _entriesByKey.clear();
    _keysByFolder.clear();
    for (final key in _folderGenerations.keys) {
      _folderGenerations[key] = _folderGenerations[key]! + 1;
    }
    return _storeWrites = _storeWrites.then((_) => _store.clear());
  }

  /// Stored copy if fresh; else the network, revalidating with the stored
  /// ETag when there is one.
  Future<FileCursorPage> _loadFirstPage(
    String key,
    String folderKey,
    Future<({FileCursorPage? page, String? etag})> Function(String? ifNoneMatch)
    fetch,
  ) async {
    final generation = _folderGenerations[folderKey] ?? 0;
    await _storeWrites;
    final stored = await _store.get(key);
    final now = _now();
    if (stored != null && now.difference(stored.storedAt) < persistTtl) {
      return stored.page;
    }

    final result = await fetch(stored?.etag);
    final page = result.page ?? stored?.page;
    if (page == null) {
      // 304 is only possible when an ETag was sent, i.e. with a copy.
      throw StateError('304 Not Modified without a stored listing');
    }
    if ((_folderGenerations[folderKey] ?? 0) == generation) {
      await _store.put(
        key,
        result.page == null
            ? stored!.touched(now)
            : StoredListing(page: page, etag: result.etag, storedAt: now),
      );
    }
    return page;
  }

  Future<FileCursorPage> _getOrFetch(
    String key,
    String folderKey,
    Future<FileCursorPage> Function() fetch,
  ) {
    final now = _now();
    final existing = _entriesByKey[key];
    if (existing != null && existing.expiresAt.isAfter(now)) {
      return existing.page;
    }

    final page = fetch();
    // Failed fetches must not be served from cache. The callback's own
    // future swallows the error; callers still see it through [page].
    page.then((_) {}, onError: (Object _) => _evictKey(key, page));

    _entriesByKey[key] = _CacheEntry(now.add(ttl), page);
    (_keysByFolder[folderKey] ??= <String>{}).add(key);
    _pruneExpired(now);
    return page;
  }

  /// Only evicts if [key] still maps to [page] — a newer fetch may have
  /// replaced it in the meantime.
  void _evictKey(String key, Future<FileCursorPage> page) {
    if (!identical(_entriesByKey[key]?.page, page)) return;
    _entriesByKey.remove(key);
    for (final keys in _keysByFolder.values) {
      keys.remove(key);
    }
  }

  void _pruneExpired(DateTime now) {
    final expired = [
      for (final MapEntry(:key, :value) in _entriesByKey.entries)
        if (!value.expiresAt.isAfter(now)) key,
    ];
    for (final key in expired) {
      _entriesByKey.remove(key);
      for (final keys in _keysByFolder.values) {
        keys.remove(key);
      }
    }
  }

  static String _folderKey(String ownerId, String? parentId) =>
      '$ownerId::${parentId ?? 'root'}';
}
