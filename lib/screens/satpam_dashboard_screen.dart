import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/user_model.dart';
import '../models/sos_model.dart';
import '../services/sos_service.dart';
import '../widget/emergency_map.dart';
import '../models/security_location.dart';
import 'package:geolocator/geolocator.dart';

class SatpamDashboardScreen extends StatefulWidget {
  final User user;

  const SatpamDashboardScreen({super.key, required this.user});

  @override
  State<SatpamDashboardScreen> createState() => _SatpamDashboardScreenState();
}

class _SatpamDashboardScreenState extends State<SatpamDashboardScreen> {
  final SosService _sosService = SosService();
  bool _isLoading = false;
  List<Emergency> _needSatpamEmergencies = [];
  List<Emergency> _myAssignedEmergencies = [];
  EmergencyStats? _stats;

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  Future<void> _refreshData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _sosService.getEmergenciesNeedSatpam(),
        _sosService.getSatpamAssignedEmergencies(int.parse(widget.user.id.toString())),
        _sosService.getEmergencyStats(),
      ]);

      setState(() {
        _needSatpamEmergencies = results[0] as List<Emergency>;
        _myAssignedEmergencies = results[1] as List<Emergency>;
        _stats = results[2] as EmergencyStats;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memuat data: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _acceptEmergency(int emergencyId) async {
    try {
      await _sosService.acceptEmergency(emergencyId, int.parse(widget.user.id.toString()));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Emergency diterima!'), backgroundColor: Colors.green),
      );
      _refreshData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menerima: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _updateStatus(Emergency emergency, String status) async {
    try {
      // Find the response ID for this satpam
      final response = emergency.emergencyResponses.firstWhere(
        (r) => r.satpamId == int.parse(widget.user.id.toString()),
      );
      
      await _sosService.updateSatpamStatus(response.id, status);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Status diupdate ke $status!'), backgroundColor: Colors.green),
      );
      _refreshData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal update status: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Satpam Dashboard', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.indigo.shade800,
        foregroundColor: Colors.white,
        actions: [
          IconButton(onPressed: _refreshData, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: _isLoading && _needSatpamEmergencies.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStatsOverview(),
                    const SizedBox(height: 24),
                    _buildSectionHeader('Tugas Saya Saat Ini', Icons.assignment_turned_in, Colors.green),
                    const SizedBox(height: 12),
                    _myAssignedEmergencies.isEmpty
                        ? _buildEmptyState('Tidak ada tugas aktif')
                        : Column(children: _myAssignedEmergencies.map((e) => _buildEmergencyCard(e, isAssigned: true)).toList()),
                    const SizedBox(height: 24),
                    _buildSectionHeader('Emergency Butuh Satpam', Icons.warning_amber_rounded, Colors.orange),
                    const SizedBox(height: 12),
                    _needSatpamEmergencies.isEmpty
                        ? _buildEmptyState('Semua terkendali')
                        : Column(children: _needSatpamEmergencies.map((e) => _buildEmergencyCard(e, isAssigned: false)).toList()),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildStatsOverview() {
    if (_stats == null) return const SizedBox.shrink();
    return Row(
      children: [
        _buildStatCard('Total', _stats!.total.toString(), Colors.blue),
        _buildStatCard('Aktif', _stats!.active.toString(), Colors.red),
        _buildStatCard('Selesai', _stats!.resolved.toString(), Colors.green),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, Color color) {
    return Expanded(
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
              const SizedBox(height: 4),
              Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, color: color),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildEmptyState(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
      ),
      child: Center(
        child: Text(message, style: TextStyle(color: Colors.grey.shade600, fontStyle: FontStyle.italic)),
      ),
    );
  }

  Widget _buildEmergencyCard(Emergency emergency, {required bool isAssigned}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: _getSeverityColor(emergency.severity).withOpacity(0.2),
          child: Icon(Icons.emergency, color: _getSeverityColor(emergency.severity)),
        ),
        title: Text(emergency.type, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('Dibuat: ${DateFormat('HH:mm').format(emergency.createdAt)} | ${emergency.location ?? "Tanpa lokasi"}'),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (emergency.details != null) ...[
                  const Text('Detail:', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(emergency.details!),
                  const SizedBox(height: 12),
                ],
                const Text('Lokasi:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                SizedBox(
                  height: 150,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: EmergencyMap(emergency: emergency),
                  ),
                ),
                const SizedBox(height: 16),
                isAssigned ? _buildAssignedActions(emergency) : _buildUnassignedActions(emergency),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnassignedActions(Emergency emergency) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () => _acceptEmergency(emergency.id),
        icon: const Icon(Icons.check),
        label: const Text('Terima Tugas'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.indigo,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }

  Widget _buildAssignedActions(Emergency emergency) {
    // Find current status
    final response = emergency.emergencyResponses.firstWhere(
      (r) => r.satpamId == int.parse(widget.user.id.toString()),
      orElse: () => EmergencyResponse(id: 0, emergencyId: 0, status: 'UNKNOWN', createdAt: DateTime.now()),
    );
    
    final status = response.satpamStatus ?? 'PENDING';

    return Column(
      children: [
        Text('Status Anda: $status', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo)),
        const SizedBox(height: 12),
        Row(
          children: [
            if (status == 'ACCEPTED')
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _updateStatus(emergency, 'ARRIVED'),
                  icon: const Icon(Icons.location_on),
                  label: const Text('Sampai'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                ),
              ),
            if (status == 'ARRIVED')
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _updateStatus(emergency, 'HANDLING'),
                  icon: const Icon(Icons.handyman),
                  label: const Text('Menangani'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
                ),
              ),
            if (status == 'HANDLING')
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _updateStatus(emergency, 'RESOLVED'),
                  icon: const Icon(Icons.check_circle),
                  label: const Text('Selesai'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Color _getSeverityColor(String severity) {
    switch (severity.toUpperCase()) {
      case 'HIGH':
        return Colors.red;
      case 'MEDIUM':
        return Colors.orange;
      case 'LOW':
        return Colors.green;
      default:
        return Colors.blue;
    }
  }
}
