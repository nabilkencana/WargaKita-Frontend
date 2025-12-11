// models/laporan_model.dart
import 'package:flutter/material.dart';

class Laporan {
  final int id;
  final String title;
  final String description;
  final String category;
  final String status;
  final String? imageUrl;
  final String? imagePublicId;
  final int? userId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, dynamic>? user;

  Laporan({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.status,
    this.imageUrl,
    this.imagePublicId,
    this.userId,
    required this.createdAt,
    required this.updatedAt,
    this.user,
  });

  factory Laporan.fromJson(Map<String, dynamic> json) {
    return Laporan(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      category: json['category'] ?? 'Lainnya',
      status: json['status'] ?? 'PENDING',
      imageUrl: json['imageUrl'],
      imagePublicId: json['imagePublicId'],
      userId: json['userId'] != null
          ? (json['userId'] is String
                ? int.tryParse(json['userId'])
                : json['userId'] as int?)
          : null,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : DateTime.now(),
      user: json['user'] != null
          ? Map<String, dynamic>.from(json['user'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != 0) 'id': id,
      'title': title,
      'description': description,
      'category': category,
      'status': status,
      if (imageUrl != null) 'imageUrl': imageUrl,
      if (imagePublicId != null) 'imagePublicId': imagePublicId,
      if (userId != null) 'userId': userId,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      if (user != null) 'user': user,
    };
  }

  // Helper methods untuk UI
  Color get statusColor {
    switch (status.toUpperCase()) {
      case 'PENDING':
        return Colors.orange;
      case 'PROCESSING':
        return Colors.blue;
      case 'RESOLVED':
        return Colors.green;
      case 'REJECTED':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String get statusText {
    switch (status.toUpperCase()) {
      case 'PENDING':
        return 'Menunggu';
      case 'PROCESSING':
        return 'Diproses';
      case 'RESOLVED':
        return 'Selesai';
      case 'REJECTED':
        return 'Ditolak';
      default:
        return 'Tidak diketahui';
    }
  }

  IconData get categoryIcon {
    switch (category.toLowerCase()) {
      case 'infrastruktur':
        return Icons.construction;
      case 'kebersihan':
        return Icons.clean_hands;
      case 'keamanan':
        return Icons.security;
      case 'lingkungan':
        return Icons.nature;
      case 'lainnya':
        return Icons.category;
      default:
        return Icons.description;
    }
  }

  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inDays > 365) {
      return '${(difference.inDays / 365).floor()} tahun lalu';
    } else if (difference.inDays > 30) {
      return '${(difference.inDays / 30).floor()} bulan lalu';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} hari lalu';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} jam lalu';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} menit lalu';
    } else {
      return 'Baru saja';
    }
  }

  // Untuk form input (create/update)
  static Laporan empty() {
    return Laporan(
      id: 0,
      title: '',
      description: '',
      category: 'Infrastruktur',
      status: 'PENDING',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  // Copy with method untuk update
  Laporan copyWith({
    int? id,
    String? title,
    String? description,
    String? category,
    String? status,
    String? imageUrl,
    String? imagePublicId,
    int? userId,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, dynamic>? user,
  }) {
    return Laporan(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      status: status ?? this.status,
      imageUrl: imageUrl ?? this.imageUrl,
      imagePublicId: imagePublicId ?? this.imagePublicId,
      userId: userId ?? this.userId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      user: user ?? this.user,
    );
  }

  @override
  String toString() {
    return 'Laporan{id: $id, title: $title, category: $category, status: $status}';
  }
}
