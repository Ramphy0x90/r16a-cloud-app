import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/file_item.dart';
import '../files_providers.dart';

/// Share picker — the web's share modal (`files.html`): checkbox list of
/// users, pre-checked with the current `sharedWithIds`. Stays open while
/// saving ("Sharing...") and closes with `true` once [onSave] succeeds.
Future<bool> showShareSheet({
  required BuildContext context,
  required FileItem file,
  required Future<void> Function(List<String> sharedWithIds) onSave,
}) async {
  final saved = await showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => _ShareSheet(file: file, onSave: onSave),
  );
  return saved ?? false;
}

class _ShareSheet extends ConsumerStatefulWidget {
  const _ShareSheet({required this.file, required this.onSave});

  final FileItem file;
  final Future<void> Function(List<String> sharedWithIds) onSave;

  @override
  ConsumerState<_ShareSheet> createState() => _ShareSheetState();
}

class _ShareSheetState extends ConsumerState<_ShareSheet> {
  late final _selected = {...widget.file.sharedWithIds};
  var _saving = false;
  var _failed = false;

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _failed = false;
    });
    try {
      await widget.onSave(_selected.toList());
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _failed = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final candidates = ref.watch(shareCandidatesProvider(widget.file.ownerId));
    final loading = candidates.isLoading;
    // Like the web, a failed user lookup reads as "no users".
    final users = candidates.value ?? const [];

    Widget message(String text) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Text(text, style: TextStyle(color: scheme.onSurfaceVariant)),
    );

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.8,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Share ${widget.file.isDirectory ? 'folder' : 'file'}',
                style: textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text.rich(
                TextSpan(
                  text: 'Select who can access ',
                  children: [
                    TextSpan(
                      text: widget.file.name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const TextSpan(text: '.'),
                  ],
                ),
              ),
              if (loading)
                message('Loading users...')
              else if (users.isEmpty)
                message('No users available to share with.')
              else
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final user in users)
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          value: _selected.contains(user.id),
                          onChanged: _saving
                              ? null
                              : (checked) => setState(() {
                                  if (checked ?? false) {
                                    _selected.add(user.id);
                                  } else {
                                    _selected.remove(user.id);
                                  }
                                }),
                          title: Text(user.label),
                          subtitle: Text(user.email),
                        ),
                    ],
                  ),
                ),
              if (_failed)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Could not update sharing.',
                    style: TextStyle(color: scheme.error),
                  ),
                ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _saving
                        ? null
                        : () => Navigator.of(context).pop(false),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: loading || _saving ? null : _save,
                    child: Text(_saving ? 'Sharing...' : 'Share'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
