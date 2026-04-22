import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // Emulator Android  → 10.0.2.2
  // HP fisik (WiFi)   → cek IP kamu di cmd: ipconfig
  static const String _baseUrl = 'http://10.0.2.2/toeic_prep_app/toeic_api';

  // ─── AUTH ─────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/auth.php?action=register'),
        headers: {'Content-Type': 'application/json'},
        body   : jsonEncode({'name': name, 'email': email, 'password': password}),
      );
      return jsonDecode(res.body);
    } catch (e) {
      return {'status': 'error', 'message': 'Tidak bisa terhubung ke server. Pastikan XAMPP menyala.'};
    }
  }

  // Dipanggil setelah user memilih tingkat kemampuan
  static Future<Map<String, dynamic>> updateSkillLevel({
    required String email,
    required String skillLevel,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/auth.php?action=update_skill'),
        headers: {'Content-Type': 'application/json'},
        body   : jsonEncode({'email': email, 'skill_level': skillLevel}),
      );
      return jsonDecode(res.body);
    } catch (e) {
      return {'status': 'error', 'message': 'Gagal menyimpan tingkat kemampuan.'};
    }
  }

  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/auth.php?action=login'),
        headers: {'Content-Type': 'application/json'},
        body   : jsonEncode({'email': email, 'password': password}),
      );
      return jsonDecode(res.body);
    } catch (e) {
      return {'status': 'error', 'message': 'Tidak bisa terhubung ke server. Pastikan XAMPP menyala.'};
    }
  }

  // ─── MATERI ───────────────────────────────────────────────────

  static Future<Map<String, dynamic>> getParts() async {
    try {
      final res = await http.get(Uri.parse('$_baseUrl/materials.php?action=parts'));
      return jsonDecode(res.body);
    } catch (e) {
      return {'status': 'error', 'message': 'Gagal mengambil daftar part'};
    }
  }

  static Future<Map<String, dynamic>> getMaterialsByPart(int partId) async {
    try {
      final res = await http.get(
        Uri.parse('$_baseUrl/materials.php?action=by_part&part_id=$partId'),
      );
      return jsonDecode(res.body);
    } catch (e) {
      return {'status': 'error', 'message': 'Gagal mengambil materi'};
    }
  }

  // ─── SOAL ─────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> getPracticeQuestions({
    required int partId,
    required int userId,
  }) async {
    try {
      final res = await http.get(
        Uri.parse('$_baseUrl/questions.php?action=practice&part_id=$partId&user_id=$userId'),
      );
      return jsonDecode(res.body);
    } catch (e) {
      return {'status': 'error', 'message': 'Gagal mengambil soal practice'};
    }
  }

  static Future<Map<String, dynamic>> getSimulationQuestions({
    required int userId,
  }) async {
    try {
      final res = await http.get(
        Uri.parse('$_baseUrl/questions.php?action=simulation&user_id=$userId'),
      );
      return jsonDecode(res.body);
    } catch (e) {
      return {'status': 'error', 'message': 'Gagal mengambil soal simulasi'};
    }
  }

  // ─── SKOR ─────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> saveAnswers({
    required int                      attemptId,
    required List<Map<String, dynamic>> answers,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/scores.php?action=save'),
        headers: {'Content-Type': 'application/json'},
        body   : jsonEncode({'attempt_id': attemptId, 'answers': answers}),
      );
      return jsonDecode(res.body);
    } catch (e) {
      return {'status': 'error', 'message': 'Gagal menyimpan jawaban'};
    }
  }

  static Future<Map<String, dynamic>> getScoreHistory(int userId) async {
    try {
      final res = await http.get(
        Uri.parse('$_baseUrl/scores.php?action=history&user_id=$userId'),
      );
      return jsonDecode(res.body);
    } catch (e) {
      return {'status': 'error', 'message': 'Gagal mengambil riwayat skor'};
    }
  }
}