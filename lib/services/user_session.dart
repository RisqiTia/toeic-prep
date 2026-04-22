import 'package:shared_preferences/shared_preferences.dart';

class UserSession {
  static const _keyId         = 'user_id';
  static const _keyName       = 'user_name';
  static const _keyEmail      = 'user_email';
  static const _keySkillLevel = 'user_skill_level';
  static const _keyRemember   = 'remember_me';

  // Simpan data user setelah login
  static Future<void> save({
    required int    id,
    required String name,
    required String email,
    required String skillLevel,
    required bool   rememberMe,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt   (_keyId,         id);
    await prefs.setString(_keyName,       name);
    await prefs.setString(_keyEmail,      email);
    await prefs.setString(_keySkillLevel, skillLevel);
    await prefs.setBool  (_keyRemember,   rememberMe);
  }

  // Ambil data user yang tersimpan
  static Future<Map<String, dynamic>?> get() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getInt(_keyId);
    if (id == null) return null;
    return {
      'id'          : id,
      'name'        : prefs.getString(_keyName)       ?? '',
      'email'       : prefs.getString(_keyEmail)      ?? '',
      'skill_level' : prefs.getString(_keySkillLevel) ?? '',
      'remember_me' : prefs.getBool(_keyRemember)     ?? false,
    };
  }

  // Cek apakah user sudah login dan memilih "Ingat Saya"
  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    final id        = prefs.getInt(_keyId);
    final remember  = prefs.getBool(_keyRemember) ?? false;
    return id != null && remember;
  }

  // Hapus sesi saat logout
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}