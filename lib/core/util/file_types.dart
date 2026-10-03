/// Port of `isImageFile` / `isVideoFile` from the web client's
/// `utils/file-utils.ts` — same extension lists, applied to a file name.
/// Callers must exclude directories themselves (see `FileItem.isImage`).
final _imagePattern = RegExp(
  r'\.(avif|bmp|gif|heic|heif|jpe?g|png|svg|webp)$',
  caseSensitive: false,
);
final _videoPattern = RegExp(
  r'\.(avi|m4v|mkv|mov|mp4|webm)$',
  caseSensitive: false,
);
final _heicPattern = RegExp(r'\.(heic|heif)$', caseSensitive: false);

bool isImageFileName(String name) => _imagePattern.hasMatch(name);

bool isVideoFileName(String name) => _videoPattern.hasMatch(name);

/// HEIC/HEIF need the server-converted `thumbnail?size=large` for a full
/// preview — mirrors `ImagePreviewService.ensureFullPreview$`.
bool isHeicFileName(String name) => _heicPattern.hasMatch(name);
