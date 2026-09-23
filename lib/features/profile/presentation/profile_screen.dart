import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_controller.dart';
import 'profile_preferences_controller.dart';
import 'widgets/profile_auth_card.dart';
import 'widgets/profile_identity_card.dart';
import 'widgets/profile_preferences_card.dart';

/// Account screen, ported from the web client's `pages/profile`: identity
/// card, preferences, and sign-out.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferences = ref.watch(profilePreferencesControllerProvider);
    final preferencesController = ref.read(profilePreferencesControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
        children: [
          const ProfileIdentityCard(
            displayName: 'Ramphy Aquino Nova',
            username: 'ramphy',
          ),
          const SizedBox(height: 16),
          ProfilePreferencesCard(
            theme: preferences.theme,
            defaultViewMode: preferences.defaultViewMode,
            encryptFilesByDefault: preferences.encryptFilesByDefault,
            onThemeChanged: preferencesController.setTheme,
            onDefaultViewModeChanged: preferencesController.setDefaultViewMode,
            onEncryptFilesByDefaultChanged: preferencesController.setEncryptFilesByDefault,
          ),
          const SizedBox(height: 16),
          ProfileAuthCard(
            onLogout: () => ref.read(authControllerProvider.notifier).logout(),
          ),
        ],
      ),
    );
  }
}
