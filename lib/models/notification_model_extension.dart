import 'notification_model.dart';

extension NotificationModelExtension on NotificationModel {
  NotificationModel copyWith({
    String? id,
    int? userId,
    NotificationType? type,
    String? title,
    String? message,
    String? icon,
    String? iconColor,
    Map<String, dynamic>? data,
    bool? isRead,
    bool? isArchived,
    DateTime? scheduledAt,
    DateTime? expiresAt,
    int? createdBy,
    String? relatedEntityId,
    String? relatedEntityType,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? readAt,
    DateTime? archivedAt,
    UserInfo? createdByUser,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      title: title ?? this.title,
      message: message ?? this.message,
      icon: icon ?? this.icon,
      iconColor: iconColor ?? this.iconColor,
      data: data ?? this.data,
      isRead: isRead ?? this.isRead,
      isArchived: isArchived ?? this.isArchived,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      expiresAt: expiresAt ?? this.expiresAt,
      createdBy: createdBy ?? this.createdBy,
      relatedEntityId: relatedEntityId ?? this.relatedEntityId,
      relatedEntityType: relatedEntityType ?? this.relatedEntityType,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      readAt: readAt ?? this.readAt,
      archivedAt: archivedAt ?? this.archivedAt,
      createdByUser: createdByUser ?? this.createdByUser,
    );
  }

  // Helper untuk mark as read
  NotificationModel markAsRead() {
    return copyWith(isRead: true, readAt: DateTime.now());
  }

  // Helper untuk mark as unread
  NotificationModel markAsUnread() {
    return copyWith(isRead: false, readAt: null);
  }

  // Helper untuk archive
  NotificationModel archive() {
    return copyWith(isArchived: true, archivedAt: DateTime.now());
  }

  // Helper untuk unarchive
  NotificationModel unarchive() {
    return copyWith(isArchived: false, archivedAt: null);
  }

  // Check if notification is actionable
  bool get hasAction {
    final actionData = data;
    if (actionData == null) return false;

    return actionData.containsKey('action') &&
        actionData['action'] != null &&
        actionData['action'].toString().isNotEmpty;
  }

  // Get action from data
  String? get action {
    return data?['action']?.toString();
  }

  // Get entity ID from data
  String? get entityId {
    return data?['entityId']?.toString() ?? relatedEntityId;
  }

  // Get entity type from data
  String? get entityType {
    return data?['entityType']?.toString() ?? relatedEntityType;
  }

  // Check if notification requires immediate attention
  bool get isUrgent {
    return type == NotificationType.EMERGENCY ||
        (type == NotificationType.BILL && !isRead) ||
        (data?['priority'] == 'high');
  }

  // Get formatted date for display
  String get formattedDate {
    if (createdAt.day == DateTime.now().day) {
      return 'Hari ini, ${createdAt.hour}:${createdAt.minute.toString().padLeft(2, '0')}';
    } else if (createdAt.day == DateTime.now().day - 1) {
      return 'Kemarin, ${createdAt.hour}:${createdAt.minute.toString().padLeft(2, '0')}';
    } else {
      return '${createdAt.day}/${createdAt.month}/${createdAt.year} ${createdAt.hour}:${createdAt.minute.toString().padLeft(2, '0')}';
    }
  }

  // Get notification category
  String get category {
    switch (type) {
      case NotificationType.ANNOUNCEMENT:
        return 'Pengumuman';
      case NotificationType.EMERGENCY:
        return 'Darurat';
      case NotificationType.BILL:
        return 'Tagihan';
      case NotificationType.PAYMENT:
        return 'Pembayaran';
      case NotificationType.REPORT:
        return 'Laporan';
      case NotificationType.COMMUNITY:
        return 'Komunitas';
      case NotificationType.SECURITY:
        return 'Keamanan';
      case NotificationType.REMINDER:
        return 'Pengingat';
      default:
        return 'Sistem';
    }
  }
}
