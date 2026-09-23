import 'package:flutter/material.dart';

import 'profile_card.dart';

/// Mirrors the web client's `.preferences-grid` section: default theme,
/// default file view, and the encrypt-by-default toggle.
class ProfilePreferencesCard extends StatelessWidget {
  const ProfilePreferencesCard({
    super.key,
    required this.theme,
    required this.defaultViewMode,
    required this.encryptFilesByDefault,
  });

  final String theme;
  final String defaultViewMode;
  final bool encryptFilesByDefault;

  @override
  Widget build(BuildContext context) {
    return ProfileCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ProfileSectionHeader(
            title: 'Preferences',
            subtitle: 'Customize your default experience.',
          ),
          const SizedBox(height: 16),
          _SelectRow(label: 'Default theme', value: theme),
          const SizedBox(height: 10),
          _SelectRow(label: 'Default file view', value: defaultViewMode),
          const SizedBox(height: 10),
          _ToggleRow(
            label: 'Encrypt files by default',
            description: 'Uploaded files will be encrypted automatically',
            value: encryptFilesByDefault,
          ),
        ],
      ),
    );
  }
}

class _SelectRow extends StatelessWidget {
  const _SelectRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(value, style: TextStyle(color: scheme.onSurfaceVariant)),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right_rounded, size: 20, color: scheme.onSurfaceVariant),
        ],
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({required this.label, required this.description, required this.value});

  final String label;
  final String description;
  final bool value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Mirrors the web `toggle-switch` component; this instance only
          // reflects the stored value, it doesn't accept input.
          Switch(value: value, onChanged: null),
        ],
      ),
    );
  }
}
