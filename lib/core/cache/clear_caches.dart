import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../media/media_providers.dart';

/// Clears everything the app keeps locally apart from the session: used by
/// Profile's "Clear cache" and on sign-out. Features can't be reached from
/// core, so the app layer (`main.dart`) overrides this to also clear
/// feature caches — see [clearCoreCaches].
final clearCachesProvider = Provider<Future<void> Function()>(
  (ref) =>
      () => clearCoreCaches(ref),
);

/// Thumbnails, decoded images and temporary copies of opened files.
Future<void> clearCoreCaches(Ref ref) async {
  ref.read(thumbnailCacheProvider).clear();
  PaintingBinding.instance.imageCache
    ..clear()
    ..clearLiveImages();
  await ref.read(fileDownloadsProvider).clearOpenedFiles();
}
