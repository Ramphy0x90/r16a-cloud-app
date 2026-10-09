import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// The installed build as "1.0.0 (1)": `pubspec.yaml` `version`, i.e.
/// Android versionName (versionCode) / iOS CFBundleShortVersionString
/// (CFBundleVersion). No web equivalent; shown on Profile so testers can
/// say which build they run.
final appVersionProvider = FutureProvider<String>((ref) async {
  final info = await PackageInfo.fromPlatform();
  return info.buildNumber.isEmpty
      ? info.version
      : '${info.version} (${info.buildNumber})';
});
