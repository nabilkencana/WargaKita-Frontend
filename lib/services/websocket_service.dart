import 'dart:developer';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../config/config.dart';

class WebSocketService {
  static final WebSocketService _instance = WebSocketService._internal();
  factory WebSocketService() => _instance;
  WebSocketService._internal();

  IO.Socket? _socket;
  bool _isConnected = false;

  Function(Map<String, dynamic>)? onNotificationReceived;
  Function(Map<String, dynamic>)? onAnnouncementReceived;

  void connect(int userId) {
    if (_isConnected) return;

    final socketUrl = Config.apiUrl; // https://wargakita.canadev.my.id

    log('🔗 Connecting Socket.IO to $socketUrl');

    _socket = IO.io(
      socketUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .setPath('/socket.io') // default socket.io
          .setQuery({'userId': userId.toString()})
          .enableReconnection()
          .setReconnectionAttempts(10)
          .setReconnectionDelay(2000)
          .build(),
    );

    _socket!.onConnect((_) {
      _isConnected = true;
      log('✅ Socket.IO connected (user $userId)');
    });

    _socket!.onDisconnect((_) {
      _isConnected = false;
      log('🔌 Socket.IO disconnected');
    });

    _socket!.onConnectError((err) {
      log('❌ Connect error: $err');
    });

    _socket!.on('new_notification', (data) {
      log('📨 Notification received');
      if (onNotificationReceived != null) {
        onNotificationReceived!(Map<String, dynamic>.from(data));
      }
    });

    _socket!.on('connected', (data) {
      log('🟢 Connected event: $data');
    });
  }

  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _isConnected = false;
  }

  bool get isConnected => _isConnected;
}
