import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:visibility_detector/visibility_detector.dart';
import '../theme/app_colors.dart';
import '../utils/app_logger.dart';

class VrThumbnailPlayer extends StatefulWidget {
  final String trailerLink;
  final String imageUrl;
  final String experienceId;
  final double opacity;

  const VrThumbnailPlayer({
    super.key,
    required this.trailerLink,
    required this.imageUrl,
    required this.experienceId,
    this.opacity = 1.0,
  });

  @override
  State<VrThumbnailPlayer> createState() => _VrThumbnailPlayerState();
}

class _VrThumbnailPlayerState extends State<VrThumbnailPlayer> {
  YoutubePlayerController? _controller;
  String? _videoId;
  bool _isPlayerReady = false;

  @override
  void initState() {
    super.initState();
    _videoId = YoutubePlayer.convertUrlToId(widget.trailerLink);
    if (_videoId != null) {
      _controller = YoutubePlayerController(
        initialVideoId: _videoId!,
        flags: const YoutubePlayerFlags(
          autoPlay: false,
          mute: true,
          loop: true,
          hideControls: true,
          disableDragSeek: true,
          enableCaption: false,
          isLive: false,
        ),
      )..addListener(_listener);
    }
  }

  void _listener() {
    if (mounted && _controller != null && _controller!.value.isReady != _isPlayerReady) {
      setState(() {
        _isPlayerReady = _controller!.value.isReady;
      });
    }
  }

  @override
  void dispose() {
    _controller?.removeListener(_listener);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final imageWidget = widget.imageUrl.startsWith('http')
        ? Image.network(
            widget.imageUrl,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => const Center(
              child: Icon(Icons.vrpano_rounded, size: 52, color: AppColors.gold),
            ),
          )
        : const Center(
            child: Icon(Icons.vrpano_rounded, size: 52, color: AppColors.gold),
          );

    final playerWidget = _controller != null
        ? VisibilityDetector(
            key: Key('vr_video_det_${widget.experienceId}'),
            onVisibilityChanged: (visibilityInfo) {
              if (!mounted || !_isPlayerReady || _controller == null) return;
              final visiblePercentage = visibilityInfo.visibleFraction * 100;
              try {
                if (visiblePercentage > 50) {
                  _controller!.play();
                } else {
                  _controller!.pause();
                }
              } catch (e) {
                logE('YoutubePlayer visibility error', e);
              }
            },
            child: Stack(
              fit: StackFit.expand,
              children: [
                IgnorePointer(
                  child: YoutubePlayer(
                    controller: _controller!,
                    showVideoProgressIndicator: false,
                    onReady: () {
                      if (mounted) {
                        setState(() {
                          _isPlayerReady = true;
                        });
                      }
                    },
                  ),
                ),
                if (!_isPlayerReady) imageWidget,
              ],
            ),
          )
        : imageWidget;

    if (widget.opacity < 1.0) {
      return Opacity(
        opacity: widget.opacity,
        child: playerWidget,
      );
    }
    return playerWidget;
  }
}
