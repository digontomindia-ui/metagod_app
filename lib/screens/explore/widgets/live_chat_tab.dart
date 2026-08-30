import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../services/auth_service.dart';
import '../../../services/socket_service.dart';
import '../../../theme/app_colors.dart';
import '../../../config/env.dart';
import '../../../widgets/app_network_image.dart';
import '../../../utils/app_logger.dart';

class LiveChatTab extends StatefulWidget {
  final String templeId;

  const LiveChatTab({
    super.key,
    required this.templeId,
  });

  @override
  State<LiveChatTab> createState() => _LiveChatTabState();
}

class _LiveChatTabState extends State<LiveChatTab> {
  final List<Map<String, dynamic>> _messages = [];
  late ScrollController _scrollController;
  late TextEditingController _chatController;
  StreamSubscription<Map<String, dynamic>>? _chatSubscription;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _chatController = TextEditingController();

    // Populate initial system messages for a welcoming Twitch-style layout
    _messages.addAll([
      {
        'userName': 'System',
        'name': 'System',
        'initials': 'SYS',
        'message': 'Welcome to the Live Chat! Join the community of devotees in prayer. ',
      }
    ]);

    _initSocketAndJoin();
  }

  Future<void> _initSocketAndJoin() async {
    final socketService = SocketService();
    final authService = context.read<AuthService>();
    final user = authService.currentUser;
    final userName = user?.name ?? 'Devotee';

    await socketService.initSocket();

    // Join the temple-specific chat room
    socketService.joinTempleChat(widget.templeId, userName);

    // Register incoming message stream listener
    _chatSubscription = socketService.chatMessageStream.listen(_handleIncomingMessage);
  }

  void _handleIncomingMessage(dynamic data) {
    if (!mounted) return;
    logD('LiveChatTab received message: $data');

    if (data is Map && data['isModAlert'] == true) {
      final alertType = data['alertType'];
      final msg = data['message'];
      
      Color bgColor = AppColors.red;
      if (alertType == 'warning') bgColor = Colors.orange;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: bgColor,
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }

    if (data is Map && data['isDelete'] == true) {
      final messageId = data['messageId'];
      setState(() {
        _messages.removeWhere((m) => m['_id'] == messageId || m['id'] == messageId);
      });
      return;
    }

    if (data is Map && data['isHistory'] == true) {
      final historyList = (data['messages'] as List?) ?? const [];
      setState(() {
        _messages.clear();
        _messages.add({
          'userName': 'System',
          'name': 'System',
          'initials': 'SYS',
          'message': 'Welcome to the Live Chat! Join the community of devotees in prayer. ',
        });
        for (var msg in historyList) {
          if (msg is Map) {
            _messages.add(Map<String, dynamic>.from(msg));
          }
        }
      });
      return;
    }

    if (data is Map) {
      final mapData = Map<String, dynamic>.from(data);
      // Room isolation validation: if templeId is present, must match
      if (mapData.containsKey('templeId') && mapData['templeId'] != widget.templeId) return;

      setState(() {
        _messages.add(mapData);
      });
    }
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.isEmpty) return 'D';
    if (parts.length == 1) {
      return parts.first.isNotEmpty ? parts.first[0].toUpperCase() : 'D';
    }
    return '${parts[0].isNotEmpty ? parts[0][0] : ""}${parts[1].isNotEmpty ? parts[1][0] : ""}'.toUpperCase();
  }

  void _sendMessage() {
    final text = _chatController.text.trim();
    if (text.isEmpty) return;

    final authService = context.read<AuthService>();
    final user = authService.currentUser;
    final userName = user?.name ?? 'Devotee';
    final initials = _getInitials(userName);

    final messageData = <String, dynamic>{
      'userName': userName,
      'name': userName,
      'initials': initials,
      'profileImage': user?.avatar,
      'message': text,
    };

    // Emit message to Socket server
    SocketService().sendMessage(widget.templeId, messageData);

    _chatController.clear();
  }

  @override
  void dispose() {
    _chatSubscription?.cancel();
    final socketService = SocketService();
    socketService.leaveTempleChat(widget.templeId);
    _scrollController.dispose();
    _chatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Messages list
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            reverse: true, // Auto-scroll behavior
            padding: const EdgeInsets.all(16),
            itemCount: _messages.length,
            itemBuilder: (context, index) {
              final msg = _messages[_messages.length - 1 - index];
              final senderName = (msg['senderName'] ?? msg['name'] ?? msg['userName'] ?? 'Devotee') as String;
              final initials = (msg['initials'] ?? _getInitials(senderName)) as String;
              final text = (msg['message'] ?? '') as String;
              final isSystem = senderName == 'System';
              final messageId = msg['_id'] as String?;
              
              final authService = context.read<AuthService>();
              final currentUser = authService.currentUser;
              final isOwnMessage = !isSystem && (
                  (msg['userId'] != null && msg['userId'] == currentUser?.id) || 
                  (senderName == currentUser?.name)
              );

              String? profileImage = (msg['profileImage'] ?? msg['avatar'] ?? msg['userAvatar']) as String?;
              if (isOwnMessage && currentUser?.avatar != null && currentUser!.avatar!.isNotEmpty) {
                profileImage = currentUser.avatar;
              }

              String? finalImageUrl;
              if (profileImage != null && profileImage.isNotEmpty) {
                finalImageUrl = Env.mediaUrl(profileImage);
              }

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Avatar
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: isSystem
                            ? const LinearGradient(colors: [AppColors.muted, Color(0xFF718096)])
                            : const LinearGradient(colors: [AppColors.gold, AppColors.saffron]),
                      ),
                      alignment: Alignment.center,
                      child: finalImageUrl != null
                          ? ClipOval(
                              child: AppNetworkImage(
                                url: profileImage,
                                width: 32,
                                height: 32,
                                fit: BoxFit.cover,
                              ),
                            )
                          : Text(
                              initials,
                              style: const TextStyle(
                                color: AppColors.bg,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                    const SizedBox(width: 12),
                    // Message bubble
                    Expanded(
                      child: GestureDetector(
                        onLongPress: isOwnMessage && messageId != null
                            ? () {
                                showDialog(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    backgroundColor: AppColors.card,
                                    title: const Text('Delete Message', style: TextStyle(color: Colors.white)),
                                    content: const Text('Are you sure you want to delete this message?', style: TextStyle(color: AppColors.muted)),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(ctx),
                                        child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          Navigator.pop(ctx);
                                          SocketService().deleteMessage(widget.templeId, messageId);
                                          // Optimistically remove locally
                                          setState(() {
                                            _messages.removeWhere((m) => m['_id'] == messageId);
                                          });
                                        },
                                        child: const Text('Delete', style: TextStyle(color: AppColors.red)),
                                      ),
                                    ],
                                  ),
                                );
                              }
                            : null,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: isSystem ? const Color(0xFF1D1B26) : AppColors.card2,
                            borderRadius: const BorderRadius.only(
                              topRight: Radius.circular(16),
                              bottomLeft: Radius.circular(16),
                              bottomRight: Radius.circular(16),
                            ),
                            border: Border.all(
                              color: isSystem
                                  ? AppColors.border.withValues(alpha: 0.15)
                                  : AppColors.border.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                senderName,
                                style: TextStyle(
                                  color: isSystem ? AppColors.gold : AppColors.muted,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                text,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),

        // Sticky Input Field panel
        SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            decoration: const BoxDecoration(
              color: AppColors.card,
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F0C16),
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      controller: _chatController,
                      style: const TextStyle(color: AppColors.cream, fontSize: 13),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Say something as a devotee...',
                        hintStyle: TextStyle(color: Colors.white24, fontSize: 12),
                        isDense: true,
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send_rounded, color: AppColors.gold),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
