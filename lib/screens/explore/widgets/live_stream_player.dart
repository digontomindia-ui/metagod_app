import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_vlc_player_16kb/flutter_vlc_player.dart';
import 'package:video_player/video_player.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:http/http.dart' as http;
import '../../../theme/app_colors.dart';
import '../../../models/temple.dart';
import '../../../services/api_client.dart';
import '../../../utils/app_logger.dart';

/// A self-contained live stream player that connects to the secure
/// backend proxy endpoint. Manages its own VLC / VideoPlayer lifecycle,
/// 30-second trial timer, and subscription lock screen.
class LiveStreamPlayer extends StatefulWidget {
  final String templeId;
  final String jwtToken;
  final bool hasUsedTrial;
  final bool isSubscribed;
  final String? coverImage;
  final String? activeCam;
  final VoidCallback? onSubscribeTap;
  final String? rtmpUrl;
  final String? directStreamUrl;
  final List<TempleAd>? ads;
  final String? adVideoUrl;
  final bool isAdSkippable;
  final bool isMuted;
  final VoidCallback? onMuteToggle;
  final void Function(LiveStreamPlayerState)? onPlayerReady;

  const LiveStreamPlayer({
    super.key,
    required this.templeId,
    required this.jwtToken,
    this.hasUsedTrial = false,
    this.isSubscribed = true,
    this.coverImage,
    this.activeCam,
    this.onSubscribeTap,
    this.rtmpUrl,
    this.directStreamUrl,
    this.ads,
    this.adVideoUrl,
    this.isAdSkippable = true,
    this.isMuted = true,
    this.onMuteToggle,
    this.onPlayerReady,
  });

  @override
  State<LiveStreamPlayer> createState() => LiveStreamPlayerState();
}

class LiveStreamPlayerState extends State<LiveStreamPlayer>
    with WidgetsBindingObserver {
  VlcPlayerController? _vlcController;
  VideoPlayerController? _videoController;
  bool _isLocked = false;
  int _timeLeft = 30;
  Timer? _trialTimer;
  bool _isInitialized = false;
  String? _error;

  // Seek and Play states
  final ValueNotifier<bool> isAtLiveEdge = ValueNotifier<bool>(true);
  final ValueNotifier<bool> isPlaying = ValueNotifier<bool>(true);

  void play() {
    isPlaying.value = true;
    if (kIsWeb && _videoController != null) {
      _videoController!.play();
    } else if (_vlcController != null) {
      _vlcController!.play();
    }
  }

  void pause() {
    isPlaying.value = false;
    if (kIsWeb && _videoController != null) {
      _videoController!.pause();
    } else if (_vlcController != null) {
      _vlcController!.pause();
    }
  }

  void jumpToLive() {
    if (isAtLiveEdge.value) return;
    isAtLiveEdge.value = true;
    
    if (kIsWeb && _videoController != null) {
      _videoController!.seekTo(_videoController!.value.duration);
    } else if (_vlcController != null) {
      _vlcController!.setMediaFromNetwork(_streamUrl, autoPlay: true).then((_) {
        _vlcController!.setVolume(widget.isMuted ? 0 : 100);
      });
    }
  }

  Future<void> seekBackward10s() async {
    isAtLiveEdge.value = false;
    
    if (kIsWeb && _videoController != null) {
      final currentPos = _videoController!.value.position;
      final newPos = currentPos - const Duration(seconds: 10);
      await _videoController!.seekTo(newPos > Duration.zero ? newPos : Duration.zero);
    } else if (_vlcController != null) {
      final currentPos = await _vlcController!.getPosition();
      final newPos = currentPos - const Duration(seconds: 10);
      await _vlcController!.seekTo(newPos > Duration.zero ? newPos : Duration.zero);
    }
  }

  // Ad states
  bool _isPlayingAd = false;
  String? _currentAdUrl;
  YoutubePlayerController? _ytAdController;
  VideoPlayerController? _html5AdController;
  int _adSkipCountdown = 3;
  Timer? _adSkipTimer;
  Timer? _randomAdTimer;

  String get _streamUrl {
    // If an exact legacy camera URL was passed (already a full URL), use it directly
    if (widget.directStreamUrl != null && widget.directStreamUrl!.isNotEmpty) {
      logD('[LiveStreamPlayer] Using exact legacy stream URL: ${widget.directStreamUrl}');
      return widget.directStreamUrl!;
    }
    
    // Default to the secure backend proxy which handles stream keys internally via Node-Media-Server
    logD('[LiveStreamPlayer] Using secure backend proxy stream URL.');
    String base = '${ApiClient.baseUrl}/temples/${widget.templeId}/stream.flv?token=${widget.jwtToken}';
    if (widget.activeCam != null && widget.activeCam != 'Main Cam') {
      base += '&view=${Uri.encodeComponent(widget.activeCam!)}';
    }
    return base;
  }

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    if (widget.hasUsedTrial && !widget.isSubscribed) {
      _isLocked = true;
    } else {
      _initPlayer();
      if (!widget.isSubscribed && !widget.hasUsedTrial) {
        _startTrialTimer();
      }
      if (!widget.isSubscribed) {
        _scheduleNextAd();
      }
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onPlayerReady?.call(this);
    });
  }

  @override
  void didUpdateWidget(covariant LiveStreamPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    // When temple changes, full re-initialization is required.
    if (oldWidget.templeId != widget.templeId) {
      _disposeControllers().then((_) => _initPlayer());
    } 
    // Effortlessly switch camera angle without disposing the player surface
    else if (oldWidget.activeCam != widget.activeCam) {
      final newUrl = _streamUrl;
      logD('[LiveStreamPlayer] Effortlessly switching camera feed to: $newUrl');
      
      if (kIsWeb && _videoController != null) {
        // Web: fast-switch using VideoPlayer
        _videoController!.pause();
        _disposeControllers().then((_) => _initPlayer());
      } else if (_vlcController != null && _isInitialized) {
        // Mobile: fast-switch using VLC without recreating native surface
        _vlcController!.setMediaFromNetwork(newUrl, autoPlay: true).then((_) {
          if (widget.isMuted) {
            _vlcController!.setVolume(0);
          } else {
            _vlcController!.setVolume(100);
          }
        });
      } else {
        _disposeControllers().then((_) => _initPlayer());
      }
    }
    
    if (oldWidget.isMuted != widget.isMuted) {
      if (kIsWeb && _videoController != null) {
        _videoController!.setVolume(widget.isMuted ? 0.0 : 1.0);
      } else if (_vlcController != null && _isInitialized) {
        _vlcController!.setVolume(widget.isMuted ? 0 : 100);
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (kIsWeb) return;
    if (_vlcController == null || !_isInitialized) return;
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _vlcController!.pause();
    } else if (state == AppLifecycleState.resumed) {
      _vlcController!.play();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _trialTimer?.cancel();
    _adSkipTimer?.cancel();
    _randomAdTimer?.cancel();
    _videoController?.dispose();
    _html5AdController?.dispose();
    _ytAdController?.dispose();
    isAtLiveEdge.dispose();
    isPlaying.dispose();
    if (!kIsWeb) {
      try {
        _vlcController?.stopRendererScanning();
      } catch (_) {}
      try {
        _vlcController?.stop();
      } catch (_) {}
      _vlcController?.dispose();
    }
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Player initialisation
  // ---------------------------------------------------------------------------

  Future<void> _initPlayer() async {
    if (!mounted) return;
    setState(() {
      _isInitialized = false;
      _error = null;
    });

    final url = _streamUrl;
    logD('[LiveStreamPlayer] Initializing stream: $url');

    if (kIsWeb) {
      try {
        final controller = VideoPlayerController.networkUrl(Uri.parse(url));
        _videoController = controller;
        await controller.initialize();
        if (!mounted) return;
        setState(() => _isInitialized = true);
        await controller.setVolume(0.0); // Mute web on start
        await controller.play();
        await controller.setLooping(true);
      } catch (e) {
        logD('[LiveStreamPlayer] Web init error: $e');
        if (!mounted) return;
        setState(() {
          _error = 'Stream offline or format unsupported';
          _isInitialized = false;
        });
      }
    } else {
      // Direct playback via VLC without pre-check (pre-check blocked matgodcreator.com)

      try {
        final controller = VlcPlayerController.network(
          url,
          hwAcc: HwAcc.disabled,
          autoPlay: true,
        );
        _vlcController = controller;

        // Rebuild immediately so that VlcPlayer is mounted in the widget tree,
        // which creates the native Android PlatformView and registers the method channel.
        if (mounted) {
          setState(() {});
        }

        // Poll until the native player initialises (max ~15 s).
        int checks = 0;
        while (!_vlcController!.value.isInitialized && checks < 100) {
          if (_vlcController!.value.hasError) {
            throw Exception(_vlcController!.value.errorDescription);
          }
          await Future.delayed(const Duration(milliseconds: 150));
          checks++;
        }

        if (!_vlcController!.value.isInitialized) {
          throw Exception('VLC Player initialization timed out');
        }

        // Explicitly trigger play to start streaming and set volume to 0
        await _vlcController!.setVolume(0);
        await _vlcController!.play();

        if (!mounted) return;
        setState(() {
          _isInitialized = true;
          _error = null;
        });
      } catch (e) {
        logD('[LiveStreamPlayer] VLC init error: $e');
        if (!mounted) return;
        setState(() {
          _error =
              'Live stream loading error. Please check if the stream is online.';
          _isInitialized = false;
        });
      }
    }
  }

  Future<void> _disposeControllers() async {
    if (_videoController != null) {
      await _videoController!.dispose();
      _videoController = null;
    }
    if (_vlcController != null) {
      try {
        await _vlcController!.stopRendererScanning();
      } catch (_) {}
      try {
        await _vlcController!.stop();
      } catch (_) {}
      await _vlcController!.dispose();
      _vlcController = null;
    }
    _isInitialized = false;
  }

  // ---------------------------------------------------------------------------
  // Trial / subscription
  // ---------------------------------------------------------------------------

  void _startTrialTimer() {
    _trialTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_timeLeft <= 1) {
          _trialTimer?.cancel();
          _isLocked = true;
          _isPlayingAd = false;
          _vlcController?.stop();
          _videoController?.pause();
          _ytAdController?.pause();
          _html5AdController?.pause();
          _randomAdTimer?.cancel();
          _completeTrialOnBackend();
        } else {
          _timeLeft--;
        }
      });
    });
  }

  void _scheduleNextAd() {
    if (_isLocked || _isPlayingAd) return;

    if (widget.ads != null && widget.ads!.isNotEmpty) {
      _currentAdUrl = widget.ads!.first.videoUrl;
    } else if (widget.adVideoUrl != null && widget.adVideoUrl!.isNotEmpty) {
      _currentAdUrl = widget.adVideoUrl;
    } else {
      // Fallback mock ad URL for testing since the API currently doesn't return any ads
      _currentAdUrl = 'https://www.youtube.com/watch?v=a3ICNMQW7Ok'; 
    }

    if (_currentAdUrl == null || _currentAdUrl!.isEmpty) return;

    _randomAdTimer?.cancel();
    
    // Play randomly between 60-180 seconds (1 to 3 minutes)
    final delaySeconds = math.Random().nextInt(121) + 60;
    
    _randomAdTimer = Timer(Duration(seconds: delaySeconds), () {
      if (!mounted || _isLocked || _isPlayingAd) return;
      _playAd();
    });
  }

  void _playAd() {
    if (_currentAdUrl == null) return;
    
    _isPlayingAd = true;
    _adSkipCountdown = 3;
    
    // Mute the main stream while ad plays
    if (kIsWeb && _videoController != null) {
      _videoController!.setVolume(0);
    } else if (_vlcController != null) {
      _vlcController!.setVolume(0);
    }

    final videoId = YoutubePlayer.convertUrlToId(_currentAdUrl!);
    if (videoId != null) {
      _ytAdController = YoutubePlayerController(
        initialVideoId: videoId,
        flags: const YoutubePlayerFlags(
          autoPlay: true,
          hideControls: true,
          mute: false,
          disableDragSeek: true,
        ),
      )..addListener(() {
          if (_ytAdController != null && _ytAdController!.value.playerState == PlayerState.ended) {
            Future.microtask(() => _skipAd());
          }
        });
    } else {
      _html5AdController = VideoPlayerController.networkUrl(Uri.parse(_currentAdUrl!))
        ..initialize().then((_) {
          setState(() {});
          _html5AdController!.play();
        })
        ..addListener(() {
          if (_html5AdController != null && 
              _html5AdController!.value.isInitialized && 
              _html5AdController!.value.position >= _html5AdController!.value.duration) {
            Future.microtask(() => _skipAd());
          }
        });
    }

    _adSkipTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() {
        if (_adSkipCountdown > 0) {
          _adSkipCountdown--;
        } else {
          t.cancel();
        }
      });
    });
  }

  void _skipAd() {
    if (!mounted) return;
    setState(() {
      _isPlayingAd = false;
      _ytAdController?.dispose();
      _ytAdController = null;
      _html5AdController?.dispose();
      _html5AdController = null;

      // Restore stream volume if user hadn't muted it
      if (!widget.isMuted) {
        // If video initialized, mute by default based on widget
        if (kIsWeb && _videoController != null) {
          _videoController!.setVolume(widget.isMuted ? 0.0 : 1.0);
        } else if (_vlcController != null) {
          _vlcController!.setVolume(widget.isMuted ? 0 : 100);
        }
      }
    });
    
    // Schedule the next ad to play
    _scheduleNextAd();
  }

  Future<void> _completeTrialOnBackend() async {
    try {
      final response = await http.post(
        Uri.parse('${ApiClient.baseUrl}/users/complete-trial'),
        headers: {
          'Authorization': 'Bearer ${widget.jwtToken}',
          'Content-Type': 'application/json',
        },
      );
      if (response.statusCode == 200) {
        logD('[LiveStreamPlayer] Trial marked as used on backend.');
      }
    } catch (e) {
      logD('[LiveStreamPlayer] Error marking trial: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (_isLocked) return _buildLockScreen();

    return Stack(
      fit: StackFit.expand,
      children: [
        // ── Video surface ────────────────────────────────────────────
        if (_error != null)
          _buildErrorOverlay()
        else if (kIsWeb)
          if (_isInitialized && _videoController != null)
            SizedBox.expand(
              child: FittedBox(
                fit: BoxFit.cover,
                clipBehavior: Clip.hardEdge,
                child: SizedBox(
                  width: _videoController!.value.size.width,
                  height: _videoController!.value.size.height,
                  child: VideoPlayer(_videoController!),
                ),
              ),
            )
          else
            _buildLoadingOverlay()
        else // Mobile (VLC)
        if (_vlcController != null)
          SizedBox.expand(
            child: VlcPlayer(
              controller: _vlcController!,
              aspectRatio: 16 / 9,
              placeholder: _buildLoadingOverlay(),
            ),
          )
        else
          _buildLoadingOverlay(),

        // ── AD OVERLAY ────────────────────────────────────────────────
        if (_isPlayingAd)
          Positioned.fill(
            child: Container(
              color: Colors.black,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (_ytAdController != null)
                    YoutubePlayer(controller: _ytAdController!)
                  else if (_html5AdController != null && _html5AdController!.value.isInitialized)
                    FittedBox(
                      fit: BoxFit.contain,
                      child: SizedBox(
                        width: _html5AdController!.value.size.width,
                        height: _html5AdController!.value.size.height,
                        child: VideoPlayer(_html5AdController!),
                      ),
                    )
                  else
                    const Center(child: CircularProgressIndicator(color: AppColors.gold)),
                  
                  // Ad badge
                  Positioned(
                    top: 10,
                    right: widget.isAdSkippable ? 110 : 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: AppColors.gold.withValues(alpha: 0.5)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.stars, color: AppColors.gold, size: 12),
                          SizedBox(width: 4),
                          Text('MetaGod AD', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),

                  // Skip Button
                  if (widget.isAdSkippable)
                    Positioned(
                      top: 10,
                      right: 10,
                      child: GestureDetector(
                        onTap: _adSkipCountdown == 0 ? _skipAd : null,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: _adSkipCountdown == 0 ? Colors.white.withValues(alpha: 0.2) : Colors.black54,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: Text(
                            _adSkipCountdown > 0 ? 'Skip in $_adSkipCountdown' : 'Skip Ad ⏭',
                            style: TextStyle(
                              color: _adSkipCountdown == 0 ? Colors.white : Colors.white70,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

        // ── Trial countdown badge ────────────────────────────────────
        if (!widget.isSubscribed && !_isLocked && _timeLeft > 0)
          Positioned(
            top: 10,
            right: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(
                  color: AppColors.gold.withValues(alpha: 0.5),
                ),
              ),
              child: Text(
                'Trial: ${_timeLeft}s',
                style: const TextStyle(
                  color: AppColors.gold,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),

        // ── Subscription Pass overlay ──────────────────────────────
        if (_isInitialized && _error == null && !_isLocked)
          if (!widget.isSubscribed && _timeLeft > 0)
            Positioned(
              bottom: 12,
              right: 12,
              child: GestureDetector(
                onTap: widget.onSubscribeTap,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.gold,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.bolt, color: Colors.black, size: 14),
                      SizedBox(width: 4),
                      Text(
                        'BUY PASS',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Sub-widgets
  // ---------------------------------------------------------------------------

  Widget _buildLoadingOverlay() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.gold),
          ),
          SizedBox(height: 12),
          Text(
            'Connecting to Live Darshan\u2026',
            style: TextStyle(color: AppColors.muted, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorOverlay() {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (widget.coverImage != null && widget.coverImage!.startsWith('http'))
          Image.network(widget.coverImage!, fit: BoxFit.cover),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.black.withValues(alpha: 0.7),
                Colors.black.withValues(alpha: 0.9),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.gold.withValues(alpha: 0.3),
                    width: 2,
                  ),
                ),
                child: const Icon(
                  Icons.live_tv_rounded,
                  color: AppColors.gold,
                  size: 32,
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Awaiting Live Darshan',
                style: TextStyle(
                  color: AppColors.cream,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'The live stream will begin shortly.\nPlease check back soon. \u{1F64F}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 11,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLockScreen() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.lock_person, color: AppColors.gold, size: 48),
          const SizedBox(height: 15),
          const Text(
            'Darshan Preview Finished',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Join our circle of devotees to continue this live experience.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[500], fontSize: 13),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.gold,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            onPressed: widget.onSubscribeTap,
            child: const Text(
              'SUBSCRIBE NOW',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
