import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:r16a_cloud_app/core/media/thumbnail_store.dart';

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('thumbs_test');
  });

  tearDown(() async {
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  Uint8List bytes(int size, [int fill = 1]) =>
      Uint8List.fromList(List.filled(size, fill));

  test('reads back what it wrote; unknown ids are null', () async {
    final store = FileThumbnailStore(Future.value(dir));

    await store.write('a-1', bytes(3, 9));

    expect(await store.read('a-1'), [9, 9, 9]);
    expect(await store.read('missing'), isNull);
  });

  test('ids never escape the directory', () async {
    final store = FileThumbnailStore(Future.value(dir));

    await store.write('../evil', bytes(1));

    expect(await store.read('../evil'), [1]);
    expect(
      dir.listSync().map((e) => e.uri.pathSegments.last),
      contains('___evil'),
    );
  });

  test('clear removes everything', () async {
    final store = FileThumbnailStore(Future.value(dir));
    await store.write('a', bytes(1));

    await store.clear();

    expect(await store.read('a'), isNull);
  });

  test('over the limit, least recently used files go first', () async {
    final old = DateTime(2026, 1, 1);
    for (var i = 0; i < 10; i++) {
      final file = File('${dir.path}/f$i')..writeAsBytesSync(bytes(100));
      // f0 oldest … f9 newest.
      file.setLastModifiedSync(old.add(Duration(minutes: i)));
    }

    // Trims at startup down to 80% of 500 bytes: four files remain.
    final store = FileThumbnailStore(Future.value(dir), maxBytes: 500);
    expect(await store.read('f9'), isNotNull);

    final left = dir.listSync().map((e) => e.uri.pathSegments.last).toSet();
    expect(left, {'f6', 'f7', 'f8', 'f9'});
  });
}
