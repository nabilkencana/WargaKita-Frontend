// services/laporan_service.dart
import 'dart:convert';
import 'package:warga_app/services/auth_service.dart';
import 'package:http/http.dart' as http;
import '../models/laporan_model.dart';

class LaporanService {
  static const String baseUrl = 'https://wargakita.canadev.my.id';

  Future<Map<String, String>> _getHeaders() async {
    final String? token = await AuthService.getToken();

    if (token == null || token.isEmpty) {
      print('⚠️ No token found in LaporanService');
      throw Exception('Token tidak ditemukan. Silakan login ulang.');
    }

    print('🔑 Token length: ${token.length}');
    print(
      '🔑 Token first 20 chars: ${token.substring(0, min(20, token.length))}...',
    );

    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  int min(int a, int b) => a < b ? a : b;

  // Create new report - OBSOLETE, gunakan method di laporan_screen.dart
  static Future<Laporan> createLaporan(Laporan laporan) async {
    final response = await http.post(
      Uri.parse('$baseUrl/reports'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(laporan.toJson()),
    );

    if (response.statusCode.toString().startsWith('2')) {
      return Laporan.fromJson(json.decode(response.body));
    } else {
      throw Exception('Gagal mengirim laporan: ${response.statusCode}');
    }
  }

  // Get all reports dengan pagination
  Future<ApiResponse<List<Laporan>>> getAllLaporan({
    int page = 1,
    int limit = 10,
    String? search,
  }) async {
    try {
      final queryParams = {
        'page': page.toString(),
        'limit': limit.toString(),
        if (search != null && search.isNotEmpty) 'search': search,
      };

      final uri = Uri.parse(
        '$baseUrl/reports',
      ).replace(queryParameters: queryParams);

      final response = await http.get(uri, headers: await _getHeaders());

      if (response.statusCode.toString().startsWith('2')) {
        final data = json.decode(response.body);
        final List<dynamic> reportsData = data['data'];

        return ApiResponse<List<Laporan>>(
          success: true,
          data: reportsData.map((item) => Laporan.fromJson(item)).toList(),
          meta: MetaData.fromJson(data['meta']),
        );
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Gagal mengambil data laporan');
      }
    } catch (e) {
      throw Exception('Gagal mengambil data laporan: $e');
    }
  }

  // Get report by ID
  Future<Laporan> getLaporanById(int id) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/reports/$id'),
        headers: await _getHeaders(),
      );

      if (response.statusCode.toString().startsWith('2')) {
        return Laporan.fromJson(json.decode(response.body));
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Laporan tidak ditemukan');
      }
    } catch (e) {
      throw Exception('Laporan tidak ditemukan: $e');
    }
  }

  // Get reports by user ID (UNTUK RIWAYAT LAPORAN)
  // Di laporan_service.dart
  Future<ApiResponse<List<Laporan>>> getLaporanByUserId(
    dynamic userId, {
    int page = 1,
    int limit = 10,
  }) async {
    try {
      final queryParams = {'page': page.toString(), 'limit': limit.toString()};

      final uri = Uri.parse(
        '$baseUrl/reports/user/$userId',
      ).replace(queryParameters: queryParams);

      print('📡 GET user reports: ${uri.toString()}');

      final headers = await _getHeaders();
      print('📡 Headers: ${headers.keys}');

      final response = await http.get(uri, headers: headers);

      print('📥 Response Status: ${response.statusCode}');
      print('📥 Response Body length: ${response.body.length}');

      if (response.statusCode.toString().startsWith('2')) {
        final data = json.decode(response.body);
        print('📊 Response data keys: ${data.keys}');

        final List<dynamic> reportsData = data['data'] ?? [];
        print('📊 Reports count: ${reportsData.length}');

        return ApiResponse<List<Laporan>>(
          success: true,
          data: reportsData.map((item) => Laporan.fromJson(item)).toList(),
          meta: MetaData.fromJson(
            data['meta'] ??
                {'page': page, 'limit': limit, 'total': 0, 'totalPages': 1},
          ),
        );
      } else if (response.statusCode == 401) {
        // Unauthorized - token invalid or expired
        print('❌ Unauthorized - Token mungkin expired');
        await AuthService.logout();
        throw Exception('Sesi telah berakhir. Silakan login ulang.');
      } else if (response.statusCode == 404) {
        // User not found or no reports
        print('ℹ️ No reports found for user $userId');
        return ApiResponse<List<Laporan>>(
          success: true,
          data: [],
          meta: MetaData.fromJson({
            'page': page,
            'limit': limit,
            'total': 0,
            'totalPages': 1,
          }),
        );
      } else {
        final errorData = json.decode(response.body);
        final errorMessage =
            errorData['message'] ?? 'Gagal memuat laporan pengguna';
        print('❌ Backend error: $errorMessage');
        throw Exception(errorMessage);
      }
    } on FormatException catch (e) {
      print('❌ JSON Format Error: $e');
      throw Exception('Format response tidak valid');
    } catch (e) {
      print('❌ General Error in getLaporanByUserId: $e');
      throw Exception('Gagal memuat laporan pengguna: ${e.toString()}');
    }
  }

  // Update report
  Future<Laporan> updateLaporan(int id, Laporan laporan) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/reports/$id'),
        headers: await _getHeaders(),
        body: json.encode(laporan.toJson()),
      );

      if (response.statusCode.toString().startsWith('2')) {
        return Laporan.fromJson(json.decode(response.body));
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Gagal mengupdate laporan');
      }
    } catch (e) {
      throw Exception('Gagal mengupdate laporan: $e');
    }
  }

  // Delete report
  Future<Map<String, dynamic>> deleteLaporan(int id) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/reports/$id'),
        headers: await _getHeaders(),
      );

      if (response.statusCode.toString().startsWith('2')) {
        final data = json.decode(response.body);
        return {
          'message': data['message'],
          'deletedReport': data['deletedReport'],
        };
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Gagal menghapus laporan');
      }
    } catch (e) {
      throw Exception('Gagal menghapus laporan: $e');
    }
  }

  // Search reports by keyword dengan pagination
  Future<ApiResponse<List<Laporan>>> searchLaporan(
    String keyword, {
    int page = 1,
    int limit = 10,
  }) async {
    try {
      final queryParams = {'page': page.toString(), 'limit': limit.toString()};

      final uri = Uri.parse(
        '$baseUrl/reports/search/$keyword',
      ).replace(queryParameters: queryParams);

      final response = await http.get(uri, headers: await _getHeaders());

      if (response.statusCode.toString().startsWith('2')) {
        final data = json.decode(response.body);
        final List<dynamic> reportsData = data['data'];

        return ApiResponse<List<Laporan>>(
          success: true,
          data: reportsData.map((item) => Laporan.fromJson(item)).toList(),
          meta: MetaData.fromJson(data['meta']),
        );
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Gagal mencari laporan');
      }
    } catch (e) {
      throw Exception('Gagal mencari laporan: $e');
    }
  }

  // Get reports by category dengan pagination
  Future<ApiResponse<List<Laporan>>> getLaporanByCategory(
    String category, {
    int page = 1,
    int limit = 10,
  }) async {
    try {
      final queryParams = {'page': page.toString(), 'limit': limit.toString()};

      final uri = Uri.parse(
        '$baseUrl/reports/category/$category',
      ).replace(queryParameters: queryParams);

      final response = await http.get(uri, headers: await _getHeaders());

      if (response.statusCode.toString().startsWith('2')) {
        final data = json.decode(response.body);
        final List<dynamic> reportsData = data['data'];

        return ApiResponse<List<Laporan>>(
          success: true,
          data: reportsData.map((item) => Laporan.fromJson(item)).toList(),
          meta: MetaData.fromJson(data['meta']),
        );
      } else {
        final errorData = json.decode(response.body);
        throw Exception(
          errorData['message'] ??
              'Gagal mengambil laporan berdasarkan kategori',
        );
      }
    } catch (e) {
      throw Exception('Gagal mengambil laporan berdasarkan kategori: $e');
    }
  }

  // Get report statistics
  Future<Map<String, dynamic>> getReportStats() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/reports/stats/summary'),
        headers: await _getHeaders(),
      );

      if (response.statusCode.toString().startsWith('2')) {
        final data = json.decode(response.body);
        return data;
      } else {
        final errorData = json.decode(response.body);
        throw Exception(
          errorData['message'] ?? 'Gagal memuat statistik laporan',
        );
      }
    } catch (e) {
      throw Exception('Gagal memuat statistik laporan: $e');
    }
  }

  // Get available categories
  Future<List<String>> getCategories() async {
    return ['Infrastruktur', 'Kebersihan', 'Keamanan', 'Lingkungan', 'Lainnya'];
  }

  // Get available statuses
  Future<List<String>> getStatuses() async {
    return ['PENDING', 'PROCESSING', 'RESOLVED', 'REJECTED'];
  }
}

// Model untuk response dengan pagination
class ApiResponse<T> {
  final bool success;
  final T data;
  final MetaData meta;

  ApiResponse({required this.success, required this.data, required this.meta});
}

class MetaData {
  final int page;
  final int limit;
  final int total;
  final int totalPages;

  MetaData({
    required this.page,
    required this.limit,
    required this.total,
    required this.totalPages,
  });

  factory MetaData.fromJson(Map<String, dynamic> json) {
    return MetaData(
      page: json['page'] ?? 1,
      limit: json['limit'] ?? 10,
      total: json['total'] ?? 0,
      totalPages: json['totalPages'] ?? 1,
    );
  }
}
