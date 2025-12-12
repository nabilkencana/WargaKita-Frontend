// profile_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:warga_app/screens/login_screen.dart';
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
  Map<String, dynamic>? _kkStatus;
  bool _isUpdatingProfile = false;
  bool _isUploadingKK = false; // Tambahkan ini

  @override
  void initState() {
    super.initState();
    _currentUser = widget.user;

    // Langsung set KK status null atau fallback
    _kkStatus = null;

    // Load data di background tanpa blocking UI
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUserDataInBackground();
    });
  }

  // TAMBAHKAN: Load data di background
  Future<void> _loadUserDataInBackground() async {
    try {
      print('🔄 Loading user profile data in background...');

      // Load user profile data
      final profileData = await ProfileService.getProfile();

      if (mounted) {
        if (profileData['user'] != null) {
          setState(() {
            _currentUser = User.fromJson(profileData['user']);
          });
        } else if (profileData['id'] != null) {
          setState(() {
            _currentUser = User.fromJson(profileData);
          });
        }
      }

      // Load KK verification status di background
      try {
        final kkData = await ProfileService.getKKVerificationStatus();
        if (mounted) {
          setState(() => _kkStatus = kkData);
        }
      } catch (e) {
        print('⚠️ Error loading KK status in background: $e');
      }

      print('✅ Background profile data loaded');
    } catch (e) {
      print('⚠️ Background profile load error (non-critical): $e');
      // Tidak tampilkan error ke user karena UI sudah ada
    }
  }

  // Ubah _loadUserData() menjadi hanya untuk background refresh
  Future<void> _loadUserData() async {
    try {
      print('🔄 Refreshing user profile data...');

      // Load user profile data
      final profileData = await ProfileService.getProfile();
      print('📊 Raw profile data: $profileData');

      // Update state jika ada perubahan
      if (mounted) {
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
        }
      }

      // Load KK verification status
      try {
        final kkData = await ProfileService.getKKVerificationStatus();
        if (mounted) {
          setState(() => _kkStatus = kkData);
        }
      } catch (e) {
        print('⚠️ Error loading KK status: $e');
      }

      print('✅ Profile data refreshed');
    } catch (e) {
      print('❌ Error refreshing profile data: $e');
      // Tidak tampilkan error ke user karena UI sudah ada
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
        final file = File(pickedFile.path);

        // Validasi ukuran file (max 5MB)
        final fileSize = await file.length();
        if (fileSize > 5 * 1024 * 1024) {
          _showErrorSnackbar('Ukuran file maksimal 5MB');
          return;
        }

        // Validasi tipe file berdasarkan ekstensi
        final fileExtension = pickedFile.path.split('.').last.toLowerCase();
        if (!['jpg', 'jpeg', 'png'].contains(fileExtension)) {
          _showErrorSnackbar(
            'Format file tidak didukung. Gunakan JPG, JPEG, atau PNG',
          );
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
      if (mounted) {}
    }
  }

  Future<String?> _showDeliveryMethodDialog(BuildContext context) async {
    return await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Pilih Metode Pengiriman'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.email, color: Colors.blue.shade600),
              title: const Text('Kirim via Email'),
              subtitle: const Text('Aplikasi email akan terbuka'),
              onTap: () => Navigator.pop(context, 'email'),
            ),
            ListTile(
              leading: Icon(Icons.chat, color: Colors.green.shade600),
              title: const Text('Kirim via WhatsApp'),
              subtitle: const Text('Aplikasi WhatsApp akan terbuka'),
              onTap: () => Navigator.pop(context, 'whatsapp'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
        ],
      ),
    );
  }

  Future<void> _sendReportViaEmail({
    required String category,
    required String description,
    String? imagePath,
  }) async {
    try {
      final userName = _currentUser.namaLengkap ?? 'Pengguna Warga App';
      final userEmail = _currentUser.email;
      final userPhone = _currentUser.nomorTelepon ?? 'Tidak tersedia';

      final subject = '🐛 [BUG REPORT] $category - ${DateTime.now().toLocal()}';

      final body =
          '''
🚨 **LAPORAN BUG/MASALAH APLIKASI Warga App**
──────────────────────────────────────────────────

**📋 INFORMASI PELAPOR**
• Nama: $userName
• Email: $userEmail
• No. Telepon: $userPhone

**📊 KATEGORI MASALAH**
$category

**📝 DESKRIPSI MASALAH**
$description

**🛠️ INFORMASI TEKNIS**
• Aplikasi: Warga App v1.0.0
• Platform: ${Platform.operatingSystem}
• Tanggal: ${DateTime.now().toLocal()}
• Status Akun: ${_currentUser.email.isNotEmpty ? 'Terdaftar' : 'Belum Verifikasi'}

**📱 DATA TAMBAHAN**
• Foto Profil: ${_currentUser.fotoProfil != null ? 'Ya' : 'Tidak'}
• Status KK: ${_kkStatus?['kkVerificationStatus'] ?? 'Belum Upload'}
• Alamat: ${_currentUser.alamat ?? 'Tidak tersedia'}
• RT/RW: ${_currentUser.rtRw ?? 'Tidak tersedia'}

──────────────────────────────────────────────────
⚠️ **CATATAN**
Laporan ini dibuat otomatis dari aplikasi Warga App.
Jika ada pertanyaan lebih lanjut, hubungi pelapor di:
📧 $userEmail
📱 $userPhone
──────────────────────────────────────────────────
''';

      final mailtoUri =
          'mailto:developer@wargaapp.com?'
          'subject=${Uri.encodeComponent(subject)}&'
          'body=${Uri.encodeComponent(body)}';

      if (await canLaunchUrl(Uri.parse(mailtoUri))) {
        await launchUrl(Uri.parse(mailtoUri));
        _showSuccessSnackbar('Membuka aplikasi email...');
      } else {
        // Fallback: tampilkan data untuk di-copy manual
        await _showManualCopyDialog(
          title: 'Data Laporan Bug',
          data: body,
          recipient: 'developer@wargaapp.com',
        );
      }
    } catch (e) {
      print('❌ Error sending email report: $e');
      _showErrorSnackbar('Gagal membuka aplikasi email');
    }
  }

  Future<void> _sendReportViaWhatsApp({
    required String category,
    required String description,
  }) async {
    try {
      final userName = _currentUser.namaLengkap ?? 'Pengguna Warga App';
      final userPhone = _currentUser.nomorTelepon ?? 'Tidak tersedia';

      // Nomor WhatsApp penerima (bisa disesuaikan)
      final whatsappNumber = '+6281234567890'; // Ganti dengan nomor support

      final message =
          '''
*🐛 LAPORAN BUG APLIKASI Warga App*

*📋 Informasi Pelapor:*
• Nama: $userName
• No. Telepon: $userPhone

*📊 Kategori Masalah:*
$category

*📝 Deskripsi Masalah:*
$description

*🛠️ Informasi Teknis:*
• Aplikasi: Warga App v1.0.0
• Platform: ${Platform.operatingSystem}
• Tanggal: ${DateTime.now().toLocal()}

*────────────────────────────*
Laporan ini dibuat otomatis dari aplikasi.
Mohon ditindaklanjuti.
''';

      final encodedMessage = Uri.encodeComponent(message);
      final whatsappUrl = 'https://wa.me/$whatsappNumber?text=$encodedMessage';

      if (await canLaunchUrl(Uri.parse(whatsappUrl))) {
        await launchUrl(Uri.parse(whatsappUrl));
      } else {
        _showErrorSnackbar('Tidak dapat membuka WhatsApp');
        await _showManualCopyDialog(
          title: 'Pesan WhatsApp',
          data: message,
          recipient: whatsappNumber,
        );
      }
    } catch (e) {
      print('❌ Error sending WhatsApp report: $e');
      _showErrorSnackbar('Gagal membuka WhatsApp');
    }
  }

  Future<void> _showManualCopyDialog({
    required String title,
    required String data,
    required String recipient,
  }) async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title),
        content: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: SelectableText(
            data,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade800),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tutup'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: data));
              _showSuccessSnackbar('Data disalin! Kirim ke: $recipient');
              Navigator.pop(context);
            },
            icon: const Icon(Icons.copy, size: 18),
            label: const Text('Salin'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          // GANTI Column dengan SingleChildScrollView
          child: Column(
            mainAxisSize: MainAxisSize.min, // TAMBAHKAN INI
            children: [
              // Header dengan tombol back
              _buildHeader(),

              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min, // TAMBAHKAN INI
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

                    // Informasi Personal - TAMPILKAN LANGSUNG
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
                                minimumSize: const Size(double.infinity, 50),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(color: Colors.blue.shade200),
                                ),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
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
                                minimumSize: const Size(double.infinity, 50),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(color: Colors.red.shade200),
                                ),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
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
            ],
          ),
        ),
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
  // Ganti bagian _buildHeader() dengan kode berikut:
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
          const SizedBox(height: 8),

          // Bio - MENGGANTI BADGE ROLE DAN VERIFIKASI DENGAN BIO
          if (_currentUser.bio != null && _currentUser.bio!.isNotEmpty)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.2)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.white.withOpacity(0.8),
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Bio',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _currentUser.bio!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 14,
                      fontStyle: FontStyle.italic,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            )
          else
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.2)),
              ),
              child: GestureDetector(
                onTap: () => _showEditProfileDialog(context),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_circle_outline,
                      color: Colors.white.withOpacity(0.8),
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Tambahkan Bio Anda',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 16),

          // Progress bar kelengkapan profil
          if (completionPercentage < 100) ...[
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
      if (mounted) {}
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

    final hasAnyData =
        (_currentUser.nik?.isNotEmpty == true) ||
        (_currentUser.nomorTelepon?.isNotEmpty == true) ||
        (_currentUser.alamat?.isNotEmpty == true) ||
        (_currentUser.kota?.isNotEmpty == true) ||
        (_currentUser.rtRw?.isNotEmpty == true) ||
        (_currentUser.kodePos?.isNotEmpty == true) ||
        (_currentUser.tempatLahir?.isNotEmpty == true) ||
        (_currentUser.tanggalLahir != null);

    if (!hasAnyData) {
      // Tampilkan placeholder jika belum ada data
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 8),
            child: Text(
              'Informasi Personal',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.blue.shade800,
              ),
            ),
          ),
          Container(
            width: double.infinity, // TAMBAHKAN INI
            child: Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Container(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min, // PERBAIKAN: MainAxisSize.min
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.grey.shade400,
                      size: 40,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Belum ada informasi personal',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Klik "Edit Profil" untuk melengkapi data',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
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
              icon: const Icon(Icons.edit, size: 16),
              label: const Text('Lengkapi Informasi Personal'),
            ),
          ),
        ],
      );
    }

    // Kode asal untuk menampilkan data jika ada
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min, // PERBAIKAN: MainAxisSize.min
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 8),
          child: Text(
            'Informasi Personal',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.blue.shade800,
            ),
          ),
        ),
        Card(
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min, // PERBAIKAN: MainAxisSize.min
            children: [
              if (_currentUser.nik?.isNotEmpty == true)
                _buildInfoRow('NIK', _currentUser.nik!),
              if (_currentUser.tanggalLahir != null)
                _buildInfoRow(
                  'Tanggal Lahir',
                  _formatDate(_currentUser.tanggalLahir!),
                ),
              if (_currentUser.tempatLahir?.isNotEmpty == true)
                _buildInfoRow('Tempat Lahir', _currentUser.tempatLahir!),
              if (_currentUser.nomorTelepon?.isNotEmpty == true)
                _buildInfoRow('Nomor Telepon', _currentUser.nomorTelepon!),
              if (_currentUser.alamat?.isNotEmpty == true)
                _buildInfoRow('Alamat', _currentUser.alamat!),
              if (_currentUser.rtRw?.isNotEmpty == true)
                _buildInfoRow('RT/RW', _currentUser.rtRw!),
              if (_currentUser.kota?.isNotEmpty == true)
                _buildInfoRow('Kota', _currentUser.kota!),
              if (_currentUser.kodePos?.isNotEmpty == true)
                _buildInfoRow('Kode Pos', _currentUser.kodePos!),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    final isEmpty = value.isEmpty || value == 'Belum diisi';

    return Column(
      mainAxisSize: MainAxisSize.min, // TAMBAHKAN INI
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
      mainAxisSize: MainAxisSize.min, // TAMBAHKAN INI
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
          child: Column(
            mainAxisSize: MainAxisSize.min, // TAMBAHKAN INI
            children: children,
          ),
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

                                    try {
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
                                      if (mounted) {
                                        Navigator.pop(context);
                                      }
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
                                    } finally {
                                      // PASTIKAN loading di-reset meskipun sukses
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

    final status =
        _kkStatus?['kkVerificationStatus']?.toString() ?? 'not_uploaded';
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
          height: MediaQuery.of(context).size.height * 0.9,
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 24,
                ),
                decoration: BoxDecoration(
                  color: Colors.blue.shade700,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Bantuan & Dukungan',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        IconButton(
                          icon: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Dapatkan bantuan untuk menggunakan aplikasi Warga',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                  ],
                ),
              ),

              // Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      // Quick Access Cards
                      const Text(
                        'Akses Cepat',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 16),

                      Row(
                        children: [
                          Expanded(
                            child: _buildQuickActionCard(
                              Icons.phone_in_talk,
                              'Telepon',
                              'Hubungi customer service',
                              Colors.green.shade50,
                              Colors.green.shade600,
                              () => _makePhoneCall("+623417890123"),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildQuickActionCard(
                              Icons.chat_bubble,
                              'Chat',
                              'Bantuan instan via chat',
                              Colors.blue.shade50,
                              Colors.blue.shade600,
                              () => _startLiveChat(context),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Bantuan Sections
                      const SizedBox(height: 24),
                      const Text(
                        'Bantuan Berdasarkan Kategori',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 16),

                      _buildHelpCategory(
                        'Akun & Profil',
                        [
                          'Cara mengedit profil',
                          'Cara upload dokumen KK',
                          'Cara reset password',
                          'Cara verifikasi email',
                          'Masalah login',
                        ],
                        Icons.person,
                        Colors.blue.shade600,
                        () => _showAccountHelp(context),
                      ),
                      const SizedBox(height: 16),

                      _buildHelpCategory(
                        'Dokumen & Verifikasi',
                        [
                          'Persyaratan upload KK',
                          'Status verifikasi dokumen',
                          'Dokumen ditolak',
                          'Cara upload ulang',
                          'Masa berlaku verifikasi',
                        ],
                        Icons.description,
                        Colors.green.shade600,
                        () => _showDocumentHelp(context),
                      ),
                      const SizedBox(height: 16),

                      _buildHelpCategory(
                        'Aplikasi & Teknis',
                        [
                          'Aplikasi crash/error',
                          'Notifikasi tidak muncul',
                          'Update aplikasi',
                          'Masalah internet',
                          'Keluhan performa',
                        ],
                        Icons.smartphone,
                        Colors.orange.shade600,
                        () => _showTechnicalHelp(context),
                      ),
                      const SizedBox(height: 16),

                      _buildHelpCategory(
                        'Keamanan & Privasi',
                        [
                          'Keamanan akun',
                          'Laporan aktivitas mencurigakan',
                          'Reset password',
                          'Data pribadi',
                          'Hapus akun',
                        ],
                        Icons.security,
                        Colors.purple.shade600,
                        () => _showSecurityHelp(context),
                      ),

                      // FAQ Section
                      const SizedBox(height: 32),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.blue.shade100),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.question_answer,
                                  color: Colors.blue.shade700,
                                  size: 24,
                                ),
                                const SizedBox(width: 12),
                                const Text(
                                  'Pertanyaan Umum (FAQ)',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _buildFAQItem(
                              'Bagaimana cara verifikasi akun?',
                              'Verifikasi dilakukan melalui upload dokumen KK. Dokumen akan diverifikasi oleh admin dalam 1-3 hari kerja.',
                            ),
                            _buildFAQItem(
                              'Berapa lama proses verifikasi KK?',
                              'Proses verifikasi biasanya memakan waktu 1-3 hari kerja. Anda akan mendapat notifikasi saat status berubah.',
                            ),
                            _buildFAQItem(
                              'Apa yang harus dilakukan jika dokumen ditolak?',
                              'Periksa alasan penolakan di profil > status KK. Upload ulang dengan dokumen yang lebih jelas dan sesuai persyaratan.',
                            ),
                            const SizedBox(height: 12),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: () => _showFullFAQ(context),
                                child: Text(
                                  'Lihat FAQ Lengkap →',
                                  style: TextStyle(
                                    color: Colors.blue.shade700,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Contact Information
                      const SizedBox(height: 32),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '📞 Kontak Resmi',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _buildContactInfoRow(
                              Icons.phone,
                              'Customer Service',
                              '(0341) 789-0123',
                              Colors.green.shade700,
                            ),
                            _buildContactInfoRow(
                              Icons.email,
                              'Email Support',
                              'support@wargaapp.com',
                              Colors.blue.shade700,
                            ),
                            _buildContactInfoRow(
                              Icons.chat_bubble,
                              'WhatsApp',
                              '+62 812-3456-7890',
                              Colors.green.shade700,
                            ),
                            _buildContactInfoRow(
                              Icons.location_on,
                              'Alamat Kantor',
                              'Jl. Danau Ranau II, Malang',
                              Colors.orange.shade700,
                            ),
                          ],
                        ),
                      ),

                      // Operating Hours
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.amber.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.access_time,
                              color: Colors.amber.shade700,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '🕐 Jam Operasional',
                                    style: TextStyle(
                                      color: Colors.amber.shade800,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Senin - Jumat: 08.00 - 17.00 WIB\nSabtu: 08.00 - 12.00 WIB',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Report Problem Button
                      const SizedBox(height: 32),
                      ElevatedButton.icon(
                        onPressed: () => _showReportProblemDialog(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade50,
                          foregroundColor: Colors.red.shade700,
                          minimumSize: const Size(double.infinity, 56),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: Colors.red.shade200),
                          ),
                        ),
                        icon: const Icon(Icons.bug_report),
                        label: const Text(
                          'Laporkan Masalah atau Bug',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),

                      const SizedBox(height: 40),
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

  // Helper Methods untuk Bantuan & Dukungan

  Widget _buildQuickActionCard(
    IconData icon,
    String title,
    String subtitle,
    Color bgColor,
    Color iconColor,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: bgColor.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHelpCategory(
    String title,
    List<String> topics,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade100),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: topics
                  .map(
                    (topic) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        topic,
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          size: 16,
          color: Colors.grey.shade400,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),
    );
  }

  Widget _buildFAQItem(String question, String answer) {
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: Text(
        question,
        style: TextStyle(
          fontWeight: FontWeight.w500,
          color: Colors.grey.shade800,
        ),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
          child: Text(answer, style: TextStyle(color: Colors.grey.shade600)),
        ),
      ],
    );
  }

  Widget _buildContactInfoRow(
    IconData icon,
    String title,
    String value,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
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
          const Spacer(),
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.content_copy, size: 14, color: color),
            ),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: value));
              _showSuccessSnackbar('Disalin: $value');
            },
          ),
        ],
      ),
    );
  }

  // Fungsi-fungsi untuk berbagai bantuan

  void _showAccountHelp(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Bantuan Akun & Profil'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHelpStep(
                '1. Edit Profil',
                'Klik menu "Edit Profil" di halaman profil Anda',
              ),
              _buildHelpStep(
                '2. Upload Foto',
                'Pastikan foto jelas, ukuran maksimal 5MB',
              ),
              _buildHelpStep(
                '3. Reset Password',
                'Gunakan fitur "Lupa Password" di halaman login',
              ),
              _buildHelpStep(
                '4. Verifikasi Email',
                'Cek email Anda untuk link verifikasi',
              ),
              const SizedBox(height: 16),
              const Text(
                'Masih butuh bantuan? Hubungi customer service kami.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tutup'),
          ),
          ElevatedButton(
            onPressed: () => _makePhoneCall("+623417890123"),
            child: const Text('Hubungi CS'),
          ),
        ],
      ),
    );
  }

  void _showContactDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Hubungi Kami'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildContactItem(
                Icons.phone,
                'Customer Service',
                '(0341) 789-0123',
                Colors.green.shade700,
                () => _makePhoneCall('+623417890123'),
              ),
              const SizedBox(height: 12),
              _buildContactItem(
                Icons.email,
                'Email Support',
                'support@wargaapp.com',
                Colors.blue.shade700,
                () => _sendEmail('support@wargaapp.com'),
              ),
              const SizedBox(height: 12),
              _buildContactItem(
                Icons.chat_bubble,
                'WhatsApp',
                '+62 812-3456-7890',
                Colors.green.shade600,
                () => _openWhatsApp('+6281234567890'),
              ),
              const SizedBox(height: 12),
              _buildContactItem(
                Icons.location_on,
                'Alamat Kantor',
                'Jl. Danau Ranau II, Malang',
                Colors.orange.shade700,
                () => _openMaps(),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    const Text(
                      '🕐 Jam Operasional',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Senin - Jumat: 08.00 - 17.00 WIB\nSabtu: 08.00 - 12.00 WIB',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Respon rata-rata: 2-4 jam',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  Widget _buildContactItem(
    IconData icon,
    String title,
    String value,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.content_copy, size: 16, color: color),
              ),
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: value));
                _showSuccessSnackbar('Disalin: $value');
              },
            ),
          ],
        ),
      ),
    );
  }

  // Helper methods untuk kontak
  Future<void> _makePhoneCall(String phoneNumber) async {
    final url = 'tel:$phoneNumber';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    } else {
      _showErrorSnackbar('Tidak dapat membuka aplikasi telepon');
    }
  }

  Future<void> _sendEmail(String email) async {
    final url = 'mailto:$email';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    } else {
      _showErrorSnackbar('Tidak dapat membuka aplikasi email');
    }
  }

  Future<void> _openWhatsApp(String phoneNumber) async {
    // Format nomor WhatsApp (hapus tanda + dan spasi)
    final formattedNumber = phoneNumber.replaceAll(RegExp(r'[+\s]'), '');
    final url = 'https://wa.me/$formattedNumber';

    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    } else {
      _showErrorSnackbar('Tidak dapat membuka WhatsApp');
    }
  }

  Future<void> _openMaps() async {
    const address = 'Jl. Danau Ranau II, Malang';
    final url = Uri.encodeFull('https://maps.google.com/?q=$address');

    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    } else {
      _showErrorSnackbar('Tidak dapat membuka aplikasi maps');
    }
  }

  void _showDocumentHelp(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Bantuan Dokumen & Verifikasi'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '📋 Persyaratan Dokumen KK:',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              _buildBulletPoint('Format: JPG, PNG, atau PDF'),
              _buildBulletPoint('Maksimal 5MB'),
              _buildBulletPoint('Foto jelas, semua informasi terbaca'),
              _buildBulletPoint('Dokumen masih berlaku'),
              const SizedBox(height: 12),
              const Text(
                '⏱️ Timeline Verifikasi:',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              _buildBulletPoint('Review awal: 1-2 jam'),
              _buildBulletPoint('Verifikasi lengkap: 1-3 hari kerja'),
              _buildBulletPoint('Notifikasi real-time saat status berubah'),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Pastikan dokumen asli siap untuk verifikasi offline jika diperlukan',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tutup'),
          ),
          ElevatedButton(
            onPressed: () => _showUploadKKDialog(context),
            child: const Text('Upload KK'),
          ),
        ],
      ),
    );
  }

  void _showTechnicalHelp(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Bantuan Teknis'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTroubleshootingStep(
                'Aplikasi crash/error',
                '1. Tutup aplikasi\n2. Clear cache\n3. Update aplikasi\n4. Restart perangkat',
              ),
              _buildTroubleshootingStep(
                'Notifikasi tidak muncul',
                '1. Cek pengaturan notifikasi\n2. Pastikan koneksi internet\n3. Update aplikasi',
              ),
              _buildTroubleshootingStep(
                'Masalah internet',
                '1. Restart WiFi/mobile data\n2. Cek sinyal\n3. Coba jaringan lain',
              ),
              const SizedBox(height: 16),
              const Text(
                'Informasi Aplikasi:',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              _buildBulletPoint('Versi: 1.0.0'),
              _buildBulletPoint('Ukuran: ~50MB'),
              _buildBulletPoint('OS Minimal: Android 8.0 / iOS 12'),
              _buildBulletPoint('Terakhir Update: Desember 2024'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tutup'),
          ),
          ElevatedButton(
            onPressed: () => _showReportProblemDialog(context),
            child: const Text('Laporkan Masalah'),
          ),
        ],
      ),
    );
  }

  void _showSecurityHelp(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Bantuan Keamanan & Privasi'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '🔒 Tips Keamanan Akun:',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              _buildBulletPoint('Gunakan password yang kuat'),
              _buildBulletPoint('Jangan bagikan kredensial login'),
              _buildBulletPoint('Logout dari perangkat bersama'),
              _buildBulletPoint('Aktifkan verifikasi 2 langkah'),
              const SizedBox(height: 12),
              const Text(
                '📝 Lapor Aktivitas Mencurigakan:',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const Text(
                'Jika Anda melihat aktivitas mencurigakan pada akun Anda:',
                style: TextStyle(fontSize: 12),
              ),
              _buildBulletPoint('Segera ubah password'),
              _buildBulletPoint('Hubungi customer service'),
              _buildBulletPoint('Laporkan ke admin komunitas'),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Kami TIDAK PERNAH meminta password melalui telepon atau email. Hati-hati dengan phishing!',
                  style: TextStyle(fontSize: 12, color: Colors.red),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tutup'),
          ),
          TextButton(
            onPressed: () => _showPrivacyPolicy(context),
            child: const Text('Kebijakan Privasi'),
          ),
        ],
      ),
    );
  }

  void _showFullFAQ(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.9,
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
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.blue.shade700,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'FAQ Lengkap',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),

              // FAQ Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      _buildDetailedFAQItem(
                        'Bagaimana cara mendaftar di Warga App?',
                        'Pendaftaran dilakukan melalui undangan dari admin komunitas. Hubungi admin RT/RW setempat untuk mendapatkan kode pendaftaran.',
                      ),
                      _buildDetailedFAQItem(
                        'Apa syarat menggunakan aplikasi?',
                        '1. Warga yang tercatat di lingkungan tersebut\n2. Memiliki smartphone dengan internet\n3. Dokumen KK yang valid\n4. Email aktif',
                      ),
                      _buildDetailedFAQItem(
                        'Apakah aplikasi ini gratis?',
                        'Ya, aplikasi Warga App sepenuhnya gratis untuk digunakan oleh warga terdaftar.',
                      ),
                      _buildDetailedFAQItem(
                        'Data saya aman tidak?',
                        'Data Anda dilindungi dengan enkripsi tingkat tinggi dan hanya digunakan untuk keperluan layanan komunitas sesuai Kebijakan Privasi.',
                      ),
                      _buildDetailedFAQItem(
                        'Bagaimana jika saya ganti nomor HP?',
                        'Hubungi admin untuk update data. Anda perlu verifikasi ulang dengan nomor baru.',
                      ),
                      _buildDetailedFAQItem(
                        'Apakah bisa digunakan di luar kota?',
                        'Bisa, selama ada koneksi internet. Beberapa fitur mungkin memerlukan verifikasi lokasi.',
                      ),
                      _buildDetailedFAQItem(
                        'Bagaimana cara hapus akun?',
                        'Kirim permintaan ke admin melalui aplikasi atau hubungi customer service.',
                      ),
                      _buildDetailedFAQItem(
                        'Aplikasi tidak bisa dibuka, kenapa?',
                        '1. Pastikan sudah update ke versi terbaru\n2. Clear cache aplikasi\n3. Restart perangkat\n4. Cek koneksi internet',
                      ),
                      _buildDetailedFAQItem(
                        'Notifikasi tidak muncul, solusinya?',
                        '1. Cek pengaturan notifikasi di perangkat\n2. Pastikan aplikasi tidak di-force stop\n3. Update aplikasi ke versi terbaru',
                      ),
                      _buildDetailedFAQItem(
                        'Kapan update fitur baru?',
                        'Kami melakukan update rutin setiap bulan. Info update tersedia di pengumuman aplikasi.',
                      ),
                    ],
                  ),
                ),
              ),

              // Footer
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: Colors.grey.shade200)),
                ),
                child: ElevatedButton(
                  onPressed: () => _showContactDialog(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade600,
                    minimumSize: const Size(double.infinity, 50),
                  ),
                  child: const Text(
                    'Butuh Bantuan Lebih Lanjut? Hubungi Kami',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHelpStep(String step, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.blue.shade100,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check, size: 12, color: Colors.blue),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(step, style: const TextStyle(fontWeight: FontWeight.w500)),
                Text(
                  description,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(fontSize: 16)),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }

  Widget _buildTroubleshootingStep(String problem, String solution) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(problem, style: const TextStyle(fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Text(
            solution,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailedFAQItem(String question, String answer) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.help_outline, color: Colors.blue.shade600, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  question,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 26),
            child: Text(
              answer,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Fungsi-fungsi aksi

  // void _makePhoneCall(String phoneNumber) async {
  //   final Uri launchUri = Uri(
  //     scheme: 'tel',
  //     path: phoneNumber,
  //   );
  //   if (await canLaunchUrl(launchUri)) {
  //     await launchUrl(launchUri);
  //   } else {
  //     _showErrorSnackbar('Tidak dapat membuka aplikasi telepon');
  //   }
  // }

  void _startLiveChat(BuildContext context) {
    // Implement live chat functionality
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Chat Langsung'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.chat_bubble_outline, size: 60, color: Colors.blue),
            SizedBox(height: 16),
            Text(
              'Fitur chat langsung akan segera hadir!',
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              'Untuk sementara, hubungi kami via WhatsApp atau telepon.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tutup'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _makePhoneCall("+623417890123");
            },
            child: const Text('Telepon Sekarang'),
          ),
        ],
      ),
    );
  }

  void _showReportProblemDialog(BuildContext context) {
    final problemController = TextEditingController();
    String selectedCategory = 'Umum';
    bool _isSubmitting = false;
    String? selectedImagePath;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.85,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.red.shade600,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.bug_report,
                          color: Colors.white,
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Laporkan Masalah',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),

                  // Content
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Kategori Masalah',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children:
                                [
                                  'Umum',
                                  'Teknis',
                                  'Akun',
                                  'Dokumen',
                                  'Notifikasi',
                                  'Lainnya',
                                ].map((category) {
                                  return ChoiceChip(
                                    label: Text(category),
                                    selected: selectedCategory == category,
                                    onSelected: (selected) {
                                      setState(
                                        () => selectedCategory = category,
                                      );
                                    },
                                  );
                                }).toList(),
                          ),
                          const SizedBox(height: 24),

                          const Text(
                            'Deskripsi Masalah',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: problemController,
                            maxLines: 5,
                            decoration: InputDecoration(
                              hintText:
                                  'Jelaskan masalah yang Anda alami secara detail...',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Sertakan: perangkat, langkah reproduksi, waktu kejadian',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Screenshot Section
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  '📸 Screenshot (Opsional)',
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 8),

                                if (selectedImagePath != null)
                                  Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    child: Stack(
                                      children: [
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          child: Image.file(
                                            File(selectedImagePath!),
                                            height: 100,
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                        Positioned(
                                          top: 4,
                                          right: 4,
                                          child: GestureDetector(
                                            onTap: () {
                                              setState(
                                                () => selectedImagePath = null,
                                              );
                                            },
                                            child: Container(
                                              padding: const EdgeInsets.all(4),
                                              decoration: BoxDecoration(
                                                color: Colors.black.withOpacity(
                                                  0.6,
                                                ),
                                                shape: BoxShape.circle,
                                              ),
                                              child: const Icon(
                                                Icons.close,
                                                color: Colors.white,
                                                size: 16,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                Row(
                                  children: [
                                    ElevatedButton.icon(
                                      onPressed: () async {
                                        final picker = ImagePicker();
                                        final pickedFile = await picker
                                            .pickImage(
                                              source: ImageSource.gallery,
                                              maxWidth: 800,
                                              maxHeight: 800,
                                              imageQuality: 85,
                                            );

                                        if (pickedFile != null) {
                                          setState(
                                            () => selectedImagePath =
                                                pickedFile.path,
                                          );
                                        }
                                      },
                                      icon: const Icon(Icons.photo, size: 18),
                                      label: const Text('Pilih Gambar'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.white,
                                        foregroundColor: Colors.blue.shade700,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    if (selectedImagePath == null)
                                      ElevatedButton.icon(
                                        onPressed: () async {
                                          // Implement screenshot capture
                                          _showSuccessSnackbar(
                                            'Fitur screenshot akan datang',
                                          );
                                        },
                                        icon: const Icon(
                                          Icons.screenshot,
                                          size: 18,
                                        ),
                                        label: const Text('Ambil Screenshot'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.white,
                                          foregroundColor:
                                              Colors.green.shade700,
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Gambar membantu kami memahami masalah lebih cepat',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 24),

                          // System Info
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'ℹ️ Informasi Sistem',
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 4),
                                Text('Aplikasi: Warga App v1.0.0'),
                                Text('Perangkat: ${Platform.operatingSystem}'),
                                Text('Tanggal: ${DateTime.now().toLocal()}'),
                                Text(
                                  'Pengguna: ${_currentUser.namaLengkap ?? 'N/A'}',
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Pilihan Pengiriman
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  '📤 Pilih Metode Pengiriman',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildDeliveryOption(
                                        icon: Icons.email,
                                        label: 'Email',
                                        color: Colors.blue.shade600,
                                        onTap: () async {
                                          await _sendReportViaEmail(
                                            category: selectedCategory,
                                            description: problemController.text,
                                            imagePath: selectedImagePath,
                                          );
                                          if (mounted) Navigator.pop(context);
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _buildDeliveryOption(
                                        icon: Icons.chat,
                                        label: 'WhatsApp',
                                        color: Colors.green.shade600,
                                        onTap: () async {
                                          await _sendReportViaWhatsApp(
                                            category: selectedCategory,
                                            description: problemController.text,
                                          );
                                          if (mounted) Navigator.pop(context);
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Footer
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(color: Colors.grey.shade200),
                      ),
                    ),
                    child: _isSubmitting
                        ? const CircularProgressIndicator()
                        : Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('Batal'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () async {
                                    if (problemController.text.isEmpty) {
                                      _showErrorSnackbar(
                                        'Harap isi deskripsi masalah',
                                      );
                                      return;
                                    }

                                    setState(() => _isSubmitting = true);

                                    // Tampilkan pilihan pengiriman
                                    final method =
                                        await _showDeliveryMethodDialog(
                                          context,
                                        );

                                    if (method == 'email') {
                                      await _sendReportViaEmail(
                                        category: selectedCategory,
                                        description: problemController.text,
                                        imagePath: selectedImagePath,
                                      );
                                    } else if (method == 'whatsapp') {
                                      await _sendReportViaWhatsApp(
                                        category: selectedCategory,
                                        description: problemController.text,
                                      );
                                    }

                                    if (mounted) Navigator.pop(context);
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red.shade600,
                                  ),
                                  child: const Text('Laporkan Sekarang'),
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

  Widget _buildDeliveryOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(color: color, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  void _showPrivacyPolicy(BuildContext context) {
    _showInfoDialog(context, 'Kebijakan Privasi Warga App', '''
**TERAKHIR DIPERBARUI: 12 Desember 2024**
**VERSI: 3.0**

### **PENGANTAR**

Selamat datang di Kebijakan Privasi Warga App ("Aplikasi"). Kebijakan ini menjelaskan bagaimana kami mengumpulkan, menggunakan, mengungkapkan, dan melindungi informasi pribadi Anda. Dengan menggunakan Aplikasi ini, Anda menyetujui praktik yang dijelaskan dalam Kebijakan Privasi ini.

### **1. INFORMASI YANG KAMI KUMPULKAN**

#### **1.1. Informasi Pribadi**
Kami mengumpulkan informasi yang Anda berikan secara langsung:
- **Data Identitas**: Nama lengkap, NIK, tanggal lahir, tempat lahir
- **Kontak**: Alamat email, nomor telepon
- **Demografis**: Alamat, kota, RT/RW, kode pos
- **Dokumen**: Foto profil, dokumen Kartu Keluarga (KK)

#### **1.2. Informasi Otomatis**
- **Data Perangkat**: Tipe perangkat, sistem operasi, versi aplikasi
- **Data Penggunaan**: Waktu akses, fitur yang digunakan, frekuensi penggunaan
- **Lokasi**: Jika diizinkan, lokasi untuk keperluan layanan komunitas

#### **1.3. Informasi dari Sumber Lain**
- Data dari administrator komunitas terkait verifikasi
- Informasi dari pihak ketiga dengan persetujuan Anda

### **2. CARA KAMI MENGGUNAKAN INFORMASI**

#### **2.1. Tujuan Penggunaan**
- **Layanan Inti**: Verifikasi identitas, pengelolaan akun, layanan komunitas
- **Komunikasi**: Pengumuman, notifikasi, informasi penting
- **Pengembangan**: Meningkatkan kualitas aplikasi dan layanan
- **Keamanan**: Deteksi dan pencegahan aktivitas mencurigakan
- **Kepatuhan**: Memenuhi kewajiban hukum dan regulasi

#### **2.2. Dasar Hukum Pemrosesan**
- **Kepentingan sah**: Untuk menyediakan layanan yang diminta
- **Persetujuan**: Untuk pemrosesan data sensitif tertentu
- **Kewajiban hukum**: Untuk mematuhi peraturan yang berlaku

### **3. BERBAGI INFORMASI**

#### **3.1. Pihak Ketiga**
Kami TIDAK akan menjual, menyewakan, atau membagikan informasi pribadi Anda kepada pihak ketiga untuk tujuan pemasaran tanpa persetujuan eksplisit Anda.

#### **3.2. Pengecualian**
Kami dapat membagikan informasi dalam kondisi berikut:
- **Dengan persetujuan Anda**: Untuk layanan khusus yang membutuhkan
- **Untuk kepatuhan hukum**: Jika diwajibkan oleh hukum atau proses hukum
- **Untuk keamanan**: Untuk melindungi hak, properti, atau keselamatan
- **Layanan pihak ketiga**: Penyedia layanan yang membantu operasi aplikasi

### **4. PERLINDUNGAN DATA**

#### **4.1. Langkah Keamanan**
Kami menerapkan langkah-langkah teknis dan organisasi yang wajar:
- **Enkripsi**: Data sensitif dienkripsi dalam transit dan penyimpanan
- **Akses Terbatas**: Hanya personel berwenang yang dapat mengakses data
- **Audit Reguler**: Pemantauan dan penilaian keamanan berkala
- **Backup**: Sistem cadangan data untuk mencegah kehilangan

#### **4.2. Penyimpanan Data**
- **Lokasi**: Data disimpan di server dalam wilayah hukum Indonesia
- **Durasi**: Data disimpan selama diperlukan atau sesuai ketentuan hukum
- **Penghapusan**: Prosedur penghapusan data yang aman dan lengkap

### **5. HAK PENGGUNA**

#### **5.1. Hak yang Anda Miliki**
- **Hak Akses**: Mengakses informasi pribadi Anda
- **Hak Perbaikan**: Memperbaiki data yang tidak akurat
- **Hak Penghapusan**: Meminta penghapusan data dalam kondisi tertentu
- **Hak Pembatasan**: Membatasi pemrosesan data
- **Hak Portabilitas**: Menerima data dalam format terstruktur
- **Hak Penolakan**: Menolak pemrosesan untuk tujuan tertentu
- **Hak Penarikan Persetujuan**: Menarik persetujuan kapan saja

#### **5.2. Cara Menjalankan Hak**
Untuk menjalankan hak-hak Anda, silakan hubungi:
📧 privacy@wargaapp.com
📞 (0341) 789-0123

### **6. COOKIES DAN TEKNOLOGI SERUPA**

#### **6.1. Penggunaan Cookies**
Aplikasi kami dapat menggunakan cookies untuk:
- **Fungsionalitas**: Menyimpan preferensi dan pengaturan
- **Analitik**: Memahami pola penggunaan aplikasi
- **Keamanan**: Mencegah aktivitas yang tidak sah

#### **6.2. Kontrol Pengguna**
Anda dapat mengelola preferensi cookies melalui pengaturan perangkat atau aplikasi.

### **7. LAYANAN PIHAK KETIGA**

#### **7.1. Penyedia Layanan**
Kami dapat menggunakan layanan pihak ketiga untuk:
- **Analitik**: Google Analytics (dengan anonimisasi data)
- **Hosting**: Penyedia server cloud terpercaya
- **Komunikasi**: Layanan email dan notifikasi push

#### **7.2. Kebijakan Pihak Ketiga**
Layanan pihak ketiga memiliki kebijakan privasi sendiri yang kami anjurkan untuk Anda tinjau.

### **8. PERLINDUNGAN ANAK**

#### **8.1. Batas Usia**
Aplikasi ini tidak ditujukan untuk anak di bawah 13 tahun. Kami tidak dengan sengaja mengumpulkan informasi dari anak-anak.

#### **8.2. Persetujuan Orang Tua**
Untuk pengguna berusia 13-17 tahun, diperlukan persetujuan orang tua atau wali.

### **9. TRANSFER DATA INTERNASIONAL**

#### **9.1. Prinsip Umum**
Data diproses dan disimpan terutama di dalam wilayah Indonesia.

#### **9.2. Transfer Antar Negara**
Jika transfer data antar negara diperlukan, kami akan memastikan perlindungan yang memadai sesuai standar hukum yang berlaku.

### **10. PERUBAHAN KEBIJAKAN**

#### **10.1. Pembaruan**
Kami dapat memperbarui Kebijakan Privasi ini dari waktu ke waktu. Versi terbaru akan tersedia di Aplikasi.

#### **10.2. Pemberitahuan**
Perubahan signifikan akan diberitahukan melalui:
- Notifikasi dalam aplikasi
- Email ke alamat terdaftar
- Pengumuman di beranda aplikasi

### **11. PENYELESAIAN SENGKETA**

#### **11.1. Mekanisme**
Sengketa terkait privasi akan diselesaikan melalui:
1. **Musyawarah**: Penyelesaian secara kekeluargaan
2. **Mediasi**: Dengan bantuan mediator independen
3. **Hukum**: Proses hukum sesuai yurisdiksi yang berlaku

#### **11.2. Yurisdiksi**
Kebijakan ini tunduk pada hukum Republik Indonesia.

### **12. HUBUNGI KAMI**

#### **12.1. Kontak Utama**
Untuk pertanyaan, keluhan, atau pelaksanaan hak privasi:
**Data Protection Officer Warga App**
📧 dpo@wargaapp.com
📞 (0341) 789-0123 (ext. 101)
📠 (0341) 789-0124
📍 Jl. Danau Ranau II, Malang, Jawa Timur 65111

#### **12.2. Waktu Respon**
Kami akan merespon dalam waktu **7 hari kerja** setelah permintaan diterima.

### **13. PERSETUJUAN PENGGUNA**

"Dengan melanjutkan penggunaan Aplikasi Warga App, saya menyatakan telah membaca, memahami, dan menyetujui seluruh ketentuan dalam Kebijakan Privasi ini. Saya memahami bahwa penggunaan aplikasi merupakan bukti persetujuan saya terhadap pemrosesan data pribadi sesuai dengan kebijakan ini."

---

**Dokumen ini telah disusun sesuai dengan:**
- Undang-Undang No. 27 Tahun 2022 tentang Perlindungan Data Pribadi
- Peraturan Menteri Komunikasi dan Informatika No. 20 Tahun 2016
- Standar Internasional ISO/IEC 27001:2013

**Status Dokumen: Disetujui**
**Tanggal Efektif: 12 Desember 2024**
**Tinjauan Berkala: Setiap 12 bulan**
**Penanggung Jawab: Data Protection Officer**
''');
  }

  void _showTermsConditions(BuildContext context) {
    _showInfoDialog(context, 'Syarat & Ketentuan Penggunaan Aplikasi Warga', '''
**PENERIMAAN SYARAT DAN KETENTUAN**

Dengan mengakses dan menggunakan aplikasi Warga App ("Aplikasi"), Anda menyetujui untuk terikat dengan Syarat dan Ketentuan Penggunaan ini beserta semua hukum dan peraturan yang berlaku. Jika Anda tidak setuju dengan salah satu ketentuan ini, Anda dilarang menggunakan Aplikasi ini.

**1. PENGGUNAAN APLIKASI**
1.1. Aplikasi ini ditujukan untuk warga yang terdaftar dalam komunitas terkait.
1.2. Anda harus berusia minimal 17 tahun atau telah mendapatkan persetujuan orang tua/wali untuk menggunakan Aplikasi.
1.3. Anda bertanggung jawab untuk menjaga kerahasiaan akun dan kata sandi Anda.

**2. KEWAJIBAN PENGGUNA**
2.1. Menggunakan Aplikasi sesuai dengan tujuan yang telah ditetapkan.
2.2. Tidak menyebarkan konten yang:
   - Melanggar hukum atau peraturan yang berlaku
   - Bersifat pornografi, SARA, ujaran kebencian, atau diskriminatif
   - Mengandung informasi palsu atau menyesatkan
   - Melanggar hak kekayaan intelektual pihak ketiga
2.3. Menghormati privasi dan hak pengguna lain.
2.4. Tidak melakukan aktivitas yang dapat mengganggu sistem atau keamanan Aplikasi.

**3. DATA DAN PRIVASI**
3.1. Data pribadi yang dikumpulkan akan digunakan sesuai dengan Kebijakan Privasi kami.
3.2. Anda memberikan persetujuan untuk pengumpulan dan pemrosesan data sesuai kebutuhan layanan.
3.3. Kami menjaga kerahasiaan data Anda kecuali diwajibkan oleh hukum.

**4. HAK KEKAYAAN INTELEKTUAL**
4.1. Seluruh konten, fitur, dan fungsi dalam Aplikasi adalah milik kami atau pemberi lisensi kami.
4.2. Anda tidak diperbolehkan menyalin, memodifikasi, atau mendistribusikan konten tanpa izin tertulis.

**5. BATASAN TANGGUNG JAWAB**
5.1. Kami tidak bertanggung jawab atas:
   - Kerugian tidak langsung, insidental, atau konsekuensial
   - Ketidakakuratan atau kelengkapan informasi yang diunggah pengguna
   - Aktivitas ilegal yang dilakukan oleh pengguna
5.2. Layanan dapat dihentikan sementara untuk pemeliharaan tanpa pemberitahuan sebelumnya.

**6. PENGGANTIAN KERUGIAN**
Anda setuju untuk membebaskan dan tidak menuntut kami dari segala klaim, kerugian, atau tanggung jawab yang timbul dari penggunaan Aplikasi yang melanggar ketentuan ini.

**7. PERUBAHAN KETENTUAN**
Kami berhak mengubah Syarat dan Ketentuan ini kapan saja. Perubahan akan diberitahukan melalui Aplikasi dan berlaku sejak tanggal ditetapkan.

**8. HUKUM YANG BERLAKU**
Syarat dan Ketentuan ini tunduk pada hukum Republik Indonesia. Segala sengketa akan diselesaikan secara musyawarah, dan jika tidak tercapai kesepakatan, akan diselesaikan di Pengadilan Negeri yang berwenang.

**9. KONTAK**
Untuk pertanyaan terkait Syarat dan Ketentuan ini, silakan hubungi:
📧 legal@wargaapp.com
📞 (0341) 123-4567

**Pernyataan Persetujuan**
"Dengan melanjutkan penggunaan Aplikasi, saya menyatakan telah membaca, memahami, dan menyetujui seluruh Syarat dan Ketentuan Penggunaan ini."

**Terakhir diperbarui: 12 Desember 2024**

Versi: 2.0
''');
  }

  // profile_screen.dart - UPDATE FUNGSI RATING SAJA

  // Hapus semua kode EmailService import dan panggilan
  // Hanya gunakan mailto yang sudah terbukti berfungsi

  void _showRatingDialog(BuildContext context) {
    int selectedRating = 0;
    final commentController = TextEditingController();
    bool _isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              insetPadding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.85,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.amber.shade700,
                            Colors.orange.shade500,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(24),
                          topRight: Radius.circular(24),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.star_rounded,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Beri Rating Aplikasi',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 24,
                            ),
                            onPressed: _isSubmitting
                                ? null
                                : () => Navigator.pop(context),
                          ),
                        ],
                      ),
                    ),

                    // Content
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            // Avatar user
                            Container(
                              margin: const EdgeInsets.only(bottom: 20),
                              child: CircleAvatar(
                                radius: 40,
                                backgroundColor: Colors.amber.shade100,
                                child: Icon(
                                  Icons.person,
                                  size: 40,
                                  color: Colors.amber.shade800,
                                ),
                              ),
                            ),

                            // Judul
                            const Text(
                              'Bagaimana pengalaman Anda?',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),

                            // Subtitle - PERBAIKI TEKS INI
                            Text(
                              'Rating Anda akan membuka aplikasi email untuk dikirim ke developer',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade600,
                                height: 1.5,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 32),

                            // Emoji
                            if (selectedRating > 0)
                              Container(
                                margin: const EdgeInsets.only(bottom: 16),
                                child: Text(
                                  _getEmojiForRating(selectedRating),
                                  style: const TextStyle(fontSize: 48),
                                ),
                              ),

                            // Bintang dengan outline
                            Container(
                              margin: const EdgeInsets.symmetric(vertical: 16),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: List.generate(5, (index) {
                                  final starNumber = index + 1;
                                  final isFilled = starNumber <= selectedRating;

                                  return GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        selectedRating = starNumber;
                                      });
                                    },
                                    child: Container(
                                      margin: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                      ),
                                      child: AnimatedContainer(
                                        duration: const Duration(
                                          milliseconds: 300,
                                        ),
                                        curve: Curves.elasticOut,
                                        transform: isFilled
                                            ? Matrix4.identity().scaled(
                                                1.15,
                                                1.15,
                                              )
                                            : Matrix4.identity(),
                                        child: Icon(
                                          isFilled
                                              ? Icons.star_rounded
                                              : Icons.star_border_rounded,
                                          color: isFilled
                                              ? Colors.amber.shade500
                                              : Colors.grey.shade400,
                                          size: 52,
                                        ),
                                      ),
                                    ),
                                  );
                                }),
                              ),
                            ),

                            // Label rating
                            Text(
                              _getRatingLabel(selectedRating),
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: selectedRating > 0
                                    ? _getRatingColor(selectedRating)
                                    : Colors.grey.shade500,
                              ),
                            ),
                            const SizedBox(height: 8),

                            Text(
                              '$selectedRating/5 Bintang',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade600,
                              ),
                            ),

                            const SizedBox(height: 32),

                            // Komentar
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 20,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.message,
                                        color: Colors.blue.shade600,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Komentar (Opsional)',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.blue.shade800,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  TextField(
                                    controller: commentController,
                                    maxLines: 4,
                                    maxLength: 300,
                                    decoration: InputDecoration(
                                      hintText:
                                          'Apa yang bisa kami perbaiki? Fitur apa yang Anda suka?',
                                      hintStyle: TextStyle(
                                        color: Colors.grey.shade400,
                                        fontSize: 14,
                                      ),
                                      border: InputBorder.none,
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey.shade800,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 20),

                            // Informasi pengiriman - PERBAIKI INI
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.blue.shade100),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.email_outlined,
                                    color: Colors.blue.shade600,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Aplikasi email akan terbuka',
                                          style: TextStyle(
                                            color: Colors.blue.shade800,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Klik "Kirim" untuk membuka email',
                                          style: TextStyle(
                                            color: Colors.blue.shade600,
                                            fontSize: 12,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Tujuan: Email developer Warga App',
                                          style: TextStyle(
                                            color: Colors.blue.shade700,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Footer
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border(
                          top: BorderSide(color: Colors.grey.shade200),
                        ),
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(24),
                          bottomRight: Radius.circular(24),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.shade200.withOpacity(0.5),
                            blurRadius: 10,
                            offset: const Offset(0, -4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // Tombol Kirim - LANGSUNG MAILTO
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: selectedRating == 0 || _isSubmitting
                                  ? null
                                  : () async {
                                      setState(() => _isSubmitting = true);

                                      try {
                                        // LANGSUNG kirim via mailto
                                        final success =
                                            await _sendRatingViaMailTo(
                                              rating: selectedRating,
                                              comment: commentController.text,
                                            );

                                        if (mounted) {
                                          Navigator.pop(context);
                                          if (success) {
                                            _showRatingSuccessDialog(
                                              context,
                                              selectedRating,
                                            );
                                          } else {
                                            _showRatingManualDialog(
                                              context,
                                              selectedRating,
                                              commentController.text,
                                            );
                                          }
                                        }
                                      } catch (e) {
                                        if (mounted) {
                                          Navigator.pop(context);
                                          _showRatingManualDialog(
                                            context,
                                            selectedRating,
                                            commentController.text,
                                          );
                                        }
                                      } finally {
                                        if (mounted) {
                                          setState(() => _isSubmitting = false);
                                        }
                                      }
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: selectedRating > 0
                                    ? Colors.amber.shade600
                                    : Colors.grey.shade300,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 18,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 3,
                                shadowColor: Colors.amber.shade200,
                              ),
                              child: _isSubmitting
                                  ? Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.5,
                                            color: Colors.white,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        const Text(
                                          'Membuka Email...',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    )
                                  : Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.email_rounded, size: 22),
                                        const SizedBox(width: 10),
                                        Text(
                                          'BUKA APLIKASI EMAIL',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Tombol Batal
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: _isSubmitting
                                  ? null
                                  : () => Navigator.pop(context),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                side: BorderSide(
                                  color: Colors.grey.shade300,
                                  width: 1.5,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: Text(
                                'Nanti Saja',
                                style: TextStyle(
                                  color: Colors.grey.shade700,
                                  fontSize: 16,
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
        );
      },
    );
  }

  // FUNGSI UTAMA: Kirim rating via mailto
  Future<bool> _sendRatingViaMailTo({
    required int rating,
    required String comment,
  }) async {
    try {
      print('📧 Membuat email rating...');

      final userName = _currentUser.namaLengkap ?? 'Pengguna Warga App';
      final userEmail = _currentUser.email;

      // Format email yang lebih baik
      final subject = '⭐ Rating $rating/5 - Warga App - $userName';
      final body =
          '''
✉️ RATING DARI APLIKASI Warga App
──────────────────────────────────

👤 **INFORMASI PENGGUNA**
Nama: $userName
Email: $userEmail

⭐ **RATING APLIKASI**
Rating: $rating/5
${_getStars(rating)}

💭 **KOMENTAR**
${comment.isNotEmpty ? comment : 'Tidak ada komentar'}

📋 **INFORMASI TEKNIS**
Tanggal: ${DateTime.now().toLocal()}
Aplikasi: Warga App
Versi: 1.0.0
Platform: ${Platform.operatingSystem}

──────────────────────────────────
📱 Rating ini dikirim otomatis dari aplikasi Warga App
📧 Email pengguna: $userEmail
''';

      final mailtoUri =
          'mailto:nabilkencana20@gmail.com?'
          'subject=${Uri.encodeComponent(subject)}&'
          'body=${Uri.encodeComponent(body)}';

      print('📤 Mailto URI siap');
      print('   Subjek: $subject');
      print('   Panjang body: ${body.length} karakter');

      if (await canLaunchUrl(Uri.parse(mailtoUri))) {
        print('🚀 Membuka aplikasi email...');
        await launchUrl(Uri.parse(mailtoUri));
        print('✅ Aplikasi email dibuka');
        return true;
      } else {
        print('❌ Tidak bisa membuka mailto');
        return false;
      }
    } catch (e) {
      print('❌ Error mailto: $e');
      return false;
    }
  }

  // Helper: Buat string bintang
  String _getStars(int rating) {
    String stars = '';
    for (int i = 0; i < rating; i++) {
      stars += '★';
    }
    for (int i = rating; i < 5; i++) {
      stars += '☆';
    }
    return 'Bintang: $stars';
  }

  // Dialog jika mailto gagal (tampilkan data rating)
  void _showRatingManualDialog(
    BuildContext context,
    int rating,
    String comment,
  ) {
    final userName = _currentUser.namaLengkap ?? 'Pengguna Warga App';
    final userEmail = _currentUser.email;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.copy_all_rounded,
                color: Colors.blue.shade600,
                size: 50,
              ),
              const SizedBox(height: 20),

              const Text(
                'Salin Data Rating',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),

              Text(
                'Aplikasi email tidak dapat dibuka. Silakan salin data di bawah dan kirim manual ke:',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 8),

              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'nabilkencana20@gmail.com',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.amber.shade800,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Data rating yang bisa di-copy
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('👤 Nama: $userName'),
                    Text('📧 Email: $userEmail'),
                    Text('⭐ Rating: $rating/5 ${_getStars(rating)}'),
                    if (comment.isNotEmpty) Text('💭 Komentar: $comment'),
                    Text('📅 Tanggal: ${DateTime.now().toLocal()}'),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Tutup'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        final data =
                            '''
Nama: $userName
Email: $userEmail
Rating: $rating/5 ${_getStars(rating)}
${comment.isNotEmpty ? 'Komentar: $comment' : ''}
Tanggal: ${DateTime.now().toLocal()}
Aplikasi: Warga App
                      ''';

                        await Clipboard.setData(ClipboardData(text: data));
                        _showSuccessSnackbar('Data rating disalin!');
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade600,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.copy, size: 18),
                          SizedBox(width: 8),
                          Text('Salin'),
                        ],
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

  // Dialog sukses
  void _showRatingSuccessDialog(BuildContext context, int rating) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, color: Colors.green.shade600, size: 60),
            const SizedBox(height: 20),

            const Text(
              'Rating Terkirim!',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),

            Text(
              'Terima kasih atas rating $rating/5!',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 8),

            Text(
              'Aplikasi email telah terbuka. Silakan klik "Kirim".',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 20),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (int i = 1; i <= 5; i++)
                  Icon(
                    Icons.star_rounded,
                    color: i <= rating
                        ? Colors.amber.shade500
                        : Colors.grey.shade300,
                    size: 28,
                  ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Tutup',
              style: TextStyle(
                color: Colors.blue.shade600,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper functions (tetap sama)
  String _getRatingLabel(int rating) {
    switch (rating) {
      case 1:
        return 'Buruk';
      case 2:
        return 'Kurang Baik';
      case 3:
        return 'Cukup';
      case 4:
        return 'Baik';
      case 5:
        return 'Luar Biasa!';
      default:
        return 'Tap bintang untuk memberi rating';
    }
  }

  String _getEmojiForRating(int rating) {
    switch (rating) {
      case 1:
        return '😞';
      case 2:
        return '😕';
      case 3:
        return '😐';
      case 4:
        return '😊';
      case 5:
        return '🤩';
      default:
        return '⭐';
    }
  }

  Color _getRatingColor(int rating) {
    switch (rating) {
      case 1:
        return Colors.red.shade600;
      case 2:
        return Colors.orange.shade600;
      case 3:
        return Colors.amber.shade600;
      case 4:
        return Colors.lightGreen.shade600;
      case 5:
        return Colors.green.shade600;
      default:
        return Colors.grey.shade400;
    }
  }

  void _showInfoDialog(BuildContext context, String title, String content) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.all(16),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
            maxWidth: 600,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header dengan ikon dan judul
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 20,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade800, Colors.blue.shade400],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        title.contains('Privasi')
                            ? Icons.security_rounded
                            : Icons.description_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Badge versi dan tanggal
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  border: Border(
                    bottom: BorderSide(color: Colors.grey.shade200),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.update, size: 14, color: Colors.blue),
                          const SizedBox(width: 6),
                          Text(
                            'Versi 3.0 • 12 Des 2024',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.blue.shade800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: Icon(
                        Icons.close,
                        color: Colors.grey.shade500,
                        size: 20,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              // Konten dengan scroll
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Konten utama
                      SelectableText(
                        content,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade800,
                          height: 1.6,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Informasi tambahan
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '📋 Informasi Dokumen',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade800,
                              ),
                            ),
                            const SizedBox(height: 8),
                            _buildDocInfoRow('Status', 'Disetujui'),
                            _buildDocInfoRow(
                              'Penanggung Jawab',
                              'Data Protection Officer',
                            ),
                            _buildDocInfoRow(
                              'Tinjauan Berkala',
                              'Setiap 12 bulan',
                            ),
                            _buildDocInfoRow('Halaman', 'Halaman 1 dari 1'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Peringatan penting
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.orange.shade200),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.warning_amber_rounded,
                              color: Colors.orange.shade600,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Pernyataan Persetujuan',
                                    style: TextStyle(
                                      color: Colors.orange.shade800,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Dengan melanjutkan penggunaan aplikasi, Anda dianggap telah membaca, memahami, dan menyetujui seluruh ketentuan dalam dokumen ini.',
                                    style: TextStyle(
                                      color: Colors.orange.shade700,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Tombol aksi
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: Colors.grey.shade200)),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          // Simpan atau bagikan dokumen
                          _showSuccessSnackbar('Fitur penyimpanan akan datang');
                        },
                        icon: Icon(
                          Icons.download_rounded,
                          size: 18,
                          color: Colors.grey.shade600,
                        ),
                        label: Text(
                          'Simpan',
                          style: TextStyle(color: Colors.grey.shade700),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: BorderSide(color: Colors.grey.shade300),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(
                          Icons.check_circle,
                          size: 18,
                          color: Colors.white,
                        ),
                        label: const Text('Saya Mengerti'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade600,
                          padding: const EdgeInsets.symmetric(vertical: 12),
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
    );
  }

  Widget _buildDocInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade800),
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
            children: [
              // Judul
              const Text(
                'Konfirmasi Keluar',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),

              const SizedBox(height: 20),

              // Icon peringatan
              Icon(Icons.logout, color: Colors.red.shade600, size: 50),

              const SizedBox(height: 16),

              // Pesan konfirmasi
              const Text(
                'Apakah Anda yakin ingin keluar dari aplikasi?',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, color: Colors.grey, height: 1.5),
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
