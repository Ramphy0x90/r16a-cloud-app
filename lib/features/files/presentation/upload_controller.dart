import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/session/session_providers.dart';
import '../data/upload_source.dart';
import 'files_providers.dart';

/// Mirrors the web `FilesPage.uploadOverlay`: "i / n — name" plus overall
/// bytes.
class UploadProgress {
  const UploadProgress({
    required this.currentIndex,
    required this.fileCount,
    required this.currentName,
    required this.overallLoaded,
    required this.overallTotal,
  });

  /// 1-based index of the most recently started file.
  final int currentIndex;
  final int fileCount;
  final String currentName;
  final int overallLoaded;
  final int overallTotal;

  /// 0..1; an all-empty batch counts as done.
  double get fraction =>
      overallTotal <= 0 ? 1 : (overallLoaded / overallTotal).clamp(0, 1);
}

class UploadState {
  const UploadState({this.progress, this.errors = const []});

  /// Non-null while a batch is running.
  final UploadProgress? progress;

  /// "name: reason" per failed file — the web's `uploadErrors`.
  final List<String> errors;

  bool get uploading => progress != null;
}

/// Runs an upload batch like the web's `uploadFiles()`: two files at a time,
/// per-file errors collected without stopping the rest, and the target
/// folder refreshed once the batch ends. The target folder is captured at
/// start, so navigating away mid-upload is fine.
class UploadController extends Notifier<UploadState> {
  /// Same as the web's `mergeMap(..., 2)`.
  static const concurrency = 2;

  @override
  UploadState build() => const UploadState();

  void dismissErrors() {
    state = UploadState(progress: state.progress);
  }

  /// Ignored while a batch is already running (the button is disabled).
  Future<void> upload(List<UploadSource> sources, {String? parentId}) async {
    if (sources.isEmpty || state.uploading) return;

    final total = sources.fold<int>(0, (sum, s) => sum + s.size);
    // Claimed before any await, so a double tap cannot start two batches.
    state = UploadState(
      progress: UploadProgress(
        currentIndex: 0,
        fileCount: sources.length,
        currentName: '',
        overallLoaded: 0,
        overallTotal: total,
      ),
    );

    final String ownerId;
    try {
      ownerId = (await ref.read(currentUserProvider.future)).id;
    } catch (_) {
      state = UploadState(
        errors: [for (final s in sources) '${s.name}: Upload failed'],
      );
      return;
    }

    final uploader = ref.read(fileUploaderProvider);
    final loaded = List<int>.filled(sources.length, 0);
    final errors = <String>[];
    var current = 0;
    var lastPercent = -1;

    void emit({bool force = false}) {
      final sum = loaded.fold<int>(0, (a, b) => a + b);
      // Progress callbacks are frequent; rebuild once per whole percent.
      final percent = total == 0 ? 100 : sum * 100 ~/ total;
      if (!force && percent == lastPercent) return;
      lastPercent = percent;
      state = UploadState(
        progress: UploadProgress(
          currentIndex: current + 1,
          fileCount: sources.length,
          currentName: sources[current].name,
          overallLoaded: sum,
          overallTotal: total,
        ),
        errors: List.unmodifiable(errors),
      );
    }

    var next = 0;
    Future<void> worker() async {
      while (next < sources.length) {
        final index = next++;
        final source = sources[index];
        current = index;
        emit(force: true);
        try {
          await uploader.upload(
            ownerId: ownerId,
            parentId: parentId,
            source: source,
            onProgress: (sent) {
              loaded[index] = sent;
              emit();
            },
          );
          loaded[index] = source.size;
        } catch (e) {
          errors.add('${source.name}: ${_reason(e)}');
        }
        emit(force: true);
      }
    }

    await Future.wait([for (var i = 0; i < concurrency; i++) worker()]);

    state = UploadState(errors: List.unmodifiable(errors));
    // Not awaited: the batch is over even if the listing is slow.
    ref.read(filesControllerProvider.notifier).folderChanged(parentId).ignore();
  }

  static String _reason(Object error) {
    if (error is ApiException) {
      return error.statusCode == 409
          ? 'A file with that name already exists.'
          : error.message;
    }
    // Web falls back to "Upload failed" for non-HTTP errors.
    return 'Upload failed';
  }
}
