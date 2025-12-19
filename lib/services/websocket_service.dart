// lib/services/websocket_service.dart
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';
import '../config/config.dart';

class WebSocketService {

  
  static final WebSocketService _instance = WebSocketService._internal();
  factory WebSocketService() => _instance;
  WebSocketService._internal();

  WebSocketChannel? _channel;
  bool _isConnected = false;

  // Callback untuk menerima notifikasi
  Function(Map<String, dynamic>)? onNotificationReceived;
  Function(Map<String, dynamic>)? onAnnouncementReceived;

  Future<void> connect(dynamic userId) async {
    try {
      // 1. Buat URL WebSocket yang benar
      final wsUrl = _buildWebSocketUrl(userId);
      print('🔗 Connecting to WebSocket: $wsUrl');

      // 2. Validate URL
      if (!_isValidWebSocketUrl(wsUrl)) {
        print('❌ Invalid WebSocket URL: $wsUrl');
        return;
      }

      // 3. Connect ke WebSocket
      _channel = IOWebSocketChannel.connect(
        Uri.parse(wsUrl),
        pingInterval: const Duration(seconds: 30),
      );

      _isConnected = true;
      print('✅ WebSocket connected successfully');

      // 4. Setup listener
      _channel!.stream.listen(
        (message) {
          print('📨 WebSocket message received: ${message.length} characters');
          if (message.length < 100) {
            print('   Content: $message');
          }
          _handleMessage(message);
        },
        onError: (error) {
          print('❌ WebSocket error: $error');
          _isConnected = false;
          _reconnect(userId);
        },
        onDone: () {
          print('🔌 WebSocket connection closed');
          _isConnected = false;
          _reconnect(userId);
        },
      );
    } catch (e) {
      print('❌ Failed to connect WebSocket: $e');
      print('❌ Error type: ${e.runtimeType}');
      _isConnected = false;

      // Coba reconnect dengan delay
      if (userId != null) {
        _reconnect(userId);
      }
    }
  }

  // Method untuk membangun URL WebSocket yang benar
  String _buildWebSocketUrl(dynamic userId) {
    // Gunakan base URL dari config
    final apiUrl = Config.apiUrl; // https://wargakita.canadev.my.id

    // Tentukan protocol WebSocket berdasarkan API URL
    String webSocketProtocol;
    String host;

    if (apiUrl.startsWith('https://')) {
      webSocketProtocol = 'wss://';
      host = apiUrl.replaceFirst('https://', '');
    } else if (apiUrl.startsWith('http://')) {
      webSocketProtocol = 'ws://';
      host = apiUrl.replaceFirst('http://', '');
    } else {
      // Jika tidak ada protocol, asumsikan https
      webSocketProtocol = 'wss://';
      host = apiUrl;
    }

    // Hapus trailing slash jika ada
    if (host.endsWith('/')) {
      host = host.substring(0, host.length - 1);
    }

    // Bangun URL lengkap
    return '$webSocketProtocol$host/notifications?userId=${userId.toString()}';
  }

  // Validasi URL WebSocket
  bool _isValidWebSocketUrl(String url) {
    if (!url.startsWith('ws://') && !url.startsWith('wss://')) {
      print('⚠️ URL must start with ws:// or wss://');
      return false;
    }

    if (url.contains('ws://ws://') ||
        url.contains('wss://wss://') ||
        url.contains('ws://wss://') ||
        url.contains('wss://ws://')) {
      print('⚠️ URL contains duplicate protocol');
      return false;
    }

    return true;
  }

  // lib/services/websocket_service.dart - perbaiki _handleMessage
  void _handleMessage(dynamic message) {
    try {
      print('=' * 50);
      print('📨 WEBSOCKET MESSAGE RECEIVED');
      print('=' * 50);

      // Log raw message
      print('📄 Raw message (first 500 chars):');
      final messageStr = message.toString();
      print(
        messageStr.length > 500
            ? '${messageStr.substring(0, 500)}...'
            : messageStr,
      );

      // Try to parse as JSON
      Map<String, dynamic> parsedData;
      try {
        parsedData = jsonDecode(message);
        print('✅ Successfully parsed as JSON');
        print('📊 JSON keys: ${parsedData.keys.toList()}');
      } catch (e) {
        print('⚠️ Failed to parse as JSON: $e');
        print('⚠️ Treating as plain text');
        parsedData = {'raw': message};
      }

      // Log structure
      if (parsedData.containsKey('type')) {
        print('🎯 Message type: ${parsedData['type']}');
      }

      if (parsedData.containsKey('data') && parsedData['data'] is Map) {
        final data = parsedData['data'] as Map;
        print('📦 Data keys: ${data.keys.toList()}');
        if (data.containsKey('title')) {
          print('📝 Title: ${data['title']}');
        }
      }

      print('=' * 50);

      // Pass to appropriate callback
      final messageType = parsedData['type']?.toString() ?? '';

      if (messageType == 'NEW_ANNOUNCEMENT') {
        print('🎯 Calling onAnnouncementReceived callback');
        if (onAnnouncementReceived != null) {
          onAnnouncementReceived!(parsedData['data'] ?? parsedData);
        }
      } else if (messageType == 'NEW_NOTIFICATION' || messageType.isNotEmpty) {
        print('🎯 Calling onNotificationReceived callback');
        if (onNotificationReceived != null) {
          onNotificationReceived!(parsedData['data'] ?? parsedData);
        }
      } else {
        print('⚠️ Unknown message type, calling onNotificationReceived');
        if (onNotificationReceived != null) {
          onNotificationReceived!(parsedData);
        }
      }
    } catch (e) {
      print('❌ Error in _handleMessage: $e');
      print('❌ Stack trace: ${e.toString()}');
    }
  }

  void _reconnect(dynamic userId) {
    Future.delayed(const Duration(seconds: 5), () {
      if (!_isConnected) {
        print('🔄 Attempting to reconnect WebSocket...');
        connect(userId);
      }
    });
  }

  void disconnect() {
    _channel?.sink.close();
    _isConnected = false;
    print('🔌 WebSocket disconnected manually');
  }

  bool get isConnected => _isConnected;

  // Helper method untuk test connection
  Future<bool> testConnection(dynamic userId) async {
    try {
      final testUrl = _buildWebSocketUrl(userId);
      print('🧪 Testing connection to: $testUrl');

      final testChannel = IOWebSocketChannel.connect(
        Uri.parse(testUrl),
        pingInterval: const Duration(seconds: 5),
      );

      // Tunggu sebentar untuk connection established
      await Future.delayed(const Duration(seconds: 2));

      testChannel.sink.close();
      return true;
    } catch (e) {
      print('🧪 Test failed: $e');
      return false;
    }
  }
}
