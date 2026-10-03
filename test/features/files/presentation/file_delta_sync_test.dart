import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:r16a_cloud_app/core/session/session_providers.dart';
import 'package:r16a_cloud_app/features/files/domain/file_event.dart';
import 'package:r16a_cloud_app/features/files/presentation/file_delta_sync.dart';
import 'package:r16a_cloud_app/features/files/presentation/files_providers.dart';
import 'package:r16a_cloud_app/features/files/presentation/files_screen.dart';

import '../fakes.dart';

const _startMs = 1759500000000;

FileEventsPage _page(List<String?> parentIds, int next, {bool more = false}) =>
    FileEventsPage(
      events: [
        for (final p in parentIds)
          FileEvent(
            fileId: 'f',
            parentId: p,
            fileName: 'f',
            eventType: 'UPDATED',
            occurredAt: next,
          ),
      ],
      nextCursor: next,
      hasMore: more,
    );

Future<void> _settle() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  group('poll', () {
    late FakeFilesApi api;
    late ProviderContainer container;
    late FileDeltaSync sync;

    setUp(() async {
      api = FakeFilesApi();
      container = ProviderContainer(
        overrides: [
          filesApiProvider.overrideWithValue(api),
          sessionApiProvider.overrideWithValue(FakeSessionApi()),
          fileDeltaSyncProvider.overrideWith(
            (ref) => FileDeltaSync(
              ref,
              now: () => DateTime.fromMillisecondsSinceEpoch(_startMs),
            ),
          ),
        ],
      );
      // Root folder open in the Files screen.
      container.listen(filesControllerProvider, (_, _) {});
      container.listen(fileDeltaSyncProvider, (_, _) {});
      await _settle();
      api.calls.single.response.complete(fakePage([]));
      await _settle();
      sync = container.read(fileDeltaSyncProvider);
    });

    tearDown(() => container.dispose());

    test('first start waits for the timer, from "now"', () async {
      sync.start();
      await _settle();
      expect(api.eventCalls, isEmpty);

      await sync.poll();
      expect(api.eventCalls, [_startMs]);
      sync.stop();
    });

    test('a change in the open folder reloads it and advances', () async {
      sync.start();
      sync.stop();
      api.eventPages.add(_page([null, 'elsewhere'], _startMs + 5));

      final poll = sync.poll();
      await _settle();
      // Root (open) reloads from the server; its cache was dropped.
      expect(api.calls, hasLength(2));
      api.calls.last.response.complete(fakePage([fakeFile('new')]));
      await poll;

      expect(container.read(filesControllerProvider).items.single.id, 'new');
      await sync.poll();
      expect(api.eventCalls.last, _startMs + 5);
    });

    test('catches up across pages, at most 5 per poll', () async {
      sync.start();
      sync.stop();
      for (var i = 1; i <= 7; i++) {
        api.eventPages.add(_page(['elsewhere'], _startMs + i, more: true));
      }

      await sync.poll();

      expect(api.eventCalls, hasLength(FileDeltaSync.maxPagesPerPoll));
      await sync.poll();
      expect(api.eventCalls[5], _startMs + 5);
    });

    test('nothing happens before the first start', () async {
      await sync.poll();
      expect(api.eventCalls, isEmpty);
    });
  });

  group('screen lifecycle', () {
    late FakeFilesApi api;

    setUp(() => api = FakeFilesApi());

    Widget app({required bool visible}) => ProviderScope(
      overrides: [
        filesApiProvider.overrideWithValue(api),
        fileDownloadsProvider.overrideWithValue(FakeFileDownloads()),
        sessionApiProvider.overrideWithValue(FakeSessionApi()),
      ],
      child: MaterialApp(
        home: TickerMode(enabled: visible, child: const FilesScreen()),
      ),
    );

    Future<void> pumpScreen(WidgetTester tester, {bool visible = true}) async {
      await tester.pumpWidget(app(visible: visible));
      await tester.pump();
      api.calls.last.response.complete(fakePage([]));
      await tester.pumpAndSettle();
    }

    testWidgets('polls every 10s while visible', (tester) async {
      await pumpScreen(tester);

      await tester.pump(const Duration(seconds: 10));
      expect(api.eventCalls, hasLength(1));
      await tester.pump(const Duration(seconds: 10));
      expect(api.eventCalls, hasLength(2));
    });

    testWidgets('a hidden tab does not poll until shown', (tester) async {
      await pumpScreen(tester, visible: false);

      await tester.pump(const Duration(seconds: 30));
      expect(api.eventCalls, isEmpty);

      await tester.pumpWidget(app(visible: true));
      await tester.pump(const Duration(seconds: 10));
      expect(api.eventCalls, hasLength(1));
    });

    testWidgets('pauses in background and catches up on resume', (
      tester,
    ) async {
      await pumpScreen(tester);
      await tester.pump(const Duration(seconds: 10));
      expect(api.eventCalls, hasLength(1));

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump(const Duration(seconds: 60));
      expect(api.eventCalls, hasLength(1));

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      // Immediate catch-up, then the regular ticks resume.
      expect(api.eventCalls, hasLength(2));
      await tester.pump(const Duration(seconds: 10));
      expect(api.eventCalls, hasLength(3));
    });
  });
}
