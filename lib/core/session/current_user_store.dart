import 'dart:convert';

import 'package:hive_ce/hive_ce.dart';

import 'current_user.dart';

/// The last `/user/me` answer, kept on the device so an offline cold start
/// still knows who is signed in (Files' stored listings are keyed by the
/// owner id). Mobile-only: the web always has the network for `/user/me`.
/// Cleared on sign-out. Failures never surface: a broken store behaves like
/// an empty one, like `ListingStore`.
abstract interface class CurrentUserStore {
  Future<CurrentUser?> read();
  Future<void> save(CurrentUser user);
  Future<void> clear();
}

/// [CurrentUserStore] on a Hive box holding one JSON string.
class HiveCurrentUserStore implements CurrentUserStore {
  HiveCurrentUserStore({this.boxName = 'current_user'});

  static const _key = 'user';

  final String boxName;
  Future<Box<String>>? _box;

  Future<Box<String>> get _opened => _box ??= Hive.openBox<String>(boxName);

  @override
  Future<CurrentUser?> read() async {
    try {
      final raw = (await _opened).get(_key);
      if (raw == null) return null;
      return CurrentUser.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> save(CurrentUser user) async {
    try {
      await (await _opened).put(_key, jsonEncode(user.toJson()));
    } catch (_) {}
  }

  @override
  Future<void> clear() async {
    try {
      await (await _opened).clear();
    } catch (_) {}
  }
}

/// In-memory [CurrentUserStore] — tests, and the default when none is given.
class MemoryCurrentUserStore implements CurrentUserStore {
  CurrentUser? user;

  @override
  Future<CurrentUser?> read() async => user;

  @override
  Future<void> save(CurrentUser user) async => this.user = user;

  @override
  Future<void> clear() async => user = null;
}
