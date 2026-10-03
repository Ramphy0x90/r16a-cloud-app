import '../../../core/model/file_item.dart';

/// One year of the Photos timeline — mirrors the web's `YearSection`
/// (`types/photo.ts`). Own photos load lazily page by page; photos shared
/// with the user are known up front and listed after them, as on the web.
class PhotoYearSection {
  const PhotoYearSection({
    required this.year,
    required this.ownCount,
    this.own = const [],
    this.shared = const [],
    this.cursor,
    this.hasMore = true,
    this.started = false,
    this.loading = false,
    this.failed = false,
  });

  final int year;

  /// Own photos the server reported for this year (`/photos/years`).
  final int ownCount;
  final List<FileItem> own;
  final List<FileItem> shared;
  final String? cursor;
  final bool hasMore;

  /// First page requested — the web's `loadStarted$`.
  final bool started;
  final bool loading;

  /// Last page request failed; placeholders stop asking until a refresh.
  final bool failed;

  /// Header count, like the web's `totalCount`.
  int get totalCount => ownCount + shared.length;

  /// Placeholder tiles still to fill with own photos. Reserves the grid's
  /// full height up front (the web's `gridHeight`), and never strands
  /// placeholders when the year count was stale.
  int get pendingOwn {
    if (!started) return ownCount;
    if (!hasMore) return 0;
    final remaining = ownCount - own.length;
    return remaining > 0 ? remaining : 1;
  }

  int get tileCount => own.length + pendingOwn + shared.length;

  /// Loaded photos in display order.
  List<FileItem> get loaded => [...own, ...shared];

  bool get canLoadMore => !loading && !failed && (!started || hasMore);

  PhotoYearSection copyWith({
    List<FileItem>? own,
    String? cursor,
    bool? hasMore,
    bool? started,
    bool? loading,
    bool? failed,
  }) => PhotoYearSection(
    year: year,
    ownCount: ownCount,
    own: own ?? this.own,
    shared: shared,
    cursor: cursor ?? this.cursor,
    hasMore: hasMore ?? this.hasMore,
    started: started ?? this.started,
    loading: loading ?? this.loading,
    failed: failed ?? this.failed,
  );
}

class PhotosState {
  const PhotosState({
    this.loading = true,
    this.error,
    this.sections = const [],
  });

  final bool loading;
  final Object? error;

  /// Newest year first.
  final List<PhotoYearSection> sections;
}

/// Hero tag prefix for Photos thumbnails (see `filesHeroPrefix`).
const photosHeroPrefix = 'photos:';
