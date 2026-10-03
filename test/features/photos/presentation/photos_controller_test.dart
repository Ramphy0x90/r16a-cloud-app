import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:r16a_cloud_app/core/session/session_providers.dart';
import 'package:r16a_cloud_app/features/photos/domain/photo_year.dart';
import 'package:r16a_cloud_app/features/photos/presentation/photos_controller.dart';
import 'package:r16a_cloud_app/features/photos/presentation/photos_providers.dart';
import 'package:r16a_cloud_app/features/photos/presentation/photos_state.dart';

import '../../files/fakes.dart';
import '../fakes.dart';

Future<void> _settle() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  late FakePhotosApi api;
  late ProviderContainer container;

  PhotosState state() => container.read(photosControllerProvider);
  PhotosController controller() =>
      container.read(photosControllerProvider.notifier);
  PhotoYearSection section(int year) =>
      state().sections.firstWhere((s) => s.year == year);

  Future<void> start() async {
    container = ProviderContainer(
      overrides: [
        photosApiProvider.overrideWithValue(api),
        sessionApiProvider.overrideWithValue(FakeSessionApi()),
      ],
    );
    container.listen(photosControllerProvider, (_, _) {});
    await _settle();
  }

  tearDown(() => container.dispose());

  test('merges own years and shared media, newest year first', () async {
    api = FakePhotosApi(
      years: const [
        PhotoYear(year: 2025, count: 3),
        PhotoYear(year: 2022, count: 1),
      ],
      shared: [
        // takenAt decides the year, in UTC.
        fakePhoto('s1', DateTime.utc(2024, 12, 31, 23, 30), owner: 'u2'),
        fakePhoto('s2', DateTime.utc(2025, 1, 1), owner: 'u2'),
      ],
    );
    await start();

    expect(state().loading, isFalse);
    expect(state().sections.map((s) => s.year), [2025, 2024, 2022]);
    expect(section(2025).totalCount, 4);
    // Own photos still to load are placeholders ahead of the shared ones.
    expect(section(2025).tileCount, 4);
    expect(section(2025).pendingOwn, 3);
    // A shared-only year has nothing to load.
    expect(section(2024).canLoadMore, isFalse);
    expect(section(2024).tileCount, 1);
  });

  test('loads a year page by page, then stops', () async {
    api = FakePhotosApi(years: const [PhotoYear(year: 2025, count: 3)]);
    await start();

    controller().loadMore(2025);
    controller().loadMore(2025); // Deduped while in flight.
    await _settle();
    expect(api.calls, hasLength(1));
    api.calls.single.response.complete(
      photoPage([
        fakePhoto('a', DateTime.utc(2025, 3)),
        fakePhoto('b', DateTime.utc(2025, 2)),
      ], nextCursor: 'c1'),
    );
    await _settle();
    expect(section(2025).own.map((f) => f.id), ['a', 'b']);
    expect(section(2025).pendingOwn, 1);

    controller().loadMore(2025);
    await _settle();
    expect(api.calls.last.cursor, 'c1');
    api.calls.last.response.complete(
      photoPage([fakePhoto('c', DateTime.utc(2025, 1))]),
    );
    await _settle();

    expect(section(2025).pendingOwn, 0);
    expect(section(2025).canLoadMore, isFalse);
    controller().loadMore(2025);
    await _settle();
    expect(api.calls, hasLength(2));
  });

  test('a stale year count never strands placeholders', () async {
    api = FakePhotosApi(years: const [PhotoYear(year: 2025, count: 5)]);
    await start();

    controller().loadMore(2025);
    await _settle();
    api.calls.single.response.complete(
      photoPage([fakePhoto('a', DateTime.utc(2025))]),
    );
    await _settle();

    expect(section(2025).tileCount, 1);
  });

  test('a failed page stops asking until refreshed', () async {
    api = FakePhotosApi(years: const [PhotoYear(year: 2025, count: 2)]);
    await start();

    controller().loadMore(2025);
    await _settle();
    api.calls.single.response.completeError(Exception('offline'));
    await _settle();

    expect(section(2025).failed, isTrue);
    controller().loadMore(2025);
    await _settle();
    expect(api.calls, hasLength(1));

    await controller().refresh();
    expect(section(2025).failed, isFalse);
  });

  test('years failing is an error; shared failing is not', () async {
    api = FakePhotosApi(years: const [PhotoYear(year: 2025, count: 1)])
      ..sharedError = Exception('shared down');
    await start();
    expect(state().error, isNull);
    expect(state().sections, hasLength(1));
    container.dispose();

    api = FakePhotosApi()..yearsError = Exception('down');
    await start();
    expect(state().error, isNotNull);
  });

  test('a page answered after a refresh is dropped', () async {
    api = FakePhotosApi(years: const [PhotoYear(year: 2025, count: 1)]);
    await start();
    controller().loadMore(2025);
    await _settle();

    await controller().refresh();
    api.calls.single.response.complete(
      photoPage([fakePhoto('stale', DateTime.utc(2025))]),
    );
    await _settle();

    expect(section(2025).own, isEmpty);
  });
}
