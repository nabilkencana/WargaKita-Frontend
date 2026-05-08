import 'package:flutter/material.dart';
import 'package:warga_app/config/config.dart';
import 'package:warga_app/models/notification_model_extension.dart';
import 'package:warga_app/services/websocket_service.dart';
import 'package:flutter/widgets.dart';
import 'dart:async';
import '../models/user_model.dart';
import '../models/announcement_model.dart';
import '../models/notification_model.dart'; // TAMBAHKAN INI
import '../services/announcement_service.dart';
import '../services/auth_service.dart';
import '../services/profile_service.dart';
import '../services/notification_service.dart'; // TAMBAHKAN INI
import 'package:cached_network_image/cached_network_image.dart';
import 'sos_screen.dart';
import 'laporan_screen.dart';
import 'profile_screen.dart';
import 'dana_screen.dart';
import 'login_screen.dart';
import 'satpam_dashboard_screen.dart';

class HomeScreen extends StatefulWidget {
  final User user;

  const HomeScreen({super.key, required this.user});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  late Future<List<Announcement>> _announcementsFuture;
  List<Announcement> _announcements = [];
  List<Announcement> _filteredAnnouncements = [];
  int _currentIndex = 0;
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  String _searchQuery = '';
  String _selectedFilter = 'Semua'; // Filter aktif saat ini
  bool _isFilterActive = false; // apakah ada filter selain 'Semua'

  // 🔄 UPDATE: Ganti dengan notifikasi real
  bool _popupOpen = false;
  List<NotificationModel> _notifications = [];
  int _unreadNotifications = 0;
  bool _isLoadingNotifications = false;

  // TAMBAHKAN: User data yang bisa diupdate
  late User _currentUser;

  // TAMBAHKAN: Flag untuk loading foto profil
  bool _isLoadingProfile = false;

  // 🔄 TAMBAHKAN: Timer untuk refresh otomatis
  Timer? _notificationTimer;
  Timer? _announcementTimer;

  // TAMBAHKAN variable untuk tracking last load time
  DateTime? _lastProfileLoadTime;

  // TAMBAHKAN: WebSocket Service
  final WebSocketService _webSocketService = WebSocketService();

  @override
  void initState() {
    super.initState();
    _currentUser = widget.user;

    WidgetsBinding.instance.addObserver(this);

    _announcementsFuture = AnnouncementService.getAnnouncements();

    // Inisialisasi WebSocket
    _initWebSocket();

    // Load data background tanpa blocking
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadEverythingInBackground();
    });
  }

  Future<void> _initWebSocket() async {
    try {
      print('🔄 Initializing WebSocket...');

      // 1. Get user ID
      int userId;
      if (widget.user.id is String) {
        userId = int.tryParse(widget.user.id as String) ?? 1;
      } else if (widget.user.id is int) {
        userId = widget.user.id as int;
      } else {
        userId = 1;
      }

      print('👤 Using user ID: $userId');
      print('📡 API URL: ${Config.apiUrl}');

      // 2. Setup callback SEBELUM connect
      _webSocketService.onNotificationReceived = (notification) {
        if (!mounted) return;

        final data = Map<String, dynamic>.from(notification);

        // ✅ update data cepat
        final notificationModel = NotificationModel.fromJson(data);

        setState(() {
          _notifications.insert(0, notificationModel);
        });

        // ✅ popup LANGSUNG (tanpa async)
        _showRealtimeNotificationPopup(data);
      };

      _webSocketService.onAnnouncementReceived = (announcement) {
        print('📢 Announcement received');
        _handleIncomingAnnouncement(announcement);
      };

      // 3. Connect (TANPA await)
      _webSocketService.connect(userId);

      // 4. Optional: tunggu sebentar lalu cek status
      Future.delayed(const Duration(seconds: 2), () {
        if (_webSocketService.isConnected) {
          print('✅ WebSocket connected successfully');
          _sendTestPing();
        } else {
          print('⚠️ WebSocket still connecting...');
        }
      });
    } catch (e) {
      print('❌ Error initializing WebSocket: $e');
    }
  }

  void _showRealtimeNotificationPopup(Map<String, dynamic> notification) {
    if (_popupOpen) return;

    _popupOpen = true;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.notifications_active, color: Colors.orange),
            SizedBox(width: 8),
            Text('Notifikasi Baru'),
          ],
        ),
        content: Text(notification['title'] ?? 'Ada notifikasi baru'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _popupOpen = false;
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _sendTestPing() {
    try {
      // Kirim ping untuk test
      print('🏓 Sending test ping...');
      // Note: Anda perlu menambahkan method untuk send message ke WebSocketService
    } catch (e) {
      print('⚠️ Error sending ping: $e');
    }
  }

  void _handleIncomingAnnouncement(Map<String, dynamic> announcement) {
    // Konversi data announcement ke model
    final announcementModel = Announcement(
      id: announcement['announcementId'] ?? 0,
      title: announcement['title']?.toString() ?? 'Pengumuman Baru',
      description: announcement['message']?.toString() ?? '',
      targetAudience:
          announcement['targetAudience']?.toString() ?? 'ALL_RESIDENTS',
      date: DateTime.now(),
      day: 'Hari ini',
      createdAt: DateTime.now(),
      admin: Admin(
        id: announcement['createdBy'] ?? 0,
        namaLengkap: announcement['createdByName']?.toString() ?? 'Admin',
        email: '',
      ),
    );

    // Tambahkan announcement ke list
    setState(() {
      _announcements.insert(0, announcementModel);
      _filteredAnnouncements = _announcements;
    });

    // Tampilkan snackbar khusus untuk announcement
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.announcement, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '📢 Pengumuman Baru',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    announcement['title']?.toString() ?? '',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: Colors.blue.shade800,
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Baca',
          textColor: Colors.white,
          onPressed: () {
            _showAnnouncementDetails(announcementModel);
          },
        ),
      ),
    );

    // Auto refresh announcements
    _refreshAnnouncements();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    print('App state changed: $state');

    if (state == AppLifecycleState.resumed) {
      // App kembali ke foreground
      _loadNotifications();
      _refreshAnnouncements();
    } else if (state == AppLifecycleState.paused) {
      // App ke background - cleanup resources
      _webSocketService.disconnect();
    }
  }

  // Fungsi background loading
  void _loadEverythingInBackground() async {
    try {
      print('🔄 Loading background data...');

      // 1. Cek token tapi jangan block
      final token = await AuthService.getToken();
      print('   Token status: ${token != null ? "Valid" : "Missing"}');

      // 2. Load profil
      await _loadUserProfileData();

      // 3. Load notifikasi
      await _loadNotifications();

      print('✅ Background loading complete');
    } catch (e) {
      print('⚠️ Background error (non-critical): $e');
    }
  }

  @override
  void dispose() {
    _webSocketService.disconnect();
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    _notificationTimer?.cancel();
    _announcementTimer?.cancel();
    super.dispose();
  }

  // 🔄 TAMBAHKAN: Fungsi untuk otomatis menandai semua notifikasi sebagai dibaca saat modal dibuka
  Future<void> _autoMarkAllNotificationsAsViewed() async {
    try {
      // Hanya tandai jika ada notifikasi yang belum dibaca
      if (_unreadNotifications > 0) {
        print('🔔 Auto marking all notifications as viewed...');

        // Update UI terlebih dahulu untuk feedback instan
        setState(() {
          _notifications = _notifications.map((notif) {
            if (!notif.isRead) {
              return notif.copyWith(isRead: true, readAt: DateTime.now());
            }
            return notif;
          }).toList();
          _unreadNotifications = 0;
        });

        // Kirim request ke API di background
        await NotificationService.markAllAsRead();
      }
    } catch (e) {
      print('⚠️ Error auto-marking notifications: $e');
    }
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
    } finally {
      if (showLoading && mounted) {
        setState(() => _isLoadingNotifications = false);
      }
    }
  }

  // 🔄 UPDATE: Fungsi untuk mark notification as read
  void _markNotificationAsRead(String notificationId) async {
    try {
      final result = await NotificationService.markAsRead(
        notificationId: notificationId,
      );

      if (result['success'] == true) {
        setState(() {
          final index = _notifications.indexWhere(
            (notif) => notif.id == notificationId,
          );
          if (index != -1) {
            _notifications[index] = _notifications[index].copyWith(
              isRead: true,
              readAt: DateTime.now(),
            );
            _unreadNotifications = _unreadNotifications - 1;
          }
        });
      }
    } catch (e) {
      print('⚠️ Error marking notification as read: $e');
    }
  }

  // 🔄 UPDATE: Fungsi untuk mark all notifications as read dengan feedback visual
  Future<void> _markAllNotificationsAsRead() async {
    try {
      // Simpan notifikasi lama untuk fallback jika error
      final oldNotifications = List<NotificationModel>.from(_notifications);

      // Update UI terlebih dahulu untuk feedback instan
      setState(() {
        _notifications = _notifications.map((notif) {
          return notif.copyWith(isRead: true, readAt: DateTime.now());
        }).toList();
        _unreadNotifications = 0;
      });

      // Tampilkan feedback
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.done_all, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              const Text('Semua notifikasi telah ditandai sebagai dibaca'),
            ],
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );

      // Kirim request ke API
      final result = await NotificationService.markAllAsRead();

      if (result['success'] != true) {
        // Rollback jika API gagal
        if (mounted) {
          setState(() {
            _notifications = oldNotifications;
            _unreadNotifications = oldNotifications
                .where((notif) => !notif.isRead)
                .length;
          });
        }
      }
    } catch (e) {
      print('⚠️ Error marking all notifications as read: $e');
      // Tampilkan error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menandai semua: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
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

            // UPDATE last load time
            _lastProfileLoadTime = DateTime.now();

            print('🖼️ Profile photo URL: ${_currentUser.fotoProfil}');
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
    // TIDAK PERLU refresh data profil setiap kali menu dibuka
    // Hanya refresh jika data belum ada atau lama sekali
    final now = DateTime.now();
    final lastLoadedTime = _lastProfileLoadTime;
    final shouldRefresh =
        lastLoadedTime == null ||
        now.difference(lastLoadedTime) > Duration(minutes: 5);

    if (shouldRefresh) {
      _loadUserProfileData();
    }

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

            // Header profil dengan foto INSTANT
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  // GANTI dengan widget yang TIDAK ADA loading
                  _buildProfileAvatarInstant(size: 60),
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

  Widget _buildProfileAvatarInstant({double size = 48}) {
    // Langsung render tanpa loading
    final userName =
        _currentUser.namaLengkap ?? _currentUser.email.split('@')[0];
    final initials = _getInitials(userName);

    // Cek apakah ada foto profil dari API
    final hasPhoto =
        _currentUser.fotoProfil != null &&
        _currentUser.fotoProfil!.isNotEmpty &&
        _currentUser.fotoProfil!.startsWith('http');

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
                // INSTANT dengan fallback
                frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                  if (wasSynchronouslyLoaded) {
                    return child;
                  }
                  // Jika loading, langsung show initials
                  return _buildInitialsAvatarInstant(userName, initials, size);
                },
                errorBuilder: (context, error, stackTrace) {
                  return _buildInitialsAvatarInstant(userName, initials, size);
                },
              ),
            )
          : _buildInitialsAvatarInstant(userName, initials, size),
    );
  }

  Widget _buildInitialsAvatarInstant(
    String userName,
    String initials,
    double size,
  ) {
    final color = _getColorFromName(userName);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.9), color.withOpacity(0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              initials,
              style: TextStyle(
                color: Colors.white,
                fontSize: size * 0.3,
                fontWeight: FontWeight.bold,
                height: 1.0,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Langsung render HomeScreen tanpa cek auth
    // TIDAK PERLU loading screen auth

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
                // ✅ FIX: Hanya update _announcements, JANGAN reset _filteredAnnouncements
                // agar search/filter yang aktif tidak terbatalkan
                final newData = snapshot.data!;
                if (_announcements.length != newData.length ||
                    (!_isSearching && !_isFilterActive)) {
                  _announcements = newData;
                  if (!_isSearching && !_isFilterActive) {
                    _filteredAnnouncements = newData;
                  }
                }
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

  /// Fungsi utama untuk menerapkan search + filter secara bersamaan
  void _applySearchAndFilter() {
    final query = _searchQuery.trim().toLowerCase();
    final filter = _selectedFilter;

    List<Announcement> result = List.from(_announcements);

    // 1. Terapkan filter kategori (targetAudience)
    if (filter != 'Semua') {
      result = result.where((a) {
        final audience = a.targetAudience.toLowerCase();
        switch (filter) {
          case 'Warga':
            return audience.contains('resident') || audience.contains('warga');
          case 'Pengurus':
            return audience.contains('admin') ||
                audience.contains('pengurus') ||
                audience.contains('rt') ||
                audience.contains('rw');
          case 'Semua Warga':
            return audience.contains('all') || audience.contains('semua');
          default:
            return true;
        }
      }).toList();
    }

    // 2. Terapkan search query
    if (query.isNotEmpty) {
      result = result.where((a) {
        return a.title.toLowerCase().contains(query) ||
            a.description.toLowerCase().contains(query) ||
            a.targetAudience.toLowerCase().contains(query) ||
            a.admin.namaLengkap.toLowerCase().contains(query) ||
            a.dayName.toLowerCase().contains(query) ||
            a.monthName.toLowerCase().contains(query);
      }).toList();
    }

    setState(() {
      _filteredAnnouncements = result;
      _isSearching = query.isNotEmpty;
      _isFilterActive = filter != 'Semua';
    });
  }

  void _handleSearch(String query) {
    _searchQuery = query;
    _applySearchAndFilter();
  }

  void _clearSearch() {
    _searchQuery = '';
    _searchController.clear();
    _applySearchAndFilter();
  }

  void _applyFilter(String filter) {
    _selectedFilter = filter;
    _applySearchAndFilter();
  }

  void _showAnnouncementDetails(Announcement announcement) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: 500,
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header Image
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(24),
                      topRight: Radius.circular(24),
                    ),
                    child: announcement.imageUrl != null
                        ? CachedNetworkImage(
                            imageUrl: announcement.imageUrl!,
                            height: 200,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              height: 200,
                              color: Colors.grey.shade100,
                              child: const Center(
                                child: CircularProgressIndicator(),
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              height: 200,
                              color: Colors.blue.shade50,
                              child: Icon(
                                Icons.image_not_supported_outlined,
                                size: 50,
                                color: Colors.blue.shade200,
                              ),
                            ),
                          )
                        : Container(
                            height: 150,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.blue.shade400,
                                  Colors.blue.shade600,
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            child: const Icon(
                              Icons.campaign_rounded,
                              size: 60,
                              color: Colors.white,
                            ),
                          ),
                  ),
                  Positioned(
                    top: 12,
                    right: 12,
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.3),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              // Content
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: announcement.backgroundColor,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: announcement.borderColor,
                              ),
                            ),
                            child: Text(
                              announcement.targetAudience,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: announcement.dateColor,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            announcement.formattedDate,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade500,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        announcement.title,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 14,
                            backgroundColor: Colors.blue.shade100,
                            child: Text(
                              announcement.admin.namaLengkap[0].toUpperCase(),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            announcement.admin.namaLengkap,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.verified_user_rounded,
                            size: 14,
                            color: Colors.blue.shade400,
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Divider(color: Colors.grey.shade200, height: 1),
                      const SizedBox(height: 20),
                      Text(
                        announcement.description,
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.grey.shade800,
                          height: 1.6,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Footer
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Tutup',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
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

  // 🔄 UPDATE: Fungsi untuk show notifications dengan auto-mark-as-read
  void _showNotifications() {
    // 🚀 JANGAN await — refresh di background
    Future.microtask(() {
      _loadNotifications();
      _autoMarkAllNotificationsAsViewed();
    });

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Column(
            children: [
              // ================= HEADER =================
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
                          // UI update DULU
                          setState(() {
                            _unreadNotifications = 0;
                            _notifications = _notifications.map((notif) {
                              return notif.copyWith(
                                isRead: true,
                                readAt: DateTime.now(),
                              );
                            }).toList();
                          });

                          // API BELAKANGAN
                          Future.microtask(() {
                            _markAllNotificationsAsRead();
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: const [
                              Icon(
                                Icons.done_all_rounded,
                                color: Colors.white,
                                size: 16,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'Tandai Semua',
                                style: TextStyle(
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

              // ================= LIST =================
              Expanded(
                child: _isLoadingNotifications
                    ? const Center(child: CircularProgressIndicator())
                    : _notifications.isEmpty
                    ? _buildEmptyNotifications()
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _notifications.length,
                        itemBuilder: (context, index) {
                          final notification = _notifications[index];

                          return Column(
                            children: [
                              _buildNotificationItem(
                                notification,
                                onTap: () {
                                  // 🚀 TUTUP MODAL DULU
                                  Navigator.pop(context);

                                  // 🚀 NAVIGASI INSTAN
                                  _handleNotificationAction(notification);

                                  // 🔄 BACKGROUND TASK
                                  if (!notification.isRead) {
                                    Future.microtask(() {
                                      _markNotificationAsRead(notification.id);
                                    });
                                  }
                                },
                              ),
                              const SizedBox(height: 12),
                            ],
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    ).then((_) {
      // refresh ringan, non-blocking
      Future.microtask(() {
        _loadNotifications();
      });
    });
  }

  // 🔄 UPDATE: Widget notification item dengan callback onTap
  Widget _buildNotificationItem(
    NotificationModel notification, {
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: notification.isRead ? Colors.white : Colors.blue.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: notification.isRead
                ? Colors.grey.shade200
                : Colors.blue.shade100,
            width: notification.isRead ? 1 : 1.5,
          ),
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
              color: notification.isRead
                  ? notification.color.withOpacity(0.1)
                  : notification.color.withOpacity(0.15),
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
                  ? Colors.grey.shade700
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
                      ? Colors.grey.shade600
                      : Colors.grey.shade700,
                  fontSize: 12,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    Icons.access_time,
                    size: 10,
                    color: notification.isRead
                        ? Colors.grey.shade400
                        : Colors.blue.shade500,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    notification.timeAgo,
                    style: TextStyle(
                      color: notification.isRead
                          ? Colors.grey.shade400
                          : Colors.blue.shade600,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ],
          ),
          trailing: !notification.isRead
              ? Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.withOpacity(0.4),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                )
              : Icon(
                  Icons.check_circle,
                  color: Colors.green.shade400,
                  size: 16,
                ),
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
              // GANTI dengan instant avatar di header juga
              GestureDetector(
                onTap: _showProfile,
                child: _buildProfileAvatarInstant(),
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
                        child: GestureDetector(
                          onTap: () {
                            // Tandai semua saat badge diklik (opsional)
                            if (_unreadNotifications > 0) {
                              _markAllNotificationsAsRead();
                            }
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: _unreadNotifications > 0
                                  ? Colors.red
                                  : Colors.transparent,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.red.withOpacity(0.3),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            constraints: BoxConstraints(
                              minWidth: _unreadNotifications > 9 ? 28 : 22,
                              minHeight: _unreadNotifications > 9 ? 28 : 22,
                            ),
                            child: Text(
                              _unreadNotifications > 9
                                  ? '9+'
                                  : '$_unreadNotifications',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: _unreadNotifications > 9 ? 10 : 12,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
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
                  // Tombol aksi: Clear saat searching, Filter icon selalu ada
                  if (_isSearching)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: IconButton(
                        icon: Icon(
                          Icons.clear,
                          color: Colors.grey.shade500,
                          size: 20,
                        ),
                        onPressed: _clearSearch,
                      ),
                    ),
                  // Tombol filter selalu tampil, dengan badge jika filter aktif
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Stack(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: _isFilterActive
                                ? Colors.orange.shade100
                                : Colors.blue.shade50,
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: Icon(
                              Icons.filter_list_rounded,
                              color: _isFilterActive
                                  ? Colors.orange.shade700
                                  : Colors.blue.shade600,
                              size: 18,
                            ),
                            onPressed: _showFilterOptions,
                            padding: EdgeInsets.zero,
                          ),
                        ),
                        if (_isFilterActive)
                          Positioned(
                            right: 0,
                            top: 0,
                            child: Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: Colors.orange.shade600,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 1.5,
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
          ),

          if (_currentUser.isSatpam) ...[
            const SizedBox(height: 20),
            _buildSatpamShortcut(),
          ],
        ],
      ),
    );
  }

  Widget _buildSatpamShortcut() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.indigo.shade400, Colors.indigo.shade700],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.indigo.shade900.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => SatpamDashboardScreen(user: _currentUser),
              ),
            );
          },
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.security_rounded,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Mode Satpam Aktif',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Klik untuk masuk ke dashboard keamanan',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Filter dengan fungsi yang benar-benar bekerja
  void _showFilterOptions() {
    // Filter options yang tersedia
    final filterOptions = [
      {
        'label': 'Semua',
        'icon': Icons.all_inclusive_rounded,
        'desc': 'Tampilkan semua pengumuman',
      },
      {
        'label': 'Semua Warga',
        'icon': Icons.people_rounded,
        'desc': 'Pengumuman untuk seluruh warga',
      },
      {
        'label': 'Warga',
        'icon': Icons.person_rounded,
        'desc': 'Khusus untuk warga umum',
      },
      {
        'label': 'Pengurus',
        'icon': Icons.admin_panel_settings_rounded,
        'desc': 'Khusus untuk RT/RW/Admin',
      },
    ];

    String tempSelected = _selectedFilter;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Drag indicator
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.filter_list_rounded,
                            color: Colors.blue.shade600,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Filter Pengumuman',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    if (tempSelected != 'Semua')
                      TextButton(
                        onPressed: () {
                          setModalState(() => tempSelected = 'Semua');
                        },
                        child: Text(
                          'Reset',
                          style: TextStyle(color: Colors.red.shade400),
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 20),

                // Filter chips
                const Text(
                  'Tampilkan Untuk',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 12),

                // Daftar opsi filter
                ...filterOptions.map((opt) {
                  final label = opt['label'] as String;
                  final icon = opt['icon'] as IconData;
                  final desc = opt['desc'] as String;
                  final isSelected = tempSelected == label;

                  return GestureDetector(
                    onTap: () => setModalState(() => tempSelected = label),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.blue.shade50
                            : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected
                              ? Colors.blue.shade300
                              : Colors.grey.shade200,
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Colors.blue.shade100
                                  : Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              icon,
                              size: 20,
                              color: isSelected
                                  ? Colors.blue.shade700
                                  : Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  label,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: isSelected
                                        ? Colors.blue.shade800
                                        : Colors.grey.shade800,
                                  ),
                                ),
                                Text(
                                  desc,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isSelected
                                        ? Colors.blue.shade500
                                        : Colors.grey.shade500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isSelected)
                            Icon(
                              Icons.check_circle_rounded,
                              color: Colors.blue.shade600,
                              size: 22,
                            ),
                        ],
                      ),
                    ),
                  );
                }).toList(),

                const SizedBox(height: 16),

                // Tombol terapkan
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _applyFilter(tempSelected);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade600,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.check_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          tempSelected == 'Semua'
                              ? 'Tampilkan Semua'
                              : 'Terapkan: $tempSelected',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
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
        _applyFilter(label);
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
    // Cari pengumuman yang di-highlight
    final highlightedAnnouncements = _announcements
        .where((a) => a.isHighlight == true)
        .toList();
    if (highlightedAnnouncements.isEmpty) {
      return const SizedBox.shrink(); // Sembunyikan banner jika tidak ada highlight
    }

    final highlightAnnouncement = highlightedAnnouncements.first;

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
            if (highlightAnnouncement.imageUrl != null)
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
                child: CachedNetworkImage(
                  imageUrl: highlightAnnouncement.imageUrl!,
                  height: 160,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    height: 160,
                    width: double.infinity,
                    color: Colors.grey.shade200,
                    child: const Center(child: CircularProgressIndicator()),
                  ),
                  errorWidget: (context, url, error) => Container(
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
                      Icons.campaign_outlined,
                      color: Colors.blue,
                      size: 60,
                    ),
                  ),
                ),
              )
            else
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
                child: Container(
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
                    Icons.campaign_outlined,
                    color: Colors.blue,
                    size: 60,
                  ),
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
                          'Sorotan',
                          style: TextStyle(
                            color: Colors.orange.shade700,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    highlightAnnouncement.title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    highlightAnnouncement.description,
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: 14,
                      height: 1.5,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
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
                              '${highlightAnnouncement.day}, ${highlightAnnouncement.formattedDate}',
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
                      GestureDetector(
                        onTap: () =>
                            _showAnnouncementDetails(highlightAnnouncement),
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
                            'Baca',
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
    // ✅ FIX: Gunakan _filteredAnnouncements jika ada search/filter aktif,
    // atau _announcements jika tidak ada filter sama sekali
    final announcementsToShow = (_isSearching || _isFilterActive)
        ? _filteredAnnouncements
        : _announcements;

    final bool hasActiveCondition = _isSearching || _isFilterActive;
    String sectionTitle = 'Pengumuman Terbaru';
    if (_isSearching && _isFilterActive) {
      sectionTitle = 'Hasil: "${_searchQuery}" · ${_selectedFilter}';
    } else if (_isSearching) {
      sectionTitle = 'Hasil: "${_searchQuery}"';
    } else if (_isFilterActive) {
      sectionTitle = 'Filter: ${_selectedFilter}';
    }

    return Padding(
      padding: const EdgeInsets.only(left: 24, right: 24, bottom: 25),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  sectionTitle,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              // Badge jumlah
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: hasActiveCondition
                      ? Colors.orange.shade50
                      : Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: hasActiveCondition
                        ? Colors.orange.shade200
                        : Colors.blue.shade100,
                  ),
                ),
                child: Text(
                  '${announcementsToShow.length} item',
                  style: TextStyle(
                    color: hasActiveCondition
                        ? Colors.orange.shade700
                        : Colors.blue.shade700,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),

          // Tag filter aktif
          if (hasActiveCondition) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                if (_isSearching)
                  _buildActiveTag(
                    Icons.search_rounded,
                    '"$_searchQuery"',
                    Colors.blue,
                    onRemove: _clearSearch,
                  ),
                if (_isFilterActive)
                  _buildActiveTag(
                    Icons.filter_list_rounded,
                    _selectedFilter,
                    Colors.orange,
                    onRemove: () => _applyFilter('Semua'),
                  ),
              ],
            ),
          ],

          const SizedBox(height: 16),
          if (announcementsToShow.isEmpty)
            _buildEmptySearchResults()
          else
            ..._buildAnnouncementsItems(announcementsToShow),
        ],
      ),
    );
  }

  /// Tag kecil yang menampilkan kondisi aktif dan bisa dihapus
  Widget _buildActiveTag(
    IconData icon,
    String label,
    Color color, {
    required VoidCallback onRemove,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 4, 4, 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onRemove,
            child: Icon(Icons.close_rounded, size: 14, color: color),
          ),
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
                      if (announcement.imageUrl != null) ...[
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: CachedNetworkImage(
                            imageUrl: announcement.imageUrl!,
                            height: 120,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              height: 120,
                              color: Colors.grey.shade200,
                              child: const Center(
                                child: CircularProgressIndicator(),
                              ),
                            ),
                            errorWidget: (context, url, error) =>
                                const SizedBox.shrink(),
                          ),
                        ),
                      ],
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
}
