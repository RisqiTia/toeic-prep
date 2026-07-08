import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class ApiService {
  // ── Ganti dengan IP komputer kamu jika test di HP fisik ──────
  // Kalau pakai emulator Android  → 10.0.2.2
  // Kalau pakai HP fisik          → cek IP WiFi kamu (misal: 192.168.1.5)
  // Kalau pakai browser/web       → localhost
  // static const String apiBaseUrl = 'http://10.0.2.2/toeic_prep_app/toeic_api';
  // static const String mediaBaseUrl = 'http://10.0.2.2/toeic_dataset_generator';
  static const String apiBaseUrl =
      'http://10.17.149.22/toeic_prep_app/toeic_api';
  static const String mediaBaseUrl =
      'http://10.17.149.22/toeic_dataset_generator';

  // ─── AUTH ─────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$apiBaseUrl/auth.php?action=register'),
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
        Uri.parse('$apiBaseUrl/auth.php?action=login'),
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
    required int userId,
    required String newName,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$apiBaseUrl/auth.php?action=update_name'),
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
    required int userId,
    required String oldPassword,
    required String newPassword,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$apiBaseUrl/auth.php?action=update_password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': userId,
          'old_password': oldPassword,
          'new_password': newPassword,
        }),
      );
      return jsonDecode(res.body);
    } catch (e) {
      return {'status': 'error', 'message': 'Gagal mengubah kata sandi.'};
    }
  }

  // Upload / ganti foto profil
  static Future<Map<String, dynamic>> updateProfilePhoto({
    required int userId,
    required File imageFile,
  }) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$apiBaseUrl/auth.php?action=update_photo'),
      );
      request.fields['user_id'] = userId.toString();
      request.files.add(
        await http.MultipartFile.fromPath('foto', imageFile.path),
      );
      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);
      print('PHOTO STATUS: ${response.statusCode}');
      print('PHOTO BODY: ${response.body}');
      return jsonDecode(response.body);
    } catch (e) {
      print('PHOTO ERROR: $e');
      return {'status': 'error', 'message': 'Gagal mengunggah foto.'};
    }
  }

  // Hapus foto profil
  static Future<Map<String, dynamic>> deleteProfilePhoto({
    required int userId,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$apiBaseUrl/auth.php?action=delete_photo'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'user_id': userId}),
      );
      return jsonDecode(res.body);
    } catch (e) {
      return {'status': 'error', 'message': 'Gagal menghapus foto.'};
    }
  }

  // ─── MATERI ───────────────────────────────────────────────────

  static Future<Map<String, dynamic>> getParts() async {
    try {
      final response = await http.get(
        Uri.parse('$apiBaseUrl/materials.php?action=parts'),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'status': 'error', 'message': 'Gagal mengambil daftar part'};
    }
  }

  static Future<Map<String, dynamic>> getMaterialsByPart(int partId) async {
    try {
      final response = await http.get(
        Uri.parse('$apiBaseUrl/materials.php?action=by_part&part_id=$partId'),
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
        Uri.parse('$apiBaseUrl/questions.php?action=practice&part_id=$partId'),
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
        Uri.parse('$apiBaseUrl/questions.php?action=simulation'),
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
        Uri.parse('$apiBaseUrl/scores.php?action=save_simulation'),
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
        Uri.parse('$apiBaseUrl/scores.php?action=history&user_id=$userId'),
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
        Uri.parse('$apiBaseUrl/auth.php?action=update_skill'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'skill_level': skillLevel}),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'status': 'error', 'message': 'Tidak bisa terhubung ke server.'};
    }
  }
}
