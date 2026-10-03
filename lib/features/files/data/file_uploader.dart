import '../domain/file_item.dart';
import 'files_api.dart';
import 'upload_source.dart';

/// Uploads one file the way the web client's `FileService.uploadFile` does:
/// multipart up to [chunkThresholdBytes], above that a chunked session
/// (init → parts in order → complete) with the server's part size.
class FileUploader {
  FileUploader(this._api);

  /// `CHUNK_UPLOAD_THRESHOLD_BYTES` on the web (strictly greater → chunked).
  static const chunkThresholdBytes = 100 * 1024 * 1024;

  final FilesApi _api;

  /// [onProgress] receives the bytes of this file sent so far.
  Future<FileItem> upload({
    required String ownerId,
    String? parentId,
    required UploadSource source,
    void Function(int sentBytes)? onProgress,
  }) {
    if (source.size > chunkThresholdBytes) {
      return _uploadChunked(ownerId, parentId, source, onProgress);
    }
    return _api.uploadMultipart(
      ownerId: ownerId,
      parentId: parentId,
      source: source,
      onProgress: onProgress,
    );
  }

  /// `[start, end)` byte ranges of each part.
  static List<(int, int)> partRanges(int totalSize, int partSize) => [
    for (var start = 0; start < totalSize; start += partSize)
      (start, start + partSize < totalSize ? start + partSize : totalSize),
  ];

  Future<FileItem> _uploadChunked(
    String ownerId,
    String? parentId,
    UploadSource source,
    void Function(int sentBytes)? onProgress,
  ) async {
    final session = await _api.initChunkedUpload(
      ownerId: ownerId,
      parentId: parentId,
      fileName: source.name,
      totalSize: source.size,
    );
    try {
      for (final (start, end) in partRanges(
        source.size,
        session.partSizeBytes,
      )) {
        await _api.uploadPart(
          session.uploadId,
          source.openRead(start, end),
          end - start,
          onProgress: onProgress == null
              ? null
              : (sent) => onProgress(start + sent),
        );
      }
      return await _api.completeChunkedUpload(session.uploadId);
    } catch (_) {
      // Best effort: the server also expires abandoned sessions.
      _api.cancelChunkedUpload(session.uploadId).ignore();
      rethrow;
    }
  }
}
