import 'package:flutter/material.dart';

import '../../../../core/widgets/option_picker_sheet.dart';
import '../../domain/profile_preferences.dart';
import 'profile_card.dart';

/// Mirrors the web client's `.preferences-grid` section: default theme,
/// default file view, and the encrypt-by-default toggle.
class ProfilePreferencesCard extends StatelessWidget {
  const ProfilePreferencesCard({
    super.key,
    required this.theme,
    required this.defaultViewMode,
    required this.encryptFilesByDefault,
    required this.onThemeChanged,
    required this.onDefaultViewModeChanged,
    required this.onEncryptFilesByDefaultChanged,
  });

  final AppThemePreference theme;
  final DefaultFileView defaultViewMode;
  final bool encryptFilesByDefault;
  final ValueChanged<AppThemePreference> onThemeChanged;
  final ValueChanged<DefaultFileView> onDefaultViewModeChanged;
  final ValueChanged<bool> onEncryptFilesByDefaultChanged;

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
          _SelectRow<AppThemePreference>(
            label: 'Default theme',
            value: theme,
            valueLabel: theme.label,
            options: AppThemePreference.values
                .map((t) => OptionItem(value: t, label: t.label))
                .toList(),
            onChanged: onThemeChanged,
          ),
          const SizedBox(height: 10),
          _SelectRow<DefaultFileView>(
            label: 'Default file view',
            value: defaultViewMode,
            valueLabel: defaultViewMode.label,
            options: DefaultFileView.values
                .map((v) => OptionItem(value: v, label: v.label))
                .toList(),
            onChanged: onDefaultViewModeChanged,
          ),
          const SizedBox(height: 10),
          _ToggleRow(
            label: 'Encrypt files by default',
            description: 'Uploaded files will be encrypted automatically',
            value: encryptFilesByDefault,
            onChanged: onEncryptFilesByDefaultChanged,
          ),
        ],
      ),
    );
  }
}

class _SelectRow<T> extends StatelessWidget {
  const _SelectRow({
    required this.label,
    required this.value,
    required this.valueLabel,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final T value;
  final String valueLabel;
  final List<OptionItem<T>> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () async {
          final selected = await showOptionPicker<T>(
            context: context,
            title: label,
            options: options,
            selected: value,
          );
          if (selected != null) onChanged(selected);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              Expanded(child: Text(label)),
              Text(valueLabel, style: TextStyle(color: scheme.onSurfaceVariant)),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right_rounded, size: 20, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.label,
    required this.description,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String description;
  final bool value;
  final ValueChanged<bool> onChanged;

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
          // Mirrors the web `toggle-switch` component.
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}
