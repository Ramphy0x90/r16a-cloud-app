import 'dart:convert';

import 'package:hive_ce/hive_ce.dart';

import '../domain/file_page.dart';

/// A persisted first page of a folder listing, with the ETag it came with.
class StoredListing {
  const StoredListing({
    required this.page,
    required this.etag,
    required this.storedAt,
  });

  final FileCursorPage page;
  final String? etag;
  final DateTime storedAt;

  StoredListing touched(DateTime now) =>
      StoredListing(page: page, etag: etag, storedAt: now);

  Map<String, dynamic> toJson() => {
    'page': page.toJson(),
    'etag': etag,
    'storedAt': storedAt.millisecondsSinceEpoch,
  };

  factory StoredListing.fromJson(Map<String, dynamic> json) => StoredListing(
    page: FileCursorPage.fromJson(json['page'] as Map<String, dynamic>),
    etag: json['etag'] as String?,
    storedAt: DateTime.fromMillisecondsSinceEpoch(json['storedAt'] as int),
  );
}

/// Persistent listing storage — the role IndexedDB plays for the web's
/// `FileListingDbService`. Failures never surface: a broken store behaves
/// like an empty one, as on web.
abstract interface class ListingStore {
  Future<StoredListing?> get(String key);
  Future<void> put(String key, StoredListing listing);
  Future<void> deleteByPrefix(String prefix);
  Future<void> clear();
}

/// [ListingStore] on a Hive box of JSON strings (no adapters / codegen).
class HiveListingStore implements ListingStore {
  HiveListingStore({this.boxName = 'files_listings'});

  final String boxName;
  Future<Box<String>>? _box;

  Future<Box<String>> get _opened => _box ??= Hive.openBox<String>(boxName);

  @override
  Future<StoredListing?> get(String key) async {
    try {
      final raw = (await _opened).get(key);
      if (raw == null) return null;
      return StoredListing.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> put(String key, StoredListing listing) async {
    try {
      await (await _opened).put(key, jsonEncode(listing.toJson()));
    } catch (_) {}
  }

  @override
  Future<void> deleteByPrefix(String prefix) async {
    try {
      final box = await _opened;
      await box.deleteAll(
        box.keys.whereType<String>().where((k) => k.startsWith(prefix)),
      );
    } catch (_) {}
  }

  @override
  Future<void> clear() async {
    try {
      await (await _opened).clear();
    } catch (_) {}
  }
}

/// In-memory [ListingStore] — tests, and the default when none is given.
class MemoryListingStore implements ListingStore {
  final entries = <String, StoredListing>{};

  @override
  Future<StoredListing?> get(String key) async => entries[key];

  @override
  Future<void> put(String key, StoredListing listing) async =>
      entries[key] = listing;

  @override
  Future<void> deleteByPrefix(String prefix) async =>
      entries.removeWhere((k, _) => k.startsWith(prefix));

  @override
  Future<void> clear() async => entries.clear();
}
