import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_controller.dart';
import '../network/dio_client.dart';
import 'file_downloads.dart';
import 'media_api.dart';
import 'thumbnail_cache.dart';

final mediaApiProvider = Provider((ref) => MediaApi(ref.watch(dioProvider)));

/// App-wide like the web's root-provided `ImagePreviewService`. The app
/// shell clears it on sign-out.
final thumbnailCacheProvider = Provider(
  (ref) => ThumbnailCache(ref.watch(mediaApiProvider)),
);

/// Platform downloads; the bearer token for the zip endpoint comes from
/// the auth controller, like every other authenticated call.
final fileDownloadsProvider = Provider(
  (ref) => FileDownloads(
    ref.watch(mediaApiProvider),
    ref.read(authControllerProvider.notifier).getValidAccessToken,
  ),
);

/// Bumped whenever the user's media changes from inside the app — uploads,
/// deletes, changes delta sync picks up — so screens showing it elsewhere
/// (Photos) can refresh. Features can't call each other; they meet here.
class MediaRevision extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

final mediaRevisionProvider = NotifierProvider<MediaRevision, int>(
  MediaRevision.new,
);
