import 'package:flutter/material.dart';

class NotificationModel {
  final String id;
  final int userId;
  final NotificationType type;
  final String title;
  final String message;
  final String? icon;
  final String? iconColor;
  final Map<String, dynamic>? data;
  final bool isRead;
  final bool isArchived;
  final DateTime? scheduledAt;
  final DateTime? expiresAt;
  final int createdBy;
  final String? relatedEntityId;
  final String? relatedEntityType;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? readAt;
  final DateTime? archivedAt;
  final UserInfo? createdByUser;

  NotificationModel({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.message,
    this.icon,
    this.iconColor,
    this.data,
    required this.isRead,
    required this.isArchived,
    this.scheduledAt,
    this.expiresAt,
    required this.createdBy,
    this.relatedEntityId,
    this.relatedEntityType,
    required this.createdAt,
    required this.updatedAt,
    this.readAt,
    this.archivedAt,
    this.createdByUser,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    // Debug: print raw JSON untuk troubleshooting
    // print('📄 Parsing notification JSON: $json');

    return NotificationModel(
      id: json['id']?.toString() ?? '',
      userId: json['userId'] != null
          ? int.tryParse(json['userId'].toString()) ?? 0
          : 0,
      type: _parseNotificationType(json['type']?.toString() ?? 'SYSTEM'),
      title: json['title']?.toString() ?? 'No Title',
      message: json['message']?.toString() ?? 'No Message',
      icon: json['icon']?.toString(),
      iconColor: json['iconColor']?.toString(),
      data: json['data'] != null && json['data'] is Map
          ? Map<String, dynamic>.from(json['data'])
          : null,
      isRead:
          json['isRead']?.toString().toLowerCase() == 'true' ||
          json['isRead'] == true ||
          (json['isRead'] is int && json['isRead'] == 1),
      isArchived:
          json['isArchived']?.toString().toLowerCase() == 'true' ||
          json['isArchived'] == true ||
          (json['isArchived'] is int && json['isArchived'] == 1),
      scheduledAt: json['scheduledAt'] != null
          ? DateTime.tryParse(json['scheduledAt'].toString())
          : null,
      expiresAt: json['expiresAt'] != null
          ? DateTime.tryParse(json['expiresAt'].toString())
          : null,
      createdBy: json['createdBy'] != null
          ? int.tryParse(json['createdBy'].toString()) ?? 0
          : 0,
      relatedEntityId: json['relatedEntityId']?.toString(),
      relatedEntityType: json['relatedEntityType']?.toString(),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      readAt: json['readAt'] != null
          ? DateTime.tryParse(json['readAt'].toString())
          : null,
      archivedAt: json['archivedAt'] != null
          ? DateTime.tryParse(json['archivedAt'].toString())
          : null,
      createdByUser:
          json['createdByUser'] != null && json['createdByUser'] is Map
          ? UserInfo.fromJson(Map<String, dynamic>.from(json['createdByUser']))
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'type': type.toString().split('.').last,
      'title': title,
      'message': message,
      'icon': icon,
      'iconColor': iconColor,
      'data': data,
      'isRead': isRead,
      'isArchived': isArchived,
      'scheduledAt': scheduledAt?.toIso8601String(),
      'expiresAt': expiresAt?.toIso8601String(),
      'createdBy': createdBy,
      'relatedEntityId': relatedEntityId,
      'relatedEntityType': relatedEntityType,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'readAt': readAt?.toIso8601String(),
      'archivedAt': archivedAt?.toIso8601String(),
      'createdByUser': createdByUser?.toJson(),
    };
  }

  static NotificationType _parseNotificationType(String type) {
    final typeStr = type.toUpperCase();

    // Cek tipe yang ada di enum NotificationType
    for (var value in NotificationType.values) {
      if (value.toString().split('.').last == typeStr) {
        return value;
      }
    }

    // Fallback berdasarkan string
    switch (typeStr) {
      case 'SYSTEM':
        return NotificationType.SYSTEM;
      case 'ANNOUNCEMENT':
        return NotificationType.ANNOUNCEMENT;
      case 'REPORT':
        return NotificationType.REPORT;
      case 'EMERGENCY':
        return NotificationType.EMERGENCY;
      case 'BILL':
        return NotificationType.BILL;
      case 'PAYMENT':
        return NotificationType.PAYMENT;
      case 'SECURITY':
        return NotificationType.SECURITY;
      case 'PROFILE':
        return NotificationType.PROFILE;
      case 'COMMUNITY':
        return NotificationType.COMMUNITY;
      case 'REMINDER':
        return NotificationType.REMINDER;
      case 'CUSTOM':
        return NotificationType.CUSTOM;
      default:
        // Debug: print tipe yang tidak dikenali
        print('⚠️ Unknown notification type: $typeStr');
        return NotificationType.SYSTEM;
    }
  }

  // Helper methods
  IconData get iconData {
    switch (icon?.toLowerCase()) {
      case 'announcement':
        return Icons.announcement;
      case 'warning':
        return Icons.warning;
      case 'payment':
        return Icons.payment;
      case 'receipt':
        return Icons.receipt;
      case 'people':
        return Icons.people;
      case 'security':
        return Icons.security;
      case 'event':
        return Icons.event;
      case 'report':
        return Icons.report;
      case 'profile':
        return Icons.person;
      case 'check_circle':
        return Icons.check_circle;
      default:
        return Icons.notifications;
    }
  }

  Color get color {
    if (iconColor != null && iconColor!.startsWith('#')) {
      try {
        final hexColor = iconColor!.replaceFirst('#', '');
        return Color(int.parse('FF$hexColor', radix: 16));
      } catch (e) {
        print('⚠️ Error parsing color: $e');
      }
    }

    // Fallback colors based on type
    switch (type) {
      case NotificationType.ANNOUNCEMENT:
        return Colors.blue.shade700;
      case NotificationType.EMERGENCY:
        return Colors.red.shade700;
      case NotificationType.BILL:
        return Colors.orange.shade700;
      case NotificationType.PAYMENT:
        return Colors.green.shade700;
      case NotificationType.REPORT:
        return Colors.amber.shade700;
      case NotificationType.SECURITY:
        return Colors.purple.shade700;
      case NotificationType.COMMUNITY:
        return Colors.teal.shade700;
      default:
        return Colors.grey.shade700;
    }
  }

  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inSeconds < 60) {
      return 'Baru saja';
    } else if (difference.inMinutes < 60) {
      final minutes = difference.inMinutes;
      return '$minutes ${minutes == 1 ? 'menit' : 'menit'} lalu';
    } else if (difference.inHours < 24) {
      final hours = difference.inHours;
      return '$hours ${hours == 1 ? 'jam' : 'jam'} lalu';
    } else if (difference.inDays < 30) {
      final days = difference.inDays;
      return '$days ${days == 1 ? 'hari' : 'hari'} lalu';
    } else if (difference.inDays < 365) {
      final months = (difference.inDays / 30).floor();
      return '$months ${months == 1 ? 'bulan' : 'bulan'} lalu';
    } else {
      final years = (difference.inDays / 365).floor();
      return '$years ${years == 1 ? 'tahun' : 'tahun'} lalu';
    }
  }

  bool get isImportant {
    return type == NotificationType.EMERGENCY ||
        type == NotificationType.BILL ||
        type == NotificationType.SECURITY;
  }

  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  bool get isScheduled {
    if (scheduledAt == null) return false;
    return DateTime.now().isBefore(scheduledAt!);
  }

  @override
  String toString() {
    return 'NotificationModel{id: $id, title: $title, type: $type, isRead: $isRead}';
  }
}

enum NotificationType {
  SYSTEM,
  ANNOUNCEMENT,
  REPORT,
  EMERGENCY,
  BILL,
  PAYMENT,
  SECURITY,
  PROFILE,
  COMMUNITY,
  REMINDER,
  CUSTOM,
}

class UserInfo {
  final int id;
  final String namaLengkap;
  final String? email;
  final String? role;

  UserInfo({
    required this.id,
    required this.namaLengkap,
    this.email,
    this.role,
  });

  factory UserInfo.fromJson(Map<String, dynamic> json) {
    return UserInfo(
      id: json['id'] != null ? int.tryParse(json['id'].toString()) ?? 0 : 0,
      namaLengkap: json['namaLengkap']?.toString() ?? 'Unknown',
      email: json['email']?.toString(),
      role: json['role']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'namaLengkap': namaLengkap, 'email': email, 'role': role};
  }
}
