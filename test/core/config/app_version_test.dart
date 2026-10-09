import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:r16a_cloud_app/core/config/app_version.dart';

void main() {
  void mockInfo({required String version, required String buildNumber}) =>
      PackageInfo.setMockInitialValues(
        appName: 'Domovoi',
        packageName: 'cloud.domovoi.app',
        version: version,
        buildNumber: buildNumber,
        buildSignature: '',
      );

  Future<String> read() async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    return container.read(appVersionProvider.future);
  }

  test('shows the version with the build number', () async {
    mockInfo(version: '1.0.0', buildNumber: '7');
    expect(await read(), '1.0.0 (7)');
  });

  test('leaves out an empty build number', () async {
    mockInfo(version: '1.2.0', buildNumber: '');
    expect(await read(), '1.2.0');
  });
}
