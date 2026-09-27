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
