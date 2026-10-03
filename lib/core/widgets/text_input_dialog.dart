import 'package:flutter/material.dart';

/// Single-field prompt — the native equivalent of the web's create-folder
/// and rename modals. Resolves to the trimmed text, or `null` on cancel.
/// [confirmLabel] stays disabled while the field is blank, like the web.
Future<String?> showTextInputDialog({
  required BuildContext context,
  required String title,
  required String hint,
  required String confirmLabel,
  String initialValue = '',
  TextSelection? initialSelection,
}) {
  return showDialog<String>(
    context: context,
    builder: (context) => _TextInputDialog(
      title: title,
      hint: hint,
      confirmLabel: confirmLabel,
      initialValue: initialValue,
      initialSelection: initialSelection,
    ),
  );
}

class _TextInputDialog extends StatefulWidget {
  const _TextInputDialog({
    required this.title,
    required this.hint,
    required this.confirmLabel,
    required this.initialValue,
    required this.initialSelection,
  });

  final String title;
  final String hint;
  final String confirmLabel;
  final String initialValue;
  final TextSelection? initialSelection;

  @override
  State<_TextInputDialog> createState() => _TextInputDialogState();
}

class _TextInputDialogState extends State<_TextInputDialog> {
  late final _controller = TextEditingController(text: widget.initialValue)
    ..selection =
        widget.initialSelection ??
        TextSelection.collapsed(offset: widget.initialValue.length);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _controller.text.trim();
    if (value.isNotEmpty) Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(hintText: widget.hint),
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ValueListenableBuilder(
          valueListenable: _controller,
          builder: (context, value, _) => FilledButton(
            onPressed: value.text.trim().isEmpty ? null : _submit,
            child: Text(widget.confirmLabel),
          ),
        ),
      ],
    );
  }
}
