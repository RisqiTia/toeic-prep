import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

class ApiService {
  // ============================================================
  // BASE URL
  // ============================================================

  // Hosting
  static const String apiBaseUrl =
      'https://toeic-prep.my.id/api/';
  
  static const String mediaBaseUrl =
      'https://toeic-prep.my.id/asset_generator';

  // Local
  // static const String apiBaseUrl =
  //     'http://10.206.78.156/toeic_prep_app/toeic_api';

  // static const String mediaBaseUrl =
  //     'http://10.206.78.156/toeic_dataset_generator';

  // ============================================================
  // HELPER RESPONSE
  // ============================================================

  static Map<String, dynamic> _decodeResponse(
    http.Response response,
  ) {
    try {
      if (response.body.trim().isEmpty) {
        return {
          'status': 'error',
          'message': 'Respons server kosong.',
        };
      }

      final dynamic data = jsonDecode(response.body);

      if (data is Map<String, dynamic>) {
        return data;
      }

      return {
        'status': 'error',
        'message': 'Format respons server tidak valid.',
      };
    } catch (e) {
      return {
        'status': 'error',
        'message': 'Respons server tidak valid.',
      };
    }
  }

  // ============================================================
  // REGISTER
  // ============================================================

  static Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(
          '$apiBaseUrl/auth.php?action=register',
        ),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'name': name.trim(),
          'email': email.trim(),
          'password': password,
        }),
      );

      return _decodeResponse(response);
    } catch (e) {
      return {
        'status': 'error',
        'message': 'Tidak dapat terhubung ke server.',
      };
    }
  }

  // ============================================================
  // LOGIN
  // ============================================================

  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(
          '$apiBaseUrl/auth.php?action=login',
        ),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'email': email.trim(),
          'password': password,
        }),
      );

      return _decodeResponse(response);
    } catch (e) {
      return {
        'status': 'error',
        'message': 'Tidak dapat terhubung ke server.',
      };
    }
  }

  // ============================================================
  // LUPA KATA SANDI
  // ============================================================

  /// Mengirim permintaan reset password kepada admin.
  ///
  /// Endpoint:
  /// auth.php?action=forgot_password
  static Future<Map<String, dynamic>>
      requestPasswordReset({
    required String email,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(
          '$apiBaseUrl/auth.php?action=forgot_password',
        ),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'email': email.trim(),
        }),
      );

      return _decodeResponse(response);
    } catch (e) {
      return {
        'status': 'error',
        'message': 'Tidak dapat terhubung ke server.',
      };
    }
  }

  /// Mengecek status permintaan reset password.
  ///
  /// Kemungkinan reset_status:
  /// none
  /// pending
  /// approved
  /// completed
  ///
  /// Endpoint:
  /// auth.php?action=check_reset_status
  static Future<Map<String, dynamic>>
      checkPasswordResetStatus({
    required String email,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(
          '$apiBaseUrl/auth.php?action=check_reset_status',
        ),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'email': email.trim(),
        }),
      );

      return _decodeResponse(response);
    } catch (e) {
      return {
        'status': 'error',
        'message': 'Tidak dapat terhubung ke server.',
      };
    }
  }

  /// Menyimpan password baru setelah permintaan
  /// reset diverifikasi oleh admin.
  ///
  /// Endpoint:
  /// auth.php?action=complete_password_reset
  static Future<Map<String, dynamic>>
      completePasswordReset({
    required String email,
    required String newPassword,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(
          '$apiBaseUrl/auth.php?action=complete_password_reset',
        ),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'email': email.trim(),
          'new_password': newPassword,
        }),
      );

      return _decodeResponse(response);
    } catch (e) {
      return {
        'status': 'error',
        'message': 'Tidak dapat terhubung ke server.',
      };
    }
  }

  // ============================================================
  // UPDATE SKILL LEVEL
  // ============================================================

  static Future<Map<String, dynamic>> updateSkillLevel({
    required String email,
    required String skillLevel,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(
          '$apiBaseUrl/auth.php?action=update_skill',
        ),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'email': email.trim(),
          'skill_level': skillLevel,
        }),
      );

      return _decodeResponse(response);
    } catch (e) {
      return {
        'status': 'error',
        'message': 'Tidak bisa terhubung ke server.',
      };
    }
  }

  // ============================================================
  // UPDATE NAMA
  // ============================================================

  static Future<Map<String, dynamic>> updateName({
    required int userId,
    required String newName,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(
          '$apiBaseUrl/auth.php?action=update_name',
        ),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'user_id': userId,
          'name': newName.trim(),
        }),
      );

      return _decodeResponse(response);
    } catch (e) {
      return {
        'status': 'error',
        'message': 'Gagal memperbarui nama.',
      };
    }
  }

  // ============================================================
  // UPDATE PASSWORD DARI PROFIL
  // ============================================================

  /// Digunakan ketika user masih ingat password lama.
  ///
  /// Ini berbeda dengan fitur Lupa Kata Sandi.
  static Future<Map<String, dynamic>> updatePassword({
    required int userId,
    required String oldPassword,
    required String newPassword,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(
          '$apiBaseUrl/auth.php?action=update_password',
        ),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'user_id': userId,
          'old_password': oldPassword,
          'new_password': newPassword,
        }),
      );

      return _decodeResponse(response);
    } catch (e) {
      return {
        'status': 'error',
        'message': 'Gagal mengubah kata sandi.',
      };
    }
  }

  // ============================================================
  // UPDATE FOTO PROFIL
  // ============================================================

  static Future<Map<String, dynamic>>
      updateProfilePhoto({
    required int userId,
    required File imageFile,
  }) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse(
          '$apiBaseUrl/auth.php?action=update_photo',
        ),
      );

      request.fields['user_id'] =
          userId.toString();

      request.files.add(
        await http.MultipartFile.fromPath(
          'foto',
          imageFile.path,
        ),
      );

      final streamedResponse =
          await request.send();

      final response =
          await http.Response.fromStream(
        streamedResponse,
      );

      return _decodeResponse(response);
    } catch (e) {
      return {
        'status': 'error',
        'message': 'Gagal mengunggah foto.',
      };
    }
  }

  // ============================================================
  // HAPUS FOTO PROFIL
  // ============================================================

  static Future<Map<String, dynamic>>
      deleteProfilePhoto({
    required int userId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(
          '$apiBaseUrl/auth.php?action=delete_photo',
        ),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'user_id': userId,
        }),
      );

      return _decodeResponse(response);
    } catch (e) {
      return {
        'status': 'error',
        'message': 'Gagal menghapus foto.',
      };
    }
  }

  // ============================================================
  // MATERI - DAFTAR PART
  // ============================================================

  static Future<Map<String, dynamic>>
      getParts() async {
    try {
      final response = await http.get(
        Uri.parse(
          '$apiBaseUrl/materials.php?action=parts',
        ),
      );

      return _decodeResponse(response);
    } catch (e) {
      return {
        'status': 'error',
        'message':
            'Gagal mengambil daftar part',
      };
    }
  }

  // ============================================================
  // MATERI BERDASARKAN PART
  // ============================================================

  static Future<Map<String, dynamic>>
      getMaterialsByPart(
    int partId,
  ) async {
    try {
      final response = await http.get(
        Uri.parse(
          '$apiBaseUrl/materials.php?action=by_part&part_id=$partId',
        ),
      );

      return _decodeResponse(response);
    } catch (e) {
      return {
        'status': 'error',
        'message': 'Gagal mengambil materi',
      };
    }
  }

  // ============================================================
  // SOAL PRACTICE
  // ============================================================

  static Future<Map<String, dynamic>>
      getPracticeQuestions(
    int partId,
  ) async {
    try {
      final response = await http.get(
        Uri.parse(
          '$apiBaseUrl/questions.php?action=practice&part_id=$partId',
        ),
      );

      return _decodeResponse(response);
    } catch (e) {
      return {
        'status': 'error',
        'message':
            'Gagal mengambil soal practice',
      };
    }
  }

  // ============================================================
  // SOAL SIMULASI
  // ============================================================

  static Future<Map<String, dynamic>>
      getSimulationQuestions() async {
    try {
      final response = await http.get(
        Uri.parse(
          '$apiBaseUrl/questions.php?action=simulation',
        ),
      );

      return _decodeResponse(response);
    } catch (e) {
      return {
        'status': 'error',
        'message':
            'Gagal mengambil soal simulasi',
      };
    }
  }

  // ============================================================
  // SIMPAN SKOR SIMULASI
  // ============================================================

  static Future<Map<String, dynamic>>
      saveSimulationScore({
    required int userId,
    required int listeningScore,
    required int readingScore,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(
          '$apiBaseUrl/scores.php?action=save_simulation',
        ),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'user_id': userId,
          'listening_score': listeningScore,
          'reading_score': readingScore,
        }),
      );

      return _decodeResponse(response);
    } catch (e) {
      return {
        'status': 'error',
        'message': 'Gagal menyimpan skor',
      };
    }
  }

  // ============================================================
  // RIWAYAT SKOR
  // ============================================================

  static Future<Map<String, dynamic>>
      getScoreHistory(
    int userId,
  ) async {
    try {
      final response = await http.get(
        Uri.parse(
          '$apiBaseUrl/scores.php?action=history&user_id=$userId',
        ),
      );

      return _decodeResponse(response);
    } catch (e) {
      return {
        'status': 'error',
        'message':
            'Gagal mengambil riwayat skor',
      };
    }
  }
}