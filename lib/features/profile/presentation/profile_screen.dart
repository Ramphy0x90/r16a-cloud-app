import 'package:flutter/material.dart';

import '../../../core/widgets/placeholder_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScreen(
      title: 'Profile',
      icon: Icons.person_rounded,
      message: 'Account details, preferences and sign-out live here.',
    );
  }
}
