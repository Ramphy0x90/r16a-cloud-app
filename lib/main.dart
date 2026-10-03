import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';

import 'app/app.dart';
import 'core/config/env.dart';
import 'features/files/data/listing_store.dart';
import 'features/files/presentation/files_providers.dart';

Future<void> main() async {
  Env.checkReleaseConfig();
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  runApp(
    ProviderScope(
      overrides: [listingStoreProvider.overrideWithValue(HiveListingStore())],
      child: const R16aCloudApp(),
    ),
  );
}
