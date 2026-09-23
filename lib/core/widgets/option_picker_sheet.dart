import 'package:flutter/material.dart';

/// One choice in an [showOptionPicker] sheet.
class OptionItem<T> {
  const OptionItem({required this.value, required this.label});

  final T value;
  final String label;
}

/// Bottom-sheet single-choice picker — the native equivalent of the web
/// client's `<select>` preference fields.
Future<T?> showOptionPicker<T>({
  required BuildContext context,
  required String title,
  required List<OptionItem<T>> options,
  required T selected,
}) {
  final scheme = Theme.of(context).colorScheme;

  return showModalBottomSheet<T>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(title, style: Theme.of(context).textTheme.titleMedium),
            ),
          ),
          for (final option in options)
            ListTile(
              title: Text(option.label),
              trailing: option.value == selected
                  ? Icon(Icons.check_rounded, color: scheme.primary)
                  : null,
              onTap: () => Navigator.of(context).pop(option.value),
            ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}
