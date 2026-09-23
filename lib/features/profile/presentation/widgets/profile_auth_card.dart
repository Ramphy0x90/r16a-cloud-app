import 'package:flutter/material.dart';

import 'profile_card.dart';

/// Mirrors the web client's "Authentication" section: session management,
/// currently just sign-out.
class ProfileAuthCard extends StatelessWidget {
  const ProfileAuthCard({super.key, required this.onLogout});

  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ProfileCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ProfileSectionHeader(title: 'Authentication', subtitle: 'Manage sessions'),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onLogout,
              icon: Icon(Icons.logout_rounded, color: scheme.error, size: 18),
              label: Text('Logout', style: TextStyle(color: scheme.error)),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: scheme.error.withValues(alpha: 0.4)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
