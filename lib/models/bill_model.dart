// models/bill_model.dart
import 'package:warga_app/models/transaction_model.dart' show Pagination;
import 'package:warga_app/models/user_model.dart';

class Bill {
  final String id;
  final String title;
  final String description;
  final double amount;
  final DateTime dueDate;
  final String status; // PENDING, PAID, OVERDUE
  final String userId;
  final String createdBy;
  final DateTime createdAt;
  final DateTime? paidAt;
  final User? user;
  final User? createdByUser;

  Bill({
    required this.id,
    required this.title,
    required this.description,
    required this.amount,
    required this.dueDate,
    required this.status,
    required this.userId,
    required this.createdBy,
    required this.createdAt,
    this.paidAt,
    this.user,
    this.createdByUser,
  });

  factory Bill.fromJson(Map<String, dynamic> json) {
    return Bill(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      dueDate: DateTime.parse(json['dueDate']),
      status: json['status']?.toString() ?? 'PENDING',
      userId: json['userId']?.toString() ?? '',
      createdBy: json['createdBy']?.toString() ?? '',
      createdAt: DateTime.parse(json['createdAt']),
      paidAt: json['paidAt'] != null ? DateTime.parse(json['paidAt']) : null,
      user: json['user'] != null ? User.fromJson(json['user']) : null,
      createdByUser: json['createdByUser'] != null
          ? User.fromJson(json['createdByUser'])
          : null,
    );
  }

  bool get isPending => status == 'PENDING';
  bool get isPaid => status == 'PAID';
  bool get isOverdue =>
      status == 'OVERDUE' || (dueDate.isBefore(DateTime.now()) && isPending);

  String get formattedDueDate {
    final now = DateTime.now();
    final difference = dueDate.difference(now);

    if (difference.inDays == 0) return 'Hari ini';
    if (difference.inDays == 1) return 'Besok';
    if (difference.inDays > 1 && difference.inDays <= 7)
      return '${difference.inDays} hari lagi';
    if (difference.inDays < 0)
      return 'Terlambat ${difference.inDays.abs()} hari';

    return '${dueDate.day}/${dueDate.month}/${dueDate.year}';
  }
}

class BillResponse {
  final List<Bill> bills;
  final Pagination pagination;

  BillResponse({required this.bills, required this.pagination});

  factory BillResponse.fromJson(Map<String, dynamic> json) {
    return BillResponse(
      bills: (json['bills'] as List? ?? [])
          .map((item) => Bill.fromJson(item))
          .toList(),
      pagination: Pagination.fromJson(json['pagination'] ?? {}),
    );
  }
}
