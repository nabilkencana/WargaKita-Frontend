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
    return NotificationModel(
      id: json['id'],
      userId: json['userId'],
      type: _parseNotificationType(json['type']),
      title: json['title'],
      message: json['message'],
      icon: json['icon'],
      iconColor: json['iconColor'],
      data: json['data'] != null
          ? Map<String, dynamic>.from(json['data'])
          : null,
      isRead: json['isRead'],
      isArchived: json['isArchived'],
      scheduledAt: json['scheduledAt'] != null
          ? DateTime.parse(json['scheduledAt'])
          : null,
      expiresAt: json['expiresAt'] != null
          ? DateTime.parse(json['expiresAt'])
          : null,
      createdBy: json['createdBy'],
      relatedEntityId: json['relatedEntityId'],
      relatedEntityType: json['relatedEntityType'],
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
      readAt: json['readAt'] != null ? DateTime.parse(json['readAt']) : null,
      archivedAt: json['archivedAt'] != null
          ? DateTime.parse(json['archivedAt'])
          : null,
      createdByUser: json['createdByUser'] != null
          ? UserInfo.fromJson(json['createdByUser'])
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
    };
  }

  static NotificationType _parseNotificationType(String type) {
    switch (type) {
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
        return NotificationType.SYSTEM;
    }
  }

  IconData get iconData {
    switch (icon) {
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
      default:
        return Icons.notifications;
    }
  }

  Color get color {
    if (iconColor != null && iconColor!.startsWith('#')) {
      return Color(
        int.parse(iconColor!.substring(1, 7), radix: 16) + 0xFF000000,
      );
    }

    switch (type) {
      case NotificationType.ANNOUNCEMENT:
        return Colors.blue;
      case NotificationType.EMERGENCY:
        return Colors.red;
      case NotificationType.BILL:
        return Colors.red.shade700;
      case NotificationType.PAYMENT:
        return Colors.green;
      case NotificationType.REPORT:
        return Colors.orange;
      case NotificationType.SECURITY:
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inSeconds < 60) {
      return 'Baru saja';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} menit lalu';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} jam lalu';
    } else if (difference.inDays < 30) {
      return '${difference.inDays} hari lalu';
    } else {
      return '${(difference.inDays / 30).floor()} bulan lalu';
    }
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
      id: json['id'],
      namaLengkap: json['namaLengkap'],
      email: json['email'],
      role: json['role'],
    );
  }
}
