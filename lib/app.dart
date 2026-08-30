import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'widgets/phone_frame.dart';
import 'widgets/bottom_nav_bar.dart';
import 'screens/home/home_screen.dart';
import 'screens/explore/divine_marketplace_screen.dart';
import 'screens/darshan/darshan_screen.dart';
import 'screens/consultation/consultation_screen.dart';
import 'screens/ai_pandit/ai_pandit_screen.dart';
import 'screens/auth/auth_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'services/auth_service.dart';
import 'theme/app_colors.dart';
import 'utils/app_logger.dart';
import 'main.dart' show navigatorKey;

class TempleApp extends StatefulWidget {
  const TempleApp({super.key});

  @override
  State<TempleApp> createState() => _TempleAppState();
}

class _TempleAppState extends State<TempleApp> {
  int _currentTab = 0;
  String _darshanFilter = 'all';

  late AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initDeepLinks() async {
    _appLinks = AppLinks();

    // Check initial link if app was in cold state
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        _handleDeepLink(initialUri);
      }
    } catch (e) {
      logE('Error getting initial link', e);
    }

    // Handle link when app is in warm state
    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      _handleDeepLink(uri);
    }, onError: (err) {
      logE('Error handling deep link', err);
    });
  }

  // Only links from our own verified hosts are honored.
  static const Set<String> _trustedHosts = {
    'metagodcreator.com',
    'www.metagodcreator.com',
  };

  void _handleDeepLink(Uri uri) {
    if (!_trustedHosts.contains(uri.host.toLowerCase())) {
      return;
    }

    // Match on normalized path SEGMENTS instead of raw substring matching.
    // Substring matching (e.g. path.contains('ai')) produces false positives
    // like matching 'ai' inside 'email' or 'detail'.
    final segments = uri.pathSegments.map((s) => s.toLowerCase()).toList();
    bool has(List<String> keys) => segments.any(
          (seg) => keys.any((k) => seg == k || seg.startsWith(k)),
        );

    if (has(['consult'])) {
      setState(() => _currentTab = 4);
    } else if (has(['shop', 'explore', 'essential', 'essentials'])) {
      setState(() => _currentTab = 1);
    } else if (has(['vr-experiences', 'vr'])) {
      setState(() {
        _currentTab = 2;
        _darshanFilter = 'vr';
      });
    } else if (has(['darshan', 'temple-live', 'temple-services'])) {
      setState(() {
        _currentTab = 2;
        _darshanFilter = 'all';
      });
    } else if (has(['ai', 'horoscope', 'astro', 'metagod-ai', 'ai-oracle'])) {
      setState(() => _currentTab = 3);
    } else if (has(['profile'])) {
      navigatorKey.currentState?.push(
        MaterialPageRoute(builder: (_) => const ProfileScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();

    Widget mainContent;
    Widget? bottomNavBar;

    if (!authService.isInitialized) {
      mainContent = const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.gold),
            ),
            SizedBox(height: 16),
            Text(
              'Namaste...',
              style: TextStyle(
                color: AppColors.muted,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
      bottomNavBar = null;
    } else if (!authService.isAuthenticated) {
      mainContent = const AuthScreen();
      bottomNavBar = null;
    } else {
      final screens = [
        HomeScreen(onTabChanged: (index, {filter}) {
          setState(() {
            _currentTab = index;
            _darshanFilter = filter ?? 'all';
          });
        }),
        const DivineMarketplaceScreen(),
        DarshanScreen(key: ValueKey(_darshanFilter), initialFilter: _darshanFilter),
        const AIPanditScreen(),
        const ConsultationScreen(),
      ];
      mainContent = screens[_currentTab];
      
      // Hide bottom navbar for AIPanditScreen (index 3) and ConsultationChatScreen if it was a tab
      if (_currentTab == 3) {
        bottomNavBar = null;
      } else {
        bottomNavBar = BottomNavBar(
          currentIndex: _currentTab,
          onTabChanged: (index) {
            setState(() => _currentTab = index);
          },
        );
      }
    }

    final innerScaffold = Scaffold(
      backgroundColor: AppColors.bg,
      extendBody: true,
      body: SafeArea(
        bottom: false,
        child: mainContent,
      ),
      bottomNavigationBar: bottomNavBar,
    );

    // On real mobile devices render without the phone-frame wrapper.
    if (!kIsWeb) {
      return PopScope(
        canPop: _currentTab == 0,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          if (_currentTab != 0) {
            setState(() {
              _currentTab = 0;
            });
          }
        },
        child: innerScaffold,
      );
    }

    // Web: wrap in the decorative phone frame.
    return PopScope(
      canPop: _currentTab == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_currentTab != 0) {
          setState(() {
            _currentTab = 0;
          });
        }
      },
      child: Scaffold(
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0a0612), Color(0xFF08060f)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Center(
            child: PhoneFrame(
              child: innerScaffold,
            ),
          ),
        ),
      ),
    );
  }
}
