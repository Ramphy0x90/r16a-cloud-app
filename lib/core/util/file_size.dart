import 'dart:math';

/// Port of the web client's `FileSizePipe`.
String formatFileSize(int? bytes) {
  if (bytes == null) return '—';
  if (bytes == 0) return '0 B';

  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  final i = (log(bytes) / log(1024)).floor().clamp(0, units.length - 1);
  final value = bytes / pow(1024, i);
  return '${value.toStringAsFixed(i == 0 ? 0 : 1)} ${units[i]}';
}
