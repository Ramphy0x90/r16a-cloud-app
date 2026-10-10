import 'dart:convert';

import 'package:hive_ce/hive_ce.dart';

import '../../../core/model/file_item.dart';
import '../../files/domain/file_page.dart';
import '../domain/photo_year.dart';

/// The last Photos timeline seen online: year counts, shared media and the
/// first page of each year opened. Mobile-only (the web has no offline
/// Photos): shown only when the server can't be reached.
class StoredPhotos {
  const StoredPhotos({
    required this.years,
    required this.shared,
    this.firstPages = const {},
  });

  final List<PhotoYear> years;
  final List<FileItem> shared;
  final Map<int, FileCursorPage> firstPages;

  Map<String, dynamic> toJson() => {
    'years': [for (final y in years) y.toJson()],
    'shared': [for (final f in shared) f.toJson()],
    'firstPages': {
      for (final MapEntry(:key, :value) in firstPages.entries)
        '$key': value.toJson(),
    },
  };

  factory StoredPhotos.fromJson(Map<String, dynamic> json) => StoredPhotos(
    years: [
      for (final y in json['years'] as List<dynamic>)
        PhotoYear.fromJson(y as Map<String, dynamic>),
    ],
    shared: parseFileList(json['shared']),
    firstPages: {
      for (final MapEntry(:key, :value)
          in (json['firstPages'] as Map<String, dynamic>).entries)
        int.parse(key): FileCursorPage.fromJson(value as Map<String, dynamic>),
    },
  );
}

/// One string per key. Failures never surface: a broken box behaves like
/// an empty one.
abstract interface class PhotosBox {
  Future<String?> get(String key);
  Future<void> put(String key, String value);
  Future<void> clear();
}

/// [PhotosBox] on a Hive box of JSON strings (no adapters / codegen).
class HivePhotosBox implements PhotosBox {
  HivePhotosBox({this.boxName = 'photos'});

  final String boxName;
  Future<Box<String>>? _box;

  Future<Box<String>> get _opened => _box ??= Hive.openBox<String>(boxName);

  @override
  Future<String?> get(String key) async {
    try {
      return (await _opened).get(key);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> put(String key, String value) async {
    try {
      await (await _opened).put(key, value);
    } catch (_) {}
  }

  @override
  Future<void> clear() async {
    try {
      await (await _opened).clear();
    } catch (_) {}
  }
}

/// In-memory [PhotosBox] — tests, and the default when none is given.
class MemoryPhotosBox implements PhotosBox {
  final entries = <String, String>{};

  @override
  Future<String?> get(String key) async => entries[key];

  @override
  Future<void> put(String key, String value) async => entries[key] = value;

  @override
  Future<void> clear() async => entries.clear();
}

/// [StoredPhotos] per owner. Writes run one after another, so pages saved
/// by parallel year loads never overwrite each other.
class PhotosStore {
  PhotosStore([PhotosBox? box]) : _box = box ?? MemoryPhotosBox();

  final PhotosBox _box;
  Future<void> _writes = Future.value();

  Future<StoredPhotos?> read(String ownerId) async {
    await _writes;
    return _read(ownerId);
  }

  /// A fresh timeline. Stored first pages survive only for years whose own
  /// count didn't change.
  Future<void> saveTimeline(
    String ownerId,
    List<PhotoYear> years,
    List<FileItem> shared,
  ) => _write(ownerId, (old) {
    final counts = {for (final y in years) y.year: y.count};
    final oldCounts = {for (final y in old?.years ?? const []) y.year: y.count};
    return StoredPhotos(
      years: years,
      shared: shared,
      firstPages: {
        for (final MapEntry(:key, :value)
            in (old?.firstPages ?? const {}).entries)
          if (counts[key] != null && counts[key] == oldCounts[key]) key: value,
      },
    );
  });

  /// [year]'s first page; ignored until a timeline is stored.
  Future<void> saveFirstPage(String ownerId, int year, FileCursorPage page) =>
      _write(ownerId, (old) {
        if (old == null) return null;
        return StoredPhotos(
          years: old.years,
          shared: old.shared,
          firstPages: {...old.firstPages, year: page},
        );
      });

  Future<void> clear() => _writes = _writes.then((_) => _box.clear());

  Future<void> _write(
    String ownerId,
    StoredPhotos? Function(StoredPhotos? old) change,
  ) => _writes = _writes.then((_) async {
    final next = change(await _read(ownerId));
    if (next != null) {
      await _box.put(ownerId, jsonEncode(next.toJson()));
    }
  });

  Future<StoredPhotos?> _read(String ownerId) async {
    try {
      final raw = await _box.get(ownerId);
      if (raw == null) return null;
      return StoredPhotos.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }
}
