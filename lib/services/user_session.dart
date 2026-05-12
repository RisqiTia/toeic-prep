import 'package:shared_preferences/shared_preferences.dart';

class UserSession {
  static const _keyId          = 'user_id';
  static const _keyName        = 'user_name';
  static const _keyEmail       = 'user_email';
  static const _keySkillLevel  = 'user_skill_level';
  static const _keyRemember    = 'remember_me';
  static const _keySavedEmail    = 'saved_email';    // ← untuk auto-fill
  static const _keySavedPassword = 'saved_password'; // ← untuk auto-fill

  // ─── SIMPAN DATA USER SETELAH LOGIN ──────────────────────────
  static Future<void> save({
    required int    id,
    required String name,
    required String email,
    required String skillLevel,
    required bool   rememberMe,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt   (_keyId,        id);
    await prefs.setString(_keyName,      name);
    await prefs.setString(_keyEmail,     email);
    await prefs.setString(_keySkillLevel, skillLevel);
    await prefs.setBool  (_keyRemember,  rememberMe);
  }

  // ─── AMBIL DATA USER YANG TERSIMPAN ──────────────────────────
  static Future<Map<String, dynamic>?> get() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getInt(_keyId);
    if (id == null) return null;
    return {
      'id'         : id,
      'name'       : prefs.getString(_keyName)       ?? '',
      'email'      : prefs.getString(_keyEmail)      ?? '',
      'skill_level': prefs.getString(_keySkillLevel) ?? '',
      'remember_me': prefs.getBool  (_keyRemember)   ?? false,
    };
  }

  // ─── CEK APAKAH USER SUDAH LOGIN (Ingat Saya aktif) ──────────
  static Future<bool> isLoggedIn() async {
    final prefs   = await SharedPreferences.getInstance();
    final id      = prefs.getInt (_keyId);
    final remember = prefs.getBool(_keyRemember) ?? false;
    return id != null && remember;
  }

  // ─── HAPUS SESI SAAT LOGOUT ───────────────────────────────────
  static Future<void> clear() async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyId);
      await prefs.remove(_keyName);
      await prefs.remove(_keyEmail);
      await prefs.remove(_keySkillLevel);
      await prefs.remove(_keyRemember);
  }

  // ─── SIMPAN KREDENSIAL UNTUK AUTO-FILL ───────────────────────
  static Future<void> saveCredentials(String email, String password) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySavedEmail,    email);
    await prefs.setString(_keySavedPassword, password);
  }

  // ─── HAPUS KREDENSIAL TERSIMPAN ──────────────────────────────
  static Future<void> clearCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keySavedEmail);
    await prefs.remove(_keySavedPassword);
  }

  // ─── AMBIL KREDENSIAL TERSIMPAN ──────────────────────────────
  static Future<Map<String, String>?> getSavedCredentials() async {
    final prefs  = await SharedPreferences.getInstance();
    final email  = prefs.getString(_keySavedEmail);
    final password = prefs.getString(_keySavedPassword);
    if (email == null || password == null) return null;
    return {'email': email, 'password': password};
  }
}