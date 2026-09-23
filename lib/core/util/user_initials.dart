/// Port of the web client's `getUserInitials` (`utils/user-utils.ts`).
String getUserInitials(String displayName) {
  final parts = displayName
      .trim()
      .split(RegExp(r'\s+'))
      .where((p) => p.isNotEmpty)
      .toList();

  if (parts.isEmpty) return '?';

  if (parts.length == 1) {
    final single = parts.first;
    return single
        .substring(0, single.length < 2 ? single.length : 2)
        .toUpperCase();
  }

  return (parts.first[0] + parts.last[0]).toUpperCase();
}
