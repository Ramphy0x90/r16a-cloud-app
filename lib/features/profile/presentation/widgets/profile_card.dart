import 'package:flutter/material.dart';

/// Shared card shell for every section of the Profile screen — mirrors the
/// web client's repeated `.profile-card` sections (identity / preferences /
/// authentication).
class ProfileCard extends StatelessWidget {
  const ProfileCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: child,
    );
  }
}

/// Section title + optional supporting line, used at the top of a
/// [ProfileCard] (mirrors `.section-header`).
class ProfileSectionHeader extends StatelessWidget {
  const ProfileSectionHeader({super.key, required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(subtitle!, style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
        ],
      ],
    );
  }
}
