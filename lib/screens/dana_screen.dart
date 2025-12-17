// dana_screen.dart - Versi User dengan Sistem Pembayaran Lengkap
import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../models/transaction_model.dart';
import '../models/bill_model.dart';
import '../services/transaction_service.dart';
import '../services/bill_service.dart';
import '../services/auth_service.dart'; // Import AuthService

class DanaScreen extends StatefulWidget {
  final User user;

  const DanaScreen({super.key, required this.user});

  @override
  State<DanaScreen> createState() => _DanaScreenState();
}

class _DanaScreenState extends State<DanaScreen> with TickerProviderStateMixin {
  // 0: Tagihan, 1: Riwayat
  final List<String> _tabs = ['Tagihan Saya', 'Riwayat'];
  late TabController _tabController;

  TransactionService? _transactionService;
  BillService? _billService;
  List<Transaction> _transactions = [];
  List<Bill> _bills = [];
  String? _token; // Tambahkan variabel untuk menyimpan token

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(() {
      setState(() {});
    });
    _initializeServices();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Ubah method _initializeServices menjadi async
  Future<void> _initializeServices() async {
    try {
      // Ambil token dari AuthService
      _token = await AuthService.getToken();

      if (_token == null || _token!.isEmpty) {
        print('⚠️ Token tidak ditemukan, user mungkin belum login');
        setState(() {
        });
        return;
      }

      print('✅ Token berhasil diambil dari AuthService');

      // Inisialisasi service dengan token
      _transactionService = TransactionService(_token!);
      _billService = BillService(_token!);

      // Load data setelah service diinisialisasi
      await _loadData();
    } catch (e) {
      print('❌ Error initializing services: $e');
      setState(() {
      });
    }
  }

  Future<void> _loadData() async {
    try {
      setState(() {
      });

      // Pastikan service sudah terinisialisasi
      if (_billService == null || _transactionService == null) {
        throw Exception('Service belum diinisialisasi');
      }

      await Future.wait([_loadUserBills(), _loadRecentTransactions()]);

      setState(() {
      });
    } catch (e) {
      print('❌ Error loading data: $e');
      setState(() {
      });
    }
  }

  Future<void> _loadUserBills() async {
    try {
      if (_billService == null) {
        throw Exception('BillService belum diinisialisasi');
      }

      final billResponse = await _billService!.getUserBills(limit: 50);
      setState(() {
        _bills = billResponse.bills;
      });
    } catch (e) {
      print('⚠️  Cannot load bills: $e');
      // Tidak set error di sini agar tab lain masih bisa diakses
    }
  }

  Future<void> _loadRecentTransactions() async {
    try {
      if (_transactionService == null) {
        throw Exception('TransactionService belum diinisialisasi');
      }

      final transactions = await _transactionService!.getRecentTransactions(
        limit: 50,
      );
      setState(() {
        _transactions = transactions;
      });
    } catch (e) {
      print('⚠️  Cannot load transactions: $e');
      // Tidak set error di sini agar tab lain masih bisa diakses
    }
  }

  Future<void> _refreshData() async {
    // Refresh token sebelum mengambil data
    _token = await AuthService.getToken();

    if (_token == null || _token!.isEmpty) {
      _showErrorSnackbar('Anda belum login. Silakan login ulang.');
      return;
    }

    // Re-initialize services dengan token terbaru
    _transactionService = TransactionService(_token!);
    _billService = BillService(_token!);

    await _loadData();
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
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: SafeArea(
        child: Column(
          children: [
            // Gunakan header yang diperbaiki
            _buildUserHeaderImproved(),

            // Tab Bar (sama seperti sebelumnya)
            Container(
              color: Colors.white,
              child: TabBar(
                controller: _tabController,
                labelColor: Colors.blue.shade700,
                unselectedLabelColor: Colors.grey.shade600,
                indicatorColor: Colors.blue.shade700,
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontWeight: FontWeight.normal,
                  fontSize: 14,
                ),
                tabs: _tabs.map((tab) => Tab(text: tab)).toList(),
              ),
            ),

            // Content (sama seperti sebelumnya)
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [_buildBillsTab(), _buildHistoryTab()],
              ),
            ),
          ],
        ),
      ),
    );
  }





  Widget _buildUserHeaderImproved() {
    final pendingBills = _bills.where((bill) => bill.isPending).toList();
    final totalPending = pendingBills.fold<double>(
      0,
      (sum, bill) => sum + bill.amount,
    );
    final paidBills = _bills.where((bill) => !bill.isPending).toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade700, Colors.blue.shade500],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          const Text(
            'Dana Community',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 8),

          // User Info
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.person,
                  color: Colors.blue.shade700,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.user.name ?? 'User',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      widget.user.email,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),

          // Stats Cards
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildStatCard(
                  'Tagihan Aktif',
                  pendingBills.length.toString(),
                  Icons.pending_actions,
                  Colors.orange.shade100,
                  Colors.orange.shade800,
                ),
                const SizedBox(width: 12),
                _buildStatCard(
                  'Sudah Lunas',
                  paidBills.length.toString(),
                  Icons.verified,
                  Colors.green.shade100,
                  Colors.green.shade800,
                ),
                const SizedBox(width: 12),
                _buildStatCard(
                  'Total Belum Bayar',
                  'Rp ${_formatCurrency(totalPending)}',
                  Icons.money_off,
                  Colors.red.shade100,
                  Colors.red.shade800,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color bgColor,
    Color color,
  ) {
    return Container(
      width: 140,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBillsTab() {
    final pendingBills = _bills.where((bill) => bill.isPending).toList();

    return RefreshIndicator(
      onRefresh: _refreshData,
      child: pendingBills.isEmpty
          ? _buildEmptyBills()
          : ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: pendingBills.length,
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemBuilder: (context, index) {
                return _buildBillCard(pendingBills[index]);
              },
            ),
    );
  }

  Widget _buildBillCard(Bill bill) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header dengan status
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: bill.isOverdue
                  ? Colors.red.shade50
                  : Colors.orange.shade50,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  bill.isOverdue ? Icons.warning : Icons.pending,
                  color: bill.isOverdue ? Colors.red : Colors.orange,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    bill.isOverdue ? 'TERLAMBAT BAYAR' : 'MENUNGGU PEMBAYARAN',
                    style: TextStyle(
                      color: bill.isOverdue ? Colors.red : Colors.orange,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: bill.isOverdue ? Colors.red : Colors.orange,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    bill.isOverdue ? 'TERLAMBAT' : 'BELUM BAYAR',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        bill.title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  bill.description,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                ),
                const SizedBox(height: 16),

                // Info jumlah dan tanggal
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Jumlah Tagihan',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Rp ${_formatCurrency(bill.amount)}',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Jatuh Tempo',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          bill.formattedDueDate,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: bill.isOverdue ? Colors.red : Colors.orange,
                          ),
                        ),
                        if (bill.isOverdue)
                          Text(
                            '${_calculateDaysOverdue(bill.dueDate)} hari terlambat',
                            style: const TextStyle(
                              color: Colors.red,
                              fontSize: 10,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Tombol Bayar
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _showPaymentMethodDialog(bill),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                    icon: const Icon(Icons.payment, size: 20),
                    label: const Text(
                      'BAYAR TAGIHAN',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyBills() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.celebration, size: 80, color: Colors.green.shade400),
          const SizedBox(height: 16),
          Text(
            'Tidak ada tagihan aktif',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Semua tagihan telah dibayar lunas',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryTab() {
    final paidBills = _bills.where((bill) => !bill.isPending).toList();
    final allHistory = <dynamic>[...paidBills, ..._transactions];

    // Sort by date (newest first)
    allHistory.sort((a, b) {
      DateTime aDate = a is Bill ? a.dueDate : a.date;
      DateTime bDate = b is Bill ? b.dueDate : b.date;
      return bDate.compareTo(aDate);
    });

    return RefreshIndicator(
      onRefresh: _refreshData,
      child: allHistory.isEmpty
          ? _buildEmptyHistory()
          : ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: allHistory.length,
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemBuilder: (context, index) {
                final item = allHistory[index];
                if (item is Bill) {
                  return _buildPaidBillCard(item);
                } else if (item is Transaction) {
                  return _buildTransactionItem(item);
                } else {
                  return Container();
                }
              },
            ),
    );
  }

  Widget _buildPaidBillCard(Bill bill) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header status lunas
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.verified, color: Colors.green.shade600, size: 18),
                const SizedBox(width: 8),
                Text(
                  'TAGIHAN LUNAS',
                  style: TextStyle(
                    color: Colors.green.shade600,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                const Spacer(),
                Text(
                  _formatDate(bill.dueDate),
                  style: TextStyle(color: Colors.green.shade600, fontSize: 11),
                ),
              ],
            ),
          ),

          // Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            bill.title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            bill.description,
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Text(
                        'Rp ${_formatCurrency(bill.amount)}',
                        style: TextStyle(
                          color: Colors.green.shade800,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Payment Info
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.credit_card,
                        size: 16,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Metode Pembayaran',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Transfer Bank', // Default value
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
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
        ],
      ),
    );
  }

  Widget _buildTransactionItem(Transaction transaction) {
    final isIncome = transaction.isIncome;
    final icon = isIncome ? Icons.arrow_downward : Icons.arrow_upward;
    final color = isIncome ? Colors.green.shade600 : Colors.blue.shade600;
    final bgColor = isIncome ? Colors.green.shade50 : Colors.blue.shade50;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.description,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        transaction.category,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatDate(transaction.date),
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                transaction.formattedAmount,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isIncome ? 'PEMASUKAN' : 'PENGELUARAN',
                  style: TextStyle(
                    color: color,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyHistory() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_toggle_off, size: 80, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'Belum ada riwayat',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Riwayat pembayaran akan muncul di sini',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // === SISTEM PEMBAYARAN YANG DIPERBAIKI ===
  void _showPaymentMethodDialog(Bill bill) {
    String selectedMethod = 'QRIS';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Container(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    const Text(
                      'Pilih Metode Pembayaran',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Tagihan info
                    Row(
                      children: [
                        Text(
                          'Tagihan: ${bill.title}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 4),

                    // Amount
                    Text(
                      'Rp ${_formatCurrency(bill.amount)}',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Garis pemisah
                    Container(height: 1, color: Colors.grey.shade300),

                    const SizedBox(height: 16),

                    // Payment methods list - PENTING: Pindahkan pembuatan list ke dalam StatefulBuilder
                    _buildPaymentMethodList(setState, selectedMethod, (
                      newMethod,
                    ) {
                      setState(() {
                        selectedMethod = newMethod;
                      });
                    }),

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
                            onPressed: () {
                              Navigator.pop(context);
                              _processPaymentSelection(bill, selectedMethod);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue.shade700,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 2,
                            ),
                            child: const Text(
                              'Lanjutkan',
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
            );
          },
        );
      },
    );
  }

  Widget _buildPaymentMethodList(
    StateSetter setState,
    String selectedMethod,
    Function(String) onMethodSelected,
  ) {
    final methods = [
      {
        'id': 'QRIS',
        'name': 'QRIS',
        'description': 'Scan QR Code',
        'icon': Icons.qr_code_2,
        'color': Colors.purple,
      },
      {
        'id': 'CASH',
        'name': 'Tunai',
        'description': 'Bayar tunai',
        'icon': Icons.money,
        'color': Colors.green,
      },
      {
        'id': 'BANK_TRANSFER',
        'name': 'Transfer Bank',
        'description': 'Transfer bank',
        'icon': Icons.account_balance,
        'color': Colors.blue,
      },
      {
        'id': 'MOBILE_BANKING',
        'name': 'Mobile Banking',
        'description': 'Aplikasi bank',
        'icon': Icons.phone_android,
        'color': Colors.orange,
      },
    ];

    return Column(
      children: methods.map((method) {
        final isSelected = selectedMethod == method['id'];
        return GestureDetector(
          onTap: () {
            onMethodSelected(method['id'] as String);
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isSelected
                  ? (method['color'] as Color).withOpacity(0.9)
                  : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected
                    ? method['color'] as Color
                    : Colors.grey.shade300,
                width: isSelected ? 2 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isSelected ? 0.1 : 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                // Icon
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.white
                        : (method['color'] as Color).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    method['icon'] as IconData,
                    color: isSelected
                        ? method['color'] as Color
                        : method['color'] as Color,
                    size: 22,
                  ),
                ),

                const SizedBox(width: 16),

                // Text content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        method['name'] as String,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        method['description'] as String,
                        style: TextStyle(
                          fontSize: 14,
                          color: isSelected
                              ? Colors.white.withOpacity(0.9)
                              : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),

                // Radio button
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? Colors.white : Colors.grey.shade400,
                      width: 2,
                    ),
                  ),
                  child: isSelected
                      ? Center(
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                          ),
                        )
                      : null,
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  void _processPaymentSelection(Bill bill, String paymentMethod) {
    switch (paymentMethod) {
      case 'QRIS':
        _showQRISPayment(bill);
        break;
      case 'CASH':
        _showCashPayment(bill);
        break;
      case 'BANK_TRANSFER':
        _showBankTransferPayment(bill);
        break;
      case 'MOBILE_BANKING':
        _showMobileBankingPayment(bill);
        break;
      default:
        _showGenericPayment(bill, paymentMethod);
    }
  }

  void _showQRISPayment(Bill bill) {
    // Generate unique QR data
    final qrData =
        'DANA_COMMUNITY|${bill.id}|${bill.amount}|${DateTime.now().millisecondsSinceEpoch}';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              const Row(
                children: [
                  Icon(Icons.qr_code_2, color: Colors.purple),
                  SizedBox(width: 12),
                  Text(
                    'Pembayaran QRIS',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // QR Code Section
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.purple.shade100,
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.purple.withOpacity(0.1),
                            blurRadius: 10,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.qr_code_2,
                            size: 80,
                            color: Colors.purple.shade600,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'QR CODE',
                            style: TextStyle(
                              color: Colors.purple.shade700,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Scan untuk bayar',
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

              const SizedBox(height: 20),

              // Payment Details
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    _buildQRISDetailRow('Tagihan', bill.title),
                    const SizedBox(height: 8),
                    _buildQRISDetailRow(
                      'Jumlah',
                      'Rp ${_formatCurrency(bill.amount)}',
                    ),
                    const SizedBox(height: 8),
                    _buildQRISDetailRow(
                      'Kode QR',
                      qrData.substring(0, 20) + '...',
                    ),
                    const SizedBox(height: 8),
                    _buildQRISDetailRow(
                      'Status',
                      'Menunggu Pembayaran',
                      statusColor: Colors.orange,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Garis pemisah
              Container(height: 1, color: Colors.grey.shade300),

              const SizedBox(height: 16),

              // Instructions
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Cara Pembayaran:',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildInstructionStep(
                    '1. Buka aplikasi e-wallet atau mobile banking',
                  ),
                  _buildInstructionStep('2. Pilih fitur QRIS'),
                  _buildInstructionStep('3. Scan QR code di atas'),
                  _buildInstructionStep('4. Konfirmasi pembayaran'),
                ],
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
                      onPressed: () => _confirmQRISPayment(bill, qrData),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple.shade600,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      child: const Text(
                        'Sudah Bayar',
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

  Widget _buildQRISDetailRow(String label, String value, {Color? statusColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: statusColor ?? Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildInstructionStep(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('• ', style: TextStyle(color: Colors.grey.shade600)),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
            ),
          ),
        ],
      ),
    );
  }

  void _showCashPayment(Bill bill) {
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
              const Row(
                children: [
                  Icon(Icons.money, color: Colors.green),
                  SizedBox(width: 12),
                  Text(
                    'Pembayaran Tunai',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Icon besar
              Center(
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.green.shade100, width: 3),
                  ),
                  child: Icon(
                    Icons.money,
                    size: 50,
                    color: Colors.green.shade600,
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Amount
              Center(
                child: Column(
                  children: [
                    Text(
                      'Jumlah Pembayaran',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Rp ${_formatCurrency(bill.amount)}',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Instructions
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.shade100),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Instruksi Pembayaran:',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.green.shade800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildCashInstruction(
                      '1. Bawa uang tunai sebesar jumlah di atas',
                    ),
                    _buildCashInstruction(
                      '2. Temui bendahara atau petugas yang ditunjuk',
                    ),
                    _buildCashInstruction(
                      '3. Tunjukkan bukti ini kepada petugas',
                    ),
                    _buildCashInstruction('4. Terima tanda terima pembayaran'),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // Note
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade100),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.orange.shade600,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Simpan bukti pembayaran ini sebagai arsip',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange.shade800,
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
                      onPressed: () => _confirmCashPayment(bill),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade600,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      child: const Text(
                        'Konfirmasi Bayar',
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

  Widget _buildCashInstruction(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('• ', style: TextStyle(color: Colors.green.shade600)),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 13, color: Colors.green.shade800),
            ),
          ),
        ],
      ),
    );
  }

  void _showBankTransferPayment(Bill bill) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          child: SingleChildScrollView(
            child: Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  const Row(
                    children: [
                      Icon(Icons.account_balance, color: Colors.blue),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Transfer Bank',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Icon besar
                  Center(
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.blue.shade100,
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        Icons.account_balance,
                        size: 40,
                        color: Colors.blue.shade600,
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Bank Details
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.shade100),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'Rekening Tujuan',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildBankDetailRow('Bank', 'Bank Central Asia (BCA)'),
                        const SizedBox(height: 6),
                        _buildBankDetailRow('No. Rekening', '1234-5678-9012'),
                        const SizedBox(height: 6),
                        _buildBankDetailRow(
                          'Atas Nama',
                          'DANA COMMUNITY RT 05',
                        ),
                        const SizedBox(height: 6),
                        _buildBankDetailRow('Cabang', 'Jakarta Pusat'),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blue.shade200),
                          ),
                          child: Column(
                            children: [
                              Text(
                                'Jumlah Transfer',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Rp ${_formatCurrency(bill.amount)}',
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Unique Code
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.security,
                          color: Colors.blue.shade700,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Kode Unik Transfer',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.blue.shade800,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '123',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue.shade900,
                                ),
                              ),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            // Copy to clipboard
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Kode unik disalin'),
                                backgroundColor: Colors.green,
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Icon(
                              Icons.copy,
                              color: Colors.blue.shade600,
                              size: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Note
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.shade100),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: Colors.orange.shade600,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Pastikan mentransfer dengan jumlah yang tepat termasuk kode unik',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.orange.shade800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Tombol aksi
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
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
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _confirmBankTransferPayment(bill),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade600,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 2,
                          ),
                          child: const Text(
                            'Sudah Transfer',
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
        ),
      ),
    );
  }

  Widget _buildBankDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  void _showMobileBankingPayment(Bill bill) {
    String selectedBank = 'BCA Mobile';

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          child: SingleChildScrollView(
            child: StatefulBuilder(
              builder: (context, setState) {
                return Container(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      const Row(
                        children: [
                          Icon(Icons.phone_android, color: Colors.orange),
                          SizedBox(width: 12),
                          Text(
                            'Mobile Banking',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // Icon besar
                      Center(
                        child: Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.orange.shade100,
                              width: 3,
                            ),
                          ),
                          child: Icon(
                            Icons.phone_android,
                            size: 50,
                            color: Colors.orange.shade600,
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Pilih Bank
                      Text(
                        'Pilih Bank Anda:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade800,
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Bank List
                      Column(
                        children: [
                          _buildBankOption(
                            'BCA Mobile',
                            Icons.mobile_friendly,
                            'BCA',
                            selectedBank,
                            () {
                              setState(() {
                                selectedBank = 'BCA Mobile';
                              });
                            },
                          ),
                          const SizedBox(height: 8),
                          _buildBankOption(
                            'BNI Mobile Banking',
                            Icons.smartphone,
                            'BNI',
                            selectedBank,
                            () {
                              setState(() {
                                selectedBank = 'BNI Mobile Banking';
                              });
                            },
                          ),
                          const SizedBox(height: 8),
                          _buildBankOption(
                            'Mandiri Online',
                            Icons.laptop_mac,
                            'Mandiri',
                            selectedBank,
                            () {
                              setState(() {
                                selectedBank = 'Mandiri Online';
                              });
                            },
                          ),
                          const SizedBox(height: 8),
                          _buildBankOption(
                            'BRI Mobile',
                            Icons.tablet_mac,
                            'BRI',
                            selectedBank,
                            () {
                              setState(() {
                                selectedBank = 'BRI Mobile';
                              });
                            },
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // Payment Info
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Jumlah Pembayaran',
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  'Rp ${_formatCurrency(bill.amount)}',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Kode Unik',
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  '123',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.orange.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Instructions
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Cara Pembayaran:',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.orange.shade800,
                              ),
                            ),
                            const SizedBox(height: 8),
                            _buildMobileBankingInstruction(
                              '1. Buka aplikasi $selectedBank',
                            ),
                            _buildMobileBankingInstruction(
                              '2. Pilih menu "Transfer" atau "Bayar"',
                            ),
                            _buildMobileBankingInstruction(
                              '3. Masukkan nomor rekening tujuan',
                            ),
                            _buildMobileBankingInstruction(
                              '4. Masukkan jumlah yang benar',
                            ),
                            _buildMobileBankingInstruction(
                              '5. Konfirmasi pembayaran',
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
                              onPressed: () {
                                Navigator.pop(context);
                                _confirmMobileBankingPayment(bill, selectedBank);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange.shade600,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 2,
                              ),
                              child: const Text(
                                'Lanjutkan',
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
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBankOption(
    String bankName,
    IconData icon,
    String bankCode,
    String selectedBank,
    VoidCallback onTap,
  ) {
    final isSelected = selectedBank == bankName;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.orange.shade50 : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.orange.shade300 : Colors.grey.shade200,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.orange.shade100
                    : Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: isSelected
                    ? Colors.orange.shade600
                    : Colors.grey.shade600,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    bankName,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? Colors.orange.shade800
                          : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    bankCode,
                    style: TextStyle(
                      fontSize: 12,
                      color: isSelected
                          ? Colors.orange.shade600
                          : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? Colors.orange.shade600
                      : Colors.grey.shade400,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: Colors.orange.shade600,
                          shape: BoxShape.circle,
                        ),
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileBankingInstruction(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('• ', style: TextStyle(color: Colors.orange.shade600)),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 12, color: Colors.orange.shade800),
            ),
          ),
        ],
      ),
    );
  }

  // Payment Confirmation Methods
  Future<void> _confirmQRISPayment(Bill bill, String qrData) async {
    Navigator.pop(context); // Close QRIS dialog
    await _processPayment(bill, 'QRIS', qrData: qrData);
  }

  Future<void> _confirmCashPayment(Bill bill) async {
    // Tutup dialog cash
    Navigator.pop(context);

    // Tunggu sebentar agar dialog tertutup sempurna
    await Future.delayed(const Duration(milliseconds: 300));

    // Proses pembayaran
    await _processPayment(bill, 'CASH');
  }

  Future<void> _confirmBankTransferPayment(Bill bill) async {
    // Tutup dialog bank transfer
    Navigator.pop(context);

    // Tunggu sebentar agar dialog tertutup sempurna
    await Future.delayed(const Duration(milliseconds: 300));

    // Proses pembayaran
    await _processPayment(bill, 'BANK_TRANSFER');
  }

  Future<void> _confirmMobileBankingPayment(Bill bill, String bank) async {
    // Tutup dialog mobile banking
    Navigator.pop(context);

    // Tunggu sebentar agar dialog tertutup sempurna
    await Future.delayed(const Duration(milliseconds: 300));

    // Proses pembayaran
    await _processPayment(bill, 'MOBILE_BANKING', bank: bank);
  }
  void _showGenericPayment(Bill bill, String method) {
    // Generic payment handler
    _processPayment(bill, method);
  }

  // DI dana_screen.dart - SESUAI FORMAT BACKEND
  Future<void> _processPayment(
    Bill bill,
    String paymentMethod, {
    String? qrData,
    String? bank,
  }) async {
    try {
      setState(() {
      });

      // Show processing dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                'Memproses pembayaran ${_getPaymentMethodName(paymentMethod)}...',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );

      // Gunakan token yang sudah disimpan
      if (_token == null) {
        throw Exception('Token tidak ditemukan. Silakan login ulang.');
      }

      // Process payment dengan token yang valid
      try {
        print(
          '🔄 Memproses pembayaran dengan token: ${_token!.substring(0, 20)}...',
        );
        // Implementasi pembayaran sesuai dengan API Anda
        // await _billService!.payBill(bill.id, paymentMethod);

        // Simulasi delay
        await Future.delayed(const Duration(seconds: 2));
      } catch (e) {
        print('❌ Gagal memproses pembayaran: $e');
        rethrow;
      }

      // Close processing dialog
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      print('✅ Payment successful!');
      _showSuccessSnackbar(
        'Pembayaran dengan ${_getPaymentMethodName(paymentMethod)} berhasil!',
      );

      // Refresh data
      await _loadData();

      // Switch to history tab
      _tabController.animateTo(1);
    } catch (e) {
      print('❌ Semua method pembayaran gagal: $e');

      // Close processing dialog jika masih terbuka
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      _showErrorDialog(
        'Gagal Memproses Pembayaran',
        'Terjadi kesalahan: ${e.toString()}\n\n'
            'Silakan coba lagi atau hubungi administrator.',
      );
    } finally {
      setState(() {
      });
    }
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: const Icon(Icons.error_outline, size: 60, color: Colors.red),
        title: Text(title, textAlign: TextAlign.center),
        content: Text(message, textAlign: TextAlign.center),
        actions: [
          Center(
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white,
              ),
              child: const Text('Mengerti'),
            ),
          ),
        ],
      ),
    );
  }

  // Juga perbaiki method showSimplePaymentDialog untuk menggunakan method yang baru

  // Pastikan method helper ini ada
  String _getPaymentMethodName(String method) {
    switch (method) {
      case 'QRIS':
        return 'QRIS';
      case 'CASH':
        return 'Tunai';
      case 'BANK_TRANSFER':
        return 'Transfer Bank';
      case 'MOBILE_BANKING':
        return 'Mobile Banking';
      default:
        return method;
    }
  }

  // Helper Methods
  int _calculateDaysOverdue(DateTime dueDate) {
    final now = DateTime.now();
    final difference = now.difference(dueDate).inDays;
    return difference > 0 ? difference : 0;
  }

  String _formatCurrency(double amount) {
    final absoluteAmount = amount.abs();
    final formatted = absoluteAmount
        .toStringAsFixed(0)
        .replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]}.',
        );
    return amount < 0 ? '-$formatted' : formatted;
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    final dateToCheck = DateTime(date.year, date.month, date.day);

    if (dateToCheck == today) {
      return 'Hari ini';
    } else if (dateToCheck == yesterday) {
      return 'Kemarin';
    } else {
      return '${date.day}/${date.month}/${date.year}';
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
        duration: const Duration(seconds: 4),
      ),
    );
  }

}
