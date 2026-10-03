import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import '../../../core/session/session_providers.dart';
import '../../../core/session/user_preferences.dart';
import '../../../core/session/user_summary.dart';
import '../data/file_uploader.dart';
import '../data/files_api.dart';
import '../data/files_cache.dart';
import '../data/upload_source.dart';
import '../data/thumbnail_cache.dart';
import 'files_controller.dart';
import 'files_state.dart';
import 'upload_controller.dart';
import 'upload_picker.dart';

final filesApiProvider = Provider((ref) => FilesApi(ref.watch(dioProvider)));

/// App-wide like the web's root-provided `FilesCacheService`; keys include
/// the owner id, so another account never reads these entries.
final filesCacheProvider = Provider(
  (ref) => FilesCache(ref.watch(filesApiProvider)),
);

final filesControllerProvider =
    NotifierProvider.autoDispose<FilesController, FilesState>(
      FilesController.new,
    );

/// The view mode to render: the user's pick in the options sheet, else
/// `UserPreferences.defaultViewMode` (the web seeds `viewMode` from it).
final filesViewModeProvider = Provider.autoDispose<DefaultFileView>((ref) {
  final picked = ref.watch(filesControllerProvider.select((s) => s.viewMode));
  return picked ??
      ref.watch(currentUserProvider).value?.preferences.defaultViewMode ??
      DefaultFileView.grid;
});

/// App-wide like the web's root-provided `ImagePreviewService`.
final thumbnailCacheProvider = Provider(
  (ref) => ThumbnailCache(ref.watch(filesApiProvider)),
);

/// Users a file owned by the given owner id can be shared with — mirrors
/// `loadShareCandidates()`: everyone except the caller and the owner.
final shareCandidatesProvider = FutureProvider.autoDispose
    .family<List<UserSummary>, String>((ref, ownerId) async {
      final me = await ref.watch(currentUserProvider.future);
      final users = await ref.watch(sessionApiProvider).listUsers();
      return users.where((u) => u.id != me.id && u.id != ownerId).toList();
    });

final fileUploaderProvider = Provider(
  (ref) => FileUploader(ref.watch(filesApiProvider)),
);

/// Not auto-disposed: a running upload outlives any one widget.
final uploadControllerProvider =
    NotifierProvider<UploadController, UploadState>(UploadController.new);

/// System pickers behind a provider so tests can stand in for them.
final uploadPickerProvider =
    Provider<Future<List<UploadSource>> Function(UploadPick)>(
      (ref) => pickUploadSources,
    );
