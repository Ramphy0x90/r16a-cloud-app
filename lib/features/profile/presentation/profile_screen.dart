import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/widgets/placeholder_screen.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Logout lives here temporarily so the auth flow is testable end-to-end
    // before the real Profile UI (identity card, preferences) is built.
    return PlaceholderScreen(
      title: 'Profile',
      icon: Icons.person_rounded,
      message: 'Account details, preferences and sign-out live here.',
      actions: [
        IconButton(
          onPressed: () => ref.read(authControllerProvider.notifier).logout(),
          icon: const Icon(Icons.logout_rounded),
          tooltip: 'Sign out',
        ),
      ],
    );
  }
}
