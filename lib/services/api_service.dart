import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // ── Ganti dengan IP komputer kamu jika test di HP fisik ──────
  // Kalau pakai emulator Android  → 10.0.2.2
  // Kalau pakai HP fisik          → cek IP WiFi kamu (misal: 192.168.1.5)
  // Kalau pakai browser/web       → localhost
  //static const String _baseUrl = 'http://10.0.2.2/toeic_prep_app/toeic_api';
  static const String _baseUrl = 'http://10.241.104.156/toeic_prep_app/toeic_api';

  // ─── AUTH ─────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth.php?action=register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'name': name, 'email': email, 'password': password}),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {
        'status': 'error',
        'message': 'Tidak bisa terhubung ke server. Pastikan XAMPP menyala.',
      };
    }
  }

  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth.php?action=login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {
        'status': 'error',
        'message': 'Tidak bisa terhubung ke server. Pastikan XAMPP menyala.',
      };
    }
  }

  // Update nama user
  static Future<Map<String, dynamic>> updateName({
    required int    userId,
    required String newName,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/auth.php?action=update_name'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'user_id': userId, 'name': newName}),
      );
      return jsonDecode(res.body);
    } catch (e) {
      return {'status': 'error', 'message': 'Gagal memperbarui nama.'};
    }
  }

  // Update password user
  static Future<Map<String, dynamic>> updatePassword({
    required int    userId,
    required String oldPassword,
    required String newPassword,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/auth.php?action=update_password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id'     : userId,
          'old_password': oldPassword,
          'new_password': newPassword,
        }),
      );
      return jsonDecode(res.body);
    } catch (e) {
      return {'status': 'error', 'message': 'Gagal mengubah kata sandi.'};
    }
  }

  // ─── MATERI ───────────────────────────────────────────────────

  static Future<Map<String, dynamic>> getParts() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/materials.php?action=parts'),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'status': 'error', 'message': 'Gagal mengambil daftar part'};
    }
  }

  static Future<Map<String, dynamic>> getMaterialsByPart(int partId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/materials.php?action=by_part&part_id=$partId'),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'status': 'error', 'message': 'Gagal mengambil materi'};
    }
  }

  // ─── SOAL PRACTICE ────────────────────────────────────────────

  static Future<Map<String, dynamic>> getPracticeQuestions(int partId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/questions.php?action=practice&part_id=$partId'),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'status': 'error', 'message': 'Gagal mengambil soal practice'};
    }
  }

  // ─── SOAL SIMULASI ────────────────────────────────────────────

  static Future<Map<String, dynamic>> getSimulationQuestions() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/questions.php?action=simulation'),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'status': 'error', 'message': 'Gagal mengambil soal simulasi'};
    }
  }

  // ─── SKOR ─────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> saveSimulationScore({
    required int userId,
    required int listeningScore,
    required int readingScore,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/scores.php?action=save_simulation'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': userId,
          'listening_score': listeningScore,
          'reading_score': readingScore,
        }),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'status': 'error', 'message': 'Gagal menyimpan skor'};
    }
  }

  static Future<Map<String, dynamic>> getScoreHistory(int userId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/scores.php?action=history&user_id=$userId'),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'status': 'error', 'message': 'Gagal mengambil riwayat skor'};
    }
  }

  static Future<Map<String, dynamic>> updateSkillLevel({
    required String email,
    required String skillLevel,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth.php?action=update_skill'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'skill_level': skillLevel}),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'status': 'error', 'message': 'Tidak bisa terhubung ke server.'};
    }
  }
}
