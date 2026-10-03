import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:r16a_cloud_app/core/cache/clear_caches.dart';
import 'package:r16a_cloud_app/core/media/media_providers.dart';

import '../../features/files/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('core clearing drops thumbnails and local file copies', () async {
    final media = FakeMediaApi()..thumbnailBytes = Uint8List.fromList([1]);
    final downloads = FakeFileDownloads();
    final container = ProviderContainer(
      overrides: [
        mediaApiProvider.overrideWithValue(media),
        fileDownloadsProvider.overrideWithValue(downloads),
      ],
    );
    addTearDown(container.dispose);
    final thumbnails = container.read(thumbnailCacheProvider);
    await thumbnails.get('a');

    await container.read(clearCachesProvider)();

    await thumbnails.get('a');
    expect(media.thumbnailCalls, hasLength(2));
    expect(downloads.localCopiesCleared, 1);
  });
}
