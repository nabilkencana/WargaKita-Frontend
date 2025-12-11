// profile_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_latihan1/screens/login_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/user_model.dart';
import '../services/profile_service.dart';
import '../services/auth_service.dart';
import '../widget/flutter_pdfview.dart';

class ProfileScreen extends StatefulWidget {
  final User user;

  const ProfileScreen({super.key, required this.user});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late User _currentUser;
  bool _isLoading = false;
  Map<String, dynamic>? _kkStatus;
  bool _isUpdatingProfile = false;
  bool _isUploadingKK = false; // Tambahkan ini

  @override
  void initState() {
    super.initState();
    _currentUser = widget.user;
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      setState(() => _isLoading = true);

      print('🔄 Loading user profile data...');

      // Load user profile data
      final profileData = await ProfileService.getProfile();
      print('📊 Raw profile data: $profileData');

      // Cek apakah data user ada di root atau nested
      if (profileData['user'] != null) {
        print('✅ Found user in nested "user" field');
        setState(() {
          _currentUser = User.fromJson(profileData['user']);
        });
      } else if (profileData['id'] != null) {
        print('✅ Found user in root object');
        setState(() {
          _currentUser = User.fromJson(profileData);
        });
      } else {
        print('⚠️ No user data found in response');
      }

      // Load KK verification status
      try {
        final kkData = await ProfileService.getKKVerificationStatus();
        setState(() => _kkStatus = kkData);
      } catch (e) {
        print('⚠️ Error loading KK status: $e');
        _kkStatus = null;
      }

      // Load dashboard stats
      try {
        await ProfileService.getDashboardStats();
      } catch (e) {
        print('⚠️ Error loading dashboard stats: $e');
      }

      print('✅ Profile data loaded successfully');
      print('   Name: ${_currentUser.namaLengkap}');
      print('   Email: ${_currentUser.email}');
      print('   Phone: ${_currentUser.nomorTelepon}');
      print('   Address: ${_currentUser.alamat}');
    } catch (e) {
      print('❌ Error loading profile data: $e');
      _showErrorSnackbar('Gagal memuat data profil: ${e.toString()}');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickAndUploadImage() async {
    final picker = ImagePicker();

    try {
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85, // Kompresi kualitas gambar
        maxWidth: 800, // Batas lebar maksimal
        maxHeight: 800, // Batas tinggi maksimal
      );

      if (pickedFile != null) {
        setState(() => _isLoading = true);

        final file = File(pickedFile.path);

        // Validasi ukuran file (max 5MB)
        final fileSize = await file.length();
        if (fileSize > 5 * 1024 * 1024) {
          _showErrorSnackbar('Ukuran file maksimal 5MB');
          setState(() => _isLoading = false);
          return;
        }

        // Validasi tipe file berdasarkan ekstensi
        final fileExtension = pickedFile.path.split('.').last.toLowerCase();
        if (!['jpg', 'jpeg', 'png'].contains(fileExtension)) {
          _showErrorSnackbar(
            'Format file tidak didukung. Gunakan JPG, JPEG, atau PNG',
          );
          setState(() => _isLoading = false);
          return;
        }

        // Baca file sebagai bytes
        final bytes = await file.readAsBytes();

        // Tentukan nama file yang aman
        final safeFileName =
            'profile_${_currentUser.id}_${DateTime.now().millisecondsSinceEpoch}.$fileExtension';

        // Upload ke server
        final result = await ProfileService.uploadProfilePicture(
          bytes,
          safeFileName,
        );

        if (result['user'] != null) {
          // Perbarui user dari response
          final updatedUserData = result['user'];
          if (updatedUserData != null) {
            setState(() {
              _currentUser = User.fromJson({
                ..._currentUser.toJson(),
                ...updatedUserData,
              });
            });
            _showSuccessSnackbar('Foto profil berhasil diperbarui');
          } else {
            // Coba refresh profile data
            await _loadUserData();
            _showSuccessSnackbar('Foto profil berhasil diupload');
          }
        } else if (result['message'] != null) {
          _showSuccessSnackbar(result['message']);
        }
      }
    } catch (e) {
      print('❌ Error picking/uploading image: $e');

      // Tampilkan pesan error yang lebih user-friendly
      String errorMessage = 'Gagal mengupload foto';
      if (e.toString().contains('Format file tidak didukung')) {
        errorMessage = 'Format file tidak didukung. Gunakan JPG atau PNG';
      } else if (e.toString().contains('Ukuran file')) {
        errorMessage = 'Ukuran file terlalu besar. Maksimal 5MB';
      } else if (e.toString().contains('Sesi telah berakhir')) {
        errorMessage = 'Sesi telah berakhir, silakan login kembali';
        // Arahkan ke login
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      }

      _showErrorSnackbar(errorMessage);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: _isLoading
            ? _buildLoading()
            : Column(
                children: [
                  // Header dengan tombol back
                  _buildHeader(),

                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: ListView(
                        physics: const BouncingScrollPhysics(),
                        children: [
                          // Info KK Verification jika ada
                          if (_kkStatus != null) _buildKKVerificationCard(),
                          if (_kkStatus != null) const SizedBox(height: 20),

                          // Menu Profil
                          _buildMenuSection('Akun Saya', [
                            _buildMenuTile(
                              Icons.person_outline,
                              'Edit Profil',
                              'Ubah informasi profil Anda',
                              Icons.arrow_forward_ios,
                              () => _showEditProfileDialog(context),
                            ),
                            _buildMenuTile(
                              Icons.security_outlined,
                              'Keamanan Akun',
                              'Pengaturan keamanan akun',
                              Icons.arrow_forward_ios,
                              () => _showSecuritySettings(context),
                            ),
                            _buildMenuTile(
                              Icons.notifications_outlined,
                              'Notifikasi',
                              'Kelola notifikasi aplikasi',
                              Icons.arrow_forward_ios,
                              () => _showNotificationSettings(context),
                            ),
                            _buildMenuTile(
                              Icons.photo_camera_outlined,
                              'Ubah Foto Profil',
                              'Ganti foto profil Anda',
                              Icons.arrow_forward_ios,
                              _pickAndUploadImage,
                            ),
                          ]),

                          const SizedBox(height: 24),

                          // Informasi Personal
                          _buildPersonalInfoSection(),

                          const SizedBox(height: 24),

                          // Lainnya
                          _buildMenuSection('Lainnya', [
                            _buildMenuTile(
                              Icons.help_outline,
                              'Bantuan & Dukungan',
                              'Dapatkan bantuan dan support',
                              Icons.arrow_forward_ios,
                              () => _showHelpSupport(context),
                            ),
                            _buildMenuTile(
                              Icons.privacy_tip_outlined,
                              'Kebijakan Privasi',
                              'Baca kebijakan privasi kami',
                              Icons.arrow_forward_ios,
                              () => _showPrivacyPolicy(context),
                            ),
                            _buildMenuTile(
                              Icons.description_outlined,
                              'Syarat & Ketentuan',
                              'Ketentuan penggunaan aplikasi',
                              Icons.arrow_forward_ios,
                              () => _showTermsConditions(context),
                            ),
                            _buildMenuTile(
                              Icons.star_outline,
                              'Beri Rating',
                              'Beri nilai untuk aplikasi kami',
                              Icons.arrow_forward_ios,
                              () => _showRatingDialog(context),
                            ),
                          ]),

                          const SizedBox(height: 40),

                          // Tombol Home dan Logout
                          Row(
                            children: [
                              // Tombol Home
                              Expanded(
                                child: Container(
                                  margin: const EdgeInsets.only(right: 8),
                                  child: ElevatedButton(
                                    onPressed: () => Navigator.pop(context),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.grey.shade100,
                                      foregroundColor: Colors.blue.shade700,
                                      elevation: 2,
                                      minimumSize: const Size(
                                        double.infinity,
                                        50,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        side: BorderSide(
                                          color: Colors.blue.shade200,
                                        ),
                                      ),
                                    ),
                                    child: const Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.home, size: 20),
                                        SizedBox(width: 8),
                                        Text('Beranda'),
                                      ],
                                    ),
                                  ),
                                ),
                              ),

                              // Tombol Logout
                              Expanded(
                                child: Container(
                                  margin: const EdgeInsets.only(left: 8),
                                  child: ElevatedButton(
                                    onPressed: () => _showLogoutDialog(context),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red.shade50,
                                      foregroundColor: Colors.red,
                                      elevation: 2,
                                      minimumSize: const Size(
                                        double.infinity,
                                        50,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        side: BorderSide(
                                          color: Colors.red.shade200,
                                        ),
                                      ),
                                    ),
                                    child: const Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.logout, size: 20),
                                        SizedBox(width: 8),
                                        Text('Keluar'),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 20),

                          // Version Info
                          Center(
                            child: Text(
                              'Versi 1.0.0',
                              style: TextStyle(
                                color: Colors.grey.shade500,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildLoading() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 20),
          Text('Memuat data profil...'),
        ],
      ),
    );
  }

  // Helper untuk cek kelengkapan profil
  int _getProfileCompletionPercentage() {
    int completedFields = 0;
    int totalFields = 8; // Jumlah field yang dianggap penting

    // Field yang dianggap penting untuk kelengkapan profil
    if (_currentUser.namaLengkap?.isNotEmpty == true) completedFields++;
    if (_currentUser.nomorTelepon?.isNotEmpty == true) completedFields++;
    if (_currentUser.alamat?.isNotEmpty == true) completedFields++;
    if (_currentUser.kota?.isNotEmpty == true) completedFields++;
    if (_currentUser.rtRw?.isNotEmpty == true) completedFields++;
    if (_currentUser.nik?.isNotEmpty == true) completedFields++;
    if (_currentUser.tempatLahir?.isNotEmpty == true) completedFields++;
    if (_currentUser.kodePos?.isNotEmpty == true) completedFields++;

    return (completedFields / totalFields * 100).round();
  }

  // Tambahkan di header untuk menunjukkan progress
  Widget _buildHeader() {
    final completionPercentage = _getProfileCompletionPercentage();

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade700, Colors.blue.shade500],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.shade200.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        children: [
          // Tombol Back dan Judul
          Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Profil Saya',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Profile Picture dengan efek shadow
          GestureDetector(
            onTap: _pickAndUploadImage,
            child: Stack(
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 4),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.shade800.withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                    gradient: LinearGradient(
                      colors: [Colors.white, Colors.blue.shade100],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: _currentUser.fotoProfil != null
                      ? ClipOval(
                          child: Image.network(
                            _currentUser.fotoProfil!,
                            fit: BoxFit.cover,
                            width: 100,
                            height: 100,
                            errorBuilder: (context, error, stackTrace) {
                              return Icon(
                                Icons.person,
                                color: Colors.blue.shade600,
                                size: 50,
                              );
                            },
                          ),
                        )
                      : Icon(
                          Icons.person,
                          color: Colors.blue.shade600,
                          size: 50,
                        ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade600,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(
                      Icons.camera_alt,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Nama Pengguna
          Text(
            _currentUser.namaLengkap ?? 'Nama Pengguna',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),

          // Email
          Text(
            _currentUser.email,
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),

          // Badge Role dan Status Verifikasi
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.3)),
                ),
                child: Text(
                  _currentUser.role?.toUpperCase() ?? 'WARGA',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _currentUser.isVerified == true
                      ? Colors.green.withOpacity(0.2)
                      : Colors.orange.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _currentUser.isVerified == true
                        ? Colors.green.withOpacity(0.3)
                        : Colors.orange.withOpacity(0.3),
                  ),
                ),
                child: Text(
                  _currentUser.isVerified == true
                      ? 'TERVERIFIKASI'
                      : 'BELUM TERVERIFIKASI',
                  style: TextStyle(
                    color: _currentUser.isVerified == true
                        ? Colors.green.shade100
                        : Colors.orange.shade100,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          // Progress bar kelengkapan profil
          if (completionPercentage < 100) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Kelengkapan Profil',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        '$completionPercentage%',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: completionPercentage / 100,
                    backgroundColor: Colors.white.withOpacity(0.2),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      completionPercentage >= 80
                          ? Colors.green.shade300
                          : completionPercentage >= 50
                          ? Colors.orange.shade300
                          : Colors.red.shade300,
                    ),
                    borderRadius: BorderRadius.circular(4),
                    minHeight: 6,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    completionPercentage < 50
                        ? 'Lengkapi profil Anda untuk pengalaman terbaik'
                        : completionPercentage < 80
                        ? 'Profil hampir lengkap'
                        : 'Profil sudah lengkap!',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildKKVerificationCard() {
    if (_kkStatus == null) return const SizedBox();

    final status = _kkStatus!['kkVerificationStatus'] ?? 'not_uploaded';

    Color statusColor;
    String statusText;
    IconData statusIcon;
    List<Widget> actions = [];

    switch (status) {
      case 'verified':
        statusColor = Colors.green;
        statusText = 'KK Terverifikasi';
        statusIcon = Icons.verified;
        actions = [
          IconButton(
            icon: const Icon(Icons.visibility, size: 20),
            onPressed: () => _viewKKDocument(context),
          ),
        ];
        break;
      case 'rejected':
        statusColor = Colors.red;
        statusText = 'KK Ditolak';
        statusIcon = Icons.error_outline;
        actions = [
          IconButton(
            icon: const Icon(Icons.visibility, size: 20),
            onPressed: () => _viewKKDocument(context),
          ),
          IconButton(
            icon: const Icon(Icons.edit, size: 20),
            onPressed: () => _showUploadKKDialog(context),
          ),
        ];
        break;
      case 'pending_review':
        statusColor = Colors.orange;
        statusText = 'Menunggu Verifikasi';
        statusIcon = Icons.pending;
        actions = [
          IconButton(
            icon: const Icon(Icons.visibility, size: 20),
            onPressed: () => _viewKKDocument(context),
          ),
        ];
        break;
      default:
        statusColor = Colors.grey;
        statusText = 'Belum Upload KK';
        statusIcon = Icons.upload_file;
        actions = [
          IconButton(
            icon: const Icon(Icons.upload, size: 20),
            onPressed: () => _showUploadKKDialog(context),
          ),
        ];
    }

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: statusColor.withOpacity(0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: ListTile(
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(statusIcon, color: statusColor),
          ),
          title: Text(
            'Dokumen KK',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade800,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(statusText),
              if (status == 'rejected' &&
                  _kkStatus!['kkRejectionReason'] != null)
                Text(
                  'Alasan: ${_kkStatus!['kkRejectionReason']}',
                  style: TextStyle(color: Colors.red.shade600, fontSize: 12),
                ),
            ],
          ),
          trailing: Row(mainAxisSize: MainAxisSize.min, children: actions),
          onTap: () => _showKKStatusDetail(context),
        ),
      ),
    );
  }

  Future<void> _uploadKKDocument(BuildContext context) async {
    final picker = ImagePicker();

    try {
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1200,
        maxHeight: 1200,
      );

      if (pickedFile != null) {
        setState(() => _isUploadingKK = true);

        final file = File(pickedFile.path);

        // Validasi ukuran file (max 5MB)
        final fileSize = await file.length();
        if (fileSize > 5 * 1024 * 1024) {
          _showErrorSnackbar('Ukuran file maksimal 5MB');
          setState(() => _isUploadingKK = false);
          return;
        }

        // Validasi tipe file
        final fileExtension = pickedFile.path.split('.').last.toLowerCase();
        if (!['jpg', 'jpeg', 'png', 'pdf'].contains(fileExtension)) {
          _showErrorSnackbar(
            'Format file tidak didukung. Gunakan JPG, JPEG, PNG, atau PDF',
          );
          setState(() => _isUploadingKK = false);
          return;
        }

        // Baca file sebagai bytes
        final bytes = await file.readAsBytes();

        // Tentukan nama file yang aman
        final safeFileName =
            'kk_${_currentUser.id}_${DateTime.now().millisecondsSinceEpoch}.$fileExtension';

        try {
          // Upload ke server menggunakan ProfileService
          final result = await ProfileService.uploadKKDocument(
            bytes,
            safeFileName,
          );

          if (result['kkVerificationStatus'] != null) {
            // Perbarui status KK
            setState(() {
              _kkStatus = {
                'kkVerificationStatus': result['kkVerificationStatus'],
                'kkRejectionReason': result['rejectionReason'],
                'kkVerifiedAt': result['verifiedAt'],
                'kkVerifiedBy': result['verifiedBy'],
              };
            });

            _showSuccessSnackbar('Dokumen KK berhasil diupload');
            Navigator.pop(context); // Tutup dialog
          } else {
            _showErrorSnackbar('Gagal mengupload dokumen KK');
          }
        } catch (e) {
          print('❌ Error uploading KK document: $e');
          _showErrorSnackbar('Gagal mengupload: ${e.toString()}');
        }
      }
    } catch (e) {
      print('❌ Error picking file: $e');
      _showErrorSnackbar('Gagal memilih file: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _isUploadingKK = false);
      }
    }
  }

  void _viewKKDocument(BuildContext context) async {
    if (_kkStatus == null ||
        _kkStatus!['kkVerificationStatus']?.toString() == 'not_uploaded') {
      _showErrorSnackbar('Belum ada dokumen KK yang diupload');
      return;
    }

    try {
      setState(() => _isLoading = true);

      // Ambil URL dokumen KK dari server
      final kkData = await ProfileService.getKKDocument();

      if (kkData['kkFile'] != null && kkData['kkFile'].isNotEmpty) {
        final kkUrl = kkData['kkFile'];

        // Buka viewer untuk dokumen KK
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => Scaffold(
              backgroundColor: Colors.grey.shade900,
              appBar: AppBar(
                title: const Text(
                  'Dokumen KK',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                backgroundColor: Colors.blue.shade700,
                foregroundColor: Colors.white,
                elevation: 4,
                shadowColor: Colors.blue.shade900.withOpacity(0.3),
                centerTitle: true,
                actions: [
                  // Share Button
                  IconButton(
                    icon: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.share, size: 20),
                    ),
                    onPressed: () => _shareKKDocument(kkUrl),
                  ),

                  // Download Button
                  IconButton(
                    icon: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.download_rounded, size: 20),
                    ),
                    onPressed: () => _downloadKKDocument(kkUrl),
                    tooltip: 'Download Dokumen',
                  ),

                  // More Options Button
                  PopupMenuButton<String>(
                    icon: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.more_vert, size: 20),
                    ),
                    color: Colors.white,
                    surfaceTintColor: Colors.white,
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    onSelected: (value) {
                      if (value == 'print') {
                        _printKKDocument(kkUrl);
                      } else if (value == 'info') {
                        _showDocumentInfo(context, kkUrl);
                      } else if (value == 'rotate') {
                        // Implement rotate functionality
                        _showSuccessSnackbar('Rotate fitur akan datang');
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem<String>(
                        value: 'print',
                        child: Row(
                          children: [
                            Icon(
                              Icons.print_rounded,
                              color: Colors.blue.shade700,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            const Text('Print Dokumen'),
                          ],
                        ),
                      ),
                      PopupMenuItem<String>(
                        value: 'rotate',
                        child: Row(
                          children: [
                            Icon(
                              Icons.rotate_90_degrees_ccw,
                              color: Colors.blue.shade700,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            const Text('Rotate Gambar'),
                          ],
                        ),
                      ),
                      PopupMenuItem<String>(
                        value: 'info',
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline_rounded,
                              color: Colors.blue.shade700,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            const Text('Info Dokumen'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              body: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.grey.shade900, Colors.grey.shade800],
                  ),
                ),
                child: Column(
                  children: [
                    // Document Status Bar
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50.withOpacity(0.1),
                        border: Border(
                          bottom: BorderSide(
                            color: Colors.grey.shade700,
                            width: 1,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.verified_rounded,
                            color: Colors.green.shade400,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Dokumen Terverifikasi',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            _getFileSizeInfo(kkUrl),
                            style: TextStyle(
                              color: Colors.grey.shade400,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Main Content
                    Expanded(
                      child: Stack(
                        children: [
                          // Document Viewer
                          Center(
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.4),
                                    blurRadius: 20,
                                    spreadRadius: 2,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              margin: const EdgeInsets.all(20),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: kkUrl.toLowerCase().endsWith('.pdf')
                                    ? PdfViewer(url: kkUrl)
                                    : _buildImageViewer(kkUrl),
                              ),
                            ),
                          ),

                          // Zoom Controls (only for images)
                          if (!kkUrl.toLowerCase().endsWith('.pdf'))
                            Positioned(
                              bottom: 30,
                              right: 20,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.7),
                                  borderRadius: BorderRadius.circular(30),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.5),
                                      blurRadius: 15,
                                      offset: const Offset(0, 5),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    IconButton(
                                      icon: Container(
                                        width: 44,
                                        height: 44,
                                        decoration: BoxDecoration(
                                          color: Colors.blue.shade600,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.remove,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                      ),
                                      onPressed: () {
                                        // Implement zoom out
                                        _showSuccessSnackbar('Zoom out');
                                      },
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: const Text(
                                        '100%',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: Container(
                                        width: 44,
                                        height: 44,
                                        decoration: BoxDecoration(
                                          color: Colors.blue.shade600,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.add,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                      ),
                                      onPressed: () {
                                        // Implement zoom in
                                        _showSuccessSnackbar('Zoom in');
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ),

                          // Navigation Controls (only for PDF)
                          if (kkUrl.toLowerCase().endsWith('.pdf'))
                            Positioned(
                              left: 20,
                              right: 20,
                              bottom: 100,
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  FloatingActionButton.small(
                                    heroTag: 'prev',
                                    backgroundColor: Colors.black.withOpacity(
                                      0.7,
                                    ),
                                    foregroundColor: Colors.white,
                                    child: const Icon(
                                      Icons.arrow_back_ios_rounded,
                                      size: 16,
                                    ),
                                    onPressed: () {
                                      // Navigate to previous page
                                      _showSuccessSnackbar(
                                        'Halaman sebelumnya',
                                      );
                                    },
                                  ),
                                  FloatingActionButton.small(
                                    heroTag: 'next',
                                    backgroundColor: Colors.black.withOpacity(
                                      0.7,
                                    ),
                                    foregroundColor: Colors.white,
                                    child: const Icon(
                                      Icons.arrow_forward_ios_rounded,
                                      size: 16,
                                    ),
                                    onPressed: () {
                                      // Navigate to next page
                                      _showSuccessSnackbar(
                                        'Halaman berikutnya',
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),

                    // Bottom Info Bar
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.2),
                        border: Border(
                          top: BorderSide(
                            color: Colors.grey.shade700,
                            width: 1,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.lock_clock_rounded,
                            color: Colors.grey.shade400,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Terakhir diakses: ${_formatLastAccessTime()}',
                            style: TextStyle(
                              color: Colors.grey.shade400,
                              fontSize: 12,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: Icon(
                              Icons.fullscreen_rounded,
                              color: Colors.blue.shade400,
                              size: 20,
                            ),
                            onPressed: () {
                              // Toggle fullscreen
                              _showSuccessSnackbar('Mode layar penuh');
                            },
                            tooltip: 'Mode Layar Penuh',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Floating Action Button for Quick Actions
              floatingActionButton: FloatingActionButton(
                backgroundColor: Colors.blue.shade600,
                foregroundColor: Colors.white,
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.download_for_offline_rounded),
                onPressed: () => _downloadKKDocument(kkUrl),
                tooltip: 'Download Dokumen',
              ),
            ),
          ),
        );
      } else {
        _showErrorSnackbar('Dokumen KK tidak ditemukan');
      }
    } catch (e) {
      print('❌ Error viewing KK document: $e');
      _showErrorSnackbar('Gagal memuat dokumen KK: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Helper method untuk image viewer
  Widget _buildImageViewer(String url) {
    return InteractiveViewer(
      minScale: 0.5,
      maxScale: 3.0,
      child: Center(
        child: Image.network(
          url,
          fit: BoxFit.contain,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                color: Colors.grey.shade800,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator.adaptive(
                    value: loadingProgress.expectedTotalBytes != null
                        ? loadingProgress.cumulativeBytesLoaded /
                              loadingProgress.expectedTotalBytes!
                        : null,
                    backgroundColor: Colors.grey.shade700,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Colors.blue.shade400,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (loadingProgress.expectedTotalBytes != null)
                    Text(
                      '${(loadingProgress.cumulativeBytesLoaded / 1024 / 1024).toStringAsFixed(1)} MB / '
                      '${(loadingProgress.expectedTotalBytes! / 1024 / 1024).toStringAsFixed(1)} MB',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  const SizedBox(height: 8),
                  Text(
                    'Memuat dokumen...',
                    style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                  ),
                ],
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            return Container(
              width: double.infinity,
              height: 300,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.grey.shade800, Colors.grey.shade900],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.red.shade900.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.error_outline_rounded,
                      color: Colors.red.shade400,
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Gagal Memuat Dokumen',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Text(
                      'Dokumen tidak dapat dimuat. Silakan coba lagi atau hubungi administrator.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () {
                          // Retry loading
                          Navigator.pop(context);
                          _viewKKDocument(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text('Coba Lagi'),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Colors.grey.shade600),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: const Icon(Icons.arrow_back_rounded, size: 18),
                        label: const Text('Kembali'),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // Helper method untuk mendapatkan info file size
  String _getFileSizeInfo(String url) {
    // Extract file extension
    final extension = url.split('.').last.toLowerCase();

    if (extension == 'pdf') {
      return 'PDF Document';
    } else if (['jpg', 'jpeg', 'png'].contains(extension)) {
      return 'Image File';
    } else {
      return 'Unknown Format';
    }
  }

  // Helper method untuk format waktu
  String _formatLastAccessTime() {
    final now = DateTime.now();
    return '${now.day}/${now.month}/${now.year} ${now.hour}:${now.minute.toString().padLeft(2, '0')}';
  }

  // Tambahkan fungsi-fungsi helper ini di class yang sama:

  Future<void> _shareKKDocument(String url) async {
    try {
      // Implement share functionality
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url));
      } else {
        _showSuccessSnackbar('Berhasil membagikan dokumen');
      }
    } catch (e) {
      print('❌ Error sharing document: $e');
      _showErrorSnackbar('Gagal membagikan dokumen');
    }
  }

  Future<void> _printKKDocument(String url) async {
    // Implement print functionality
    _showSuccessSnackbar('Mempersiapkan dokumen untuk dicetak...');
  }

  void _showDocumentInfo(BuildContext context, String url) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(30),
              topRight: Radius.circular(30),
            ),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 60,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Informasi Dokumen',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 20),
              _buildDocumentInfoRow(
                'Nama File',
                'kartu_keluarga.${url.split('.').last}',
              ),
              _buildDocumentInfoRow(
                'Format',
                url.split('.').last.toUpperCase(),
              ),
              _buildDocumentInfoRow('Status', 'Terverifikasi'),
              _buildDocumentInfoRow('Tanggal Akses', _formatLastAccessTime()),
              if (_kkStatus?['kkVerifiedAt'] != null)
                _buildDocumentInfoRow(
                  'Tanggal Verifikasi',
                  _kkStatus!['kkVerifiedAt']?.toString().split('T')[0] ?? '-',
                ),
              if (_kkStatus?['kkVerifiedBy'] != null)
                _buildDocumentInfoRow(
                  'Diverifikasi oleh',
                  _kkStatus!['kkVerifiedBy']?.toString() ?? '-',
                ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade600,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Tutup'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDocumentInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _downloadKKDocument(String url) async {
    try {
      // Implementasi download menggunakan package flutter_downloader atau lainnya
      _showSuccessSnackbar('Memulai download dokumen KK...');

      // Contoh sederhana dengan package url_launcher
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url));
      } else {
        _showErrorSnackbar('Tidak dapat membuka dokumen');
      }
    } catch (e) {
      print('❌ Error downloading KK document: $e');
      _showErrorSnackbar('Gagal mendownload dokumen');
    }
  }

  void _showUploadKKDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: !_isUploadingKK,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: Colors.grey.shade200),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.description,
                            color: Colors.blue.shade600,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Upload Dokumen KK',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Content
                  Column(
                    children: [
                      Icon(
                        Icons.cloud_upload,
                        color: Colors.blue.shade400,
                        size: 60,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Upload Kartu Keluarga (KK)',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'Format: JPG, PNG, atau PDF\nMaksimal: 5MB\nPastikan foto jelas dan terbaca',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Loading atau Tombol
                  _isUploadingKK
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: CircularProgressIndicator(),
                        )
                      : Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => Navigator.pop(context),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  side: BorderSide(color: Colors.grey.shade300),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: Text(
                                  'Batal',
                                  style: TextStyle(
                                    color: Colors.grey.shade700,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () => _uploadKKDocument(context),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue.shade600,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.upload, size: 18),
                                    SizedBox(width: 8),
                                    Text('Upload'),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPersonalInfoSection() {
    // Cek apakah data personal sudah lengkap
    final hasPersonalInfo =
        (_currentUser.nik?.isNotEmpty ?? false) ||
        (_currentUser.tanggalLahir != null) ||
        (_currentUser.tempatLahir?.isNotEmpty ?? false) ||
        (_currentUser.nomorTelepon?.isNotEmpty ?? false) ||
        (_currentUser.alamat?.isNotEmpty ?? false) ||
        (_currentUser.kota?.isNotEmpty ?? false) ||
        (_currentUser.rtRw?.isNotEmpty ?? false) ||
        (_currentUser.kodePos?.isNotEmpty ?? false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 8),
          child: Row(
            children: [
              Text(
                'Informasi Personal',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.blue.shade800,
                ),
              ),
              if (!hasPersonalInfo) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Text(
                    'Belum lengkap',
                    style: TextStyle(
                      color: Colors.orange.shade700,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        Card(
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              _buildInfoRow('NIK', _currentUser.nik ?? 'Belum diisi'),
              _buildInfoRow(
                'Tanggal Lahir',
                _currentUser.tanggalLahir != null
                    ? _formatDate(_currentUser.tanggalLahir)
                    : 'Belum diisi',
              ),
              _buildInfoRow(
                'Tempat Lahir',
                _currentUser.tempatLahir?.isNotEmpty == true
                    ? _currentUser.tempatLahir!
                    : 'Belum diisi',
              ),
              _buildInfoRow(
                'Nomor Telepon',
                _currentUser.nomorTelepon?.isNotEmpty == true
                    ? _currentUser.nomorTelepon!
                    : 'Belum diisi',
              ),
              _buildInfoRow(
                'Alamat',
                _currentUser.alamat?.isNotEmpty == true
                    ? _currentUser.alamat!
                    : 'Belum diisi',
              ),
              _buildInfoRow(
                'RT/RW',
                _currentUser.rtRw?.isNotEmpty == true
                    ? _currentUser.rtRw!
                    : 'Belum diisi',
              ),
              _buildInfoRow(
                'Kota',
                _currentUser.kota?.isNotEmpty == true
                    ? _currentUser.kota!
                    : 'Belum diisi',
              ),
              _buildInfoRow(
                'Kode Pos',
                _currentUser.kodePos?.isNotEmpty == true
                    ? _currentUser.kodePos!
                    : 'Belum diisi',
              ),
            ],
          ),
        ),

        // Tombol edit jika data belum lengkap
        if (!hasPersonalInfo) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _showEditProfileDialog(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.shade50,
                foregroundColor: Colors.orange.shade700,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.orange.shade200),
                ),
              ),
              icon: Icon(Icons.edit, size: 16),
              label: const Text('Lengkapi Informasi Personal'),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    final isEmpty = value.isEmpty || value == 'Belum diisi';

    return Column(
      children: [
        ListTile(
          title: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          subtitle: Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: isEmpty ? Colors.grey.shade500 : Colors.grey.shade800,
            ),
          ),
          trailing: isEmpty
              ? Icon(
                  Icons.error_outline,
                  color: Colors.orange.shade400,
                  size: 18,
                )
              : null,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 4,
          ),
        ),
        Divider(
          height: 1,
          color: Colors.grey.shade100,
          indent: 16,
          endIndent: 16,
        ),
      ],
    );
  }

  Widget _buildMenuSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 8),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.blue.shade800,
            ),
          ),
        ),
        Card(
          elevation: 3,
          shadowColor: Colors.blue.shade50,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildMenuTile(
    IconData leadingIcon,
    String title,
    String subtitle,
    IconData trailingIcon,
    VoidCallback onTap,
  ) {
    return Column(
      children: [
        ListTile(
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.blue.shade100),
            ),
            child: Icon(leadingIcon, color: Colors.blue.shade600, size: 22),
          ),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15),
          ),
          subtitle: Text(
            subtitle,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
          ),
          trailing: Icon(trailingIcon, size: 16, color: Colors.grey.shade400),
          onTap: onTap,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
        ),
        Divider(
          height: 1,
          color: Colors.grey.shade100,
          indent: 16,
          endIndent: 16,
        ),
      ],
    );
  }

  // === FUNGSI UTAMA ===

  void _showEditProfileDialog(BuildContext context) {
    final nameController = TextEditingController(
      text: _currentUser.namaLengkap ?? '',
    );
    final phoneController = TextEditingController(
      text: _currentUser.nomorTelepon ?? '',
    );
    final addressController = TextEditingController(
      text: _currentUser.alamat ?? '',
    );
    final cityController = TextEditingController(text: _currentUser.kota ?? '');
    final rtRwController = TextEditingController(text: _currentUser.rtRw ?? '');
    final kodePosController = TextEditingController(
      text: _currentUser.kodePos ?? '',
    );
    final bioController = TextEditingController(text: _currentUser.bio ?? '');
    final nikController = TextEditingController(text: _currentUser.nik ?? '');
    final tempatLahirController = TextEditingController(
      text: _currentUser.tempatLahir ?? '',
    );

    showDialog(
      context: context,
      barrierDismissible:
          !_isUpdatingProfile, // Tidak bisa ditutup saat loading
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            insetPadding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.9,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header dengan background gradient dan tombol close
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 20,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.blue.shade700, Colors.blue.shade500],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.person,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'Edit Profil',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 24,
                          ),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),

                  // Content form
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Field NIK
                          _buildFormField(
                            controller: nikController,
                            label: 'NIK',
                            hintText: '00000000000000000',
                            icon: Icons.badge,
                            keyboardType: TextInputType.number,
                            maxLength: 16,
                          ),
                          const SizedBox(height: 16),

                          // Field Tempat Lahir
                          _buildFormField(
                            controller: tempatLahirController,
                            label: 'Tempat Lahir',
                            hintText: 'Malang',
                            icon: Icons.place,
                          ),
                          const SizedBox(height: 16),

                          // Field Nomor Telepon (wajib)
                          _buildFormField(
                            controller: phoneController,
                            label: 'Nomor Telepon *',
                            hintText: '085648898807',
                            icon: Icons.phone,
                            keyboardType: TextInputType.phone,
                            isRequired: true,
                          ),
                          const SizedBox(height: 16),

                          // Field Alamat (wajib)
                          _buildFormField(
                            controller: addressController,
                            label: 'Alamat *',
                            hintText: 'Jl. Danau Ranau II',
                            icon: Icons.location_on,
                            maxLines: 2,
                            isRequired: true,
                          ),
                          const SizedBox(height: 16),

                          // Row untuk Kota dan RT/RW
                          Row(
                            children: [
                              Expanded(
                                child: _buildFormField(
                                  controller: cityController,
                                  label: 'Kota',
                                  hintText: 'Malang',
                                  icon: Icons.location_city,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _buildFormField(
                                  controller: rtRwController,
                                  label: 'RT/RW',
                                  hintText: '01/02',
                                  icon: Icons.home,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Field Kode Pos
                          _buildFormField(
                            controller: kodePosController,
                            label: 'Kode Pos',
                            hintText: '65111',
                            icon: Icons.local_post_office,
                            keyboardType: TextInputType.number,
                            maxLength: 5,
                          ),
                          const SizedBox(height: 16),

                          // Field Bio (Opsional)
                          _buildFormField(
                            controller: bioController,
                            label: 'Bio (Opsional)',
                            hintText: 'Ceritakan sedikit tentang diri Anda',
                            icon: Icons.description,
                            maxLines: 3,
                            isOptional: true,
                          ),
                          const SizedBox(height: 24),

                          // Pesan info field wajib
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.blue.shade100),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.info,
                                  color: Colors.blue.shade600,
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Field bertanda * wajib diisi',
                                    style: TextStyle(
                                      color: Colors.blue.shade800,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Footer dengan tombol Batal dan Simpan
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 20,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      border: Border(
                        top: BorderSide(color: Colors.grey.shade200),
                      ),
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(20),
                        bottomRight: Radius.circular(20),
                      ),
                    ),
                    child: _isUpdatingProfile
                        ? Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                CircularProgressIndicator(
                                  color: Colors.blue.shade600,
                                  strokeWidth: 2,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Menyimpan...',
                                  style: TextStyle(
                                    color: Colors.grey.shade700,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : Row(
                            children: [
                              // Tombol Batal
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => Navigator.pop(context),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    side: BorderSide(
                                      color: Colors.grey.shade300,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: Text(
                                    'Batal',
                                    style: TextStyle(
                                      color: Colors.grey.shade700,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(width: 16),

                              // Tombol Simpan
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () async {
                                    // Validasi field wajib
                                    if (nameController.text.trim().isEmpty) {
                                      _showErrorSnackbar(
                                        'Nama lengkap wajib diisi',
                                      );
                                      return;
                                    }

                                    if (phoneController.text.trim().isEmpty) {
                                      _showErrorSnackbar(
                                        'Nomor telepon wajib diisi',
                                      );
                                      return;
                                    }

                                    if (addressController.text.trim().isEmpty) {
                                      _showErrorSnackbar('Alamat wajib diisi');
                                      return;
                                    }

                                    // Set loading state di dialog
                                    setDialogState(
                                      () => _isUpdatingProfile = true,
                                    );

                                    // Buat object update
                                    final updatedUser = _currentUser.copyWith(
                                      name: nameController.text.trim(),
                                      phone: phoneController.text.trim(),
                                      alamat: addressController.text.trim(),
                                      kota: cityController.text.trim(),
                                      rtRw: rtRwController.text.trim(),
                                      kodePos: kodePosController.text.trim(),
                                      bio: bioController.text.trim(),
                                      nik: nikController.text.trim(),
                                      tempatLahir: tempatLahirController.text
                                          .trim(),
                                    );

                                    try {
                                      // Panggil service update profile
                                      final result =
                                          await ProfileService.updateProfile(
                                            updatedUser,
                                          );

                                      // Update state di main screen jika berhasil
                                      if (mounted) {
                                        if (result['user'] != null) {
                                          setState(() {
                                            _currentUser = User.fromJson(
                                              result['user'],
                                            );
                                          });
                                          _showSuccessSnackbar(
                                            'Profil berhasil diperbarui',
                                          );
                                        } else {
                                          _showSuccessSnackbar(
                                            result['message'] ??
                                                'Profil berhasil diperbarui',
                                          );
                                          // Refresh data profil
                                          await _loadUserData();
                                        }
                                      }

                                      // Tutup dialog setelah sukses
                                      if (mounted) Navigator.pop(context);
                                    } catch (e) {
                                      print('❌ Error updating profile: $e');
                                      _showErrorSnackbar(
                                        'Gagal memperbarui profil: ${e.toString()}',
                                      );
                                      // Matikan loading state jika error
                                      if (mounted) {
                                        setDialogState(
                                          () => _isUpdatingProfile = false,
                                        );
                                      }
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue.shade600,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    elevation: 2,
                                  ),
                                  child: const Text(
                                    'Simpan',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // Helper method untuk membuat form field
  Widget _buildFormField({
    required TextEditingController controller,
    required String label,
    required String hintText,
    required IconData icon,
    bool isRequired = false,
    bool isOptional = false,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    int? maxLength,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: TextStyle(color: Colors.grey.shade400),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.blue.shade500, width: 1.5),
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            prefixIcon: Icon(icon, color: Colors.grey.shade500, size: 20),
            suffixIcon: isOptional
                ? Container(
                    padding: const EdgeInsets.all(10),
                    child: Text(
                      'Opsional',
                      style: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 10,
                      ),
                    ),
                  )
                : null,
            isDense: true,
          ),
          keyboardType: keyboardType,
          maxLines: maxLines,
          maxLength: maxLength,
          style: TextStyle(fontSize: 15, color: Colors.grey.shade800),
        ),
        if (isRequired) ...[
          const SizedBox(height: 4),
          Text(
            '* Wajib diisi',
            style: TextStyle(color: Colors.red.shade500, fontSize: 11),
          ),
        ],
      ],
    );
  }

  void _showSecuritySettings(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.6,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.blue.shade600,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 24,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Pengaturan Keamanan',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      _buildSecurityOption(
                        Icons.fingerprint,
                        'Autentikasi Biometrik',
                        'Gunakan sidik jari atau wajah untuk login',
                        _currentUser.biometricData != null,
                        (value) => _toggleBiometricAuth(value),
                      ),
                      const SizedBox(height: 12),
                      _buildSecurityOption(
                        Icons.phone_android,
                        'Verifikasi 2 Langkah',
                        'Tambah keamanan ekstra dengan OTP',
                        _currentUser.twoFactorEnabled ?? false,
                        (value) => _toggleTwoFactorAuth(value),
                      ),
                      const SizedBox(height: 12),
                      _buildSecurityOption(
                        Icons.language,
                        'Bahasa Aplikasi',
                        'Pilih bahasa untuk aplikasi',
                        false,
                        (value) => _showLanguageSettings(context),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSecurityOption(
    IconData icon,
    String title,
    String subtitle,
    bool value,
    Function(bool) onChanged,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.blue.shade600, size: 22),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
        subtitle: Text(subtitle, style: TextStyle(color: Colors.grey.shade600)),
        trailing: title == 'Bahasa Aplikasi'
            ? Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Colors.grey.shade400,
              )
            : Switch(
                value: value,
                onChanged: onChanged,
                activeColor: Colors.blue.shade600,
              ),
        onTap: title == 'Bahasa Aplikasi'
            ? () => _showLanguageSettings(context)
            : null,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    );
  }

  void _toggleBiometricAuth(bool value) {
    // Implement biometric auth toggle
    _showSuccessSnackbar(
      'Autentikasi biometrik ${value ? 'diaktifkan' : 'dinonaktifkan'}',
    );
  }

  void _toggleTwoFactorAuth(bool value) {
    // Implement two-factor auth toggle
    _showSuccessSnackbar(
      'Verifikasi 2 langkah ${value ? 'diaktifkan' : 'dinonaktifkan'}',
    );
  }

  void _showLanguageSettings(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Pilih Bahasa'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildLanguageOption('Indonesia', 'id', '🇮🇩'),
            const SizedBox(height: 12),
            _buildLanguageOption('English', 'en', '🇺🇸'),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageOption(String name, String code, String flag) {
    return ListTile(
      leading: Text(flag, style: const TextStyle(fontSize: 24)),
      title: Text(name),
      trailing: _currentUser.language == code
          ? Icon(Icons.check, color: Colors.blue.shade600)
          : null,
      onTap: () {
        // Update language
        _showSuccessSnackbar('Bahasa diubah ke $name');
        Navigator.pop(context);
      },
    );
  }

  void _showKKStatusDetail(BuildContext context) {
  if (_kkStatus == null || _kkStatus!.isEmpty) {
    _showErrorSnackbar('Data status KK tidak tersedia');
    return;
  }

  final status = _kkStatus?['kkVerificationStatus']?.toString() ?? 'not_uploaded';
  final rejectionReason = _kkStatus?['kkRejectionReason']?.toString();
  final verifiedAt = _kkStatus?['kkVerifiedAt']?.toString();
  _kkStatus?['kkVerifiedBy']?.toString();

  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Detail Verifikasi KK'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildKKDetailItem(
              'Status',
              _getKKStatusText(status),
              color: _getStatusColor(status),
            ),
            
            if (verifiedAt != null && verifiedAt.isNotEmpty)
              _buildKKDetailItem(
                'Diverifikasi pada',
                _formatDateTime(verifiedAt),
              ),
            
            if (rejectionReason != null && rejectionReason.isNotEmpty)
              _buildKKDetailItem(
                'Alasan Penolakan',
                rejectionReason,
                color: Colors.red.shade600,
              ),
            
            // Tambahkan petunjuk berdasarkan status
            if (status == 'not_uploaded') ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info, color: Colors.blue.shade600, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Silakan upload dokumen KK untuk verifikasi',
                        style: TextStyle(
                          color: Colors.blue.shade800,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Tutup', style: TextStyle(color: Colors.grey.shade600)),
        ),
        if (status == 'rejected' || status == 'not_uploaded')
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _showUploadKKDialog(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade600,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Upload Ulang'),
          ),
      ],
    ),
  );
}

Widget _buildKKDetailItem(String label, String value, {Color? color}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: color ?? Colors.grey.shade800,
          ),
        ),
      ],
    ),
  );
}

String _getKKStatusText(String status) {
  switch (status) {
    case 'verified':
      return 'Terverifikasi ✅';
    case 'rejected':
      return 'Ditolak ❌';
    case 'pending_review':
      return 'Menunggu Verifikasi ⏳';
    case 'not_uploaded':
      return 'Belum Upload Dokumen 📄';
    default:
      return status;
  }
}

Color _getStatusColor(String status) {
  switch (status) {
    case 'verified':
      return Colors.green.shade600;
    case 'rejected':
      return Colors.red.shade600;
    case 'pending_review':
      return Colors.orange.shade600;
    case 'not_uploaded':
      return Colors.grey.shade600;
    default:
      return Colors.grey.shade800;
  }
}

  void _showNotificationSettings(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.6,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.blue.shade600,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 24,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Pengaturan Notifikasi',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      _buildNotificationOption('Notifikasi Umum', true),
                      _buildNotificationOption('Pengumuman', true),
                      _buildNotificationOption('Laporan', true),
                      _buildNotificationOption('Kegiatan', false),
                      _buildNotificationOption('Email Notifikasi', true),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNotificationOption(String title, bool value) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
        trailing: Switch(
          value: value,
          onChanged: (newValue) {},
          activeColor: Colors.blue.shade600,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
    );
  }

  void _showHelpSupport(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.8,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.blue.shade600,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 24,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Bantuan & Dukungan',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      _buildHelpOption(
                        Icons.contact_support,
                        'Hubungi Kami',
                        'Kontak customer service',
                        () => _showContactDialog(context),
                      ),
                      const SizedBox(height: 12),
                      _buildHelpOption(
                        Icons.chat_bubble_outline,
                        'Chat Langsung',
                        'Dapatkan bantuan instan',
                        () => _showLiveChat(context),
                      ),
                      const SizedBox(height: 12),
                      _buildHelpOption(
                        Icons.help_center,
                        'FAQ',
                        'Pertanyaan yang sering diajukan',
                        () => _showFAQ(context),
                      ),
                      const SizedBox(height: 12),
                      _buildHelpOption(
                        Icons.bug_report,
                        'Laporkan Masalah',
                        'Kirim laporan bug atau masalah',
                        () => _showReportProblem(context),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHelpOption(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.blue.shade600, size: 22),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
        subtitle: Text(subtitle, style: TextStyle(color: Colors.grey.shade600)),
        trailing: Icon(
          Icons.arrow_forward_ios,
          size: 16,
          color: Colors.grey.shade400,
        ),
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    );
  }

  void _showContactDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Hubungi Kami'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('📞 Customer Service: 1500-123'),
            SizedBox(height: 8),
            Text('📧 Email: support@communityapp.com'),
            SizedBox(height: 8),
            Text('💬 WhatsApp: +62 812-3456-7890'),
            SizedBox(height: 16),
            Text('🕐 Jam Operasional:'),
            Text('Senin - Jumat: 08.00 - 17.00 WIB'),
            Text('Sabtu: 08.00 - 12.00 WIB'),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade600,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  void _showLiveChat(BuildContext context) {
    _showSuccessSnackbar('Membuka chat langsung...');
  }

  void _showFAQ(BuildContext context) {
    _showSuccessSnackbar('Membuka FAQ...');
  }

  void _showReportProblem(BuildContext context) {
    final problemController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Laporkan Masalah'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Jelaskan masalah yang Anda alami:'),
            const SizedBox(height: 12),
            TextField(
              controller: problemController,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                hintText: 'Deskripsikan masalah Anda...',
              ),
              maxLines: 4,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Batal', style: TextStyle(color: Colors.grey.shade600)),
          ),
          ElevatedButton(
            onPressed: () {
              if (problemController.text.isNotEmpty) {
                _showSuccessSnackbar('Laporan masalah berhasil dikirim');
                Navigator.pop(context);
              } else {
                _showErrorSnackbar('Harap isi deskripsi masalah');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade600,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Kirim Laporan'),
          ),
        ],
      ),
    );
  }

  void _showPrivacyPolicy(BuildContext context) {
    _showInfoDialog(
      context,
      'Kebijakan Privasi',
      'Aplikasi Community App menghargai privasi Anda. Data yang kami kumpulkan digunakan untuk:'
          '\n\n• Memperbaiki pengalaman pengguna'
          '\n• Menyediakan layanan yang diminta'
          '\n• Komunikasi penting terkait layanan'
          '\n• Analisis dan pengembangan fitur'
          '\n\nKami tidak akan membagikan data pribadi Anda kepada pihak ketiga tanpa persetujuan.'
          '\n\nTerakhir diperbarui: 1 Desember 2024',
    );
  }

  void _showTermsConditions(BuildContext context) {
    _showInfoDialog(
      context,
      'Syarat & Ketentuan',
      'Dengan menggunakan aplikasi Community App, Anda menyetujui:'
          '\n\n• Menggunakan aplikasi sesuai dengan peraturan yang berlaku'
          '\n• Tidak menyebarkan konten yang melanggar hukum'
          '\n• Bertanggung jawab atas konten yang diunggah'
          '\n• Menghormati privasi pengguna lain'
          '\n• Mengikuti panduan komunitas yang telah ditetapkan'
          '\n\nPelanggaran terhadap syarat dan ketentuan dapat mengakibatkan pembatasan akses.'
          '\n\nTerakhir diperbarui: 1 Desember 2024',
    );
  }

  void _showRatingDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.star, color: Colors.amber.shade600),
            ),
            const SizedBox(width: 12),
            const Text(
              'Beri Rating',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Bagaimana pengalaman Anda menggunakan aplikasi?'),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [1, 2, 3, 4, 5].map((star) {
                return IconButton(
                  icon: Icon(Icons.star, color: Colors.amber, size: 35),
                  onPressed: () {
                    _showSuccessSnackbar(
                      'Terima kasih atas rating $star bintang!',
                    );
                    Navigator.pop(context);
                  },
                );
              }).toList(),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Nanti', style: TextStyle(color: Colors.grey.shade600)),
          ),
        ],
      ),
    );
  }

  void _showInfoDialog(BuildContext context, String title, String content) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(child: Text(content)),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade600,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  // profile_screen.dart - FUNGSI _showLogoutDialog YANG DIPERBAIKI
  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status verifikasi di bagian atas seperti screenshot
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 16,
                ),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade100),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.verified_user_outlined,
                      color: Colors.red.shade600,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _currentUser.isVerified == true
                            ? 'ADMIN - TERVERIFIKASI'
                            : 'ADMIN - BELUM TERVERIFIKASI',
                        style: TextStyle(
                          color: Colors.red.shade700,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Judul
              const Center(
                child: Text(
                  'Konfirmasi Keluar',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Pesan konfirmasi
              const Center(
                child: Text(
                  'Apakah Anda yakin ingin keluar dari aplikasi?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.grey,
                    height: 1.5,
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // Tombol aksi - horizontal untuk Batal dan Keluar
              Row(
                children: [
                  // Tombol Batal (kiri)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: Colors.grey.shade300),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Batal',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 12),

                  // Tombol Keluar (kanan)
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _performLogout(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade600,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Keluar',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _performLogout(BuildContext context) async {
    try {
      await AuthService.logout();
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    } catch (e) {
      _showErrorSnackbar('Gagal logout: $e');
    }
  }

  // === HELPER FUNCTIONS ===

  String _formatDate(DateTime? date) {
    if (date == null) return '-';
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatDateTime(String? dateTime) {
    if (dateTime == null) return '-';
    try {
      final date = DateTime.parse(dateTime);
      return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateTime;
    }
  }

  void _showSuccessSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
