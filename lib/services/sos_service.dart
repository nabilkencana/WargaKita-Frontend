// services/sos_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/sos_model.dart';
import '../config/config.dart';

class SosService {
  static const String baseUrl = Config.apiUrl;

  final String _apiUrl = '$baseUrl/emergency';

  // Headers untuk request
  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  // Handle error response
  void _handleError(http.Response response) {
    if (response.statusCode >= 400) {
      final errorData = json.decode(response.body);
      final message = errorData['message'] ?? 'Terjadi kesalahan';
      throw Exception(message);
    }
  }

  // Create new SOS emergency
  Future<Emergency> createSOS(CreateSOSRequest request) async {
    try {
      final response = await http.post(
        Uri.parse('$_apiUrl/sos'),
        headers: _headers,
        body: json.encode(request.toJson()),
      );

      _handleError(response);

      final responseData = json.decode(response.body);
      return Emergency.fromJson(responseData);
    } catch (e) {
      throw Exception('Gagal mengirim SOS: $e');
    }
  }

  // Get all active emergencies
  Future<List<Emergency>> getActiveEmergencies() async {
    try {
      final response = await http.get(
        Uri.parse('$_apiUrl/active'),
        headers: _headers,
      );

      _handleError(response);

      final List<dynamic> responseData = json.decode(response.body);
      return responseData.map((json) => Emergency.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Gagal mengambil data emergency aktif: $e');
    }
  }

  // Get all emergencies
  Future<List<Emergency>> getAllEmergencies() async {
    try {
      final response = await http.get(Uri.parse(_apiUrl), headers: _headers);

      _handleError(response);

      final List<dynamic> responseData = json.decode(response.body);
      return responseData.map((json) => Emergency.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Gagal mengambil semua data emergency: $e');
    }
  }

  // Get emergencies that need volunteers
  Future<List<Emergency>> getEmergenciesNeedVolunteers() async {
    try {
      final response = await http.get(
        Uri.parse('$_apiUrl/need-volunteers'),
        headers: _headers,
      );

      _handleError(response);

      final List<dynamic> responseData = json.decode(response.body);
      return responseData.map((json) => Emergency.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Gagal mengambil data emergency butuh relawan: $e');
    }
  }

  // Get emergency by ID
  Future<Emergency> getEmergencyById(int id) async {
    try {
      final response = await http.get(
        Uri.parse('$_apiUrl/$id'),
        headers: _headers,
      );

      _handleError(response);

      final responseData = json.decode(response.body);
      return Emergency.fromJson(responseData);
    } catch (e) {
      throw Exception('Gagal mengambil detail emergency: $e');
    }
  }

  // Update emergency status
  Future<Emergency> updateEmergencyStatus(int id, String status) async {
    try {
      final response = await http.patch(
        Uri.parse('$_apiUrl/$id/status'),
        headers: _headers,
        body: json.encode({'status': status}),
      );

      _handleError(response);

      final responseData = json.decode(response.body);
      return Emergency.fromJson(responseData);
    } catch (e) {
      throw Exception('Gagal mengupdate status emergency: $e');
    }
  }

  // Toggle need volunteer
  Future<Emergency> toggleNeedVolunteer(
    int id,
    bool needVolunteer, {
    int? volunteerCount,
  }) async {
    try {
      final Map<String, dynamic> body = {'needVolunteer': needVolunteer};
      if (volunteerCount != null) {
        body['volunteerCount'] = volunteerCount;
      }

      final response = await http.patch(
        Uri.parse('$_apiUrl/$id/volunteer'),
        headers: _headers,
        body: json.encode(body),
      );

      _handleError(response);

      final responseData = json.decode(response.body);
      return Emergency.fromJson(responseData);
    } catch (e) {
      throw Exception('Gagal mengupdate kebutuhan relawan: $e');
    }
  }

  // Register as volunteer
  Future<Volunteer> registerVolunteer(
    int emergencyId,
    RegisterVolunteerRequest request,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$_apiUrl/$emergencyId/volunteers'),
        headers: _headers,
        body: json.encode(request.toJson()),
      );

      _handleError(response);

      final responseData = json.decode(response.body);
      return Volunteer.fromJson(responseData);
    } catch (e) {
      throw Exception('Gagal mendaftar sebagai relawan: $e');
    }
  }

  // Update volunteer status
  Future<Volunteer> updateVolunteerStatus(
    int volunteerId,
    String status,
  ) async {
    try {
      final response = await http.patch(
        Uri.parse('$_apiUrl/volunteers/$volunteerId/status'),
        headers: _headers,
        body: json.encode({'status': status}),
      );

      _handleError(response);

      final responseData = json.decode(response.body);
      return Volunteer.fromJson(responseData);
    } catch (e) {
      throw Exception('Gagal mengupdate status relawan: $e');
    }
  }

  // Get volunteers for an emergency
  Future<List<Volunteer>> getEmergencyVolunteers(int emergencyId) async {
    try {
      final response = await http.get(
        Uri.parse('$_apiUrl/$emergencyId/volunteers'),
        headers: _headers,
      );

      _handleError(response);

      final List<dynamic> responseData = json.decode(response.body);
      return responseData.map((json) => Volunteer.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Gagal mengambil data relawan: $e');
    }
  }

  // Cancel emergency
  Future<Emergency> cancelEmergency(int id) async {
    return updateEmergencyStatus(id, 'CANCELLED');
  }

  // Resolve emergency
  Future<Emergency> resolveEmergency(int id) async {
    return updateEmergencyStatus(id, 'RESOLVED');
  }

  // Get emergencies by type
  Future<List<Emergency>> getEmergenciesByType(String type) async {
    try {
      final response = await http.get(
        Uri.parse('$_apiUrl/type/$type'),
        headers: _headers,
      );

      _handleError(response);

      final List<dynamic> responseData = json.decode(response.body);
      return responseData.map((json) => Emergency.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Gagal mengambil data emergency berdasarkan tipe: $e');
    }
  }

  // Get emergency statistics
  Future<EmergencyStats> getEmergencyStats() async {
    try {
      final response = await http.get(
        Uri.parse('$_apiUrl/stats'),
        headers: _headers,
      );

      _handleError(response);

      final responseData = json.decode(response.body);
      return EmergencyStats.fromJson(responseData);
    } catch (e) {
      throw Exception('Gagal mengambil statistik emergency: $e');
    }
  }

  // Send alarm to security dashboard
  Future<void> sendAlarmToSecurityDashboard(Emergency emergency) async {
    final String alarmUrl = baseUrl + Config.alarmEndpoint;

    final response = await http.post(
      Uri.parse(alarmUrl),
      headers: _headers,
      body: json.encode(emergency.toJson()),
    );

    _handleError(response);
  }
}
