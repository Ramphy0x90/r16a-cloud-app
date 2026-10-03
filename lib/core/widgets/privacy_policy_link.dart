import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/env.dart';
import '../util/link_opener.dart';

/// "Privacy policy" link to [Env.privacyPolicyUrl], opened in the browser.
class PrivacyPolicyLink extends ConsumerWidget {
  const PrivacyPolicyLink({super.key});

  Future<void> _open(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    bool opened;
    try {
      opened = await ref.read(linkOpenerProvider)(
        Uri.parse(Env.privacyPolicyUrl),
      );
    } catch (_) {
      opened = false;
    }
    if (!opened) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Could not open the privacy policy.')),
        );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return TextButton(
      onPressed: () => _open(context, ref),
      child: const Text('Privacy policy'),
    );
  }
}
