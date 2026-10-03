import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:r16a_cloud_app/app/shell/offline_banner.dart';
import 'package:r16a_cloud_app/core/network/network_status.dart';

/// Fails to connect, or answers with [status].
class _Adapter implements HttpClientAdapter {
  int? status;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final code = status;
    if (code == null) {
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
      );
    }
    return ResponseBody.fromString('{}', code);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late ProviderContainer container;
  late _Adapter adapter;
  late Dio dio;
  var probeAnswers = true;
  var probes = 0;

  NetworkStatus status() => container.read(networkStatusProvider);

  setUp(() {
    probes = 0;
    probeAnswers = true;
    container = ProviderContainer(
      overrides: [
        reachabilityProbeProvider.overrideWithValue(() async {
          probes++;
          return probeAnswers;
        }),
      ],
    );
    adapter = _Adapter();
    dio = Dio(BaseOptions(baseUrl: 'http://test'))
      ..httpClientAdapter = adapter
      ..interceptors.add(
        NetworkStatusInterceptor(container.read(_refProvider)),
      );
  });

  tearDown(() => container.dispose());

  test(
    'a connection failure means offline; any response means online',
    () async {
      await expectLater(dio.get<void>('/x'), throwsA(isA<DioException>()));
      expect(status(), NetworkStatus.offline);

      adapter.status = 500;
      await expectLater(dio.get<void>('/x'), throwsA(isA<DioException>()));
      expect(status(), NetworkStatus.online);
    },
  );

  test('checkNow recovers only when the probe reaches the server', () async {
    container.read(networkStatusProvider.notifier).reportUnreachable();

    probeAnswers = false;
    await container.read(networkStatusProvider.notifier).checkNow();
    expect(status(), NetworkStatus.offline);

    probeAnswers = true;
    await container.read(networkStatusProvider.notifier).checkNow();
    expect(status(), NetworkStatus.online);
    expect(probes, 2);
  });

  testWidgets('banner shows while offline and Retry probes', (tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: OfflineBanner())),
      ),
    );
    expect(find.textContaining("You're offline"), findsNothing);

    container.read(networkStatusProvider.notifier).reportUnreachable();
    await tester.pumpAndSettle();
    expect(find.textContaining("You're offline"), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(probes, 1);
    expect(find.textContaining("You're offline"), findsNothing);
  });
}

/// Hands the interceptor a real [Ref] from the test container.
final _refProvider = Provider<Ref>((ref) => ref);
