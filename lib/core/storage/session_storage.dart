import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _secure = FlutterSecureStorage();

/// Persists the Supabase session (access + refresh token) in the platform
/// keychain / keystore instead of plain shared_preferences.
class SecureSessionStorage extends LocalStorage {
  const SecureSessionStorage();

  static const _sessionKey = 'supabase_session';

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> hasAccessToken() => _secure.containsKey(key: _sessionKey);

  @override
  Future<String?> accessToken() => _secure.read(key: _sessionKey);

  @override
  Future<void> removePersistedSession() => _secure.delete(key: _sessionKey);

  @override
  Future<void> persistSession(String persistSessionString) =>
      _secure.write(key: _sessionKey, value: persistSessionString);
}

/// Small non-secret values that must survive an app restart.
class AppPrefs {
  AppPrefs(this._prefs);
  final SharedPreferences _prefs;

  static const _activeShift = 'active_shift_id';

  String? get activeShiftId => _prefs.getString(_activeShift);
  Future<void> setActiveShiftId(String? id) => id == null
      ? _prefs.remove(_activeShift)
      : _prefs.setString(_activeShift, id);
}
