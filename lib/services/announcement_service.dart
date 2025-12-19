// services/announcement_service.dart - REVISI LANGSUNG
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/announcement_model.dart';
import '../config/config.dart';

class AnnouncementService {
  static const String baseUrl = Config.apiUrl;

  // Helper untuk mendapatkan token dari SharedPreferences
  static Future<String?> _getTokenFromStorage() async {
    try {
      print('🔄 Mencari token dari SharedPreferences...');
      final prefs = await SharedPreferences.getInstance();

      // Coba ambil dengan key yang mungkin digunakan
      final token1 = prefs.getString('token');
      final token2 = prefs.getString('auth_token');
      final token3 = prefs.getString('access_token');

      String? finalToken = token1 ?? token2 ?? token3;

      if (finalToken != null && finalToken.isNotEmpty) {
        print('✅ Token ditemukan di storage (length: ${finalToken.length})');
        print('🔐 Token preview: Bearer ${finalToken.substring(0, 20)}...');
        return finalToken;
      } else {
        print('❌ Token TIDAK ditemukan di storage');
        print('🔍 Keys yang dicari: token, auth_token, access_token');
        print('🔍 Semua keys di storage: ${prefs.getKeys()}');
        return null;
      }
    } catch (e) {
      print('❌ Error mengambil token dari storage: $e');
      return null;
    }
  }

  // Helper untuk get headers dengan token
  static Future<Map<String, String>> _getHeaders() async {
    final token = await _getTokenFromStorage();
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
      print('✅ Authorization header ditambahkan dengan token');
    } else {
      print('⚠️ Request tanpa Authorization header - token kosong');
    }

    print('📋 Headers final: $headers');
    return headers;
  }

  // Debug: Cek status token sebelum request
  static Future<void> _debugTokenStatus() async {
    print('🔍 Debug Token Status:');
    try {
      final prefs = await SharedPreferences.getInstance();
      print('📱 SharedPreferences keys: ${prefs.getKeys()}');

      final token = prefs.getString('token');
      print('🔐 Token value: ${token != null ? "Ada" : "Tidak ada"}');
      if (token != null) {
        print('🔐 Token length: ${token.length}');
        print('🔐 Token preview: ${token.substring(0, 30)}...');
      }

      // Cek user data juga
      final userJson = prefs.getString('user_data');
      print('👤 User data: ${userJson != null ? "Ada" : "Tidak ada"}');
    } catch (e) {
      print('❌ Error debug: $e');
    }
  }

  // Get semua pengumuman DENGAN AUTH
  static Future<List<Announcement>> getAnnouncements() async {
    try {
      print('🔍 Memulai request pengumuman...');

      // Debug dulu
      await _debugTokenStatus();

      final headers = await _getHeaders();

      print('📡 Mengirim GET ke: $baseUrl/announcements');
      print('🔑 Menggunakan headers: $headers');

      final response = await http.get(
        Uri.parse('$baseUrl/announcements'),
        headers: headers,
      );

      print('📡 Response status: ${response.statusCode}');
      print('📡 Response headers: ${response.headers}');
      print(
        '📡 Response body (50 chars): ${response.body.length > 50 ? response.body.substring(0, 50) + "..." : response.body}',
      );

      if (response.statusCode == 200) {
        try {
          final List<dynamic> data = json.decode(response.body);
          print('✅ Berhasil mengambil ${data.length} pengumuman');
          return data.map((json) => Announcement.fromJson(json)).toList();
        } catch (e) {
          print('❌ Error parsing response: $e');
          throw Exception('Gagal memproses data pengumuman');
        }
      } else if (response.statusCode == 401) {
        print('❌ 401 Unauthorized - Token mungkin expired atau tidak valid');
        print('🔍 Coba cek token di storage');

        // Auto-clear token jika 401
        await _clearInvalidToken();

        throw Exception('Sesi telah berakhir. Silakan login kembali.');
      } else if (response.statusCode == 403) {
        print('❌ 403 Forbidden - Tidak punya akses');
        throw Exception('Anda tidak memiliki izin untuk mengakses pengumuman');
      } else {
        print('❌ Gagal mengambil pengumuman: ${response.statusCode}');
        print('📝 Response full body: ${response.body}');
        throw Exception('Gagal memuat pengumuman: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error mengambil pengumuman: $e');
      print('🔍 Stack trace: ${e.toString()}');
      rethrow;
    }
  }

  // Clear token jika invalid
  static Future<void> _clearInvalidToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('token');
      await prefs.remove('auth_token');
      await prefs.remove('access_token');
      print('🧹 Token invalid dibersihkan dari storage');
    } catch (e) {
      print('⚠️ Error clearing token: $e');
    }
  }

  // Get detail pengumuman by ID dengan auth
  static Future<Announcement> getAnnouncementById(int id) async {
    try {
      final headers = await _getHeaders();

      print('📡 Mengambil detail pengumuman ID: $id');

      final response = await http.get(
        Uri.parse('$baseUrl/announcements/$id'),
        headers: headers,
      );

      print('📡 Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        print('✅ Berhasil mengambil detail pengumuman');
        return Announcement.fromJson(data);
      } else if (response.statusCode == 401) {
        await _clearInvalidToken();
        throw Exception('Sesi telah berakhir. Silakan login kembali.');
      } else if (response.statusCode == 404) {
        throw Exception('Pengumuman tidak ditemukan');
      } else {
        throw Exception(
          'Gagal memuat detail pengumuman: ${response.statusCode}',
        );
      }
    } catch (e) {
      print('❌ Error mengambil detail pengumuman: $e');
      rethrow;
    }
  }

  // Create new announcement (Admin only) dengan auth
  static Future<Map<String, dynamic>> createAnnouncement({
    required String title,
    required String description,
    required String targetAudience,
    required DateTime date,
    required String day,
  }) async {
    try {
      final headers = await _getHeaders();

      print('📡 Membuat pengumuman baru...');
      print('📋 Headers: $headers');

      final response = await http.post(
        Uri.parse('$baseUrl/announcements'),
        headers: headers,
        body: json.encode({
          'title': title,
          'description': description,
          'targetAudience': targetAudience,
          'date': date.toIso8601String(),
          'day': day,
        }),
      );

      print('📡 Response status: ${response.statusCode}');
      print('📡 Response body: ${response.body}');

      if (response.statusCode == 201 || response.statusCode == 200) {
        try {
          final data = json.decode(response.body);
          print('✅ Berhasil membuat pengumuman: ${data['message']}');
          return {
            'success': true,
            'message': data['message'] ?? 'Pengumuman berhasil dibuat',
            'announcement': Announcement.fromJson(data['announcement'] ?? data),
          };
        } catch (e) {
          print('❌ Error parsing create response: $e');
          return {'success': false, 'message': 'Gagal memproses response'};
        }
      } else if (response.statusCode == 401) {
        await _clearInvalidToken();
        return {
          'success': false,
          'message': 'Sesi telah berakhir. Silakan login kembali.',
        };
      } else if (response.statusCode == 403) {
        return {
          'success': false,
          'message': 'Anda tidak memiliki izin untuk membuat pengumuman',
        };
      } else {
        return {
          'success': false,
          'message': 'Gagal membuat pengumuman: ${response.statusCode}',
        };
      }
    } catch (e) {
      print('❌ Error membuat pengumuman: $e');
      return {'success': false, 'message': 'Error: $e'};
    }
  }
}
