import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/config.dart';
import '../models/notification_model.dart';
import '../services/auth_service.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  // 🔄 PERBAIKAN: Get all notifications
  static Future<List<NotificationModel>> getNotifications({
    bool? isRead,
    String? type,
    int? limit,
    bool? archived,
  }) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) throw Exception('Token not found');

      final url = Uri.parse('${Config.apiUrl}/notifications').replace(
        queryParameters: {
          if (isRead != null) 'isRead': isRead.toString(),
          if (type != null) 'type': type,
          if (limit != null) 'limit': limit.toString(),
          if (archived != null) 'archived': archived.toString(),
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

      if (response.statusCode == 200) {
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
        print('❌ Failed to load notifications: ${response.statusCode}');
        throw Exception('Gagal memuat notifikasi: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error getting notifications: $e');
      rethrow;
    }
  }

  // 🔄 PERBAIKAN: Get unread count - sesuai dengan controller
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

      if (response.statusCode == 200) {
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
      return 0;
    }
  }

  // 🔄 PERBAIKAN: Mark as read - sesuai dengan controller yang baru
  static Future<Map<String, dynamic>> markAsRead({
    String? notificationId,
    List<String>? ids,
  }) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        print('⚠️ No token found for mark as read');
        return {'success': false, 'count': 0};
      }

      final url = Uri.parse('${Config.apiUrl}/notifications/mark-read');
      final body = json.encode({
        if (notificationId != null) 'notificationId': notificationId,
        if (ids != null && ids.isNotEmpty) 'ids': ids,
      });

      print('📝 Marking notifications as read...');

      final response = await http.put(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: body,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('✅ Successfully marked notifications as read: ${data['count']}');
        return {'success': true, 'count': data['count'] ?? 0};
      } else if (response.statusCode == 401) {
        print('❌ Unauthorized for mark as read');
        return {'success': false, 'count': 0};
      } else {
        print('⚠️ Failed to mark as read: ${response.statusCode}');
        return {'success': false, 'count': 0};
      }
    } catch (e) {
      print('⚠️ Error marking as read: $e');
      return {'success': false, 'count': 0};
    }
  }

  // 🔄 PERBAIKAN: Mark all as read - simplified
  static Future<Map<String, dynamic>> markAllAsRead() async {
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        print('⚠️ No token found for mark all as read');
        return {'success': false, 'count': 0};
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

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final count = data['count'] ?? 0;
        print('✅ Successfully marked $count notifications as read');
        return {'success': true, 'count': count};
      } else if (response.statusCode == 401) {
        print('❌ Unauthorized for mark all as read');
        return {'success': false, 'count': 0};
      } else {
        print('⚠️ Failed to mark all as read: ${response.statusCode}');
        return {'success': false, 'count': 0};
      }
    } catch (e) {
      print('⚠️ Error marking all as read: $e');
      return {'success': false, 'count': 0};
    }
  }

  // 🔄 PERBAIKAN: Archive notification - sesuai dengan controller
  static Future<bool> archiveNotification(String id) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        print('⚠️ No token found for archive');
        return false;
      }

      final url = Uri.parse('${Config.apiUrl}/notifications/archive/$id');

      print('📦 Archiving notification $id...');

      final response = await http.put(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        print('✅ Successfully archived notification');
        return true;
      } else if (response.statusCode == 401) {
        print('❌ Unauthorized for archive');
        return false;
      } else if (response.statusCode == 404) {
        print('❌ Notification not found');
        return false;
      } else {
        print('⚠️ Failed to archive: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('⚠️ Error archiving notification: $e');
      return false;
    }
  }

  // 🔄 PERBAIKAN: Delete notification
  static Future<bool> deleteNotification(String id) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        print('⚠️ No token found for delete');
        return false;
      }

      final url = Uri.parse('${Config.apiUrl}/notifications/$id');

      print('🗑️ Deleting notification $id...');

      final response = await http.delete(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        print('✅ Successfully deleted notification');
        return true;
      } else if (response.statusCode == 401) {
        print('❌ Unauthorized for delete');
        return false;
      } else if (response.statusCode == 404) {
        print('❌ Notification not found');
        return false;
      } else {
        print('⚠️ Failed to delete: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('⚠️ Error deleting notification: $e');
      return false;
    }
  }

  // 🔄 PERBAIKAN: Get notification stats
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

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print(
          '📊 Stats loaded: ${data['total']} total, ${data['unread']} unread',
        );
        return data;
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

  // =============================================
  // TESTING ENDPOINTS (Sesuai dengan controller)
  // =============================================

  // 🔄 PERBAIKAN: Create test notification (sesuai dengan endpoint baru)
  static Future<Map<String, dynamic>> createTestNotification() async {
    try {
      final token = await AuthService.getToken();
      if (token == null) throw Exception('Token not found');

      final url = Uri.parse('${Config.apiUrl}/notifications/test/notification');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        print('✅ Test notification created successfully');
        return {
          'success': true,
          'message': data['message'],
          'notification': data['notification'],
        };
      } else {
        print('⚠️ Failed to create test notification: ${response.statusCode}');
        return {
          'success': false,
          'message': 'Failed to create test notification',
        };
      }
    } catch (e) {
      print('⚠️ Error creating test notification: $e');
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  // 🔄 BARU: Test broadcast notification
  static Future<Map<String, dynamic>> testBroadcastNotification() async {
    try {
      final token = await AuthService.getToken();
      if (token == null) throw Exception('Token not found');

      final url = Uri.parse('${Config.apiUrl}/notifications/test/broadcast');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('✅ Broadcast test sent successfully');
        return {'success': true, 'message': data['message']};
      } else {
        print('⚠️ Failed to send broadcast test: ${response.statusCode}');
        return {'success': false, 'message': 'Failed to send broadcast test'};
      }
    } catch (e) {
      print('⚠️ Error sending broadcast test: $e');
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  // 🔄 BARU: Test send to specific user
  static Future<Map<String, dynamic>> testSendToSpecificUser(
    int targetUserId,
  ) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) throw Exception('Token not found');

      final url = Uri.parse(
        '${Config.apiUrl}/notifications/test/specific/$targetUserId',
      );

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('✅ Test notification sent to user $targetUserId');
        return {'success': true, 'message': data['message']};
      } else {
        print('⚠️ Failed to send to specific user: ${response.statusCode}');
        return {'success': false, 'message': 'Failed to send to specific user'};
      }
    } catch (e) {
      print('⚠️ Error sending to specific user: $e');
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  // 🔄 BARU: Test announcement notification
  static Future<Map<String, dynamic>> testAnnouncementNotification() async {
    try {
      final token = await AuthService.getToken();
      if (token == null) throw Exception('Token not found');

      final url = Uri.parse('${Config.apiUrl}/notifications/test/announcement');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        print('✅ Test announcement created successfully');
        return {
          'success': true,
          'message': data['message'],
          'result': data['result'],
        };
      } else {
        print('⚠️ Failed to create test announcement: ${response.statusCode}');
        return {
          'success': false,
          'message': 'Failed to create test announcement',
        };
      }
    } catch (e) {
      print('⚠️ Error creating test announcement: $e');
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  // 🔄 BARU: Test emergency notification
  static Future<Map<String, dynamic>> testEmergencyNotification() async {
    try {
      final token = await AuthService.getToken();
      if (token == null) throw Exception('Token not found');

      final url = Uri.parse('${Config.apiUrl}/notifications/test/emergency');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        print('✅ Test emergency notification created');
        return {
          'success': true,
          'message': data['message'],
          'notification': data['notification'],
        };
      } else {
        print('⚠️ Failed to create test emergency: ${response.statusCode}');
        return {'success': false, 'message': 'Failed to create test emergency'};
      }
    } catch (e) {
      print('⚠️ Error creating test emergency: $e');
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  // 🔄 BARU: Test payment notification
  static Future<Map<String, dynamic>> testPaymentNotification() async {
    try {
      final token = await AuthService.getToken();
      if (token == null) throw Exception('Token not found');

      final url = Uri.parse('${Config.apiUrl}/notifications/test/payment');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        print('✅ Test payment notification created');
        return {
          'success': true,
          'message': data['message'],
          'notification': data['notification'],
        };
      } else {
        print('⚠️ Failed to create test payment: ${response.statusCode}');
        return {'success': false, 'message': 'Failed to create test payment'};
      }
    } catch (e) {
      print('⚠️ Error creating test payment: $e');
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  // 🔄 BARU: Test bill notification
  static Future<Map<String, dynamic>> testBillNotification() async {
    try {
      final token = await AuthService.getToken();
      if (token == null) throw Exception('Token not found');

      final url = Uri.parse('${Config.apiUrl}/notifications/test/bill');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        print('✅ Test bill notification created');
        return {
          'success': true,
          'message': data['message'],
          'notification': data['notification'],
        };
      } else {
        print('⚠️ Failed to create test bill: ${response.statusCode}');
        return {'success': false, 'message': 'Failed to create test bill'};
      }
    } catch (e) {
      print('⚠️ Error creating test bill: $e');
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  // 🔄 BARU: Ping WebSocket
  static Future<Map<String, dynamic>> pingWebSocket() async {
    try {
      final token = await AuthService.getToken();
      if (token == null) throw Exception('Token not found');

      final url = Uri.parse('${Config.apiUrl}/notifications/test/ws-ping');

      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('✅ WebSocket ping sent');
        return {'success': true, 'message': data['message']};
      } else {
        print('⚠️ Failed to ping WebSocket: ${response.statusCode}');
        return {'success': false, 'message': 'Failed to ping WebSocket'};
      }
    } catch (e) {
      print('⚠️ Error pinging WebSocket: $e');
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  // 🔄 BARU: Get notification by ID
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

      if (response.statusCode == 200) {
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

  // 🔄 BARU: Get recent notifications
  static Future<List<NotificationModel>> getRecentNotifications() async {
    try {
      return await getNotifications(limit: 20);
    } catch (e) {
      print('⚠️ Error getting recent notifications: $e');
      return [];
    }
  }

  // 🔄 BARU: Get important notifications
  static Future<List<NotificationModel>> getImportantNotifications() async {
    try {
      final allNotifications = await getNotifications(isRead: false);

      return allNotifications.where((notification) {
        final type = notification.type;
        return type == NotificationType.EMERGENCY ||
            type == NotificationType.BILL ||
            type == NotificationType.SECURITY ||
            type == NotificationType.ANNOUNCEMENT;
      }).toList();
    } catch (e) {
      print('⚠️ Error getting important notifications: $e');
      return [];
    }
  }
}
