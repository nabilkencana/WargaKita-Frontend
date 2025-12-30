// sos_screen.dart
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:warga_app/models/security_location.dart';
import 'package:warga_app/widget/emergency_map.dart';
import '../models/user_model.dart';
import '../models/sos_model.dart';
import '../services/sos_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

class SosScreen extends StatefulWidget {
  final User user;

  const SosScreen({super.key, required this.user});

  @override
  State<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends State<SosScreen> {
  final SosService _sosService = SosService();
  bool _isLoading = false;
  bool _isLoadingEmergencies = false;
  List<Emergency> _activeEmergencies = [];
  EmergencyStats? _stats;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await Future.wait([_loadActiveEmergencies(), _loadStats()]);
  }

  Future<void> _loadActiveEmergencies() async {
    setState(() {
      _isLoadingEmergencies = true;
    });
    try {
      final emergencies = await _sosService.getActiveEmergencies();
      setState(() {
        _activeEmergencies = emergencies;
      });
    } catch (e) {
      _showErrorSnackbar('Gagal memuat data emergency aktif: $e');
    } finally {
      setState(() {
        _isLoadingEmergencies = false;
      });
    }
  }

  Future<void> _loadStats() async {
    try {
      final stats = await _sosService.getEmergencyStats();
      setState(() {
        _stats = stats;
      });
    } catch (e) {
      // Ignore error for stats
    }
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showSuccessSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _sendEmergencySignal(String type) async {
    setState(() {
      _isLoading = true;
    });

    try {
      late final int userId;

      if (widget.user.id == null) {
        throw Exception('User ID tidak ditemukan (null)');
      }

      if (widget.user.id is int) {
        userId = widget.user.id as int;
      } else if (widget.user.id is String) {
        final parsed = int.tryParse(widget.user.id as String);
        if (parsed == null) {
          throw Exception('User ID tidak valid: ${widget.user.id}');
        }
        userId = parsed;
      } else {
        throw Exception('Tipe User ID tidak dikenal');
      }

      print('👤 USER ID RAW: ${widget.user.id}');
      print('👤 USER ID TYPE: ${widget.user.id.runtimeType}');
      print('👤 USER ID FINAL: $userId');

    
      final request = CreateSOSRequest(
        type: type,
        details: 'SOS Emergency dari ${widget.user.name ?? "Pengguna"}',
        location: 'Lokasi saat ini',
        latitude: '-6.2088', // Contoh koordinat (Jakarta)
        longitude: '106.8456',
        needVolunteer: true,
        volunteerCount: 5,
        userId: userId,
      );

      final emergency = await _sosService.createSOS(request);

      _showSuccessSnackbar('SOS Emergency berhasil dikirim!');

      // Refresh data setelah mengirim SOS
      await _loadData();

      // Tampilkan detail emergency yang baru dibuat
      _showEmergencyDetails(emergency);
    } catch (e) {
      print('❌ Error: $e');
      _showErrorSnackbar('Gagal mengirim SOS: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showEmergencyDetails(Emergency emergency) async {
    SecurityLocation? securityLocation;

     try {
      final position = await Geolocator.getCurrentPosition();
      securityLocation = SecurityLocation(
        position.latitude,
        position.longitude,
      );
    } catch (_) {}
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.emergency, color: Colors.red.shade700, size: 24),
            const SizedBox(width: 12),
            const Text(
              'Emergency Details',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailItem('ID', '#${emergency.id}'),
              _buildDetailItem('Tipe', emergency.type),
              _buildDetailItem('Status', emergency.status),
              if (emergency.details != null)
                _buildDetailItem('Detail', emergency.details!),
              const SizedBox(height: 12),
              // 🗺️ MAP
              EmergencyMap(
                emergency: emergency,
                securityLocation: securityLocation,
              ),
              _buildDetailItem(
                'Dibuat',
                DateFormat('dd MMM yyyy HH:mm').format(emergency.createdAt),
              ),
              _buildDetailItem(
                'Butuh Relawan',
                emergency.needVolunteer ? 'Ya' : 'Tidak',
              ),
              if (emergency.needVolunteer)
                _buildDetailItem(
                  'Jumlah Relawan Dibutuhkan',
                  emergency.volunteerCount.toString(),
                ),
              if (emergency.volunteers.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text(
                  'Relawan Terdaftar:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                ...emergency.volunteers.map(
                  (volunteer) => Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '• ${volunteer.userName ?? "Anonim"} - ${volunteer.status}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ),
              ],
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

  Widget _buildDetailItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }

  void _showEmergencyDialog(BuildContext context, String type) {
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
              // Header dengan icon emergency
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.red.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.emergency,
                      color: Colors.red.shade700,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Kirim SOS Emergency?',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Tipe: $type',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Deskripsi sistem
              const Text(
                'Sistem akan:',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey,
                ),
              ),

              const SizedBox(height: 12),

              // Fitur-fitur yang akan dijalankan
              _buildSystemFeature(
                Icons.location_on,
                'Mengirimkan lokasi Anda saat ini',
              ),
              _buildSystemFeature(
                Icons.help_outline,
                'Mengirim permintaan bantuan',
              ),
              _buildSystemFeature(
                Icons.notifications_active,
                'Memberi tahu kontak darurat',
              ),
              _buildSystemFeature(Icons.people_alt, 'Mencari relawan terdekat'),
              _buildSystemFeature(
                Icons.assignment_turned_in,
                'Membuat emergency case dengan ID unik',
              ),

              const SizedBox(height: 20),

              // Peringatan penting
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade100),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.red.shade600,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Gunakan hanya dalam keadaan darurat sesungguhnya!',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.red.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
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
                        side: BorderSide(color: Colors.grey.shade400),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Batal',
                        style: TextStyle(
                          color: Colors.grey,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isLoading
                          ? null
                          : () {
                              Navigator.pop(context);
                              _sendEmergencySignal(type);
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 3,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.emergency,
                                  color: Colors.white,
                                  size: 18,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Kirim SOS',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
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

  Widget _buildSystemFeature(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.red.shade600),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _makePhoneCall(String number) async {
    try {
      final Uri phoneUri = Uri(scheme: 'tel', path: number);
      if (await canLaunchUrl(phoneUri)) {
        await launchUrl(phoneUri);
      } else {
        _showErrorSnackbar('Tidak dapat melakukan panggilan');
      }
    } catch (e) {
      _showErrorSnackbar('Error: $e');
    }
  }

  void _showCallDialog(String title, String number) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Hubungi $title?',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Text(
              number,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const Text(
              'Pastikan Anda berada dalam keadaan darurat sebelum menghubungi',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.grey,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Batal'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _makePhoneCall(number);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.phone, size: 18),
                      SizedBox(width: 8),
                      Text('Hubungi'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmergencyContact(
    String title,
    String number,
    IconData icon,
    Color color,
  ) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(number),
        trailing: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: Icon(Icons.phone, color: Colors.green.shade700, size: 20),
            onPressed: () => _showCallDialog(title, number),
          ),
        ),
      ),
    );
  }

  Widget _buildEmergencyItem(Emergency emergency) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.emergency, color: Colors.red.shade700, size: 20),
        ),
        title: Text(
          emergency.type,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            if (emergency.location != null)
              Text('Lokasi: ${emergency.location}'),
            Text('Status: ${emergency.status}'),
            Text('Butuh Relawan: ${emergency.needVolunteer ? "Ya" : "Tidak"}'),
            Text(
              'Dibuat: ${DateFormat('dd/MM HH:mm').format(emergency.createdAt)}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        trailing: IconButton(
          icon: Icon(
            Icons.arrow_forward_ios,
            color: Colors.grey.shade600,
            size: 16,
          ),
          onPressed: () => _showEmergencyDetails(emergency),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      floatingActionButton: FloatingActionButton(
        onPressed: _isLoading
            ? null
            : () => _showEmergencyDialog(context, 'Emergency Umum'),
        backgroundColor: Colors.red,
        child: _isLoading
            ? const CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2.5,
              )
            : const Icon(Icons.emergency, color: Colors.white),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.red.shade700, Colors.red.shade500],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'SOS Emergency',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Bantuan Darurat 24 Jam',
                    style: TextStyle(fontSize: 16, color: Colors.white),
                  ),
                  if (_stats != null) ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        _buildStatItem(_stats!.active.toString(), 'Aktif'),
                        _buildStatItem(_stats!.resolved.toString(), 'Selesai'),
                        _buildStatItem(
                          _stats!.needVolunteers.toString(),
                          'Butuh Relawan',
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    // Emergency Types
                    const Text(
                      'Jenis Emergency',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildEmergencyTypeButton(
                          'Kecelakaan',
                          Icons.car_crash,
                        ),
                        _buildEmergencyTypeButton(
                          'Kesehatan',
                          Icons.medical_services,
                        ),
                        _buildEmergencyTypeButton(
                          'Kebakaran',
                          Icons.fire_truck,
                        ),
                        _buildEmergencyTypeButton('Keamanan', Icons.security),
                        _buildEmergencyTypeButton('Bencana Alam', Icons.nature),
                        _buildEmergencyTypeButton('Lainnya', Icons.more_horiz),
                      ],
                    ),
                    const SizedBox(height: 32),

                    // Active Emergencies Section
                    if (_activeEmergencies.isNotEmpty) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Emergency Aktif',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            onPressed: _loadActiveEmergencies,
                            icon: Icon(
                              Icons.refresh,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _isLoadingEmergencies
                          ? const Center(child: CircularProgressIndicator())
                          : Column(
                              children: _activeEmergencies
                                  .map(_buildEmergencyItem)
                                  .toList(),
                            ),
                      const SizedBox(height: 32),
                    ],

                    // Emergency Contacts Section
                    const Text(
                      'Kontak Darurat',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildEmergencyContact(
                      'Polisi',
                      '110',
                      Icons.local_police,
                      Colors.blue,
                    ),
                    _buildEmergencyContact(
                      'Ambulans',
                      '118',
                      Icons.medical_services,
                      Colors.red,
                    ),
                    _buildEmergencyContact(
                      'Pemadam Kebakaran',
                      '113',
                      Icons.fire_truck,
                      Colors.orange,
                    ),
                    _buildEmergencyContact(
                      'SAR Nasional',
                      '115',
                      Icons.search,
                      Colors.green,
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String value, String label) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmergencyTypeButton(String label, IconData icon) {
    return ElevatedButton.icon(
      onPressed: () => _showEmergencyDialog(context, label),
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.red.shade50,
        foregroundColor: Colors.red.shade700,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.red.shade200),
        ),
      ),
    );
  }
}
