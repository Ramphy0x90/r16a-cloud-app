import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/session/session_providers.dart';
import 'files_providers.dart';

/// Port of the web client's `FileDeltaSyncService`
/// (`services/file-delta-sync.service.ts`): polls `GET /fs/events` every
/// 10s from the moment syncing first starts, and for every folder touched
/// by an event drops its cached pages and reloads it if it is open
/// (`FilesController.folderChanged`).
///
/// Unlike the web, which only runs while the Files page is mounted, the
/// screen pauses this while the tab is hidden or the app is in the
/// background. The cursor survives a pause, so [start] catches up on
/// whatever changed meanwhile (the backend keeps the event log).
class FileDeltaSync {
  FileDeltaSync(
    this._ref, {
    this.interval = const Duration(seconds: 10),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  /// Pages read per poll when catching up after a long pause.
  static const maxPagesPerPoll = 5;

  final Ref _ref;
  final Duration interval;
  final DateTime Function() _now;

  Timer? _timer;
  int? _cursor;
  var _polling = false;

  bool get running => _timer != null;

  /// Starts polling. The first start only records "now" (web semantics);
  /// a restart after a pause polls immediately to catch up.
  void start() {
    if (running) return;
    final resuming = _cursor != null;
    _cursor ??= _now().millisecondsSinceEpoch;
    _timer = Timer.periodic(interval, (_) => poll());
    if (resuming) poll();
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// One poll. Overlapping calls are skipped (the web's `switchMap`
  /// equivalent) and failures are ignored until the next tick, like the
  /// web's `catchError(() => EMPTY)`.
  Future<void> poll() async {
    final since = _cursor;
    if (_polling || since == null) return;
    _polling = true;
    try {
      final ownerId = (await _ref.read(currentUserProvider.future)).id;
      final api = _ref.read(filesApiProvider);
      final changed = <String?>{};
      var cursor = since;

      for (var page = 0; page < maxPagesPerPoll; page++) {
        final events = await api.getFileEvents(ownerId: ownerId, since: cursor);
        if (events.events.isEmpty) break;
        cursor = events.nextCursor;
        changed.addAll(events.events.map((e) => e.parentId));
        if (!events.hasMore) break;
      }

      _cursor = cursor;
      final files = _ref.read(filesControllerProvider.notifier);
      for (final parentId in changed) {
        await files.folderChanged(parentId);
      }
    } catch (_) {
      // Next tick retries from the same cursor.
    } finally {
      _polling = false;
    }
  }
}
