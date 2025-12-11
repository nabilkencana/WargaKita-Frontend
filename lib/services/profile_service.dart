import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../models/user_model.dart';
import 'auth_service.dart';

class ProfileService {
  static final String _baseUrl = 'https://wargakita.canadev.my.id';

  // Get user profile
  static Future<Map<String, dynamic>> getProfile() async {
    try {
      final token = await AuthService.getToken();
      if (token == null || token.isEmpty) {
        throw Exception('Token tidak tersedia');
      }

      final response = await http.get(
        Uri.parse('$_baseUrl/profile/me'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      print('🔍 Profile Response Status: ${response.statusCode}');
      print('🔍 Profile Response Body: ${response.body}');

      if (response.statusCode.toString().startsWith('2')) {
        final data = json.decode(response.body);
        print('✅ Profile Data: $data');
        return data;
      } else if (response.statusCode == 401) {
        await AuthService.logout();
        throw Exception('Sesi telah berakhir, silakan login kembali');
      } else if (response.statusCode == 404) {
        throw Exception('Profil tidak ditemukan');
      } else {
        final error = json.decode(response.body);
        throw Exception(
          error['message'] ?? 'Gagal mengambil profil: ${response.statusCode}',
        );
      }
    } catch (e) {
      print('❌ Error getting profile: $e');
      throw Exception('Gagal mengambil profil: ${e.toString()}');
    }
  }

  // Update user profile
  static Future<Map<String, dynamic>> updateProfile(User user) async {
    try {
      final token = await AuthService.getToken();
      if (token == null || token.isEmpty) {
        throw Exception('Token tidak tersedia');
      }

      // Prepare update data sesuai dengan UpdateProfileDto di backend
      final updateData = {
        'namaLengkap': user.namaLengkap ?? '',
        'nomorTelepon': user.nomorTelepon ?? '',
        'alamat': user.alamat ?? '',
        'kota': user.kota ?? '',
        'rtRw': user.rtRw ?? '',
        'kodePos': user.kodePos ?? '',
        'bio': user.bio ?? '',
        'nik': user.nik ?? '',
        'tempatLahir': user.tempatLahir ?? '',
        // Tambahkan field tanggal lahir jika ada
        if (user.tanggalLahir != null)
          'tanggalLahir': user.tanggalLahir!.toIso8601String().split('T')[0],
      };

      // Hapus field yang kosong
      updateData.removeWhere((key, value) => value.toString().isEmpty);

      print('🔄 Updating profile with data: $updateData');

      final response = await http.put(
        Uri.parse('$_baseUrl/profile/update'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode(updateData),
      );

      print('🔄 Update Response Status: ${response.statusCode}');
      print('🔄 Update Response Body: ${response.body}');

      if (response.statusCode.toString().startsWith('2')) {
        final data = json.decode(response.body);
        print('✅ Profile updated successfully');
        return data;
      } else if (response.statusCode == 401) {
        await AuthService.logout();
        throw Exception('Sesi telah berakhir, silakan login kembali');
      } else if (response.statusCode == 400) {
        final error = json.decode(response.body);
        throw Exception(
          error['message'] ?? 'Data tidak valid: ${response.statusCode}',
        );
      } else if (response.statusCode == 404) {
        throw Exception('User tidak ditemukan');
      } else if (response.statusCode == 409) {
        final error = json.decode(response.body);
        throw Exception(
          error['message'] ?? 'Konflik data: ${error['details'] ?? response.statusCode}',
        );
      } else {
        throw Exception('Gagal memperbarui profil: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error updating profile: $e');
      rethrow;
    }
  }

  // Upload profile picture
  static Future<Map<String, dynamic>> uploadProfilePicture(
    List<int> imageBytes,
    String fileName,
  ) async {
    try {
      final token = await AuthService.getToken();
      if (token == null || token.isEmpty) {
        throw Exception('Token tidak tersedia');
      }

      // Validasi file sebelum upload
      if (imageBytes.isEmpty) {
        throw Exception('File gambar kosong');
      }

      if (imageBytes.length > 5 * 1024 * 1024) {
        throw Exception('Ukuran file maksimal 5MB');
      }

      // Tentukan MIME type berdasarkan file extension
      final fileExtension = fileName.split('.').last.toLowerCase();
      String mimeType;

      switch (fileExtension) {
        case 'jpg':
        case 'jpeg':
          mimeType = 'image/jpeg';
          break;
        case 'png':
          mimeType = 'image/png';
          break;
        default:
          throw Exception('Format file harus JPG, JPEG, atau PNG');
      }

      print('🔍 File info before upload:');
      print('   Filename: $fileName');
      print('   Bytes length: ${imageBytes.length}');
      print('   MIME type: $mimeType');

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/profile/upload-picture'),
      );

      request.headers['Authorization'] = 'Bearer $token';
      request.headers['Accept'] = 'application/json';

      // Buat multipart file
      final multipartFile = http.MultipartFile.fromBytes(
        'profilePicture', // <-- INI HARUS DIPERBAIKI. Contoh: 'file', 'profilePicture', dll.
        imageBytes,
        filename: fileName,
        contentType: MediaType.parse(mimeType),
      );

      request.files.add(multipartFile);

      print('📤 Uploading profile picture: $fileName');

      final response = await request.send();
      final responseData = await http.Response.fromStream(response);

      print('📤 Upload Response Status: ${response.statusCode}');
      print('📤 Upload Response Body: ${responseData.body}');

      if (response.statusCode.toString().startsWith('2')) {
        final data = json.decode(responseData.body);
        print('✅ Profile picture uploaded successfully');
        return data;
      } else if (response.statusCode == 401) {
        await AuthService.logout();
        throw Exception('Sesi telah berakhir, silakan login kembali');
      } else if (response.statusCode == 400) {
        final error = json.decode(responseData.body);
        throw Exception(error['message'] ?? 'Format file tidak didukung');
      } else if (response.statusCode == 413) {
        throw Exception('Ukuran file terlalu besar (maksimal 5MB)');
      } else {
        final error = json.decode(responseData.body);
        throw Exception(error['message'] ?? 'Gagal mengupload foto profil: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error uploading profile picture: $e');
      throw Exception('Gagal mengupload foto profil: ${e.toString()}');
    }
  }

  // Get KK verification status
  static Future<Map<String, dynamic>> getKKVerificationStatus() async {
    try {
      final token = await AuthService.getToken();
      if (token == null || token.isEmpty) {
        throw Exception('Token tidak tersedia');
      }

      final response = await http.get(
        Uri.parse('$_baseUrl/profile/kk-status'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      print('🔍 KK Status Response: ${response.statusCode}');
      print('🔍 KK Status Body: ${response.body}');

      if (response.statusCode.toString().startsWith('2')) {
        return json.decode(response.body);
      } else if (response.statusCode == 401) {
        await AuthService.logout();
        throw Exception('Sesi telah berakhir, silakan login kembali');
      } else if (response.statusCode == 404) {
        return {
          'kkVerificationStatus': 'not_uploaded',
          'message': 'Dokumen KK belum diupload'
        };
      } else {
        final error = json.decode(response.body);
        throw Exception(error['message'] ?? 'Gagal mengambil status KK: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error getting KK status: $e');
      return {
        'kkVerificationStatus': 'not_uploaded',
        'message': 'Belum ada data KK'
      };
    }
  }

  // Upload KK document
  static Future<Map<String, dynamic>> uploadKKDocument(
    List<int> fileBytes,
    String fileName,
  ) async {
    try {
      final token = await AuthService.getToken();
      if (token == null || token.isEmpty) {
        throw Exception('Token tidak tersedia');
      }

      // Validasi file sebelum upload
      if (fileBytes.isEmpty) {
        throw Exception('File kosong');
      }

      if (fileBytes.length > 5 * 1024 * 1024) {
        throw Exception('Ukuran file maksimal 5MB');
      }

      // Tentukan MIME type berdasarkan file extension
      final fileExtension = fileName.split('.').last.toLowerCase();
      String mimeType;

      switch (fileExtension) {
        case 'jpg':
        case 'jpeg':
          mimeType = 'image/jpeg';
          break;
        case 'png':
          mimeType = 'image/png';
          break;
        case 'pdf':
          mimeType = 'application/pdf';
          break;
        default:
          throw Exception('Format file harus JPG, JPEG, PNG, atau PDF');
      }

      print('🔍 KK File info before upload:');
      print('   Filename: $fileName');
      print('   Bytes length: ${fileBytes.length}');
      print('   MIME type: $mimeType');

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/profile/upload-kk'),
      );

      request.headers['Authorization'] = 'Bearer $token';
      request.headers['Accept'] = 'application/json';

      // Buat multipart file dengan field name 'file'
      final multipartFile = http.MultipartFile.fromBytes(
        'kkFile', // Field name harus sesuai dengan backend
        fileBytes,
        filename: fileName,
        contentType: MediaType.parse(mimeType),
      );

      request.files.add(multipartFile);

      print('📤 Uploading KK document: $fileName');

      final response = await request.send();
      final responseData = await http.Response.fromStream(response);

      print('📤 KK Upload Response Status: ${response.statusCode}');
      print('📤 KK Upload Response Body: ${responseData.body}');

      if (response.statusCode.toString().startsWith('2')) {
        final data = json.decode(responseData.body);
        print('✅ KK document uploaded successfully');
        return data;
      } else if (response.statusCode == 401) {
        await AuthService.logout();
        throw Exception('Sesi telah berakhir, silakan login kembali');
      } else if (response.statusCode == 400) {
        final error = json.decode(responseData.body);
        throw Exception(error['message'] ?? 'Format file tidak didukung');
      } else if (response.statusCode == 413) {
        throw Exception('Ukuran file terlalu besar (maksimal 5MB)');
      } else {
        final error = json.decode(responseData.body);
        throw Exception(error['message'] ?? 'Gagal mengupload dokumen KK: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error uploading KK document: $e');
      throw Exception('Gagal mengupload dokumen KK: ${e.toString()}');
    }
  }

  // Get KK document details
  static Future<Map<String, dynamic>> getKKDocument() async {
    try {
      final token = await AuthService.getToken();
      if (token == null || token.isEmpty) {
        throw Exception('Token tidak tersedia');
      }

      final response = await http.get(
        Uri.parse('$_baseUrl/profile/kk'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      print('🔍 KK Document Response: ${response.statusCode}');
      print('🔍 KK Document Body: ${response.body}');

      if (response.statusCode.toString().startsWith('2')) {
        final data = json.decode(response.body);

        // Cek struktur response
        if (data['data'] != null) {
          // Jika response ada di dalam data field
          return {
            ...data['data'],
            'success': data['success'] ?? true,
            'message': data['message'] ?? 'Dokumen KK ditemukan',
          };
        } else {
          // Jika response langsung
          return data;
        }
      } else if (response.statusCode == 401) {
        await AuthService.logout();
        throw Exception('Sesi telah berakhir, silakan login kembali');
      } else if (response.statusCode == 404) {
        throw Exception('Dokumen KK tidak ditemukan');
      } else {
        final error = json.decode(response.body);
        throw Exception(
          error['message'] ??
              'Gagal mengambil dokumen KK: ${response.statusCode}',
        );
      }
    } catch (e) {
      print('❌ Error getting KK document: $e');
      throw Exception('Gagal mengambil dokumen KK: ${e.toString()}');
    }
  }

  // View KK document (get file URL)
  static Future<Map<String, dynamic>> viewKKDocument() async {
    try {
      final token = await AuthService.getToken();
      if (token == null || token.isEmpty) {
        throw Exception('Token tidak tersedia');
      }

      final response = await http.get(
        Uri.parse('$_baseUrl/profile/kk/view'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      print('👁️ View KK Document Response: ${response.statusCode}');
      print('👁️ View KK Document Body: ${response.body}');

      if (response.statusCode.toString().startsWith('2')) {
        final data = json.decode(response.body);

        // Cek struktur response
        if (data['data'] != null) {
          return {
            ...data['data'],
            'success': data['success'] ?? true,
            'message': data['message'] ?? 'Dokumen KK ditemukan',
          };
        } else {
          return data;
        }
      } else if (response.statusCode == 401) {
        await AuthService.logout();
        throw Exception('Sesi telah berakhir, silakan login kembali');
      } else if (response.statusCode == 404) {
        throw Exception('Dokumen KK tidak ditemukan');
      } else {
        final error = json.decode(response.body);
        throw Exception(
          error['message'] ??
              'Gagal melihat dokumen KK: ${response.statusCode}',
        );
      }
    } catch (e) {
      print('❌ Error viewing KK document: $e');
      throw Exception('Gagal melihat dokumen KK: ${e.toString()}');
    }
  }

  // Delete KK document
  static Future<Map<String, dynamic>> deleteKKDocument() async {
    try {
      final token = await AuthService.getToken();
      if (token == null || token.isEmpty) {
        throw Exception('Token tidak tersedia');
      }

      final response = await http.delete(
        Uri.parse('$_baseUrl/profile/kk'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      print('🗑️ Delete KK Response: ${response.statusCode}');
      print('🗑️ Delete KK Body: ${response.body}');

      if (response.statusCode.toString().startsWith('2')) {
        return json.decode(response.body);
      } else if (response.statusCode == 401) {
        await AuthService.logout();
        throw Exception('Sesi telah berakhir, silakan login kembali');
      } else if (response.statusCode == 404) {
        throw Exception('Dokumen KK tidak ditemukan');
      } else {
        final error = json.decode(response.body);
        throw Exception(error['message'] ?? 'Gagal menghapus dokumen KK: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error deleting KK document: $e');
      throw Exception('Gagal menghapus dokumen KK: ${e.toString()}');
    }
  }

  // Get user dashboard statistics
  static Future<Map<String, dynamic>> getDashboardStats() async {
    try {
      final token = await AuthService.getToken();
      if (token == null || token.isEmpty) {
        throw Exception('Token tidak tersedia');
      }

      final response = await http.get(
        Uri.parse('$_baseUrl/profile/dashboard-stats'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      print('📊 Dashboard Stats Response: ${response.statusCode}');
      print('📊 Dashboard Stats Body: ${response.body}');

      if (response.statusCode.toString().startsWith('2')) {
        return json.decode(response.body);
      } else if (response.statusCode == 401) {
        await AuthService.logout();
        throw Exception('Sesi telah berakhir, silakan login kembali');
      } else if (response.statusCode == 404) {
        throw Exception('Statistik tidak ditemukan');
      } else {
        final error = json.decode(response.body);
        throw Exception(error['message'] ?? 'Gagal mengambil statistik: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error getting dashboard stats: $e');
      throw Exception('Gagal mengambil statistik: ${e.toString()}');
    }
  }

  // Update phone number
  static Future<Map<String, dynamic>> updatePhoneNumber(
    String phoneNumber,
  ) async {
    try {
      final token = await AuthService.getToken();
      if (token == null || token.isEmpty) {
        throw Exception('Token tidak tersedia');
      }

      final response = await http.put(
        Uri.parse('$_baseUrl/profile/update-phone'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode({'phoneNumber': phoneNumber}),
      );

      print('📱 Update Phone Response: ${response.statusCode}');
      print('📱 Update Phone Body: ${response.body}');

      if (response.statusCode.toString().startsWith('2')) {
        return json.decode(response.body);
      } else if (response.statusCode == 401) {
        await AuthService.logout();
        throw Exception('Sesi telah berakhir, silakan login kembali');
      } else if (response.statusCode == 400) {
        final error = json.decode(response.body);
        throw Exception(error['message'] ?? 'Nomor telepon tidak valid');
      } else if (response.statusCode == 409) {
        final error = json.decode(response.body);
        throw Exception(error['message'] ?? 'Nomor telepon sudah digunakan');
      } else {
        throw Exception(
          'Gagal memperbarui nomor telepon: ${response.statusCode}',
        );
      }
    } catch (e) {
      print('❌ Error updating phone number: $e');
      rethrow;
    }
  }

  // Delete profile picture
  static Future<Map<String, dynamic>> deleteProfilePicture() async {
    try {
      final token = await AuthService.getToken();
      if (token == null || token.isEmpty) {
        throw Exception('Token tidak tersedia');
      }

      final response = await http.delete(
        Uri.parse('$_baseUrl/profile/picture'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      print('🗑️ Delete Profile Picture Response: ${response.statusCode}');
      print('🗑️ Delete Profile Picture Body: ${response.body}');

      if (response.statusCode.toString().startsWith('2')) {
        final data = json.decode(response.body);
        print('✅ Profile picture deleted successfully');
        return data;
      } else if (response.statusCode == 401) {
        await AuthService.logout();
        throw Exception('Sesi telah berakhir, silakan login kembali');
      } else if (response.statusCode == 404) {
        throw Exception('Foto profil tidak ditemukan');
      } else {
        throw Exception('Gagal menghapus foto profil: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error deleting profile picture: $e');
      throw Exception('Gagal menghapus foto profil: ${e.toString()}');
    }
  }

  // Update bio
  static Future<Map<String, dynamic>> updateBio(String bio) async {
    try {
      final token = await AuthService.getToken();
      if (token == null || token.isEmpty) {
        throw Exception('Token tidak tersedia');
      }

      final response = await http.put(
        Uri.parse('$_baseUrl/profile/bio'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode({'bio': bio}),
      );

      print('📝 Update Bio Response: ${response.statusCode}');
      print('📝 Update Bio Body: ${response.body}');

      if (response.statusCode.toString().startsWith('2')) {
        return json.decode(response.body);
      } else if (response.statusCode == 401) {
        await AuthService.logout();
        throw Exception('Sesi telah berakhir, silakan login kembali');
      } else {
        throw Exception('Gagal memperbarui bio: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error updating bio: $e');
      throw Exception('Gagal memperbarui bio: ${e.toString()}');
    }
  }

  // Get profile activity
  static Future<Map<String, dynamic>> getProfileActivity({
    int page = 1,
    int limit = 10,
  }) async {
    try {
      final token = await AuthService.getToken();
      if (token == null || token.isEmpty) {
        throw Exception('Token tidak tersedia');
      }

      final response = await http.get(
        Uri.parse('$_baseUrl/profile/activity?page=$page&limit=$limit'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      print('📊 Activity Response: ${response.statusCode}');
      print('📊 Activity Body: ${response.body}');

      if (response.statusCode.toString().startsWith('2')) {
        return json.decode(response.body);
      } else if (response.statusCode == 401) {
        await AuthService.logout();
        throw Exception('Sesi telah berakhir, silakan login kembali');
      } else {
        throw Exception('Gagal mengambil aktivitas: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error getting profile activity: $e');
      throw Exception('Gagal mengambil aktivitas: ${e.toString()}');
    }
  }
}