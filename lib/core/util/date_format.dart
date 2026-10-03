/// Port of the web client's `dd/MM/yy HH:mm` date pipe format.
String formatShortDateTime(DateTime dateTime) {
  final local = dateTime.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');

  final day = two(local.day);
  final month = two(local.month);
  final year = two(local.year % 100);
  final hour = two(local.hour);
  final minute = two(local.minute);

  return '$day/$month/$year $hour:$minute';
}

/// Port of the web files list's `dd/MM/yyyy HH:mm` date pipe format.
String formatDateTime(DateTime dateTime) {
  final local = dateTime.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');

  return '${two(local.day)}/${two(local.month)}/${local.year} '
      '${two(local.hour)}:${two(local.minute)}';
}
