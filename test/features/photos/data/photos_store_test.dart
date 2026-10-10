import 'package:flutter_test/flutter_test.dart';

import 'package:r16a_cloud_app/features/photos/data/photos_store.dart';
import 'package:r16a_cloud_app/features/photos/domain/photo_year.dart';

import '../fakes.dart';

void main() {
  late PhotosStore store;

  setUp(() => store = PhotosStore());

  test('round-trips a timeline and its first pages', () async {
    final shared = fakePhoto('s', DateTime.utc(2024), owner: 'u2');
    await store.saveTimeline(
      'o',
      const [PhotoYear(year: 2025, count: 2)],
      [shared],
    );
    await store.saveFirstPage(
      'o',
      2025,
      photoPage([fakePhoto('a', DateTime.utc(2025))], nextCursor: 'c1'),
    );

    final stored = await store.read('o');
    expect(stored!.years.single.count, 2);
    expect(stored.shared.single.id, 's');
    expect(stored.firstPages[2025]!.content.single.id, 'a');
    expect(stored.firstPages[2025]!.nextCursor, 'c1');
    expect(await store.read('other'), isNull);
  });

  test('parallel page saves all land', () async {
    await store.saveTimeline('o', const [
      PhotoYear(year: 2025, count: 1),
      PhotoYear(year: 2024, count: 1),
    ], const []);

    await Future.wait([
      store.saveFirstPage('o', 2025, photoPage([])),
      store.saveFirstPage('o', 2024, photoPage([])),
    ]);

    expect((await store.read('o'))!.firstPages.keys, {2025, 2024});
  });

  test('a new timeline drops pages of years whose count changed', () async {
    await store.saveTimeline('o', const [
      PhotoYear(year: 2025, count: 1),
      PhotoYear(year: 2024, count: 1),
    ], const []);
    await store.saveFirstPage('o', 2025, photoPage([]));
    await store.saveFirstPage('o', 2024, photoPage([]));

    await store.saveTimeline('o', const [
      PhotoYear(year: 2025, count: 1),
      PhotoYear(year: 2024, count: 2),
    ], const []);

    expect((await store.read('o'))!.firstPages.keys, {2025});
  });

  test('a page without a timeline is not stored; clear empties it', () async {
    await store.saveFirstPage('o', 2025, photoPage([]));
    expect(await store.read('o'), isNull);

    await store.saveTimeline('o', const [], const []);
    await store.clear();
    expect(await store.read('o'), isNull);
  });
}
