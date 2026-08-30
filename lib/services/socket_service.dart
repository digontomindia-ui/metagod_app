import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../utils/app_logger.dart';
import 'api_client.dart';

class SocketService {
  // Private constructor for internal instantiation
  SocketService._internal();

  // The single active instance of SocketService
  static final SocketService _instance = SocketService._internal();

  // Factory constructor that returns the Singleton instance
  factory SocketService() => _instance;

  io.Socket? _socket;
  io.Socket? _consultationSocket;
  String? _currentTempleRoom;
  String? _currentGuestName;

  /// Broadcast stream controller for incoming chat messages.
  /// Each event is a `Map<String, dynamic>` with keys like
  /// `name`, `initials`, `message`, `templeId`.
  final StreamController<Map<String, dynamic>> _chatStreamController =
      StreamController<Map<String, dynamic>>.broadcast();

  /// Exposes the incoming chat_message stream for UI listeners.
  Stream<Map<String, dynamic>> get chatMessageStream =>
      _chatStreamController.stream;

  /// Returns the underlying socket instance
  io.Socket? get socket => _socket;

  /// Utility flag indicating current socket connection state
  bool get isConnected => _socket?.connected ?? false;

  /// Initializes the WebSocket connection with Bearer authentication headers
  Future<void> initSocket() async {
    // Prevent duplicate connections if already connected
    if (_socket != null && _socket!.connected) {
      logD('WebSocket already connected.');
      return;
    }

    try {
      // Retrieve the current accessToken from secure storage with SharedPreferences fallback
      String? accessToken;
      if (kIsWeb) {
        final prefs = await SharedPreferences.getInstance();
        accessToken = prefs.getString('accessToken');
      } else {
        try {
          const secureStorage = FlutterSecureStorage(
            aOptions: AndroidOptions(encryptedSharedPreferences: true),
          );
          accessToken = await secureStorage.read(key: 'accessToken');
        } catch (e) {
          // Fail closed: connect without auth rather than read a plaintext token.
          logE('Socket: secure token read failed', e);
          accessToken = null;
        }
      }

      final optionsBuilder = io.OptionBuilder()
          .setTransports(['websocket']) // Enforce pure WebSockets
          .disableAutoConnect()         // Postpone connection until callbacks are registered
          .enableReconnection()         // Explicitly enable auto-reconnection
          .setReconnectionAttempts(5)   // Attempt reconnection 5 times
          .setReconnectionDelay(2000)   // Delay of 2 seconds between attempts
          .setExtraHeaders({
            if (accessToken != null) 'Authorization': 'Bearer $accessToken',
          });

      if (accessToken != null) {
        optionsBuilder.setAuth({'token': accessToken});
      }

      final options = optionsBuilder.build();

      // Derive socket URL from ApiClient.baseUrl by removing the '/api' suffix if present
      String socketUrl = ApiClient.baseUrl;
      if (socketUrl.endsWith('/api')) {
        socketUrl = socketUrl.substring(0, socketUrl.length - 4);
      }

      _socket = io.io(socketUrl, options);

      // Register Connection status listener
      _socket!.onConnect((_) {
        logD('WebSocket connected successfully to $socketUrl');
        // Auto-join if a room was requested before connection completed
        if (_currentTempleRoom != null && _currentGuestName != null) {
          _socket!.emit('join_live_chat', {
            'templeId': _currentTempleRoom,
            'guestName': _currentGuestName,
          });
          logD('SocketService (onConnect): Auto-Joined live chat room: $_currentTempleRoom');
        }
      });

      // Register Disconnection listener
      _socket!.onDisconnect((data) {
        logD('WebSocket disconnected: $data');
      });

      // Register Connection Error listener
      _socket!.onConnectError((data) {
        logD('WebSocket connection error: $data');
      });

      // Register Connection Timeout listener
      _socket!.onConnectTimeout((data) {
        logD('WebSocket connection timeout: $data');
      });

      // Live chat message listener
      _socket!.on('live_chat_message', (data) {
        logD('Received live_chat_message: $data');
        if (data is Map) {
          _chatStreamController.add(Map<String, dynamic>.from(data));
        }
      });

      // Chat history listener
      _socket!.on('chat_history', (data) {
        logD('Received chat_history');
        if (data is List) {
          _chatStreamController.add({
            'isHistory': true,
            'messages': data,
          });
        }
      });

      // Delete message listener
      _socket!.on('message_deleted', (data) {
        logD('Received message_deleted: $data');
        if (data is Map && data['messageId'] != null) {
          _chatStreamController.add({
            'isDelete': true,
            'messageId': data['messageId'],
          });
        }
      });

      // Viewer count listener
      _socket!.on('viewer_count_update', (data) {
        if (data is Map && data['viewerCount'] != null) {
          _chatStreamController.add({
            'isViewerUpdate': true,
            'viewerCount': data['viewerCount'],
          });
        }
      });

      // Moderation alerts listeners
      void pushModAlert(String type, dynamic data) {
        if (data is Map) {
          _chatStreamController.add({
            'isModAlert': true,
            'alertType': type,
            'message': data['message'] ?? data['reason'] ?? 'Action blocked',
          });
        }
      }

      _socket!.on('warning_alert', (data) => pushModAlert('warning', data));
      _socket!.on('message_blocked', (data) => pushModAlert('blocked', data));
      _socket!.on('you_are_muted', (data) => pushModAlert('muted', data));
      _socket!.on('you_are_banned', (data) => pushModAlert('banned', data));

      // Trigger the connection process for main socket
      _socket!.connect();

      // Initialize Consultation Socket
      _consultationSocket = io.io('$socketUrl/consultation', options);
      _consultationSocket!.onConnect((_) {
        logD('Consultation WebSocket connected successfully to $socketUrl/consultation');
        if (_currentConsultationExpertId != null) {
          _consultationSocket!.emit('join_consultation', {'expertId': _currentConsultationExpertId});
          logD('SocketService (onConnect): Auto-Joined consultation room: $_currentConsultationExpertId');
        }
      });
      _consultationSocket!.onDisconnect((data) {
        logD('Consultation WebSocket disconnected: $data');
      });
      _consultationSocket!.connect();

    } catch (e) {
      logD('Error initializing WebSocket service: $e');
    }
  }

  /// Emits a chat message event to the server for a specific temple stream.
  void emitChatMessage({
    required String templeId,
    required String message,
    required String userName,
  }) {
    if (_socket == null || !_socket!.connected) {
      logD('SocketService: Cannot emit — socket not connected.');
      return;
    }

    _socket!.emit('send_live_chat', {
      'templeId': templeId,
      'message': message,
      'senderName': userName,
    });
  }

  /// Joins a specific temple chat room
  void joinTempleChat(String templeId, String guestName) {
    _currentTempleRoom = templeId;
    _currentGuestName = guestName;

    if (_socket != null && _socket!.connected) {
      _socket!.emit('join_live_chat', {'templeId': templeId, 'guestName': guestName});
      logD('SocketService: Joined live chat room: $templeId');
    } else {
      logD('SocketService: Socket not connected yet, will join room $templeId upon connection.');
    }
  }

  /// Leaves a specific temple chat room
  void leaveTempleChat(String templeId) {
    if (_currentTempleRoom == templeId) {
      _currentTempleRoom = null;
      _currentGuestName = null;
    }
    if (_socket != null && _socket!.connected) {
      _socket!.emit('leave_live_chat', {'templeId': templeId});
      logD('SocketService: Left live chat room: $templeId');
    }
  }

  /// Listen for new messages using a callback
  void onNewMessage(Function(dynamic) callback) {
    if (_socket != null) {
      _socket!.on('live_chat_message', callback);
      _socket!.on('chat_history', callback);
    }
  }

  /// Remove listener for new messages
  void offNewMessage(Function(dynamic) callback) {
    if (_socket != null) {
      _socket!.off('live_chat_message', callback);
      _socket!.off('chat_history', callback);
    }
  }

  /// Sends a chat message event to the server
  void sendMessage(String templeId, Map<String, dynamic> messageData) {
    if (_socket == null || !_socket!.connected) {
      logD('SocketService: Cannot sendMessage — socket not connected.');
      return;
    }

    _socket!.emit('send_live_chat', {
      'templeId': templeId,
      'senderName': messageData['name'] ?? messageData['userName'] ?? 'Devotee',
      'message': messageData['message'] ?? '',
    });
  }

  /// Deletes a chat message
  void deleteMessage(String templeId, String messageId) {
    if (_socket == null || !_socket!.connected) return;
    _socket!.emit('delete_message', {
      'templeId': templeId,
      'messageId': messageId,
    });
  }

  String? _currentConsultationExpertId;

  /// Joins a specific consultation chat room for Pandit consultations
  void joinConsultation(String expertId) {
    _currentConsultationExpertId = expertId;
    if (_consultationSocket != null && _consultationSocket!.connected) {
      _consultationSocket!.emit('join_consultation', {'expertId': expertId});
      logD('SocketService: Joined consultation room: $expertId');
    } else {
      logD('SocketService: Consultation socket not connected yet, will join when connected.');
    }
  }

  /// Sends a consultation message event to the server
  void sendConsultationMessage(String expertId, String message) {
    if (_consultationSocket == null || !_consultationSocket!.connected) {
      logD('SocketService: Cannot sendConsultationMessage — socket not connected.');
      return;
    }
    _consultationSocket!.emit('send_consultation_message', {
      'expertId': expertId,
      'message': message,
    });
    logD('SocketService: Sent consultation message to expert: $expertId');
  }

  /// Listen for new consultation messages using a callback
  void onConsultationMessage(Function(dynamic) callback) {
    if (_consultationSocket != null) {
      _consultationSocket!.on('new_consultation_message', callback);
    }
  }

  /// Listen for WebRTC events
  void onWebRTCEvent(String eventName, Function(dynamic) callback) {
    if (_consultationSocket != null) {
      _consultationSocket!.on(eventName, callback);
    }
  }

  /// Emit WebRTC events
  void emitWebRTCEvent(String eventName, Map<String, dynamic> data) {
    if (_consultationSocket != null && _consultationSocket!.connected) {
      _consultationSocket!.emit(eventName, data);
    }
  }

  /// Remove listener for consultation messages
  void offConsultationMessage(Function(dynamic) callback) {
    if (_consultationSocket != null) {
      _consultationSocket!.off('new_consultation_message', callback);
    }
  }

  /// Remove listener for WebRTC events
  void offWebRTCEvent(String eventName, Function(dynamic) callback) {
    if (_consultationSocket != null) {
      _consultationSocket!.off(eventName, callback);
    }
  }

  /// Closes the connection and cleans up the active socket client
  void disconnect() {
    if (_socket != null) {
      _socket!.disconnect();
      _socket = null;
    }
    if (_consultationSocket != null) {
      _consultationSocket!.disconnect();
      _consultationSocket = null;
    }
    logD('WebSocket connections disposed.');
  }

  /// Fully disposes the service including the stream controller.
  /// Call only on app shutdown.
  void dispose() {
    disconnect();
    _chatStreamController.close();
  }
}

