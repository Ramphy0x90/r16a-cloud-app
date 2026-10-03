import 'package:flutter/material.dart';

/// Word the user types to confirm, so deletion can't happen by a stray tap.
const deleteConfirmationWord = 'DELETE';

/// Explains what account deletion erases and asks for a typed
/// confirmation. Resolves to `true` only when confirmed.
Future<bool> showDeleteAccountDialog(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (_) => const _DeleteAccountDialog(),
  );
  return confirmed ?? false;
}

class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog();

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return AlertDialog(
      title: const Text('Delete account?'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This permanently deletes your Domovoi account and everything '
              'in it: your files, photos and folders, and anything you '
              'shared with others. Files other people shared with you stay '
              'with them. This can\'t be undone.',
            ),
            const SizedBox(height: 12),
            Text(
              'Your invitation sign-in is removed by the administrator.',
              style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              autofocus: true,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'Type $deleteConfirmationWord to confirm',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        ValueListenableBuilder(
          valueListenable: _controller,
          builder: (context, value, _) => FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: scheme.error,
              foregroundColor: scheme.onError,
            ),
            onPressed: value.text.trim() == deleteConfirmationWord
                ? () => Navigator.of(context).pop(true)
                : null,
            child: const Text('Delete account'),
          ),
        ),
      ],
    );
  }
}
