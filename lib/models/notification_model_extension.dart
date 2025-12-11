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
}
