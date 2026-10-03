/// A local file to upload, independent of the picker that produced it:
/// its name, size and ranged reads (chunked uploads read one part at a
/// time instead of loading the whole file).
class UploadSource {
  const UploadSource({
    required this.name,
    required this.size,
    required this.openRead,
  });

  final String name;
  final int size;

  /// Bytes in `[start, end)`.
  final Stream<List<int>> Function(int start, int end) openRead;
}
