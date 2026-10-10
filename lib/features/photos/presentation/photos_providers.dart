import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import '../data/photos_api.dart';
import '../data/photos_store.dart';
import 'photos_controller.dart';
import 'photos_state.dart';

final photosApiProvider = Provider((ref) => PhotosApi(ref.watch(dioProvider)));

/// Stored timelines. In-memory by default (tests); `main()` overrides it
/// with the Hive-backed store once Hive is initialized.
final photosStoreProvider = Provider((ref) => PhotosStore());

final photosControllerProvider =
    NotifierProvider.autoDispose<PhotosController, PhotosState>(
      PhotosController.new,
    );
