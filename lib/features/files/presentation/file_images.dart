import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../../../core/util/file_types.dart';
import '../data/files_api.dart';
import '../data/thumbnail_cache.dart';
import '../domain/file_item.dart';

/// Decodes bytes from an authenticated source into Flutter's [ImageCache],
/// keyed by [cacheKey] only — the loader is not part of the identity.
abstract class _BytesImage<T extends _BytesImage<T>> extends ImageProvider<T> {
  const _BytesImage();

  String get cacheKey;

  Future<Uint8List> loadBytes();

  /// Longest decoded side; `null` keeps the intrinsic size.
  int? get maxDimension => null;

  @override
  Future<T> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this as T);

  @override
  ImageStreamCompleter loadImage(T key, ImageDecoderCallback decode) =>
      MultiFrameImageStreamCompleter(
        codec: _decode(decode),
        scale: 1,
        debugLabel: cacheKey,
      );

  Future<ui.Codec> _decode(ImageDecoderCallback decode) async {
    final buffer = await ui.ImmutableBuffer.fromUint8List(await loadBytes());
    final max = maxDimension;
    if (max == null) return decode(buffer);
    return decode(
      buffer,
      getTargetSize: (width, height) {
        final scale = math.min(1.0, max / math.max(width, height));
        return ui.TargetImageSize(
          width: (width * scale).round(),
          height: (height * scale).round(),
        );
      },
    );
  }

  @override
  bool operator ==(Object other) =>
      other.runtimeType == runtimeType &&
      other is _BytesImage &&
      other.cacheKey == cacheKey;

  @override
  int get hashCode => Object.hash(runtimeType, cacheKey);
}

/// Small thumbnail via [ThumbnailCache] — the web's `ensureThumbnail$`.
class FileThumbnailImage extends _BytesImage<FileThumbnailImage> {
  const FileThumbnailImage(this.fileId, this._cache);

  final String fileId;
  final ThumbnailCache _cache;

  @override
  String get cacheKey => 'thumb:$fileId';

  @override
  Future<Uint8List> loadBytes() async {
    final bytes = await _cache.get(fileId);
    if (bytes == null) throw StateError('No thumbnail for $fileId');
    return bytes;
  }
}

/// Full-size preview — the web's `ensureFullPreview$`: the raw file, except
/// HEIC/HEIF which use the server-converted large thumbnail. Timeouts match
/// the web (15s / 30s). Decoding is capped so huge photos stay cheap.
class FilePreviewImage extends _BytesImage<FilePreviewImage> {
  FilePreviewImage(FileItem file, this._api)
    : fileId = file.id,
      _heic = isHeicFileName(file.name);

  static const maxSide = 2560;

  final String fileId;
  final bool _heic;
  final FilesApi _api;

  @override
  String get cacheKey => 'preview:$fileId';

  @override
  int get maxDimension => maxSide;

  @override
  Future<Uint8List> loadBytes() => _heic
      ? _api.getThumbnail(
          fileId,
          size: ThumbnailSize.large,
          receiveTimeout: const Duration(seconds: 30),
        )
      : _api.downloadBytes(fileId, receiveTimeout: const Duration(seconds: 15));
}
