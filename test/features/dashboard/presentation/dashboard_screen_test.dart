import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:r16a_cloud_app/core/navigation/home_tab.dart';
import 'package:r16a_cloud_app/features/dashboard/data/dashboard_api.dart';
import 'package:r16a_cloud_app/features/dashboard/domain/dashboard_metrics.dart';
import 'package:r16a_cloud_app/features/dashboard/presentation/dashboard_providers.dart';
import 'package:r16a_cloud_app/features/dashboard/presentation/dashboard_screen.dart';

/// Answers every request with [status] and an empty body.
class _StatusAdapter implements HttpClientAdapter {
  _StatusAdapter(this.status);

  final int status;
  final paths = <String>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    paths.add(options.path);
    return ResponseBody.fromString('', status);
  }

  @override
  void close({bool force = false}) {}
}

final _dashboard = DashboardResponse(
  metrics: const DashboardMetrics(
    uploadedFiles: 1,
    usedStorageBytes: 1024,
    sharedFiles: 0,
    uploadedPhotos: 0,
  ),
  recentFiles: [
    RecentFileItem(
      id: 'f1',
      name: 'notes.pdf',
      visibility: 'PRIVATE',
      sizeBytes: 2048,
      updatedAt: DateTime.utc(2026, 9, 24),
    ),
  ],
);

void main() {
  late _StatusAdapter adapter;
  late ProviderContainer container;

  Future<void> pump(WidgetTester tester, {int status = 404}) async {
    adapter = _StatusAdapter(status);
    final dio = Dio(BaseOptions(baseUrl: 'http://test'))
      ..httpClientAdapter = adapter;
    container = ProviderContainer(
      overrides: [
        dashboardProvider.overrideWith((ref) async => _dashboard),
        dashboardApiProvider.overrideWithValue(DashboardApi(dio)),
      ],
    );
    addTearDown(container.dispose);
    // Keep the auto-disposed tab alive, like HomeShell does.
    container.listen(homeTabProvider, (_, _) {});
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: DashboardScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('"View all" switches to the Files tab', (tester) async {
    await pump(tester);
    expect(container.read(homeTabProvider), HomeTab.dashboard);

    await tester.tap(find.text('View all'));

    expect(container.read(homeTabProvider), HomeTab.files);
  });

  testWidgets('tapping a deleted recent file says so', (tester) async {
    await pump(tester);

    await tester.tap(find.text('notes.pdf'));
    await tester.pumpAndSettle();

    expect(adapter.paths, ['/fs/f1']);
    expect(find.text('This file no longer exists.'), findsOneWidget);
  });

  testWidgets('tapping a recent file that fails to load reports it', (
    tester,
  ) async {
    await pump(tester, status: 500);

    await tester.tap(find.text('notes.pdf'));
    await tester.pumpAndSettle();

    expect(find.text('Could not open the file.'), findsOneWidget);
  });
}
