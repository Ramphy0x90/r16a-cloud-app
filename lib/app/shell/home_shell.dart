import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/navigation/home_tab.dart';
import 'dock.dart';
import 'dock_destination.dart';
import 'offline_banner.dart';

/// Root authenticated shell: keeps every tab alive in an [IndexedStack]
/// and hosts the floating [Dock]. The current tab is [homeTabProvider].
class HomeShell extends ConsumerWidget {
  const HomeShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = ref.watch(homeTabProvider).index;

    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: index,
        children: [
          // Only the visible tab ticks — screens also read this to pause
          // background work (e.g. the Files delta sync).
          for (final (i, d) in dockDestinations.indexed)
            TickerMode(enabled: i == index, child: d.screen),
        ],
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const OfflineBanner(),
          Dock(
            currentIndex: index,
            onSelected: (i) =>
                ref.read(homeTabProvider.notifier).select(HomeTab.values[i]),
          ),
        ],
      ),
    );
  }
}
