import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';

import 'app/app.dart';
import 'core/cache/clear_caches.dart';
import 'core/config/env.dart';
import 'core/logging/app_logger.dart';
import 'core/media/media_providers.dart';
import 'core/media/thumbnail_store.dart';
import 'core/session/current_user_store.dart';
import 'core/session/session_providers.dart';
import 'features/files/data/listing_store.dart';
import 'features/files/presentation/files_providers.dart';
import 'features/photos/data/photos_store.dart';
import 'features/photos/presentation/photos_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppLogger.install();
  Env.checkReleaseConfig();
  await Hive.initFlutter();
  runApp(
    ProviderScope(
      overrides: [
        listingStoreProvider.overrideWithValue(HiveListingStore()),
        currentUserStoreProvider.overrideWithValue(HiveCurrentUserStore()),
        thumbnailStoreProvider.overrideWithValue(FileThumbnailStore.appCache()),
        photosStoreProvider.overrideWithValue(PhotosStore(HivePhotosBox())),
        // Core caches plus the Files listings (memory + Hive) and the
        // stored Photos timelines.
        clearCachesProvider.overrideWith(
          (ref) => () async {
            await clearCoreCaches(ref);
            await ref.read(filesCacheProvider).clear();
            await ref.read(photosStoreProvider).clear();
          },
        ),
      ],
      child: const R16aCloudApp(),
    ),
  );
}
