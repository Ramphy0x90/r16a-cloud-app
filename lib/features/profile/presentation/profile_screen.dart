import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/session/current_user.dart';
import '../../../core/session/session_providers.dart';
import '../../../core/session/user_preferences.dart';
import 'profile_save_controller.dart';
import 'widgets/profile_auth_card.dart';
import 'widgets/profile_identity_card.dart';
import 'widgets/profile_preferences_card.dart';

/// Account screen, ported from the web client's `pages/profile`: identity
/// card, preferences, and sign-out.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: userAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => _LoadError(
          onRetry: () => ref.invalidate(currentUserProvider),
        ),
        data: (user) => _ProfileContent(user: user),
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, color: scheme.error, size: 40),
            const SizedBox(height: 12),
            Text(
              'Could not load profile details right now.',
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

class _ProfileContent extends ConsumerWidget {
  const _ProfileContent({required this.user});

  final CurrentUser user;

  void _updatePreferences(WidgetRef ref, UserPreferences next) {
    // Reflect the change immediately; the debounced save below reconciles
    // with the server and adopts its response as the source of truth.
    ref.read(currentUserProvider.notifier).setOptimistic(user.copyWith(preferences: next));
    ref.read(profileSaveControllerProvider.notifier).schedule(next);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saveState = ref.watch(profileSaveControllerProvider);
    final scheme = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
      children: [
        ProfileIdentityCard(displayName: user.displayName, username: user.username),
        const SizedBox(height: 16),
        ProfilePreferencesCard(
          theme: user.preferences.theme,
          defaultViewMode: user.preferences.defaultViewMode,
          encryptFilesByDefault: user.preferences.encryptFilesByDefault,
          onThemeChanged: (value) => _updatePreferences(
            ref,
            user.preferences.copyWith(theme: value),
          ),
          onDefaultViewModeChanged: (value) => _updatePreferences(
            ref,
            user.preferences.copyWith(defaultViewMode: value),
          ),
          onEncryptFilesByDefaultChanged: (value) => _updatePreferences(
            ref,
            user.preferences.copyWith(encryptFilesByDefault: value),
          ),
        ),
        if (saveState.errorMessage != null) ...[
          const SizedBox(height: 8),
          Text(
            saveState.errorMessage!,
            style: TextStyle(color: scheme.error, fontSize: 13),
          ),
        ],
        const SizedBox(height: 16),
        ProfileAuthCard(
          onLogout: () => ref.read(authControllerProvider.notifier).logout(),
        ),
      ],
    );
  }
}
