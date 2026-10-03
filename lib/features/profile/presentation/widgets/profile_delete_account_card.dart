import 'package:flutter/material.dart';

import 'delete_account_dialog.dart';
import 'profile_card.dart';

/// Self-service account deletion (app-store requirement, GDPR erasure).
/// No web equivalent yet.
class ProfileDeleteAccountCard extends StatefulWidget {
  const ProfileDeleteAccountCard({super.key, required this.onDeleteAccount});

  /// Erases the account and signs out; throws on failure.
  final Future<void> Function() onDeleteAccount;

  @override
  State<ProfileDeleteAccountCard> createState() =>
      _ProfileDeleteAccountCardState();
}

class _ProfileDeleteAccountCardState extends State<ProfileDeleteAccountCard> {
  var _deleting = false;

  Future<void> _delete() async {
    if (!await showDeleteAccountDialog(context)) return;
    setState(() => _deleting = true);
    try {
      await widget.onDeleteAccount();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Could not delete your account. Please try again.'),
          ),
        );
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ProfileCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ProfileSectionHeader(
            title: 'Delete account',
            subtitle: 'Permanently erase your account and files',
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _deleting ? null : _delete,
              icon: Icon(
                Icons.delete_forever_outlined,
                color: scheme.error,
                size: 18,
              ),
              label: Text(
                _deleting ? 'Deleting…' : 'Delete account',
                style: TextStyle(color: scheme.error),
              ),
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
