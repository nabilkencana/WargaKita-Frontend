import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/config.dart';
import '../models/notification_model.dart';
import '../services/auth_service.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  // 🔄 UPDATE: Get all notifications WITHOUT pagination (sesuai backend)
  static Future<List<NotificationModel>> getNotifications({
    bool? isRead,
    String? type,
    int? limit,
  }) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) throw Exception('Token not found');

      final url = Uri.parse('${Config.apiUrl}/notifications').replace(
        queryParameters: {
          if (isRead != null) 'isRead': isRead.toString(),
          if (type != null) 'type': type,
          if (limit != null) 'limit': limit.toString(),
        },
      );

      print('🔍 Fetching notifications from: ${url.toString()}');

      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print('📡 Notification response status: ${response.statusCode}');

      if (response.statusCode.toString().startsWith('2')) {
        final List<dynamic> data = json.decode(response.body);
        print('✅ Successfully fetched ${data.length} notifications');

        final notifications = data
            .map((item) {
              try {
                return NotificationModel.fromJson(item);
              } catch (e) {
                print('⚠️ Error parsing notification item: $e');
                print('   Raw item: $item');
                return null;
              }
            })
            .where((item) => item != null)
            .cast<NotificationModel>()
            .toList();

        return notifications;
      } else if (response.statusCode == 401) {
        print('❌ Unauthorized: Token expired or invalid');
        throw Exception('Sesi telah berakhir. Silakan login kembali.');
      } else {
        print('❌ Failed to load notifications: ${response.body}');
        throw Exception('Gagal memuat notifikasi: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error getting notifications: $e');
      rethrow;
    }
  }

  // 🔄 UPDATE: Get unread count - simplified
  static Future<int> getUnreadCount() async {
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        print('⚠️ No token found for unread count');
        return 0;
      }

      final url = Uri.parse('${Config.apiUrl}/notifications/unread-count');

      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode.toString().startsWith('2')) {
        final data = json.decode(response.body);
        final count = data['count'] ?? 0;
        print('📊 Unread notifications count: $count');
        return count;
      } else if (response.statusCode == 401) {
        print('❌ Unauthorized for unread count');
        return 0;
      } else {
        print('⚠️ Failed to get unread count: ${response.statusCode}');
        return 0;
      }
    } catch (e) {
      print('⚠️ Error getting unread count: $e');
      return 0; // Return 0 instead of throwing to prevent app crash
    }
  }

  // 🔄 UPDATE: Mark as read - simplified parameters
  static Future<bool> markAsRead(String notificationId) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        print('⚠️ No token found for mark as read');
        return false;
      }

      final url = Uri.parse('${Config.apiUrl}/notifications/mark-read');
      final body = json.encode({'notificationId': notificationId});

      print('📝 Marking notification $notificationId as read...');

      final response = await http.put(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: body,
      );

      if (response.statusCode.toString().startsWith('2')) {
        print('✅ Successfully marked notification as read');
        return true;
      } else if (response.statusCode == 401) {
        print('❌ Unauthorized for mark as read');
        return false;
      } else {
        print('⚠️ Failed to mark as read: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('⚠️ Error marking as read: $e');
      return false;
    }
  }

  // 🔄 UPDATE: Mark all as read - simplified
  static Future<bool> markAllAsRead() async {
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        print('⚠️ No token found for mark all as read');
        return false;
      }

      final url = Uri.parse('${Config.apiUrl}/notifications/mark-all-read');

      print('📝 Marking all notifications as read...');

      final response = await http.put(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode.toString().startsWith('2')) {
        final data = json.decode(response.body);
        final count = data['count'] ?? 0;
        print('✅ Successfully marked $count notifications as read');
        return true;
      } else if (response.statusCode == 401) {
        print('❌ Unauthorized for mark all as read');
        return false;
      } else {
        print('⚠️ Failed to mark all as read: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('⚠️ Error marking all as read: $e');
      return false;
    }
  }

  // DELETE: Archive notification - REMOVED karena tidak ada di backend
  // DELETE: Delete notification - REMOVED karena tidak ada di backend

  // 🔄 UPDATE: Get notification stats
  static Future<Map<String, dynamic>> getStats() async {
    try {
      final token = await AuthService.getToken();
      if (token == null) throw Exception('Token not found');

      final url = Uri.parse('${Config.apiUrl}/notifications/stats');

      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode.toString().startsWith('2')) {
        return json.decode(response.body);
      } else if (response.statusCode == 401) {
        throw Exception('Sesi telah berakhir');
      } else {
        print('⚠️ Failed to get stats: ${response.statusCode}');
        return {'total': 0, 'unread': 0, 'today': 0, 'byType': {}};
      }
    } catch (e) {
      print('⚠️ Error getting stats: $e');
      return {'total': 0, 'unread': 0, 'today': 0, 'byType': {}};
    }
  }

  // 🔄 TAMBAHKAN: Create test notification (for testing only)
  static Future<bool> createTestNotification() async {
    try {
      final token = await AuthService.getToken();
      if (token == null) throw Exception('Token not found');

      final url = Uri.parse('${Config.apiUrl}/notifications/test');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode.toString().startsWith('2') || response.statusCode == 201) {
        print('✅ Test notification created successfully');
        return true;
      } else {
        print('⚠️ Failed to create test notification: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('⚠️ Error creating test notification: $e');
      return false;
    }
  }

  // 🔄 TAMBAHKAN: Get notification by ID
  static Future<NotificationModel?> getNotificationById(String id) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) throw Exception('Token not found');

      final url = Uri.parse('${Config.apiUrl}/notifications/$id');

      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode.toString().startsWith('2')) {
        final data = json.decode(response.body);
        return NotificationModel.fromJson(data);
      } else if (response.statusCode == 404) {
        print('⚠️ Notification not found: $id');
        return null;
      } else {
        throw Exception('Failed to get notification: ${response.statusCode}');
      }
    } catch (e) {
      print('⚠️ Error getting notification by ID: $e');
      return null;
    }
  }

  // 🔄 TAMBAHKAN: Create custom notification (for admin use)
  static Future<bool> createCustomNotification({
    required int userId,
    required String title,
    required String message,
    required String type,
    String? icon,
    String? iconColor,
    Map<String, dynamic>? data,
  }) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) throw Exception('Token not found');

      final url = Uri.parse('${Config.apiUrl}/notifications');
      final body = json.encode({
        'userId': userId,
        'type': type,
        'title': title,
        'message': message,
        if (icon != null) 'icon': icon,
        if (iconColor != null) 'iconColor': iconColor,
        if (data != null) 'data': data,
      });

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: body,
      );

      if (response.statusCode.toString().startsWith('2') || response.statusCode == 201) {
        print('✅ Custom notification created for user $userId');
        return true;
      } else {
        print(
          '⚠️ Failed to create custom notification: ${response.statusCode}',
        );
        return false;
      }
    } catch (e) {
      print('⚠️ Error creating custom notification: $e');
      return false;
    }
  }

  // 🔄 TAMBAHKAN: Batch mark as read
  static Future<bool> markBatchAsRead(List<String> notificationIds) async {
    try {
      if (notificationIds.isEmpty) return true;

      final token = await AuthService.getToken();
      if (token == null) {
        print('⚠️ No token found for batch mark as read');
        return false;
      }

      final url = Uri.parse('${Config.apiUrl}/notifications/mark-read');
      final body = json.encode({'ids': notificationIds});

      print('📝 Marking ${notificationIds.length} notifications as read...');

      final response = await http.put(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: body,
      );

      if (response.statusCode.toString().startsWith('2')) {
        final data = json.decode(response.body);
        final count = data['count'] ?? 0;
        print('✅ Successfully marked $count notifications as read');
        return true;
      } else if (response.statusCode == 401) {
        print('❌ Unauthorized for batch mark as read');
        return false;
      } else {
        print('⚠️ Failed to batch mark as read: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('⚠️ Error in batch mark as read: $e');
      return false;
    }
  }

  // 🔄 TAMBAHKAN: Get recent notifications (last 7 days)
  static Future<List<NotificationModel>> getRecentNotifications() async {
    try {
      return await getNotifications(
        limit: 20, // Get last 20 notifications
      );
    } catch (e) {
      print('⚠️ Error getting recent notifications: $e');
      return [];
    }
  }

  // 🔄 TAMBAHKAN: Get important notifications (unread + high priority)
  static Future<List<NotificationModel>> getImportantNotifications() async {
    try {
      final allNotifications = await getNotifications(isRead: false);

      // Filter untuk notifikasi penting (emergency, bill overdue, dll)
      return allNotifications.where((notification) {
        final type = notification.type.toString();
        return type.contains('EMERGENCY') ||
            type.contains('BILL') ||
            type.contains('SECURITY') ||
            type.contains('ANNOUNCEMENT');
      }).toList();
    } catch (e) {
      print('⚠️ Error getting important notifications: $e');
      return [];
    }
  }

  // 🔄 TAMBAHKAN: Check if notifications are enabled
  static Future<bool> checkNotificationPermission() async {
    try {
      final token = await AuthService.getToken();
      if (token == null) return false;

      // Cek apakah user bisa menerima notifikasi
      final url = Uri.parse('${Config.apiUrl}/notifications/permission');

      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode.toString().startsWith('2')) {
        final data = json.decode(response.body);
        return data['enabled'] ?? true; // Default true jika tidak ada data
      }
      return true; // Default true jika ada error
    } catch (e) {
      print('⚠️ Error checking notification permission: $e');
      return true;
    }
  }
}
