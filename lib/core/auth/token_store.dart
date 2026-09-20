import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// The set of tokens returned by an OIDC authorization-code or refresh
/// exchange, as persisted between app launches.
class StoredTokens {
  const StoredTokens({
    required this.accessToken,
    required this.refreshToken,
    required this.idToken,
    required this.accessTokenExpiry,
  });

  final String accessToken;
  final String? refreshToken;
  final String? idToken;
  final DateTime accessTokenExpiry;

  bool get isExpired => DateTime.now().isAfter(accessTokenExpiry);
}

/// Secure (Keychain/Keystore-backed) persistence for [StoredTokens].
///
/// Instance-based (rather than static) so tests can swap in a fake via
/// [tokenStoreProvider] instead of touching the real platform channel.
class TokenStore {
  const TokenStore({this._storage = const FlutterSecureStorage()});

  final FlutterSecureStorage _storage;

  static const _accessTokenKey = 'r16a.auth.access_token';
  static const _refreshTokenKey = 'r16a.auth.refresh_token';
  static const _idTokenKey = 'r16a.auth.id_token';
  static const _expiryKey = 'r16a.auth.access_token_expiry';

  Future<void> save(StoredTokens tokens) async {
    await Future.wait([
      _storage.write(key: _accessTokenKey, value: tokens.accessToken),
      _storage.write(key: _refreshTokenKey, value: tokens.refreshToken),
      _storage.write(key: _idTokenKey, value: tokens.idToken),
      _storage.write(
        key: _expiryKey,
        value: tokens.accessTokenExpiry.toIso8601String(),
      ),
    ]);
  }

  Future<StoredTokens?> read() async {
    final values = await Future.wait([
      _storage.read(key: _accessTokenKey),
      _storage.read(key: _refreshTokenKey),
      _storage.read(key: _idTokenKey),
      _storage.read(key: _expiryKey),
    ]);

    final accessToken = values[0];
    final expiryRaw = values[3];
    if (accessToken == null || expiryRaw == null) return null;

    return StoredTokens(
      accessToken: accessToken,
      refreshToken: values[1],
      idToken: values[2],
      accessTokenExpiry: DateTime.parse(expiryRaw),
    );
  }

  Future<void> clear() async {
    await Future.wait([
      _storage.delete(key: _accessTokenKey),
      _storage.delete(key: _refreshTokenKey),
      _storage.delete(key: _idTokenKey),
      _storage.delete(key: _expiryKey),
    ]);
  }
}

final tokenStoreProvider = Provider<TokenStore>((ref) => const TokenStore());
