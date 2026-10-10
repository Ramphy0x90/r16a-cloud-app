import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/media/media_providers.dart';
import '../../../core/model/file_item.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/network_status.dart';
import '../../../core/session/session_providers.dart';
import '../../files/domain/file_page.dart';
import '../domain/photo_year.dart';
import 'photos_providers.dart';
import 'photos_state.dart';

/// Port of the web `PhotosPage` (`pages/photos/photos.ts`): own year counts
/// plus shared media grouped by year, merged newest first; each year's own
/// photos then load lazily, page by page, as its tiles come on screen.
///
/// Mobile-only: the timeline and each year's first page are stored
/// ([PhotosStore]) and shown when the server can't be reached, until the
/// app is back online.
class PhotosController extends Notifier<PhotosState> {
  /// Waits for a burst of media changes (e.g. a delta-sync poll touching
  /// several folders) to settle before reloading.
  static const refreshDebounce = Duration(seconds: 1);

  /// Bumps on each full reload so stale page results are dropped.
  var _generation = 0;
  Timer? _refreshDebounce;

  /// The timeline on screen is the stored one: reload once back online.
  var _showingStored = false;

  @override
  PhotosState build() {
    Future.microtask(() => _load().catchError((_) {}));
    // Uploads / deletes elsewhere in the app: rebuild the timeline quietly,
    // once per burst of changes, keeping years whose count didn't change.
    ref.listen(mediaRevisionProvider, (_, _) {
      _refreshDebounce?.cancel();
      _refreshDebounce = Timer(refreshDebounce, () {
        _load(silent: true, keepUnchanged: true).catchError((_) {});
      });
    });
    ref.listen(networkStatusProvider, (_, next) {
      if (next == NetworkStatus.online && _showingStored) {
        _load(silent: true, keepUnchanged: true).catchError((_) {});
      }
    });
    ref.onDispose(() => _refreshDebounce?.cancel());
    return const PhotosState();
  }

  void retry() => _load().catchError((_) {});

  /// Pull-to-refresh: rebuilds the timeline, keeping the current one on
  /// screen until the new one arrives. Throws on failure.
  Future<void> refresh() => _load(silent: true);

  /// Next page of [year]'s own photos; no-op while one is in flight or
  /// when nothing is left.
  Future<void> loadMore(int year) async {
    final section = _section(year);
    if (section == null || !section.canLoadMore) return;

    final gen = _generation;
    _update(year, (s) => s.copyWith(loading: true));
    try {
      final ownerId = (await ref.read(currentUserProvider.future)).id;
      final page = await ref
          .read(photosApiProvider)
          .getPhotos(ownerId: ownerId, year: year, cursor: section.cursor);
      if (section.cursor == null) {
        ref.read(photosStoreProvider).saveFirstPage(ownerId, year, page);
      }
      if (!ref.mounted || gen != _generation) return;
      _update(year, (s) {
        final shown = {for (final f in s.own) f.id};
        return s.copyWith(
          own: [...s.own, ...page.content.where((f) => !shown.contains(f.id))],
          cursor: page.nextCursor,
          hasMore: page.hasMore,
          started: true,
          loading: false,
        );
      });
    } catch (_) {
      if (!ref.mounted || gen != _generation) return;
      _update(year, (s) => s.copyWith(loading: false, failed: true));
    }
  }

  /// [keepUnchanged]: a year whose own count is the same keeps the photos
  /// already loaded instead of going back to placeholders.
  Future<void> _load({bool silent = false, bool keepUnchanged = false}) async {
    final gen = ++_generation;
    if (!silent) state = const PhotosState();
    String? ownerId;
    try {
      final owner = ownerId = (await ref.read(currentUserProvider.future)).id;
      final api = ref.read(photosApiProvider);
      // Like the web: shared media is a bonus, never a reason to fail.
      final sharedRequest = api.getSharedMedia().catchError(
        (_) => <FileItem>[],
      );
      final years = await api.getPhotoYears(owner);
      final shared = await sharedRequest;
      ref.read(photosStoreProvider).saveTimeline(owner, years, shared);
      if (!ref.mounted || gen != _generation) return;
      _showingStored = false;
      state = PhotosState(
        loading: false,
        sections: _sections(
          years,
          shared,
          previous: keepUnchanged ? state.sections : const [],
        ),
      );
    } catch (e) {
      if (!ref.mounted || gen != _generation) return;
      if (silent) rethrow;
      // Server unreachable: the last timeline seen beats an error screen.
      final stored =
          ownerId != null && e is ApiException && e.statusCode == null
          ? await ref.read(photosStoreProvider).read(ownerId)
          : null;
      if (!ref.mounted || gen != _generation) return;
      if (stored == null) {
        state = PhotosState(loading: false, error: e);
        return;
      }
      _showingStored = true;
      state = PhotosState(
        loading: false,
        sections: _withFirstPages(
          _sections(stored.years, stored.shared),
          stored.firstPages,
        ),
      );
    }
  }

  static List<PhotoYearSection> _withFirstPages(
    List<PhotoYearSection> sections,
    Map<int, FileCursorPage> pages,
  ) => [
    for (final s in sections)
      if (pages[s.year] case final page? when s.ownCount > 0)
        s.copyWith(
          own: page.content,
          cursor: page.nextCursor,
          hasMore: page.hasMore,
          started: true,
        )
      else
        s,
  ];

  /// Years from both sources, newest first. Shared media is filed under
  /// the UTC year of `takenAt ?? createdAt`, like the web. A year in
  /// [previous] with the same own count keeps its loaded pages.
  static List<PhotoYearSection> _sections(
    List<PhotoYear> years,
    List<FileItem> shared, {
    List<PhotoYearSection> previous = const [],
  }) {
    final sharedByYear = <int, List<FileItem>>{};
    for (final file in shared) {
      final year = (file.takenAt ?? file.createdAt).toUtc().year;
      (sharedByYear[year] ??= []).add(file);
    }
    final ownByYear = {for (final y in years) y.year: y.count};
    final allYears = {...ownByYear.keys, ...sharedByYear.keys}.toList()
      ..sort((a, b) => b.compareTo(a));
    final kept = {
      for (final s in previous)
        if (s.started && s.ownCount > 0 && s.ownCount == ownByYear[s.year])
          s.year: s,
    };

    return [
      for (final year in allYears)
        if (kept[year] case final old?)
          PhotoYearSection(
            year: year,
            ownCount: old.ownCount,
            own: old.own,
            shared: sharedByYear[year] ?? const [],
            cursor: old.cursor,
            hasMore: old.hasMore,
            started: true,
          )
        else
          PhotoYearSection(
            year: year,
            ownCount: ownByYear[year] ?? 0,
            shared: sharedByYear[year] ?? const [],
            // No own photos this year: nothing to load.
            started: (ownByYear[year] ?? 0) == 0,
            hasMore: (ownByYear[year] ?? 0) > 0,
          ),
    ];
  }

  PhotoYearSection? _section(int year) {
    for (final s in state.sections) {
      if (s.year == year) return s;
    }
    return null;
  }

  void _update(int year, PhotoYearSection Function(PhotoYearSection) change) {
    state = PhotosState(
      loading: state.loading,
      error: state.error,
      sections: [
        for (final s in state.sections) s.year == year ? change(s) : s,
      ],
    );
  }
}
