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
    required this.iconAsset,
    required this.screen,
  });

  final String label;
  final String iconAsset;
  final Widget screen;
}

const dockDestinations = <DockDestination>[
  DockDestination(
    label: 'Dashboard',
    iconAsset: 'assets/icons/home.svg',
    screen: DashboardScreen(),
  ),
  DockDestination(
    label: 'Files',
    iconAsset: 'assets/icons/cloud.svg',
    screen: FilesScreen(),
  ),
  DockDestination(
    label: 'Photos',
    iconAsset: 'assets/icons/photo.svg',
    screen: PhotosScreen(),
  ),
  DockDestination(
    label: 'Profile',
    iconAsset: 'assets/icons/user-circle.svg',
    screen: ProfileScreen(),
  ),
];
