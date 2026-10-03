import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import '../data/photos_api.dart';
import 'photos_controller.dart';
import 'photos_state.dart';

final photosApiProvider = Provider((ref) => PhotosApi(ref.watch(dioProvider)));

final photosControllerProvider =
    NotifierProvider.autoDispose<PhotosController, PhotosState>(
      PhotosController.new,
    );
