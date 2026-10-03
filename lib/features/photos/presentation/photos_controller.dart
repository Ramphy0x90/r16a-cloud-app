import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/media/media_providers.dart';
import '../../../core/model/file_item.dart';
import '../../../core/session/session_providers.dart';
import '../domain/photo_year.dart';
import 'photos_providers.dart';
import 'photos_state.dart';

/// Port of the web `PhotosPage` (`pages/photos/photos.ts`): own year counts
/// plus shared media grouped by year, merged newest first; each year's own
/// photos then load lazily, page by page, as its tiles come on screen.
class PhotosController extends Notifier<PhotosState> {
  /// Waits for a burst of media changes (e.g. a delta-sync poll touching
  /// several folders) to settle before reloading.
  static const refreshDebounce = Duration(seconds: 1);

  /// Bumps on each full reload so stale page results are dropped.
  var _generation = 0;
  Timer? _refreshDebounce;

  @override
  PhotosState build() {
    Future.microtask(() => _load().catchError((_) {}));
    // Uploads / deletes elsewhere in the app: rebuild the timeline quietly,
    // once per burst of changes.
    ref.listen(mediaRevisionProvider, (_, _) {
      _refreshDebounce?.cancel();
      _refreshDebounce = Timer(refreshDebounce, () {
        _load(silent: true).catchError((_) {});
      });
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

  Future<void> _load({bool silent = false}) async {
    final gen = ++_generation;
    if (!silent) state = const PhotosState();
    try {
      final ownerId = (await ref.read(currentUserProvider.future)).id;
      final api = ref.read(photosApiProvider);
      final (years, shared) = await (
        api.getPhotoYears(ownerId),
        // Like the web: shared media is a bonus, never a reason to fail.
        api.getSharedMedia().catchError((_) => <FileItem>[]),
      ).wait;
      if (!ref.mounted || gen != _generation) return;
      state = PhotosState(loading: false, sections: _sections(years, shared));
    } catch (e) {
      if (!ref.mounted || gen != _generation) return;
      if (silent) rethrow;
      state = PhotosState(loading: false, error: e);
    }
  }

  /// Years from both sources, newest first. Shared media is filed under
  /// the UTC year of `takenAt ?? createdAt`, like the web.
  static List<PhotoYearSection> _sections(
    List<PhotoYear> years,
    List<FileItem> shared,
  ) {
    final sharedByYear = <int, List<FileItem>>{};
    for (final file in shared) {
      final year = (file.takenAt ?? file.createdAt).toUtc().year;
      (sharedByYear[year] ??= []).add(file);
    }
    final ownByYear = {for (final y in years) y.year: y.count};
    final allYears = {...ownByYear.keys, ...sharedByYear.keys}.toList()
      ..sort((a, b) => b.compareTo(a));

    return [
      for (final year in allYears)
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
