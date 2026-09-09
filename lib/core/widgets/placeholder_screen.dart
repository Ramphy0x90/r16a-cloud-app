import 'package:flutter/material.dart';

/// Temporary screen scaffold used while feature UIs are being built out.
/// Renders an app bar plus a centered empty-state, matching the web client's
/// `.empty-state` pattern (icon + heading + supporting line).
class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({
    super.key,
    required this.title,
    required this.icon,
    required this.message,
    this.actions,
  });

  final String title;
  final IconData icon;
  final String message;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(title), actions: actions),
      body: Center(
        child: Padding(
          // Keep content clear of the floating dock.
          padding: const EdgeInsets.fromLTRB(32, 0, 32, 120),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 56, color: scheme.onSurfaceVariant),
              const SizedBox(height: 16),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
