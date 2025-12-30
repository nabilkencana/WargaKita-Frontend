class User {
  final dynamic id;
  final String email;
  final String? name;
  final String? phone;
  final String? role;
  final String? otpCode;
  final DateTime? otpExpire;
  final String? profilePicture;
  final String? alamat;
  final String? kota;
  final String? rtRw;
  final String? bio;

  // Field baru dari schema Prisma
  final String? nik;
  final DateTime? tanggalLahir;
  final String? tempatLahir;
  final String? instagram;
  final String? facebook;
  final String? negara;
  final String? kodePos;
  final bool? isVerified;
  final bool? twoFactorEnabled;
  final String? twoFactorSecret;
  final String? language;
  final String? biometricData;
  final bool? isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // KK Verification Fields
  final String? kkFile;
  final String? kkFilePublicId;
  final String? kkRejectionReason;
  final DateTime? kkVerifiedAt;
  final String? kkVerifiedBy;

  // Additional fields for display
  final int? usia;
  final String? kkVerificationStatus;
  final bool? hasKKDocument;

  User({
    required this.id,
    required this.email,
    this.name,
    this.phone,
    this.role,
    this.otpCode,
    this.otpExpire,
    this.profilePicture,
    this.alamat,
    this.kota,
    this.bio,
    this.rtRw,
    this.nik,
    this.tanggalLahir,
    this.tempatLahir,
    this.instagram,
    this.facebook,
    this.negara,
    this.kodePos,
    this.isVerified,
    this.twoFactorEnabled,
    this.twoFactorSecret,
    this.language,
    this.biometricData,
    this.isActive,
    this.createdAt,
    this.updatedAt,
    this.kkFile,
    this.kkFilePublicId,
    this.kkRejectionReason,
    this.kkVerifiedAt,
    this.kkVerifiedBy,
    this.usia,
    this.kkVerificationStatus,
    this.hasKKDocument,
    required String namaLengkap,
    required String nomorTelepon,
    String? fotoProfil,
  });

  // Getter untuk kompatibilitas dengan screen
  String? get namaLengkap => name;
  String? get nomorTelepon => phone;
  String? get fotoProfil => profilePicture;
  String? get address => alamat;
  String? get city => kota;
  String? get country => negara;
  String? get postalCode => kodePos;

  factory User.fromJson(Map<String, dynamic> json) {
    print('🔄 Parsing User from JSON keys: ${json.keys}');

    try {
      // Handle nested structure
      Map<String, dynamic> userData = json;
      if (json['user'] != null && json['user'] is Map<String, dynamic>) {
        userData = json['user'];
      }

      // Debug: Print semua data yang diterima
      print('📊 User data received:');
      userData.forEach((key, value) {
        print('   $key: $value');
      });

      // Extract ID
      String id = userData['id']?.toString() ?? 'unknown';

      // Extract email - dengan berbagai kemungkinan field
      String email = userData['email']?.toString() ?? '';

      // Extract nama lengkap - prioritas: namaLengkap, lalu name
      String? namaLengkap =
          userData['namaLengkap']?.toString() ?? userData['name']?.toString();

      // Extract nomor telepon
      String? nomorTelepon =
          userData['nomorTelepon']?.toString() ?? userData['phone']?.toString();

      // Extract alamat
      String? alamat = userData['alamat']?.toString();

      // Extract kota
      String? kota = userData['kota']?.toString();

      // Extract rtRw
      String? rtRw = userData['rtRw']?.toString();

      // Extract kodePos
      String? kodePos = userData['kodePos']?.toString();

      // Extract bio
      String? bio = userData['bio']?.toString();

      // Extract NIK
      String? nik = userData['nik']?.toString();

      // Extract tempat lahir
      String? tempatLahir = userData['tempatLahir']?.toString();

      // Extract tanggal lahir
      DateTime? tanggalLahir;
      if (userData['tanggalLahir'] != null) {
        if (userData['tanggalLahir'] is String) {
          tanggalLahir = DateTime.tryParse(userData['tanggalLahir']);
        }
      }

      // Extract role
      String role = userData['role']?.toString() ?? 'warga';

      // Extract isVerified
      bool isVerified = userData['isVerified'] ?? false;

      // Extract foto profil
      String? fotoProfil = userData['fotoProfil']?.toString();

      // Extract KK fields
      String? kkFile = userData['kkFile']?.toString();
      String? kkRejectionReason = userData['kkRejectionReason']?.toString();
      String? kkVerifiedBy =
          userData['verifiedBy']?.toString() ??
          userData['kkVerifiedBy']?.toString(); // fallback kalau lama

      print('🧪 verifiedBy from API: ${userData['verifiedBy']}');
      print('🧪 kkVerifiedBy from API: ${userData['kkVerifiedBy']}');

      DateTime? kkVerifiedAt;
      if (userData['kkVerifiedAt'] != null) {
        if (userData['kkVerifiedAt'] is String) {
          kkVerifiedAt = DateTime.tryParse(userData['kkVerifiedAt']);
        }
      }

      print('✅ Parsed User:');
      print('   ID: $id');
      print('   Email: $email');
      print('   Nama Lengkap: $namaLengkap');
      print('   NIK: $nik');
      print('   Alamat: $alamat');
      print('   Nomor Telepon: $nomorTelepon');
      print('   Kota: $kota');
      print('   RT/RW: $rtRw');
      print('   Kode Pos: $kodePos');

      return User(
        id: id,
        email: email,
        name: namaLengkap,
        phone: nomorTelepon,
        role: role,
        profilePicture: fotoProfil,
        alamat: alamat,
        kota: kota,
        rtRw: rtRw,
        bio: bio,
        nik: nik,
        tempatLahir: tempatLahir,
        tanggalLahir: tanggalLahir,
        isVerified: isVerified,
        kodePos: kodePos,
        kkFile: kkFile,
        kkRejectionReason: kkRejectionReason,
        kkVerifiedAt: kkVerifiedAt,
        kkVerifiedBy: kkVerifiedBy,
        namaLengkap: '',
        nomorTelepon: '',
      );
    } catch (e) {
      print('❌ Error parsing User: $e');
      print('❌ JSON that caused error: $json');
      rethrow;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'role': role,
      'phone': phone,
      'otpCode': otpCode,
      'otpExpire': otpExpire?.toIso8601String(),
      'profilePicture': profilePicture,
      'alamat': alamat,
      'kota': kota,
      'rtRw': rtRw,
      'bio': bio,
      'nik': nik,
      'tanggalLahir': tanggalLahir?.toIso8601String(),
      'tempatLahir': tempatLahir,
      'instagram': instagram,
      'facebook': facebook,
      'negara': negara,
      'kodePos': kodePos,
      'isVerified': isVerified,
      'twoFactorEnabled': twoFactorEnabled,
      'twoFactorSecret': twoFactorSecret,
      'language': language,
      'biometricData': biometricData,
      'isActive': isActive,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'kkFile': kkFile,
      'kkFilePublicId': kkFilePublicId,
      'kkRejectionReason': kkRejectionReason,
      'kkVerifiedAt': kkVerifiedAt?.toIso8601String(),
      'kkVerifiedBy': kkVerifiedBy,
    };
  }

  // Method untuk membuat salinan dengan perubahan
  User copyWith({
    String? id,
    String? email,
    String? name,
    String? phone,
    String? role,
    String? otpCode,
    DateTime? otpExpire,
    String? profilePicture,
    String? alamat,
    String? kota,
    String? rtRw,
    String? bio,
    String? nik,
    DateTime? tanggalLahir,
    String? tempatLahir,
    String? instagram,
    String? facebook,
    String? negara,
    String? kodePos,
    bool? isVerified,
    bool? twoFactorEnabled,
    String? twoFactorSecret,
    String? language,
    String? biometricData,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? kkFile,
    String? kkFilePublicId,
    String? kkRejectionReason,
    DateTime? kkVerifiedAt,
    String? kkVerifiedBy,
    int? usia,
    String? kkVerificationStatus,
    bool? hasKKDocument,
  }) {
    return User(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      otpCode: otpCode ?? this.otpCode,
      otpExpire: otpExpire ?? this.otpExpire,
      profilePicture: profilePicture ?? this.profilePicture,
      alamat: alamat ?? this.alamat,
      kota: kota ?? this.kota,
      rtRw: rtRw ?? this.rtRw,
      bio: bio ?? this.bio,
      nik: nik ?? this.nik,
      tanggalLahir: tanggalLahir ?? this.tanggalLahir,
      tempatLahir: tempatLahir ?? this.tempatLahir,
      instagram: instagram ?? this.instagram,
      facebook: facebook ?? this.facebook,
      negara: negara ?? this.negara,
      kodePos: kodePos ?? this.kodePos,
      isVerified: isVerified ?? this.isVerified,
      twoFactorEnabled: twoFactorEnabled ?? this.twoFactorEnabled,
      twoFactorSecret: twoFactorSecret ?? this.twoFactorSecret,
      language: language ?? this.language,
      biometricData: biometricData ?? this.biometricData,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      kkFile: kkFile ?? this.kkFile,
      kkFilePublicId: kkFilePublicId ?? this.kkFilePublicId,
      kkRejectionReason: kkRejectionReason ?? this.kkRejectionReason,
      kkVerifiedAt: kkVerifiedAt ?? this.kkVerifiedAt,
      kkVerifiedBy: kkVerifiedBy ?? this.kkVerifiedBy,
      usia: usia ?? this.usia,
      kkVerificationStatus: kkVerificationStatus ?? this.kkVerificationStatus,
      hasKKDocument: hasKKDocument ?? this.hasKKDocument,
      namaLengkap: '',
      nomorTelepon: '',
    );
  }

  // Method untuk mengecek kesamaan user
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is User && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  // Method untuk mendapatkan usia dari tanggal lahir (jika tidak dari backend)
  int? get calculatedUsia {
    if (tanggalLahir == null) return null;
    final now = DateTime.now();
    int age = now.year - tanggalLahir!.year;
    final monthDiff = now.month - tanggalLahir!.month;
    if (monthDiff < 0 || (monthDiff == 0 && now.day < tanggalLahir!.day)) {
      age--;
    }
    return age;
  }

  // Method untuk mendapatkan usia (prioritaskan dari backend)
  int? get getUsia => usia ?? calculatedUsia;

  // Method untuk mendapatkan status verifikasi KK (prioritaskan dari backend)
  String get getKkVerificationStatus {
    return kkVerificationStatus ??
        (isVerified == true
            ? 'verified'
            : kkRejectionReason != null
            ? 'rejected'
            : kkFile != null
            ? 'pending_review'
            : 'not_uploaded');
  }

  // Method untuk cek apakah user adalah admin
  bool get isAdmin =>
      role?.toLowerCase() == 'admin' || role?.toLowerCase() == 'super_admin';

  // Method untuk cek apakah user adalah super admin
  bool get isSuperAdmin => role?.toLowerCase() == 'super_admin';

  // Method untuk cek apakah user aktif
  bool get isUserActive => isActive ?? true;

  // Method untuk format tanggal lahir
  String? get formattedTanggalLahir {
    if (tanggalLahir == null) return null;
    return '${tanggalLahir!.day}/${tanggalLahir!.month}/${tanggalLahir!.year}';
  }

  // Method untuk format tanggal bergabung
  String? get formattedJoinDate {
    if (createdAt == null) return null;
    return '${createdAt!.day}/${createdAt!.month}/${createdAt!.year}';
  }

  // Method untuk cek apakah profil lengkap
  bool get isProfileComplete {
    return namaLengkap != null &&
        namaLengkap!.isNotEmpty &&
        nik != null &&
        nik!.isNotEmpty &&
        nomorTelepon != null &&
        nomorTelepon!.isNotEmpty &&
        alamat != null &&
        alamat!.isNotEmpty;
  }

  // Method untuk mendapatkan persentase kelengkapan profil
  double get profileCompletionPercentage {
    int completedFields = 0;
    int totalFields = 6; // nama, email, nik, telepon, alamat, foto

    if (namaLengkap != null && namaLengkap!.isNotEmpty) completedFields++;
    if (email.isNotEmpty) completedFields++;
    if (nik != null && nik!.isNotEmpty) completedFields++;
    if (nomorTelepon != null && nomorTelepon!.isNotEmpty) completedFields++;
    if (alamat != null && alamat!.isNotEmpty) completedFields++;
    if (fotoProfil != null && fotoProfil!.isNotEmpty) completedFields++;

    return completedFields / totalFields;
  }
}

// Model lainnya tetap sama...

class AuthResponse {
  final String message;
  final User? user;
  final String? accessToken;
  final String? refreshToken;

  AuthResponse({
    required this.message,
    this.user,
    this.accessToken,
    this.refreshToken,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      message: json['message']?.toString() ?? 'Success',
      user: json['user'] != null ? User.fromJson(json['user']) : null,
      accessToken:
          json['accessToken']?.toString() ?? json['access_token']?.toString(),
      refreshToken:
          json['refreshToken']?.toString() ?? json['refresh_token']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'message': message,
      'user': user?.toJson(),
      'accessToken': accessToken,
      'refreshToken': refreshToken,
    };
  }
}

class OtpResponse {
  final String message;
  final String? otpCode;
  final DateTime? otpExpire;

  OtpResponse({required this.message, this.otpCode, this.otpExpire});

  factory OtpResponse.fromJson(Map<String, dynamic> json) {
    return OtpResponse(
      message: json['message']?.toString() ?? 'OTP sent successfully',
      otpCode: json['otpCode']?.toString(),
      otpExpire: json['otpExpire'] != null
          ? DateTime.tryParse(json['otpExpire'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'message': message,
      'otpCode': otpCode,
      'otpExpire': otpExpire?.toIso8601String(),
    };
  }
}

// Model untuk response profile update
class ProfileUpdateResponse {
  final String message;
  final User user;

  ProfileUpdateResponse({required this.message, required this.user});

  factory ProfileUpdateResponse.fromJson(Map<String, dynamic> json) {
    return ProfileUpdateResponse(
      message: json['message']?.toString() ?? 'Profile updated successfully',
      user: User.fromJson(json['user']),
    );
  }

  Map<String, dynamic> toJson() {
    return {'message': message, 'user': user.toJson()};
  }
}

// Model untuk response KK verification status
class KKVerificationResponse {
  final String kkVerificationStatus;
  final bool hasKKDocument;
  final String? kkFile;
  final String? kkRejectionReason;
  final DateTime? kkVerifiedAt;
  final String? kkVerifiedBy;

  KKVerificationResponse({
    required this.kkVerificationStatus,
    required this.hasKKDocument,
    this.kkFile,
    this.kkRejectionReason,
    this.kkVerifiedAt,
    this.kkVerifiedBy,
  });

  factory KKVerificationResponse.fromJson(Map<String, dynamic> json) {
    return KKVerificationResponse(
      kkVerificationStatus:
          json['kkVerificationStatus']?.toString() ?? 'no_document',
      hasKKDocument: json['hasKKDocument'] ?? false,
      kkFile: json['kkFile']?.toString(),
      kkRejectionReason: json['kkRejectionReason']?.toString(),
      kkVerifiedAt: json['kkVerifiedAt'] != null
          ? DateTime.tryParse(json['kkVerifiedAt'].toString())
          : null,
      kkVerifiedBy: json['kkVerifiedBy']?.toString(),
    );
  }
}

// Model untuk response dashboard stats
class DashboardStatsResponse {
  final int totalReports;
  final int totalActivities;
  final int totalDonations;
  final String verifiedStatus;
  final DateTime? verificationDate;

  DashboardStatsResponse({
    required this.totalReports,
    required this.totalActivities,
    required this.totalDonations,
    required this.verifiedStatus,
    this.verificationDate,
  });

  factory DashboardStatsResponse.fromJson(Map<String, dynamic> json) {
    return DashboardStatsResponse(
      totalReports: json['totalReports'] ?? 0,
      totalActivities: json['totalActivities'] ?? 0,
      totalDonations: json['totalDonations'] ?? 0,
      verifiedStatus: json['verifiedStatus']?.toString() ?? 'not_verified',
      verificationDate: json['verificationDate'] != null
          ? DateTime.tryParse(json['verificationDate'].toString())
          : null,
    );
  }
}
