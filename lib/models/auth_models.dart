// models/auth_models.dart
import 'package:warga_app/models/register_model.dart';

class AuthResponse {
  final String message;
  final User? user;
  final String? accessToken;

  AuthResponse({required this.message, this.user, this.accessToken});

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      message: json['message'],
      user: json['user'] != null ? User.fromJson(json['user']) : null,
      accessToken: json['access_token'] ?? json['accessToken'],
    );
  }
}

class OtpResponse {
  final String message;
  final bool success;

  OtpResponse({required this.message, required this.success});

  factory OtpResponse.fromJson(Map<String, dynamic> json) {
    return OtpResponse(
      message: json['message'],
      success: json['success'] ?? false,
    );
  }
}
