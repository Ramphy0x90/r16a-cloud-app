import 'package:flutter/material.dart';

import 'dock.dart';
import 'dock_destination.dart';

/// Root authenticated shell: keeps every tab alive in an [IndexedStack]
/// and hosts the floating [Dock].
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: _index,
        children: [
          // Only the visible tab ticks — screens also read this to pause
          // background work (e.g. the Files delta sync).
          for (final (i, d) in dockDestinations.indexed)
            TickerMode(enabled: i == _index, child: d.screen),
        ],
      ),
      bottomNavigationBar: Dock(
        currentIndex: _index,
        onSelected: (i) => setState(() => _index = i),
      ),
    );
  }
}
