// services/auth_service.dart
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';

class AuthService {
  static const String baseUrl = 'https://wargakita.canadev.my.id';
  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'user_data';

  // Initialize Google Sign In
  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
  );

  // ==================== TOKEN MANAGEMENT ====================
  // Simpan token ke SharedPreferences
  static Future<void> saveToken(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenKey, token);
      print('✅ Token saved: ${token.substring(0, 20)}...');
    } catch (e) {
      print('❌ Error saving token: $e');
    }
  }

  // Ambil token dari SharedPreferences
  static Future<String?> getToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(_tokenKey);
      if (token != null) {
        print('✅ Token retrieved (length: ${token.length})');
      } else {
        print('⚠️ No token found');
      }
      return token;
    } catch (e) {
      print('❌ Error getting token: $e');
      return null;
    }
  }

  // Simpan user data
  static Future<void> saveUser(User user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = jsonEncode(user.toJson());
      await prefs.setString(_userKey, userJson);
      print('✅ User saved: ${user.email}');
    } catch (e) {
      print('❌ Error saving user: $e');
    }
  }

  // Ambil user data
  static Future<User?> getUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString(_userKey);
      if (userJson != null) {
        final userData = jsonDecode(userJson);
        return User.fromJson(userData);
      }
      return null;
    } catch (e) {
      print('❌ Error getting user: $e');
      return null;
    }
  }

  // Logout - hapus semua data
  static Future<void> logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tokenKey);
      await prefs.remove(_userKey);
      await _googleSignIn.signOut();
      print('✅ Logout successful');
    } catch (e) {
      print('❌ Error during logout: $e');
    }
  }

  // Cek apakah user sudah login
  static Future<bool> isLoggedIn() async {
    final token = await getToken();
    final user = await getUser();
    return token != null && user != null;
  }

  // ==================== AUTH METHODS ====================
  Future<OtpResponse> sendOtp(String email) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/send-otp'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'email': email}),
      );

      if (response.statusCode.toString().startsWith('2')) {
        return OtpResponse.fromJson(json.decode(response.body));
      } else {
        final error = json.decode(response.body);
        throw Exception(error['message'] ?? 'Gagal mengirim OTP');
      }
    } catch (e) {
      throw Exception('Terjadi kesalahan: $e');
    }
  }

  // services/auth_service.dart - UPDATE bagian verifyOtp
  Future<AuthResponse> verifyOtp(String email, String otp) async {
    try {
      print('📱 Verifying OTP for: $email');

      final response = await http
          .post(
            Uri.parse('$baseUrl/auth/verify-otp'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: json.encode({'email': email, 'otp': otp}),
          )
          .timeout(const Duration(seconds: 15));

      final responseData = json.decode(response.body);
      print('📡 Response Status: ${response.statusCode}');
      print('📦 Response Body: ${response.body}');

      if (response.statusCode.toString().startsWith("2")) {
        final authResponse = _parseAuthResponse(responseData);

        // ✅ SIMPAN TOKEN JIKA ADA
        if (authResponse.accessToken != null) {
          await saveToken(authResponse.accessToken!);
          print(
            '✅ Token saved: ${authResponse.accessToken!.substring(0, 20)}...',
          );
        } else {
          print('⚠️ No access token received from server');
        }

        // ✅ SIMPAN USER DATA
        if (authResponse.user != null) {
          await saveUser(authResponse.user!);
          print('✅ User data saved: ${authResponse.user!.email}');
        }

        return authResponse;
      } else {
        final errorMessage =
            responseData['message'] ?? 'OTP verification failed';
        throw Exception(errorMessage);
      }
    } catch (e) {
      print('❌ OTP verification error: $e');
      throw Exception('Terjadi kesalahan: $e');
    }
  }

  // 🔐 REAL GOOGLE SIGN IN
  Future<AuthResponse> signInWithGoogle() async {
    try {
      print('🔐 Starting real Google Sign In...');
      await _googleSignIn.signOut();

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        throw Exception('Google sign in dibatalkan oleh user');
      }

      print('✅ Google user selected: ${googleUser.email}');

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final response = await http
          .post(
            Uri.parse('$baseUrl/auth/google/mobile'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: json.encode({
              'idToken': googleAuth.idToken,
              'accessToken': googleAuth.accessToken,
              'email': googleUser.email,
              'name': googleUser.displayName,
              'picture': googleUser.photoUrl,
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode.toString().startsWith('2')) {
        final responseData = json.decode(response.body);
        final authResponse = _parseAuthResponse(responseData);

        // Simpan token jika ada
        if (authResponse.accessToken != null) {
          await saveToken(authResponse.accessToken!);
        }

        // Simpan user data
        if (authResponse.user != null) {
          await saveUser(authResponse.user!);
        }

        return authResponse;
      } else {
        final errorData = json.decode(response.body);
        final errorMessage =
            errorData['message'] ?? 'Gagal login dengan Google';
        throw Exception(errorMessage);
      }
    } on http.ClientException {
      throw Exception('Koneksi internet bermasalah');
    } on TimeoutException {
      throw Exception('Timeout - server tidak merespons');
    } catch (error) {
      throw Exception('Gagal login dengan Google: $error');
    }
  }

  // Check if user already signed in
  Future<GoogleSignInAccount?> getCurrentGoogleUser() async {
    return await _googleSignIn.currentUser;
  }

  // Sign out from Google
  Future<void> signOutGoogle() async {
    await logout(); // Use our logout method
  }

  // Method untuk parsing response
  AuthResponse _parseAuthResponse(Map<String, dynamic> responseData) {
    User? user;

    if (responseData['user'] != null &&
        responseData['user'] is Map<String, dynamic>) {
      try {
        user = User.fromJson(responseData['user']);
      } catch (e) {
        print('⚠️ Error parsing user data: $e');
        user = _createFallbackUser(responseData);
      }
    } else {
      user = _createFallbackUser(responseData);
    }

    String message = responseData['message'] ?? 'Login berhasil';
    String? accessToken =
        responseData['access_token'] ?? responseData['accessToken'];

    return AuthResponse(message: message, user: user, accessToken: accessToken);
  }

  User _createFallbackUser(Map<String, dynamic> responseData) {
    return User(
      id:
          responseData['userId']?.toString() ??
          responseData['user']['id']?.toString() ??
          'user_${DateTime.now().millisecondsSinceEpoch}',
      email:
          responseData['email']?.toString() ??
          responseData['user']['email']?.toString() ??
          'unknown@email.com',
      name:
          responseData['name']?.toString() ??
          responseData['user']['name']?.toString() ??
          'User',
      role:
          responseData['role']?.toString() ??
          responseData['user']['role']?.toString() ??
          'user', nomorTelepon: '', namaLengkap: '',
    );
  }

  Future<void> resendOtp(String email) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/auth/send-otp'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'email': email}),
          )
          .timeout(const Duration(seconds: 15));

      if (!response.statusCode.toString().startsWith('2')) {
        final error = json.decode(response.body);
        throw Exception(error['message'] ?? 'Gagal mengirim ulang OTP');
      }
    } catch (e) {
      throw Exception('Gagal mengirim ulang OTP: $e');
    }
  }

  // Get auth headers untuk API calls
  static Future<Map<String, String>> getAuthHeaders() async {
    final token = await getToken();

    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }

    return headers;
  }
}
