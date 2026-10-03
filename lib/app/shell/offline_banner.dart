import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/network_status.dart';

/// Floating notice above the dock while the backend is unreachable. Saved
/// listings and cached thumbnails keep working; changes need a connection.
class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offline = ref.watch(networkStatusProvider) == NetworkStatus.offline;
    final scheme = Theme.of(context).colorScheme;

    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      child: !offline
          ? const SizedBox(width: double.infinity)
          : Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Material(
                color: scheme.inverseSurface,
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 4, 4),
                  child: Row(
                    children: [
                      Icon(
                        Icons.cloud_off_rounded,
                        size: 18,
                        color: scheme.onInverseSurface,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          "You're offline — showing saved files",
                          style: TextStyle(
                            fontSize: 13,
                            color: scheme.onInverseSurface,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: ref
                            .read(networkStatusProvider.notifier)
                            .checkNow,
                        child: Text(
                          'Retry',
                          style: TextStyle(color: scheme.inversePrimary),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
