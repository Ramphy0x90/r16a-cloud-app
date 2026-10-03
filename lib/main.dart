import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';

import 'app/app.dart';
import 'core/cache/clear_caches.dart';
import 'core/config/env.dart';
import 'core/logging/app_logger.dart';
import 'features/files/data/listing_store.dart';
import 'features/files/presentation/files_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppLogger.install();
  Env.checkReleaseConfig();
  await Hive.initFlutter();
  runApp(
    ProviderScope(
      overrides: [
        listingStoreProvider.overrideWithValue(HiveListingStore()),
        // Core caches plus the Files listings (memory + Hive).
        clearCachesProvider.overrideWith(
          (ref) => () async {
            await clearCoreCaches(ref);
            await ref.read(filesCacheProvider).clear();
          },
        ),
      ],
      child: const R16aCloudApp(),
    ),
  );
}
