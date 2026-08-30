import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../services/auth_service.dart';
import '../../services/socket_service.dart';
import '../../services/api_client.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_network_image.dart';
import '../../utils/app_logger.dart';

class ConsultationChatScreen extends StatefulWidget {
  final String expertId;
  final String panditName;
  final String panditEmoji;
  final bool isSessionActive;

  const ConsultationChatScreen({
    super.key,
    required this.expertId,
    required this.panditName,
    required this.panditEmoji,
    this.isSessionActive = false,
  });

  @override
  State<ConsultationChatScreen> createState() => _ConsultationChatScreenState();
}

class _ConsultationChatScreenState extends State<ConsultationChatScreen> {
  final List<Map<String, dynamic>> _messages = [];
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  String? _roomId;
  String? _currentUserName;

  Timer? _countdownTimer;
  int _secondsRemaining = 0; // chat seconds
  int _audioSecondsRemaining = 0;
  int _videoSecondsRemaining = 0;
  bool _isExpired = false;

  // WebRTC & Call State
  bool _isPartyOnline = false;
  bool _isPartyTyping = false;
  bool _isCalling = false;
  Map<String, dynamic>? _incomingCall;
  bool _callActive = false;
  String? _callType;
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();

  bool _isAudioMuted = false;
  bool _isVideoMuted = false;
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    _localRenderer.initialize();
    _remoteRenderer.initialize();
    _initPrivateSession();
  }

  void _initPrivateSession() async {
    final authService = context.read<AuthService>();
    final user = authService.currentUser;
    _currentUserName = user?.name ?? 'Devotee';
    
    final userId = user?.id ?? 'guest';
    final formattedPanditName = widget.panditName.replaceAll(' ', '_');
    _roomId = '${userId}_$formattedPanditName';

    // Fetch balances first
    await _fetchBalances();

    // Socket Integration
    final socketService = SocketService();
    await socketService.initSocket();
    
    socketService.onConsultationMessage(_handleIncomingConsultationMessage);
    
    // WebRTC Events
    socketService.onWebRTCEvent('party_online', (data) {
      if (mounted && !_isDisposed) setState(() => _isPartyOnline = true);
    });
    socketService.onWebRTCEvent('party_offline', (data) {
      if (mounted && !_isDisposed) setState(() => _isPartyOnline = false);
    });
    socketService.onWebRTCEvent('party_typing', (data) {
      if (mounted && !_isDisposed) setState(() => _isPartyTyping = data['typing'] ?? false);
    });
    socketService.onWebRTCEvent('time_update', _handleTimeUpdate);
    socketService.onWebRTCEvent('joined_consultation', _handleJoinedConsultation);
    socketService.onWebRTCEvent('incoming_call', _handleIncomingCall);
    socketService.onWebRTCEvent('call_accepted', _handleCallAccepted);
    socketService.onWebRTCEvent('call_rejected', _handleCallRejected);
    socketService.onWebRTCEvent('webrtc_signal', _handleWebRTCSignal);
    socketService.onWebRTCEvent('call_ended', _handleCallEnded);
    socketService.onWebRTCEvent('insufficient_balance', (data) {
      _showError(data['message'] ?? 'Insufficient balance.');
      setState(() {
        _isExpired = true;
        _secondsRemaining = 0;
      });
      _cleanupCall();
    });
    socketService.onWebRTCEvent('consultation_message_deleted', (data) {
      if (mounted && !_isDisposed && data['messageId'] != null) {
        setState(() {
          // Could filter messages by id if we stored _id
        });
      }
    });

    socketService.joinConsultation(widget.expertId);

    _fetchHistory();
    if (widget.isSessionActive) {
      _startTimer();
    }
  }

  Future<void> _fetchBalances() async {
    try {
      final apiClient = ApiClient();
      final response = await apiClient.get('/consultations/balance/${widget.expertId}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          final b = data['data'];
          if (mounted && !_isDisposed) {
            setState(() {
              _secondsRemaining = b['chatSeconds'] ?? b['remainingSeconds'] ?? 0;
              _audioSecondsRemaining = b['audioSeconds'] ?? 0;
              _videoSecondsRemaining = b['videoSeconds'] ?? 0;
              if (_secondsRemaining <= 0 && _audioSecondsRemaining <= 0 && _videoSecondsRemaining <= 0) _isExpired = true;
            });
          }
        }
      }
    } catch (e) {
      logE('[ChatScreen] Error fetching balances', e);
    }
  }

  void _handleJoinedConsultation(dynamic data) {
    if (data['remainingSeconds'] != null) {
      if (mounted && !_isDisposed) {
        setState(() {
          _secondsRemaining = data['chatSeconds'] ?? data['remainingSeconds'] ?? 0;
          _audioSecondsRemaining = data['audioSeconds'] ?? 0;
          _videoSecondsRemaining = data['videoSeconds'] ?? 0;
          if (_secondsRemaining <= 0 && _audioSecondsRemaining <= 0 && _videoSecondsRemaining <= 0) _isExpired = true;
        });
      }
    }
  }

  void _handleTimeUpdate(dynamic data) {
    if (mounted && !_isDisposed && data['remainingSeconds'] != null) {
      setState(() {
        final mode = data['mode'];
        final secs = data['remainingSeconds'];
        if (mode == 'video') _videoSecondsRemaining = secs;
        else if (mode == 'call' || mode == 'audio') _audioSecondsRemaining = secs;
        else _secondsRemaining = secs;

        if ((!_callActive && (mode == 'chat' || mode == null)) || (_callActive && mode == _callType)) {
          if (secs <= 0) _isExpired = true;
        }
      });
    }
  }

  void _handleIncomingCall(dynamic data) {
    logD('📞 Incoming call: $data');
    if (mounted && !_isDisposed) {
      setState(() {
        _incomingCall = data;
      });
    }
  }

  void _handleCallAccepted(dynamic data) async {
    logD('✅ Call accepted');
    if (mounted && !_isDisposed) setState(() => _callActive = true);
    
    if (_peerConnection != null) {
      try {
        final offer = await _peerConnection!.createOffer();
        await _peerConnection!.setLocalDescription(offer);
        SocketService().emitWebRTCEvent('webrtc_signal', {
          'expertId': widget.expertId,
          'signal': offer.toMap(),
        });
      } catch (e) {
        logE('Error creating offer', e);
      }
    }
  }

  void _handleCallRejected(dynamic data) {
    logD('❌ Call rejected');
    _showError('Call was rejected');
    _cleanupCall();
  }

  void _handleCallEnded(dynamic data) {
    logD('🏁 Call ended');
    _cleanupCall();
  }

  void _handleWebRTCSignal(dynamic data) async {
    if (_peerConnection == null) return;
    final signal = data['signal'];
    if (signal == null) return;

    try {
      if (signal['type'] == 'offer') {
        await _peerConnection!.setRemoteDescription(RTCSessionDescription(signal['sdp'], signal['type']));
        final answer = await _peerConnection!.createAnswer();
        await _peerConnection!.setLocalDescription(answer);
        SocketService().emitWebRTCEvent('webrtc_signal', {
          'expertId': widget.expertId,
          'signal': answer.toMap(),
        });
      } else if (signal['type'] == 'answer') {
        await _peerConnection!.setRemoteDescription(RTCSessionDescription(signal['sdp'], signal['type']));
      } else if (signal['candidate'] != null) {
        await _peerConnection!.addCandidate(RTCIceCandidate(
          signal['candidate'],
          signal['sdpMid'],
          signal['sdpMLineIndex'],
        ));
      }
    } catch (e) {
      logE('Error handling WebRTC signal', e);
    }
  }

  Future<RTCPeerConnection> _initPeerConnection() async {
    final configuration = <String, dynamic>{
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
        {'urls': 'stun:stun1.l.google.com:19302'}
      ]
    };
    final pc = await createPeerConnection(configuration);

    pc.onIceCandidate = (RTCIceCandidate candidate) {
      SocketService().emitWebRTCEvent('webrtc_signal', {
        'expertId': widget.expertId,
        'signal': {
          'candidate': candidate.candidate,
          'sdpMid': candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex,
        }
      });
    };

    pc.onTrack = (RTCTrackEvent event) {
      logD('🎬 Received remote track: \${event.track.kind}');
      if (event.track.kind == 'video') {
        _remoteStream = event.streams[0];
        _remoteRenderer.srcObject = _remoteStream;
        setState(() {});
      } else if (event.track.kind == 'audio') {
        _remoteStream = event.streams[0];
      }
    };

    _peerConnection = pc;
    return pc;
  }

  Future<void> _startCall(String type) async {
    if (_isExpired) {
      _showError('Session expired');
      return;
    }
    if (!_isPartyOnline) {
      _showError('Wait for the expert to join the session');
      return;
    }
    if (type == 'audio' && _audioSecondsRemaining <= 0) {
      _showError('Please buy Audio Consultation minutes to start a voice call.');
      return;
    }
    if (type == 'video' && _videoSecondsRemaining <= 0) {
      _showError('Please buy Video Consultation minutes to start a video call.');
      return;
    }

    try {
      await [Permission.camera, Permission.microphone].request();
      setState(() {
        _callType = type;
        _isCalling = true;
      });

      final stream = await navigator.mediaDevices.getUserMedia({
        'video': type == 'video',
        'audio': true,
      });

      _localStream = stream;
      _localRenderer.srcObject = stream;

      final pc = await _initPeerConnection();
      stream.getTracks().forEach((track) {
        pc.addTrack(track, stream);
      });

      SocketService().emitWebRTCEvent('start_call', {
        'expertId': widget.expertId,
        'type': type,
      });

      setState(() => _callActive = true);
    } catch (e) {
      logE('Failed to start call', e);
      _showError('Could not access camera/microphone');
      _cleanupCall();
    }
  }

  Future<void> _acceptCall() async {
    if (_incomingCall == null) return;
    final type = _incomingCall!['type'];
    setState(() {
      _callType = type;
      _incomingCall = null;
    });

    try {
      await [Permission.camera, Permission.microphone].request();
      final stream = await navigator.mediaDevices.getUserMedia({
        'video': type == 'video',
        'audio': true,
      });

      _localStream = stream;
      _localRenderer.srcObject = stream;

      final pc = await _initPeerConnection();
      stream.getTracks().forEach((track) {
        pc.addTrack(track, stream);
      });

      SocketService().emitWebRTCEvent('accept_call', {
        'expertId': widget.expertId,
      });
      setState(() => _callActive = true);
    } catch (e) {
      logE('Failed to accept call', e);
      _showError('Could not access camera/microphone');
      SocketService().emitWebRTCEvent('reject_call', {'expertId': widget.expertId});
      _cleanupCall();
    }
  }

  void _rejectCall() {
    SocketService().emitWebRTCEvent('reject_call', {'expertId': widget.expertId});
    setState(() => _incomingCall = null);
  }

  void _endCall() {
    SocketService().emitWebRTCEvent('end_call', {'expertId': widget.expertId});
    _cleanupCall();
  }

  void _cleanupCall() {
    if (_localStream != null) {
      _localStream!.getTracks().forEach((track) => track.stop());
      _localStream!.dispose();
      _localStream = null;
    }
    if (_peerConnection != null) {
      _peerConnection!.close();
      _peerConnection = null;
    }
    _localRenderer.srcObject = null;
    _remoteRenderer.srcObject = null;
    if (mounted && !_isDisposed) {
      setState(() {
        _callActive = false;
        _isCalling = false;
        _incomingCall = null;
        _callType = null;
        _isAudioMuted = false;
        _isVideoMuted = false;
      });
    }
  }

  void _toggleAudio() {
    if (_localStream != null) {
      final audioTracks = _localStream!.getAudioTracks();
      if (audioTracks.isNotEmpty) {
        final track = audioTracks[0];
        track.enabled = !track.enabled;
        setState(() {
          _isAudioMuted = !track.enabled;
        });
      }
    }
  }

  void _toggleVideo() {
    if (_localStream != null && _callType == 'video') {
      final videoTracks = _localStream!.getVideoTracks();
      if (videoTracks.isNotEmpty) {
        final track = videoTracks[0];
        track.enabled = !track.enabled;
        setState(() {
          _isVideoMuted = !track.enabled;
        });
      }
    }
  }

  void _showError(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
    }
  }

  Future<void> _fetchHistory() async {
    try {
      final apiClient = ApiClient();
      final response = await apiClient.get('/consultations/history/${widget.expertId}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          final List history = data['data'];
          if (mounted && !_isDisposed) {
            setState(() {
              _messages.clear(); // Replace mock message with real history
              final authService = context.read<AuthService>();
              for (var msg in history) {
                final isSentByMe = msg['senderRole'] == 'USER' || msg['senderId'] == authService.currentUser?.id;
                _messages.add({
                  '_id': msg['_id'],
                  'text': msg['message'] ?? '',
                  'isSentByMe': isSentByMe,
                  'time': msg['createdAt'] != null ? DateTime.parse(msg['createdAt']).toLocal() : DateTime.now().toLocal(),
                });
              }
            });
            _scrollToBottom();
          }
        }
      }
    } catch (e) {
      logE('[ChatScreen] Error fetching history', e);
    }
  }

  void _startTimer() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && !_isDisposed) {
        setState(() {
          // Local countdown based on active mode
          if (_callActive && _callType == 'video' && _videoSecondsRemaining > 0) {
            _videoSecondsRemaining--;
          } else if (_callActive && _callType == 'audio' && _audioSecondsRemaining > 0) {
            _audioSecondsRemaining--;
          } else if (!_callActive && _secondsRemaining > 0) {
            _secondsRemaining--;
          }

          // Check if ALL balances are exhausted
          if (_secondsRemaining <= 0 && _audioSecondsRemaining <= 0 && _videoSecondsRemaining <= 0) {
            _countdownTimer?.cancel();
            if (!_isExpired) {
              _isExpired = true;
              _showSessionExpiredDialog();
            }
          }
        });
      }
    });
  }

  String _formatTime(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _isDisposed = true;
    _countdownTimer?.cancel();
    _cleanupCall();
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    final socketService = SocketService();
    socketService.offConsultationMessage(_handleIncomingConsultationMessage);
    socketService.offWebRTCEvent('time_update', _handleTimeUpdate);
    socketService.offWebRTCEvent('joined_consultation', _handleJoinedConsultation);
    socketService.offWebRTCEvent('incoming_call', _handleIncomingCall);
    socketService.offWebRTCEvent('call_accepted', _handleCallAccepted);
    socketService.offWebRTCEvent('call_rejected', _handleCallRejected);
    socketService.offWebRTCEvent('webrtc_signal', _handleWebRTCSignal);
    socketService.offWebRTCEvent('call_ended', _handleCallEnded);
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _handleIncomingConsultationMessage(dynamic data) {
    if (data is Map) {
      final msgText = data['message']?.toString() ?? '';
      final authService = context.read<AuthService>();
      final isSentByMe = data['senderRole'] == 'USER' || data['senderId'] == authService.currentUser?.id;

      if (mounted && !_isDisposed && msgText.isNotEmpty) {
        if (isSentByMe) return;

        setState(() {
          _messages.add({
            '_id': data['_id'],
            'text': msgText,
            'isSentByMe': false,
            'time': DateTime.now().toLocal(),
          });
        });
        _scrollToBottom();
      }
    }
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty || _roomId == null) return;
    if (_isExpired) {
      _showError('Session expired.');
      return;
    }

    final socketService = SocketService();
    socketService.sendConsultationMessage(widget.expertId, text);
    socketService.emitWebRTCEvent('stop_typing', {'expertId': widget.expertId});

    setState(() {
      _messages.add({
        'text': text,
        'isSentByMe': true,
        'time': DateTime.now().toLocal(),
      });
    });

    _messageController.clear();
    _scrollToBottom();
  }

  void _sendDevotionalAction(String actionText) {
    if (_roomId == null) return;

    final socketService = SocketService();
    socketService.sendConsultationMessage(widget.expertId, actionText);

    setState(() {
      _messages.add({
        'text': actionText,
        'isSentByMe': true,
        'time': DateTime.now().toLocal(),
      });
    });

    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0.0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showEndSessionDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF16121F),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.red, size: 28),
            SizedBox(width: 12),
            Text(
              'End Session',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: const Text(
          'Are you sure you want to end this sacred consultation session?',
          style: TextStyle(color: Colors.white70, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: AppColors.muted)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('End Sacred Session', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showSessionExpiredDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF16121F),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.timer_off_rounded, color: Color(0xFFFCA311), size: 28),
            SizedBox(width: 12),
            Text(
              'Session Finished',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: const Text(
          'Your sacred consultation session has expired. May the divine blessings be with you.',
          style: TextStyle(color: Colors.white70, height: 1.4),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFCA311),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Pranam ', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showDevotionalActionsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF16121F),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Divine Offerings', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                const Text('Send a spiritual gesture to the pandit during your session.', style: TextStyle(color: AppColors.muted, fontSize: 12)),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildOfferingItem(
                      icon: '',
                      label: 'Offer Flower',
                      onTap: () {
                        Navigator.pop(context);
                        _sendDevotionalAction('Offered a lotus flower to the deity ');
                      },
                    ),
                    _buildOfferingItem(
                      icon: '',
                      label: 'Light Diya',
                      onTap: () {
                        Navigator.pop(context);
                        _sendDevotionalAction('Lit a sacred ghee lamp ');
                      },
                    ),
                    _buildOfferingItem(
                      icon: '',
                      label: 'Ring Bell',
                      onTap: () {
                        Navigator.pop(context);
                        _sendDevotionalAction('Rang the temple bell ');
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildOfferingItem({required String icon, required String label, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(color: AppColors.card, shape: BoxShape.circle, border: Border.all(color: AppColors.border)),
              alignment: Alignment.center,
              child: Text(icon, style: const TextStyle(fontSize: 26)),
            ),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(color: AppColors.cream, fontSize: 11, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _buildSacredHeader() {
    return Container(
      margin: const EdgeInsets.only(bottom: 24, top: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Text(
                widget.isSessionActive ? 'Sacred Session Active'.toUpperCase() : 'Session Inactive'.toUpperCase(),
                style: TextStyle(color: widget.isSessionActive ? const Color(0xFFFCA311) : Colors.grey, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.0),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Your 1-on-1 consultation with Pt. ${widget.panditName} is private, secure, and blessed.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.muted, fontSize: 11, height: 1.4),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_callActive) {
          _endCall();
        }
        _showEndSessionDialog();
      },
      child: Scaffold(
        backgroundColor: AppColors.bg,
        appBar: AppBar(
          backgroundColor: AppColors.card,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_rounded, color: AppColors.cream),
            onPressed: () {
              if (_callActive) _endCall();
              _showEndSessionDialog();
            },
          ),
          titleSpacing: 0,
          title: Row(
            children: [
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: 38, height: 38, color: AppColors.card2, alignment: Alignment.center,
                      child: const Icon(Icons.person_outline_rounded, color: AppColors.gold, size: 20),
                    ),
                  ),
                  Positioned(
                    right: 0, bottom: 0,
                    child: Container(
                      width: 10, height: 10,
                      decoration: BoxDecoration(
                        color: _isPartyOnline ? AppColors.green : Colors.grey,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.card, width: 1.5),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Text(widget.panditName, style: const TextStyle(color: AppColors.cream, fontSize: 14, fontWeight: FontWeight.bold)),
                        const SizedBox(width: 6),
                        if (_isPartyOnline)
                          const Text('ONLINE', style: TextStyle(color: AppColors.green, fontSize: 8, fontWeight: FontWeight.w900)),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _isExpired ? 'Session Expired' : '${_formatTime(_callActive ? (_callType == "video" ? _videoSecondsRemaining : _audioSecondsRemaining) : _secondsRemaining)} ${_callActive ? (_callType == "video" ? "Video" : "Audio") : "Chat"} Left',
                      style: TextStyle(color: _isExpired ? Colors.red : const Color(0xFFFCA311), fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.call, color: AppColors.gold),
              onPressed: () => _startCall('audio'),
            ),
            IconButton(
              icon: const Icon(Icons.videocam, color: AppColors.gold),
              onPressed: () => _startCall('video'),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    reverse: true,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length + 1,
                    itemBuilder: (context, index) {
                      if (index == _messages.length) return _buildSacredHeader();
                      final msg = _messages[_messages.length - 1 - index];
                      final isMe = msg['isSentByMe'] as bool;
                      final text = msg['text'] as String;
                      final time = msg['time'] as DateTime;
                      final timeStr = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
                      return _buildMessageBubble(text, isMe, timeStr);
                    },
                  ),
                ),
                if (_isPartyTyping)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Typing...', style: TextStyle(color: AppColors.gold, fontSize: 12, fontStyle: FontStyle.italic)),
                    ),
                  ),
                _buildMessageInput(),
              ],
            ),
            if (_incomingCall != null)
              Positioned(
                top: 40, left: 20, right: 20,
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.gold),
                      boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 10)],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Incoming ${_incomingCall!['type']} call...', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                              onPressed: _rejectCall,
                              child: const Text('Reject', style: TextStyle(color: Colors.white)),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                              onPressed: _acceptCall,
                              child: const Text('Accept', style: TextStyle(color: Colors.white)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            if (_callActive)
              Positioned.fill(
                child: Container(
                  color: Colors.black,
                  child: Stack(
                    children: [
                      if (_callType == 'video')
                        Positioned.fill(child: RTCVideoView(_remoteRenderer, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover)),
                      if (_callType == 'video')
                        Positioned(
                          right: 20, top: 20,
                          width: 100, height: 150,
                          child: Container(
                            decoration: BoxDecoration(border: Border.all(color: Colors.white, width: 2)),
                            child: RTCVideoView(_localRenderer, mirror: true, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover),
                          ),
                        ),
                      if (_callType == 'audio')
                        Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.person, size: 100, color: Colors.grey),
                              const SizedBox(height: 16),
                              Text('Audio Call with ${widget.panditName}', style: const TextStyle(color: Colors.white, fontSize: 20)),
                              const SizedBox(height: 8),
                              const Text('Voice Consultation Active', style: TextStyle(color: AppColors.gold, fontSize: 14)),
                            ],
                          ),
                        ),
                      Positioned(
                        bottom: 40, left: 0, right: 0,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            FloatingActionButton(
                              heroTag: 'mute_audio',
                              backgroundColor: _isAudioMuted ? Colors.white : Colors.grey[800],
                              onPressed: _toggleAudio,
                              child: Icon(
                                _isAudioMuted ? Icons.mic_off : Icons.mic,
                                color: _isAudioMuted ? Colors.red : Colors.white,
                              ),
                            ),
                            const SizedBox(width: 24),
                            FloatingActionButton(
                              heroTag: 'end_call',
                              backgroundColor: Colors.red,
                              onPressed: _endCall,
                              child: const Icon(Icons.call_end, color: Colors.white),
                            ),
                            if (_callType == 'video') ...[
                              const SizedBox(width: 24),
                              FloatingActionButton(
                                heroTag: 'mute_video',
                                backgroundColor: _isVideoMuted ? Colors.white : Colors.grey[800],
                                onPressed: _toggleVideo,
                                child: Icon(
                                  _isVideoMuted ? Icons.videocam_off : Icons.videocam,
                                  color: _isVideoMuted ? Colors.red : Colors.white,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(String text, bool isMe, String timeStr) {
    final user = context.read<AuthService>().currentUser;
    final userAvatar = user?.avatar;
    final initials = user?.name.isNotEmpty == true ? user!.name.substring(0, 1).toUpperCase() : 'U';

    if (isMe) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.70),
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [Color(0xFFFFB800), Color(0xFFFCA311)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16), bottomLeft: Radius.circular(16), bottomRight: Radius.circular(2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(text, style: const TextStyle(color: Colors.black, fontSize: 13, fontWeight: FontWeight.w500, height: 1.4)),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(timeStr, style: TextStyle(color: Colors.black.withValues(alpha: 0.5), fontSize: 9, fontWeight: FontWeight.w500)),
                      const SizedBox(width: 4),
                      const Icon(Icons.done_all, color: Colors.black, size: 11),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(color: AppColors.card, shape: BoxShape.circle, border: Border.all(color: AppColors.border)),
              alignment: Alignment.center,
              child: userAvatar != null && userAvatar.isNotEmpty
                  ? ClipOval(child: AppNetworkImage(url: userAvatar, width: 28, height: 28, fit: BoxFit.cover))
                  : Text(initials, style: const TextStyle(color: AppColors.cream, fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(color: AppColors.card, shape: BoxShape.circle, border: Border.all(color: AppColors.border)),
            alignment: Alignment.center,
            child: const Icon(Icons.person_outline_rounded, color: AppColors.gold, size: 16),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.70),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16), bottomLeft: Radius.circular(2), bottomRight: Radius.circular(16)),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(text, style: const TextStyle(color: AppColors.cream, fontSize: 13, height: 1.4)),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Spacer(),
                    Text(timeStr, style: const TextStyle(color: AppColors.muted, fontSize: 9)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    if (!widget.isSessionActive) {
      return Container(
        padding: EdgeInsets.fromLTRB(16, 20, 16, 20 + MediaQuery.of(context).padding.bottom),
        decoration: const BoxDecoration(color: Color(0xFF16121F), border: Border(top: BorderSide(color: Colors.white12))),
        child: const Center(
          child: Text('Please buy a consultation session to start messaging.', style: TextStyle(color: Colors.white54, fontSize: 13, fontStyle: FontStyle.italic)),
        ),
      );
    }

    return Container(
      padding: EdgeInsets.fromLTRB(12, 8, 12, 16 + MediaQuery.of(context).padding.bottom),
      decoration: const BoxDecoration(color: AppColors.card, border: Border(top: BorderSide(color: AppColors.border))),
      child: Row(
        children: [
          // Plus icon removed as requested
          Expanded(
            child: Container(
              height: 44,
              decoration: BoxDecoration(color: const Color(0xFF0F0C16), border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(22)),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.center,
              child: TextField(
                controller: _messageController,
                style: const TextStyle(color: AppColors.cream, fontSize: 13),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: _isExpired ? 'Session Expired' : 'Ask your question to the Pandit...',
                  hintStyle: const TextStyle(color: Colors.white24, fontSize: 12),
                  isDense: true,
                ),
                enabled: !_isExpired,
                onChanged: (val) {
                  final socketService = SocketService();
                  socketService.emitWebRTCEvent('typing', {'expertId': widget.expertId});
                },
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 44, height: 44,
            decoration: const BoxDecoration(color: Color(0xFFFCA311), shape: BoxShape.circle),
            child: IconButton(
              icon: const Icon(Icons.send_rounded, color: AppColors.bg, size: 16),
              onPressed: _isExpired ? null : _sendMessage,
              padding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }
}
