import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens a URL in the user's browser; `false` when nothing could open it.
/// Behind a provider so tests don't need the platform plugin.
final linkOpenerProvider = Provider<Future<bool> Function(Uri)>(
  (ref) =>
      (uri) => launchUrl(uri, mode: LaunchMode.externalApplication),
);
