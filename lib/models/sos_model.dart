// models/sos_model.dart
class Emergency {
  final int id;
  final String type;
  final String? details;
  final String? location;
  final String? latitude;
  final String? longitude;
  final bool needVolunteer;
  final int volunteerCount;
  final String status;
  final int? userId; // Diubah dari String? ke int?
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<Volunteer> volunteers;
  final bool needSatpam;
  final bool satpamAssigned;
  final String severity;
  final bool satpamAlertSent;
  final DateTime? satpamAlertSentAt;
  final List<EmergencyResponse> emergencyResponses;

  Emergency({
    required this.id,
    required this.type,
    this.details,
    this.location,
    this.latitude,
    this.longitude,
    required this.needVolunteer,
    required this.volunteerCount,
    required this.status,
    this.userId,
    required this.createdAt,
    required this.updatedAt,
    required this.volunteers,
    this.needSatpam = true,
    this.satpamAssigned = false,
    this.severity = 'MEDIUM',
    this.satpamAlertSent = false,
    this.satpamAlertSentAt,
    this.emergencyResponses = const [],
  });

  factory Emergency.fromJson(Map<String, dynamic> json) {
    return Emergency(
      id: (json['id'] as num?)?.toInt() ?? 0,
      type: json['type'] ?? '',
      details: json['details'],
      location: json['location'],
      latitude: json['latitude']?.toString(),
      longitude: json['longitude']?.toString(),
      needVolunteer: json['needVolunteer'] ?? false,
      volunteerCount: (json['volunteerCount'] as num?)?.toInt() ?? 0,
      status: json['status'] ?? 'active',
      userId: (json['userId'] as num?)?.toInt(),
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : DateTime.now(),
      volunteers:
          (json['volunteers'] as List?)
              ?.map((v) => Volunteer.fromJson(v))
              .toList() ??
          [],
      needSatpam: json['needSatpam'] ?? true,
      satpamAssigned: json['satpamAssigned'] ?? false,
      severity: json['severity'] ?? 'MEDIUM',
      satpamAlertSent: json['satpamAlertSent'] ?? false,
      satpamAlertSentAt: json['satpamAlertSentAt'] != null
          ? DateTime.parse(json['satpamAlertSentAt'])
          : null,
      emergencyResponses: (json['emergencyResponses'] as List?)
              ?.map((r) => EmergencyResponse.fromJson(r))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'details': details,
      'location': location,
      'latitude': latitude,
      'longitude': longitude,
      'needVolunteer': needVolunteer,
      'volunteerCount': volunteerCount,
      'userId': userId,
      'needSatpam': needSatpam,
      'severity': severity,
    };
  }
}

enum SatpamResponseStatus {
  PENDING,
  ACCEPTED,
  REJECTED,
  ARRIVED,
  HANDLING,
  RESOLVED
}

class EmergencyResponse {
  final int id;
  final int emergencyId;
  final int? satpamId;
  final String status;
  final String? satpamStatus;
  final String? actionTaken;
  final String? notes;
  final DateTime? satpamArrivedAt;
  final DateTime? satpamCompletedAt;
  final DateTime createdAt;

  EmergencyResponse({
    required this.id,
    required this.emergencyId,
    this.satpamId,
    required this.status,
    this.satpamStatus,
    this.actionTaken,
    this.notes,
    this.satpamArrivedAt,
    this.satpamCompletedAt,
    required this.createdAt,
  });

  factory EmergencyResponse.fromJson(Map<String, dynamic> json) {
    return EmergencyResponse(
      id: (json['id'] as num?)?.toInt() ?? 0,
      emergencyId: (json['emergencyId'] as num?)?.toInt() ?? 0,
      satpamId: (json['satpamId'] as num?)?.toInt(),
      status: json['status'] ?? 'DISPATCHED',
      satpamStatus: json['satpamStatus'],
      actionTaken: json['actionTaken'],
      notes: json['notes'],
      satpamArrivedAt: json['satpamArrivedAt'] != null
          ? DateTime.parse(json['satpamArrivedAt'])
          : null,
      satpamCompletedAt: json['satpamCompletedAt'] != null
          ? DateTime.parse(json['satpamCompletedAt'])
          : null,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
    );
  }
}

class Volunteer {
  final int id;
  final int emergencyId;
  final int? userId; // Diubah dari String? ke int?
  final String? userName;
  final String? userPhone;
  final String? skills;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  Volunteer({
    required this.id,
    required this.emergencyId,
    this.userId,
    this.userName,
    this.userPhone,
    this.skills,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Volunteer.fromJson(Map<String, dynamic> json) {
    return Volunteer(
      id: (json['id'] as num?)?.toInt() ?? 0,
      emergencyId: (json['emergencyId'] as num?)?.toInt() ?? 0,
      userId: (json['userId'] as num?)?.toInt(),
      userName: json['userName'],
      userPhone: json['userPhone'],
      skills: json['skills'],
      status: json['status'] ?? 'pending',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : DateTime.now(),
    );
  }


  Map<String, dynamic> toJson() {
    return {
      'emergencyId': emergencyId,
      'userId': userId,
      'userName': userName,
      'skills': skills,
    };
  }
}

class EmergencyStats {
  final int total;
  final int active;
  final int resolved;
  final int needVolunteers;
  final int needSatpam;

  EmergencyStats({
    required this.total,
    required this.active,
    required this.resolved,
    required this.needVolunteers,
    this.needSatpam = 0,
  });

  factory EmergencyStats.fromJson(Map<String, dynamic> json) {
    return EmergencyStats(
      total: json['total'] as int? ?? 0,
      active: json['active'] as int? ?? 0,
      resolved: json['resolved'] as int? ?? 0,
      needVolunteers: json['needVolunteers'] as int? ?? 0,
      needSatpam: json['needSatpam'] as int? ?? 0,
    );
  }
}

class CreateSOSRequest {
  final String type;
  final String? details;
  final String? location;
  final String? latitude;
  final String? longitude;
  final bool needVolunteer;
  final int volunteerCount;
  final int? userId; // Diubah dari String? ke int?

  CreateSOSRequest({
    required this.type,
    this.details,
    this.location,
    this.latitude,
    this.longitude,
    this.needVolunteer = false,
    this.volunteerCount = 0,
    this.userId,
  });

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'details': details,
      'location': location,
      'latitude': latitude,
      'longitude': longitude,
      'needVolunteer': needVolunteer,
      'volunteerCount': volunteerCount,
      'userId': userId,
    };
  }
}

class RegisterVolunteerRequest {
  final int? userId; // Diubah dari String? ke int?
  final String? userName;
  final String? skills;
  // userPhone tidak ada di backend, mungkin diambil dari user profile

  RegisterVolunteerRequest({this.userId, this.userName, this.skills});

  Map<String, dynamic> toJson() {
    return {'userId': userId, 'userName': userName, 'skills': skills};
  }
}

// Tambahkan model untuk response error jika perlu
class ApiError {
  final String message;
  final int statusCode;
  final String? error;

  ApiError({required this.message, required this.statusCode, this.error});

  factory ApiError.fromJson(Map<String, dynamic> json) {
    return ApiError(
      message: json['message'] as String,
      statusCode: json['statusCode'] as int? ?? 500,
      error: json['error'] as String?,
    );
  }
}
