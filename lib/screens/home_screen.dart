import 'package:flutter/material.dart';
import 'package:flutter_latihan1/models/notification_model_extension.dart';
import 'dart:async';
import '../models/user_model.dart';
import '../models/announcement_model.dart';
import '../models/notification_model.dart'; // TAMBAHKAN INI
import '../services/announcement_service.dart';
import '../services/auth_service.dart';
import '../services/profile_service.dart';
import '../services/notification_service.dart'; // TAMBAHKAN INI
import 'sos_screen.dart';
import 'laporan_screen.dart';
import 'profile_screen.dart';
import 'dana_screen.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  final User user;

  const HomeScreen({super.key, required this.user});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<List<Announcement>> _announcementsFuture;
  List<Announcement> _announcements = [];
  List<Announcement> _filteredAnnouncements = [];
  int _currentIndex = 0;
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;

  // 🔄 UPDATE: Ganti dengan notifikasi real
  List<NotificationModel> _notifications = [];
  int _unreadNotifications = 0;
  bool _isLoadingNotifications = false;

  // TAMBAHKAN: Flag untuk auth check
  bool _isCheckingAuth = true;
  bool _isAuthenticated = false;

  // TAMBAHKAN: User data yang bisa diupdate
  late User _currentUser;

  // TAMBAHKAN: Flag untuk loading foto profil
  bool _isLoadingProfile = false;

  // 🔄 TAMBAHKAN: Timer untuk refresh otomatis
  Timer? _notificationTimer;
  Timer? _announcementTimer;

  @override
  void initState() {
    super.initState();
    _currentUser = widget.user;
    _checkAuthentication();
    _announcementsFuture = AnnouncementService.getAnnouncements();

    // TAMBAHKAN: Load data profil saat init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUserProfileData();
    });

    // 🔄 TAMBAHKAN: Mulai timer untuk refresh otomatis
    _startAutoRefresh();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _notificationTimer?.cancel();
    _announcementTimer?.cancel();
    super.dispose();
  }

  // 🔄 TAMBAHKAN: Fungsi untuk start auto refresh
  void _startAutoRefresh() {
    // Refresh notifikasi setiap 30 detik
    _notificationTimer = Timer.periodic(
      Duration(seconds: 30),
      (timer) => _loadNotifications(),
    );

    // Refresh pengumuman setiap 1 menit
    _announcementTimer = Timer.periodic(
      Duration(minutes: 1),
      (timer) => _refreshAnnouncements(),
    );
  }

  // 🔄 UPDATE: Fungsi untuk load notifikasi real
  Future<void> _loadNotifications({bool showLoading = false}) async {
    if (_isLoadingNotifications) return;

    try {
      if (showLoading) {
        setState(() => _isLoadingNotifications = true);
      }

      // Load unread count
      final unreadCount = await NotificationService.getUnreadCount();

      // Load notifications
      final notifications = await NotificationService.getNotifications(
        isRead: false,
        limit: 20,
      );

      if (mounted) {
        setState(() {
          _notifications = notifications;
          _unreadNotifications = unreadCount;
        });
      }
    } catch (e) {
      print('⚠️ Error loading notifications: $e');
      _loadFallbackNotifications();
    } finally {
      if (showLoading && mounted) {
        setState(() => _isLoadingNotifications = false);
      }
    }
  }

  // 🔄 TAMBAHKAN: Fallback notifications untuk development
  void _loadFallbackNotifications() {
    setState(() {
      _notifications = [
        NotificationModel(
          id: '1',
          userId:
              int.tryParse(widget.user.id.toString()) ?? 1, // Convert ke int
          type: NotificationType.COMMUNITY,
          title: 'Kerja Bakti Bersama',
          message: 'Anda telah bergabung dalam kegiatan kerja bakti',
          icon: 'people',
          iconColor: '#10B981',
          isRead: false,
          isArchived: false,
          createdBy: 1,
          createdAt: DateTime.now().subtract(Duration(minutes: 5)),
          updatedAt: DateTime.now(),
        ),
        NotificationModel(
          id: '2',
          userId: int.tryParse(widget.user.id.toString()) ?? 1,
          type: NotificationType.ANNOUNCEMENT,
          title: 'Pengumuman Baru',
          message: 'Ada pengumuman penting dari admin',
          icon: 'announcement',
          iconColor: '#3B82F6',
          isRead: false,
          isArchived: false,
          createdBy: 1,
          createdAt: DateTime.now().subtract(Duration(hours: 1)),
          updatedAt: DateTime.now(),
        ),
      ];
      _unreadNotifications = 2;
    });
  }

  // 🔄 UPDATE: Fungsi untuk mark notification as read
  void _markNotificationAsRead(String notificationId) async {
    try {
      final success = await NotificationService.markAsRead(notificationId);

      if (success) {
        setState(() {
          final index = _notifications.indexWhere(
            (notif) => notif.id == notificationId,
          );
          if (index != -1) {
            _notifications[index] = _notifications[index].copyWith(
              isRead: true,
              readAt: DateTime.now(),
            );
            _unreadNotifications--;
          }
        });
      }
    } catch (e) {
      print('⚠️ Error marking notification as read: $e');
    }
  }

  // 🔄 UPDATE: Fungsi untuk mark all notifications as read
  void _markAllNotificationsAsRead() async {
    try {
      final success = await NotificationService.markAllAsRead();

      if (success) {
        setState(() {
          _notifications = _notifications.map((notif) {
            return notif.copyWith(isRead: true, readAt: DateTime.now());
          }).toList();
          _unreadNotifications = 0;
        });
      }
    } catch (e) {
      print('⚠️ Error marking all notifications as read: $e');
    }
  }

  // TAMBAHKAN: Fungsi untuk load data profil terbaru dengan handling foto profil
  Future<void> _loadUserProfileData() async {
    if (_isLoadingProfile) return;

    try {
      setState(() => _isLoadingProfile = true);

      final token = await AuthService.getToken();
      if (token != null && token.isNotEmpty) {
        final profileData = await ProfileService.getProfile();

        if (mounted) {
          setState(() {
            if (profileData['user'] != null) {
              _currentUser = User.fromJson(profileData['user']);
            } else if (profileData['id'] != null) {
              _currentUser = User.fromJson(profileData);
            }

            // Log untuk debugging foto profil
            print('🖼️ Profile photo URL: ${_currentUser.fotoProfil}');
            print(
              '🖼️ Has foto: ${_currentUser.fotoProfil != null && _currentUser.fotoProfil!.isNotEmpty}',
            );
          });
        }
      }
    } catch (e) {
      print('⚠️ Error loading user profile data in HomeScreen: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingProfile = false);
      }
    }
  }

  // TAMBAHKAN: Fungsi untuk cek authentication
  Future<void> _checkAuthentication() async {
    setState(() => _isCheckingAuth = true);

    try {
      // 1. Cek token
      final token = await AuthService.getToken();
      print('🔍 Checking auth in HomeScreen:');
      print('   Token exists: ${token != null}');
      print('   Token length: ${token?.length}');

      // 2. Cek user data
      final storedUser = await AuthService.getUser();
      print('   Stored user: ${storedUser?.email}');
      print('   Widget user: ${widget.user.email}');

      if (token == null || token.isEmpty) {
        print('❌ No token found, redirecting to login...');
        _redirectToLogin();
        return;
      }

      // 3. Validate user consistency
      if (storedUser == null || storedUser.id != widget.user.id) {
        print('⚠️ User mismatch, using widget user');
      }

      // 4. Load data profil terbaru
      await _loadUserProfileData();

      // 🔄 TAMBAHKAN: Load notifikasi setelah auth berhasil
      await _loadNotifications(showLoading: true);

      setState(() {
        _isAuthenticated = true;
        _isCheckingAuth = false;
      });

      print('✅ Authentication check passed');
    } catch (e) {
      print('❌ Auth check error: $e');
      _redirectToLogin();
    }
  }

  // TAMBAHKAN: Fungsi untuk redirect ke login
  void _redirectToLogin() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    });
  }

  // TAMBAHKAN: Fungsi untuk logout
  Future<void> _logout() async {
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
              // Icon peringatan
              Center(
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.exit_to_app_rounded,
                    color: Colors.red.shade600,
                    size: 32,
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Judul
              const Center(
                child: Text(
                  'Keluar',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),

              const SizedBox(height: 12),

              // Pesan konfirmasi
              const Center(
                child: Text(
                  'Apakah Anda yakin ingin keluar dari aplikasi?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.grey,
                    height: 1.4,
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // Tombol aksi
              Row(
                children: [
                  // Tombol Batal
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

                  // Tombol Keluar
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(context);
                        await AuthService.logout();
                        _redirectToLogin();
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

  // MODIFIKASI: Widget untuk menampilkan foto profil
  Widget _buildProfileAvatar({double size = 48}) {
    if (_isLoadingProfile) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          border: Border.all(color: Colors.white, width: 2),
        ),
        child: Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade600),
          ),
        ),
      );
    }

    // Cek apakah ada foto profil dari API
    final hasPhoto =
        _currentUser.fotoProfil != null &&
        _currentUser.fotoProfil!.isNotEmpty &&
        _currentUser.fotoProfil!.startsWith('http');

    // Cek apakah ada inisial nama dari user
    final userName =
        _currentUser.namaLengkap ?? _currentUser.email.split('@')[0];
    final initials = _getInitials(userName);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.shade800.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: hasPhoto
          ? ClipOval(
              child: Image.network(
                _currentUser.fotoProfil!,
                fit: BoxFit.cover,
                width: size,
                height: size,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.white, _getColorFromName(userName)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Center(
                      child: CircularProgressIndicator(
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded /
                                  loadingProgress.expectedTotalBytes!
                            : null,
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.blue.shade600,
                        ),
                      ),
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return _buildInitialsAvatar(userName, initials, size);
                },
              ),
            )
          : _buildInitialsAvatar(userName, initials, size),
    );
  }

  // TAMBAHKAN: Fungsi untuk membuat avatar dengan inisial
  Widget _buildInitialsAvatar(String userName, String initials, double size) {
    final color = _getColorFromName(userName);

    return Container(
      width: size,
      height : size, 
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.9), color.withOpacity(0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: BoxShape.circle
      ),
      child: Center(
        child: FittedBox(
          // TAMBAHKAN: Gunakan FittedBox
          fit: BoxFit.scaleDown,
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              initials,
              style: TextStyle(
                color: Colors.white,
                fontSize: size * 0.3, // PERKECIL sedikit ukuran font
                fontWeight: FontWeight.bold,
                height: 1.0, // TAMBAHKAN: Set height ke 1.0
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }

  // TAMBAHKAN: Fungsi untuk mendapatkan inisial dari nama
  String _getInitials(String name) {
    final nameParts = name.trim().split(' ');
    if (nameParts.length >= 2) {
      return '${nameParts[0][0]}${nameParts[1][0]}'.toUpperCase();
    } else if (nameParts[0].isNotEmpty) {
      return nameParts[0][0].toUpperCase();
    }
    return 'U';
  }

  // TAMBAHKAN: Fungsi untuk mendapatkan warna konsisten berdasarkan nama
  Color _getColorFromName(String name) {
    const colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.pink,
      Colors.indigo,
      Colors.cyan,
      Colors.amber,
      Colors.deepPurple,
    ];

    // Gunakan hash nama untuk menentukan warna yang konsisten
    final hashCode = name.hashCode.abs();
    return colors[hashCode % colors.length];
  }

  // MODIFIKASI: Fungsi _buildProfileMenuItem dengan visual yang lebih baik
  Widget _buildProfileMenuItem({
    required IconData icon,
    required String text,
    required Color color,
    required VoidCallback onTap,
    bool isLogout = false,
  }) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isLogout ? Colors.red.shade50 : color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          color: isLogout ? Colors.red.shade600 : color,
          size: 22,
        ),
      ),
      title: Text(
        text,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: isLogout ? Colors.red.shade700 : Colors.grey.shade800,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: isLogout ? Colors.red.shade400 : Colors.grey.shade400,
      ),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    );
  }

  // MODIFIKASI: Menu profile dengan foto yang sama
  void _showProfile() {
    // Refresh data profil sebelum menampilkan
    _loadUserProfileData();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.35,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: Column(
          children: [
            // Drag indicator
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header profil dengan foto yang sama
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  _buildProfileAvatar(size: 60),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _currentUser.namaLengkap ?? 'User',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _currentUser.email,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blue.shade100),
                          ),
                          child: Text(
                            _currentUser.role?.toUpperCase() ?? 'USER',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.blue.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const Divider(height: 1, thickness: 1),

            // Menu opsi
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  _buildProfileMenuItem(
                    icon: Icons.person_outline,
                    text: 'Profil Saya',
                    color: Colors.blue.shade600,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              ProfileScreen(user: _currentUser),
                        ),
                      ).then((_) {
                        // Refresh data profil setelah kembali dari ProfileScreen
                        _loadUserProfileData();
                      });
                    },
                  ),

                  const SizedBox(height: 8),

                  // Separator untuk logout
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Divider(color: Colors.grey.shade200, thickness: 1),
                  ),

                  _buildProfileMenuItem(
                    icon: Icons.logout_rounded,
                    text: 'Keluar',
                    color: Colors.red.shade600,
                    onTap: () {
                      Navigator.pop(context);
                      _logout();
                    },
                    isLogout: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // TAMBAHKAN: Loading saat cek auth
  Widget _buildAuthChecking() {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 20),
            Text('Memeriksa autentikasi...'),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // TAMBAHKAN: Tampilkan loading jika sedang cek auth
    if (_isCheckingAuth) {
      return _buildAuthChecking();
    }

    // TAMBAHKAN: Tampilkan error jika tidak terautentikasi
    if (!_isAuthenticated) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, color: Colors.red, size: 64),
              const SizedBox(height: 20),
              const Text(
                'Sesi telah berakhir',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              const Text('Silakan login kembali'),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _redirectToLogin,
                child: const Text('Login Ulang'),
              ),
            ],
          ),
        ),
      );
    }

    // KODE ASAL YANG SUDAH ADA
    return Scaffold(
      body: _currentIndex == 0 ? _buildHomeContent() : _buildOtherScreen(),
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  Widget _buildOtherScreen() {
    switch (_currentIndex) {
      case 0:
        return _buildHomeContent();
      case 1:
        return SosScreen(user: _currentUser);
      case 2:
        return LaporanScreen(user: _currentUser);
      case 3:
        return DanaScreen(user: _currentUser);
      default:
        return _buildHomeContent();
    }
  }

  Widget _buildHomeContent() {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshAnnouncements,
          child: FutureBuilder<List<Announcement>>(
            future: _announcementsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return _buildLoadingState();
              } else if (snapshot.hasError) {
                return _buildErrorState(snapshot.error.toString());
              } else if (snapshot.hasData) {
                _announcements = snapshot.data!;
                _filteredAnnouncements = _announcements;
                return _buildContent();
              } else {
                return _buildEmptyState();
              }
            },
          ),
        ),
      ),
    );
  }

  Future<void> _refreshAnnouncements() async {
    setState(() {
      _announcementsFuture = AnnouncementService.getAnnouncements();
    });

    // 🔄 TAMBAHKAN: Refresh notifikasi juga
    await _loadNotifications();
  }

  void _onItemTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  void _handleSearch(String query) {
    setState(() {
      _isSearching = query.isNotEmpty;
      if (query.isEmpty) {
        _filteredAnnouncements = _announcements;
      } else {
        _filteredAnnouncements = _announcements.where((announcement) {
          return announcement.title.toLowerCase().contains(
                query.toLowerCase(),
              ) ||
              announcement.description.toLowerCase().contains(
                query.toLowerCase(),
              ) ||
              announcement.targetAudience.toLowerCase().contains(
                query.toLowerCase(),
              );
        }).toList();
      }
    });
  }

  void _clearSearch() {
    setState(() {
      _searchController.clear();
      _isSearching = false;
      _filteredAnnouncements = _announcements;
    });
  }

  // 🔄 UPDATE: Fungsi untuk show notifications dengan data real
  void _showNotifications() {
    // Refresh notifikasi sebelum menampilkan
    _loadNotifications();

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
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade700,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Notifikasi',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const Spacer(),
                    if (_unreadNotifications > 0)
                      GestureDetector(
                        onTap: () {
                          _markAllNotificationsAsRead();
                          Navigator.pop(context);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.done_all,
                                color: Colors.white,
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '$_unreadNotifications Baru',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: _isLoadingNotifications
                    ? Center(child: CircularProgressIndicator())
                    : _notifications.isEmpty
                    ? _buildEmptyNotifications()
                    : ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          ..._notifications.map((notification) {
                            return Column(
                              children: [
                                _buildNotificationItem(notification),
                                const SizedBox(height: 12),
                              ],
                            );
                          }).toList(),
                        ],
                      ),
              ),
            ],
          ),
        );
      },
    ).then((_) {
      // Update badge count setelah modal ditutup
      setState(() {
        _unreadNotifications = _notifications
            .where((notif) => !notif.isRead)
            .length;
      });
    });
  }

  // 🔄 UPDATE: Widget untuk menampilkan notifikasi real
  Widget _buildNotificationItem(NotificationModel notification) {
    return GestureDetector(
      onTap: () {
        if (!notification.isRead) {
          _markNotificationAsRead(notification.id);
        }
        _handleNotificationAction(notification);
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ListTile(
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: notification.color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              notification.iconData,
              color: notification.color,
              size: 20,
            ),
          ),
          title: Text(
            notification.title,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: notification.isRead
                  ? Colors.grey.shade600
                  : Colors.black87,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                notification.message,
                style: TextStyle(
                  color: notification.isRead
                      ? Colors.grey.shade500
                      : Colors.grey.shade600,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                notification.timeAgo,
                style: TextStyle(color: Colors.grey.shade400, fontSize: 10),
              ),
            ],
          ),
          trailing: !notification.isRead
              ? Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                )
              : const SizedBox(width: 8),
        ),
      ),
    );
  }

  // 🔄 TAMBAHKAN: Handle notification action
  void _handleNotificationAction(NotificationModel notification) {
    final data = notification.data;
    if (data != null && data['action'] != null) {
      switch (data['action']) {
        case 'view_announcement':
          final announcementId = data['announcementId'];
          _showAnnouncementDetailsById(announcementId);
          break;
        case 'view_bill':
          final billId = data['billId'];
          _showBillDetails(billId);
          break;
        case 'view_payment':
          final paymentId = data['paymentId'];
          _showPaymentDetails(paymentId);
          break;
        case 'view_emergency':
          final emergencyId = data['emergencyId'];
          _showEmergencyDetails(emergencyId);
          break;
        case 'view_report':
          final reportId = data['reportId'];
          _showReportDetails(reportId);
          break;
        case 'view_profile':
          _showProfile();
          break;
      }
    }
  }

  // 🔄 TAMBAHKAN: Fungsi untuk menampilkan detail berdasarkan ID
  void _showAnnouncementDetailsById(int announcementId) {
    final announcement = _announcements.firstWhere(
      (a) => a.id == announcementId,
      orElse: () => Announcement(
        id: 0,
        title: 'Pengumuman',
        description: 'Detail pengumuman',
        targetAudience: 'Semua warga',
        date: DateTime.now(),
        day: 'Hari ini', // ✅ HARUS ADA karena required
        createdAt: DateTime.now(),
        admin: Admin(
          // ✅ Gunakan Admin bukan User
          id: 0,
          namaLengkap: 'Admin',
          email: 'admin@example.com',
        ),
      ),
    );

    _showAnnouncementDetails(announcement);
  }

  // 🔄 TAMBAHKAN: Fungsi untuk menampilkan detail tagihan
  void _showBillDetails(String billId) {
    // Navigasi ke screen tagihan
    // Navigator.push(
    //   context,
    //   MaterialPageRoute(
    //     builder: (context) => BillDetailScreen(billId: billId),
    //   ),
    // );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Melihat detail tagihan: $billId'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  // 🔄 TAMBAHKAN: Fungsi untuk menampilkan detail pembayaran
  void _showPaymentDetails(int paymentId) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Melihat detail pembayaran: $paymentId'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  // 🔄 TAMBAHKAN: Fungsi untuk menampilkan detail emergency
  void _showEmergencyDetails(int emergencyId) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Melihat detail emergency: $emergencyId'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  // 🔄 TAMBAHKAN: Fungsi untuk menampilkan detail laporan
  void _showReportDetails(int reportId) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Melihat detail laporan: $reportId'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Widget _buildEmptyNotifications() {
    return Container(
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          Icon(
            Icons.notifications_off_outlined,
            color: Colors.grey.shade400,
            size: 64,
          ),
          const SizedBox(height: 16),
          Text(
            'Tidak ada notifikasi',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Notifikasi akan muncul di sini ketika ada pembaruan',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _loadNotifications,
            icon: Icon(Icons.refresh),
            label: Text('Refresh'),
          ),
        ],
      ),
    );
  }

  void _joinWorkActivity() {
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
              // Header
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.people_alt_rounded,
                      color: Colors.green.shade700,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Bergabung Kerja Bakti',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Deskripsi
              const Text(
                'Apakah Anda yakin ingin bergabung dalam kegiatan kerja bakti bersama warga?',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),

              const SizedBox(height: 20),

              // Detail kegiatan
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    _buildDetailRow(
                      Icons.calendar_today,
                      'Minggu, 15 Desember 2024',
                      Colors.blue,
                    ),
                    const SizedBox(height: 10),
                    _buildDetailRow(
                      Icons.access_time,
                      '08.00 - 12.00 WIB',
                      Colors.orange,
                    ),
                    const SizedBox(height: 10),
                    _buildDetailRow(
                      Icons.location_on,
                      'Lapangan RT 05',
                      Colors.red,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Tombol aksi
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: Colors.red.shade400),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Batal',
                        style: TextStyle(
                          color: Colors.red.shade600,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _showJoinSuccess();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      child: const Text(
                        'Ya, Bergabung',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
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

  Widget _buildDetailRow(IconData icon, String text, Color color) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade800),
          ),
        ),
      ],
    );
  }

  void _showJoinSuccess() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 8),
            Text('Berhasil bergabung dalam kerja bakti!'),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Widget _buildLoadingState() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 24),
          _buildBannerShimmer(),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Divider(color: Colors.grey.shade300, thickness: 1),
          ),
          const SizedBox(height: 16),
          _buildAnnouncementsShimmer(),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Column(
        children: [
          _buildHeader(),
          const SizedBox(height: 40),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.error_outline,
                    color: Colors.red.shade400,
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Gagal memuat pengumuman',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.red.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    error,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.red.shade600, fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _refreshAnnouncements,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade600,
                    ),
                    child: const Text(
                      'Coba Lagi',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Column(
        children: [
          _buildHeader(),
          const SizedBox(height: 40),
          _buildEmptyAnnouncements(),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 24),
          _buildBanner(),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Divider(color: Colors.grey.shade300, thickness: 1),
          ),
          const SizedBox(height: 16),
          _buildAnnouncementsList(),
        ],
      ),
    );
  }

  // === HEADER YANG DIPERBAIKI - DENGAN FOTO PROFIL YANG SAMA ===
  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade700, Colors.blue.shade500],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.shade800.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Foto Profil yang sama dengan ProfileScreen
              GestureDetector(
                onTap: _showProfile,
                child: _buildProfileAvatar(),
              ),
              GestureDetector(
                onTap: _showNotifications,
                child: Stack(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.notifications_outlined,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    if (_unreadNotifications > 0)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          child: Text(
                            _unreadNotifications > 9
                                ? '9+'
                                : '$_unreadNotifications',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // MODIFIKASI: Gunakan _currentUser.namaLengkap bukan widget.user.name
          Text(
            'Hai, ${_currentUser.namaLengkap?.split(' ')[0] ?? 'User'}!',
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _getGreeting(),
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 16,
              fontWeight: FontWeight.w400,
            ),
          ),

          const SizedBox(height: 24),

          // Search Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(25),
            child: Container(
              height: 50,
              color: Colors.white,
              child: Row(
                children: [
                  const SizedBox(width: 16),
                  Icon(Icons.search, color: Colors.blue.shade400, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(
                        hintText:
                            'Cari pengumuman, kegiatan, atau informasi...',
                        border: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        errorBorder: InputBorder.none,
                        disabledBorder: InputBorder.none,
                        focusedErrorBorder: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                        hintStyle: TextStyle(color: Colors.grey, fontSize: 14),
                      ),
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade800,
                        height: 2.0,
                      ),
                      onChanged: _handleSearch,
                    ),
                  ),
                  // Tombol aksi
                  if (_isSearching)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: IconButton(
                        icon: Icon(
                          Icons.clear,
                          color: Colors.grey.shade500,
                          size: 20,
                        ),
                        onPressed: _clearSearch,
                      ),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: Icon(
                            Icons.filter_list_rounded,
                            color: Colors.blue.shade600,
                            size: 18,
                          ),
                          onPressed: _showFilterOptions,
                          padding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // TAMBAHKAN FUNGSI FILTER (OPTIONAL)
  void _showFilterOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: 300,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Filter Pengumuman',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Text(
                'Kategori',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              // Tambahkan opsi filter di sini
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildFilterChip('Semua', true),
                  _buildFilterChip('Kegiatan', false),
                  _buildFilterChip('Informasi', false),
                  _buildFilterChip('Penting', false),
                ],
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Terapkan Filter',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, bool isSelected) {
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        // Handle filter selection
      },
      selectedColor: Colors.blue.shade100,
      checkmarkColor: Colors.blue,
      labelStyle: TextStyle(
        color: isSelected ? Colors.blue.shade700 : Colors.grey.shade700,
      ),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Selamat pagi, semoga hari Anda menyenangkan!';
    } else if (hour < 15) {
      return 'Selamat siang, semoga aktivitas lancar!';
    } else if (hour < 19) {
      return 'Selamat sore, semoga hari Anda berjalan baik!';
    } else {
      return 'Selamat malam, semoga istirahat Anda nyenyak!';
    }
  }

  // === BANNER YANG DIPERBAIKI ===
  Widget _buildBanner() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
          border: Border.all(color: Colors.grey.shade100),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
              child: Image.asset(
                'assets/images/OIP.webp',
                height: 160,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 160,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.blue.shade50, Colors.blue.shade100],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: const Icon(
                      Icons.people_alt_outlined,
                      color: Colors.blue,
                      size: 60,
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.orange.shade100),
                        ),
                        child: Text(
                          'Kegiatan',
                          style: TextStyle(
                            color: Colors.orange.shade700,
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
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.green.shade100),
                        ),
                        child: Text(
                          'Komunitas',
                          style: TextStyle(
                            color: Colors.green.shade700,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Kerja Bakti Bersama Warga',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Mari bersama-sama membersihkan lingkungan sekitar untuk menciptakan suasana yang lebih nyaman dan sehat bagi semua warga.',
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.blue.shade100),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.calendar_today,
                              color: Colors.blue.shade600,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Minggu, 08.00 WIB',
                              style: TextStyle(
                                color: Colors.blue.shade700,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      // Tombol Ikuti - DIFUNGSIKAN
                      GestureDetector(
                        onTap: _joinWorkActivity,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.blue.shade600,
                                Colors.blue.shade400,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.blue.shade300.withOpacity(0.4),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Text(
                            'Ikuti',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
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
    );
  }

  // === ANNOUNCEMENTS LIST YANG DIPERBAIKI ===
  Widget _buildAnnouncementsList() {
    final announcementsToShow = _isSearching
        ? _filteredAnnouncements
        : _announcements;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                _isSearching ? 'Hasil Pencarian' : 'Pengumuman Terbaru',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${announcementsToShow.length} items',
                  style: TextStyle(
                    color: Colors.blue.shade700,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (announcementsToShow.isEmpty)
            _buildEmptySearchResults()
          else
            ..._buildAnnouncementsItems(announcementsToShow),
        ],
      ),
    );
  }

  List<Widget> _buildAnnouncementsItems(List<Announcement> announcements) {
    List<Widget> items = [];
    for (int i = 0; i < announcements.length; i++) {
      final announcement = announcements[i];
      items.add(_buildAnnouncementItem(announcement));

      if (i < announcements.length - 1) {
        items.add(const SizedBox(height: 16));
      }
    }
    return items;
  }

  Widget _buildAnnouncementItem(Announcement announcement) {
    return Container(
      decoration: BoxDecoration(
        color: announcement.backgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: announcement.borderColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showAnnouncementDetails(announcement),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Tanggal dengan design yang lebih menarik
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    color: announcement.dateColor,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: announcement.dateColor.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        announcement.date.day.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        announcement.monthName.substring(0, 3),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                // Konten pengumuman
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            announcement.dayIcon,
                            color: announcement.dateColor,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            announcement.dayName,
                            style: TextStyle(
                              color: announcement.dateColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          if (announcement.isHoliday)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.red.shade100),
                              ),
                              child: Text(
                                'LIBUR',
                                style: TextStyle(
                                  color: Colors.red.shade600,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        announcement.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Text(
                          announcement.targetAudience,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            color: Colors.grey.shade500,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            announcement.day,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: announcement.dateColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _getDayType(announcement),
                              style: TextStyle(
                                color: announcement.dateColor,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
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
      ),
    );
  }

  Widget _buildEmptySearchResults() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        children: [
          Icon(Icons.search_off_rounded, color: Colors.grey.shade400, size: 48),
          const SizedBox(height: 16),
          const Text(
            'Tidak ada hasil pencarian',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tidak ada pengumuman yang cocok dengan "${_searchController.text}"',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _clearSearch,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            child: const Text(
              'Tampilkan Semua',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  String _getDayType(Announcement announcement) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final announcementDay = DateTime(
      announcement.date.year,
      announcement.date.month,
      announcement.date.day,
    );

    if (announcementDay.isAtSameMomentAs(today)) {
      return 'HARI INI';
    } else if (announcement.isHoliday) {
      return 'LIBUR';
    } else {
      switch (announcement.date.weekday) {
        case DateTime.friday:
          return 'JUMAT';
        case DateTime.saturday:
          return 'SABTU';
        case DateTime.sunday:
          return 'MINGGU';
        default:
          return 'BIASA';
      }
    }
  }

  // === EMPTY ANNOUNCEMENTS ===
  Widget _buildEmptyAnnouncements() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Column(
          children: [
            Icon(
              Icons.announcement_outlined,
              color: Colors.grey.shade400,
              size: 48,
            ),
            const SizedBox(height: 16),
            const Text(
              'Belum ada pengumuman',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Pengumuman akan muncul di sini ketika admin membuat pengumuman baru',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  // === SHIMMER EFFECTS FOR LOADING ===
  Widget _buildBannerShimmer() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 160,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 20,
                    width: 120,
                    color: Colors.grey.shade200,
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 16,
                    width: double.infinity,
                    color: Colors.grey.shade200,
                  ),
                  const SizedBox(height: 4),
                  Container(
                    height: 16,
                    width: 200,
                    color: Colors.grey.shade200,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnnouncementsShimmer() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(height: 24, width: 120, color: Colors.grey.shade200),
          const SizedBox(height: 16),
          ...List.generate(3, (index) => _buildAnnouncementItemShimmer()),
        ],
      ),
    );
  }

  Widget _buildAnnouncementItemShimmer() {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 20,
                    width: 150,
                    color: Colors.grey.shade200,
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 16,
                    width: 100,
                    color: Colors.grey.shade200,
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 14,
                    width: 120,
                    color: Colors.grey.shade200,
                  ),
                ],
              ),
            ),
            Container(width: 24, height: 24, color: Colors.grey.shade200),
          ],
        ),
        const SizedBox(height: 16),
        Container(height: 1, color: Colors.grey.shade300),
        const SizedBox(height: 16),
      ],
    );
  }

  // === BOTTOM NAV BAR YANG DIPERBAIKI ===
  Widget _buildBottomNavBar() {
    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(Icons.home_filled, 'Home', 0),
          _buildNavItem(Icons.emergency_outlined, 'SOS', 1),
          _buildNavItem(Icons.report_outlined, 'Laporan', 2),
          _buildNavItem(Icons.account_balance_wallet_outlined, 'Dana', 3),
        ],
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    bool active = _currentIndex == index;
    return GestureDetector(
      onTap: () => _onItemTapped(index),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: active ? Colors.blue.shade50 : Colors.transparent,
              shape: BoxShape.circle,
              border: active
                  ? Border.all(color: Colors.blue.shade100, width: 2)
                  : null,
            ),
            child: Icon(
              icon,
              color: active ? Colors.blue : Colors.grey.shade600,
              size: 22,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: active ? Colors.blue : Colors.grey.shade600,
              fontSize: 11,
              fontWeight: active ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  // === SHOW ANNOUNCEMENT DETAILS ===
  void _showAnnouncementDetails(Announcement announcement) {
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
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Column(
            children: [
              // Header dengan drag indicator
              Container(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Tanggal
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: announcement.dateColor,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              announcement.date.day.toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              announcement.monthName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Judul
                      Text(
                        announcement.title,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Info
                      Row(
                        children: [
                          Icon(
                            Icons.people_outline,
                            color: Colors.grey.shade600,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            announcement.targetAudience,
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 20),
                          Icon(
                            Icons.access_time,
                            color: Colors.grey.shade600,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${announcement.dayName}, ${announcement.day}',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      // Deskripsi
                      Text(
                        announcement.description,
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 16,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Dibuat oleh
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.person, color: Colors.grey),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Dibuat oleh',
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  announcement.admin.namaLengkap,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
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
}
