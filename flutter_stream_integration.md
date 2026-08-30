# 📱 Flutter FLV Live Stream Integration Guide

To integrate the secured live stream in your Flutter application, you will consume the exact same backend proxy endpoint that the web frontend uses.

---

## 🏗️ The Integration Flow

1. **Get JWT Token**: Retrieve the user's stored auth token (usually from `flutter_secure_storage` or `shared_preferences`).
2. **Build the Proxy Stream URL**:
   `https://api.metagod.in/api/temples/$templeId/stream.flv?token=$jwtToken`
3. **Handle Trial / Subscriptions**: 
   - Fetch the user's status from your `/api/auth/me` endpoint.
   - Check if `user.subscriptionStatus == 'active'` or if `user.hasUsedTrial == false`.
   - If the trial is active, start a `Timer` in Flutter for `30` seconds. When the timer ends, hit `/api/users/complete-trial`, stop the player, and show the subscription lock overlay.
   - If they have no subscription and have already used their trial, show the lock screen immediately.

---

## 📦 Step 1: Add a Video Player Dependency

Flutter's default `video_player` package does not support the HTTP-FLV format out-of-the-box on all platforms. 

It is highly recommended to use **`flutter_vlc_player`** (which wraps VLC and supports FLV/RTMP streams natively) or **`fijkplayer`** (based on ijkplayer/FFmpeg).

Add this to your `pubspec.yaml`:
```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_vlc_player: ^7.2.0  # Supports HTTP-FLV streaming natively
  http: ^1.2.0                # For API calls
```

---

## 💻 Step 2: Implementation Code Example

Here is a complete, production-ready Flutter widget displaying the video player, implementing the **30-second trial timer**, and managing authorization:

```dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_vlc_player/flutter_vlc_player.dart';
import 'package:http/http.dart' as http;

class LiveStreamPlayer extends StatefulWidget {
  final String templeId;
  final String jwtToken;
  final bool hasUsedTrial;
  final bool isSubscribed;

  const LiveStreamPlayer({
    Key? key,
    required this.templeId,
    required this.jwtToken,
    required this.hasUsedTrial,
    required this.isSubscribed,
  }) : super(key: key);

  @override
  _LiveStreamPlayerState createState() => _LiveStreamPlayerState();
}

class _LiveStreamPlayerState extends State<LiveStreamPlayer> {
  late VlcPlayerController _vlcViewController;
  bool _isLocked = false;
  int _timeLeft = 30;
  Timer? _trialTimer;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();

    // 1. Check if user is locked out immediately
    if (widget.hasUsedTrial && !widget.isSubscribed) {
      _isLocked = true;
    } else {
      // Initialize VLC Controller pointing to our SECURE proxy route with token query param
      final String streamUrl = 
          "https://api.metagod.in/api/temples/${widget.templeId}/stream.flv?token=${widget.jwtToken}";

      _vlcViewController = VlcPlayerController.network(
        streamUrl,
        hwAcc: HwAcc.full,
        autoPlay: true,
        options: VlcPlayerOptions(
          advanced: VlcAdvancedOptions([
            '--network-caching=300', // Low latency cache setup
          ]),
        ),
      );
      _isPlaying = true;

      // 2. Start trial timer if they are logged in but don't have a subscription
      if (!widget.isSubscribed && !widget.hasUsedTrial) {
        _startTrialTimer();
      }
    }
  }

  void _startTrialTimer() {
    _trialTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_timeLeft <= 1) {
          _trialTimer?.cancel();
          _isLocked = true;
          _isPlaying = false;
          _vlcViewController.stop();
          _completeTrialOnBackend(); // Notify backend that trial is consumed
        } else {
          _timeLeft--;
        }
      });
    });
  }

  Future<void> _completeTrialOnBackend() async {
    try {
      final response = await http.post(
        Uri.parse("https://api.metagod.in/api/users/complete-trial"),
        headers: {
          "Authorization": "Bearer ${widget.jwtToken}",
          "Content-Type": "application/json",
        },
      );
      if (response.statusCode == 200) {
        print("Trial successfully marked as used on backend.");
      }
    } catch (e) {
      print("Error marking trial as completed: $e");
    }
  }

  @override
  void dispose() {
    _trialTimer?.cancel();
    if (_isPlaying) {
      _vlcViewController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLocked) {
      return _buildLockScreen();
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        // Video Stream View
        AspectRatio(
          aspectRatio: 16 / 9,
          child: VlcPlayer(
            controller: _vlcViewController,
            aspectRatio: 16 / 9,
            placeholder: const Center(
              child: CircularProgressIndicator(color: Colors.amber),
            ),
          ),
        ),

        // Countdown Timer Overlay (Trial Mode)
        if (!widget.isSubscribed && _timeLeft > 0)
          Positioned(
            top: 10,
            right: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, py: 5),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.amber.withOpacity(0.5)),
              ),
              child: Text(
                "Trial: ${_timeLeft}s",
                style: const TextStyle(
                  color: Colors.amber,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
      ],
    );
  }

  // Beautiful Lock Screen Overlay
  Widget _buildLockScreen() {
    return Container(
      width: double.infinity,
      height: 250, // Matches video player height
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.95),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.lock_person, color: Colors.amber, size: 48),
          const SizedBox(height: 15),
          const Text(
            "Darshan Preview Finished",
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
              "Join our circle of devotees to continue this live experience.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[500], fontSize: 13),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            onPressed: () {
              // Trigger Razorpay / In-App purchase logic
            },
            child: const Text(
              "SUBSCRIBE NOW",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
```

---

## 🛡️ Security Benefits in Flutter

1. **No Hardcoded Keys**: The Flutter app code does not contain any secret RTMP stream keys. It only ever requests the secure `stream.flv` endpoint.
2. **Easy Token Propagation**: JWT verification handles user session validation instantly.
3. **Low-Latency Streaming**: The network-caching optimization (`--network-caching=300` in VLC configurations) ensures the proxied stream remains real-time with very minimal buffering latency.
