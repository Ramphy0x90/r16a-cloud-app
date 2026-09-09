import 'package:flutter/material.dart';

import '../../../core/widgets/placeholder_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScreen(
      title: 'Dashboard',
      icon: Icons.grid_view_rounded,
      message: 'Storage metrics and recent files will show up here.',
    );
  }
}
