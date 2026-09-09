import 'package:flutter/material.dart';

import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/files/presentation/files_screen.dart';
import '../../features/photos/presentation/photos_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';

/// A single destination in the bottom dock.
///
/// Mirrors `NAV_BAR_ROUTES` from the web client (`app.routes.ts`).
class DockDestination {
  const DockDestination({
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.screen,
  });

  final String label;
  final IconData icon;
  final IconData activeIcon;
  final Widget screen;
}

const dockDestinations = <DockDestination>[
  DockDestination(
    label: 'Dashboard',
    icon: Icons.grid_view_outlined,
    activeIcon: Icons.grid_view_rounded,
    screen: DashboardScreen(),
  ),
  DockDestination(
    label: 'Files',
    icon: Icons.cloud_outlined,
    activeIcon: Icons.cloud_rounded,
    screen: FilesScreen(),
  ),
  DockDestination(
    label: 'Photos',
    icon: Icons.photo_library_outlined,
    activeIcon: Icons.photo_library_rounded,
    screen: PhotosScreen(),
  ),
  DockDestination(
    label: 'Profile',
    icon: Icons.person_outline_rounded,
    activeIcon: Icons.person_rounded,
    screen: ProfileScreen(),
  ),
];
