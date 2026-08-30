import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/hero_slide.dart';
import '../../../services/temple_service.dart';
import '../../../theme/app_colors.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../profile/profile_screen.dart';
import '../../../utils/app_logger.dart';

class HeroBanner extends StatefulWidget {
  final void Function(int index, {String? filter})? onTabChanged;

  const HeroBanner({super.key, this.onTabChanged});

  @override
  State<HeroBanner> createState() => _HeroBannerState();
}

class _HeroBannerState extends State<HeroBanner> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  Timer? _autoSlideTimer;
  List<HeroSlide>? _heroSlides;

  @override
  void initState() {
    super.initState();
    _loadVrExperiences();
    _startAutoSlide();
  }

  @override
  void dispose() {
    _autoSlideTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadVrExperiences() async {
    if (!mounted) return;

    try {
      final templeService = context.read<TempleService>();
      final list = await templeService.fetchHeroSlides();
      if (mounted) {
        setState(() {
          _heroSlides = list;
        });
      }
    } catch (e) {
      logE('Failed to load hero slides', e);
    }
  }

  void _startAutoSlide() {
    _autoSlideTimer = Timer.periodic(const Duration(seconds: 6), (timer) {
      if (!mounted || _pageController.hasClients == false) return;
      
      final totalSlides = _heroSlides?.length ?? 1;
      if (totalSlides <= 1) return;

      final nextPage = (_currentPage + 1) % totalSlides;
      
      _pageController.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  void _showActionDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF16121F),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text(message, style: const TextStyle(color: Colors.white70, height: 1.4)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close', style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final slideList = _heroSlides;
    if (slideList == null) {
      // Loading state
      return Container(
        height: 210,
        margin: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Center(child: CircularProgressIndicator(color: AppColors.gold)),
      );
    }

    if (slideList.isEmpty) {
      return const SizedBox.shrink(); // No slides available
    }

    final totalSlides = slideList.length;

    return Column(
      children: [
        SizedBox(
          height: 280,
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (page) {
              setState(() {
                _currentPage = page;
              });
            },
            itemCount: totalSlides,
            itemBuilder: (context, index) {
              return _buildDynamicSlide(slideList[index]);
            },
          ),
        ),
        const SizedBox(height: 10),
        // Dots Indicator
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            totalSlides,
            (index) => Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: _currentPage == index ? 16 : 6,
              height: 6,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(3),
                color: _currentPage == index ? AppColors.gold : AppColors.muted.withValues(alpha: 0.4),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _handleLink(String link) async {
    final lowerLink = link.toLowerCase();
    
    if (lowerLink.startsWith('http')) {
      final uri = Uri.tryParse(link);
      if (uri != null && (uri.host == 'metagodcreator.com' || uri.host == 'www.metagodcreator.com')) {
        _handleDeepLinkRoute(uri.path);
        return;
      }

      if (uri != null) {
        try {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } catch (e) {
          logE('Error launching link', e);
        }
      }
      return;
    }

    _handleDeepLinkRoute(lowerLink);
  }

  void _handleDeepLinkRoute(String path) {
    final lowerLink = path.toLowerCase();

    if (lowerLink.contains('consult')) {
      widget.onTabChanged?.call(4);
    } else if (lowerLink.contains('shop') || lowerLink.contains('explore') || lowerLink.contains('essential') || lowerLink.contains('puja')) {
      widget.onTabChanged?.call(1);
    } else if (lowerLink.contains('vr-experiences') || lowerLink.contains('vr')) {
      widget.onTabChanged?.call(2, filter: 'vr');
    } else if (lowerLink.contains('darshan') || lowerLink.contains('temple-live') || lowerLink.contains('temple-services')) {
      widget.onTabChanged?.call(2);
    } else if (lowerLink.contains('ai') || lowerLink.contains('horoscope') || lowerLink.contains('astro') || lowerLink.contains('metagod-ai') || lowerLink.contains('ai-oracle')) {
      widget.onTabChanged?.call(3);
    } else if (lowerLink.contains('profile')) {
      if (context.mounted) {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen()));
      }
    }
  }

  Widget _buildDynamicSlide(HeroSlide slide) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        color: AppColors.card,
        image: slide.bg.startsWith('http')
            ? DecorationImage(
                image: NetworkImage(slide.bg),
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(
                  Colors.black.withValues(alpha: 0.6), // Dark overlay for text readability
                  BlendMode.darken,
                ),
              )
            : null,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.bg.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.verified_user_rounded, color: AppColors.gold, size: 12),
                  const SizedBox(width: 4),
                  Text(
                    slide.badge.toUpperCase(),
                    style: const TextStyle(
                      color: AppColors.cream,
                      fontSize: 10,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            RichText(
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              text: TextSpan(
                style: const TextStyle(
                  color: AppColors.cream,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  height: 1.2,
                ),
                children: [
                  TextSpan(text: '${slide.title}\n'),
                  TextSpan(
                    text: slide.highlight,
                    style: const TextStyle(color: AppColors.gold, fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              slide.desc,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 10,
              children: [
                InkWell(
                  onTap: () => _handleLink(slide.link1),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.gold, AppColors.saffron],
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    child: Text(
                      slide.cta1,
                      style: const TextStyle(
                        color: AppColors.bg,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
                if (slide.cta2.isNotEmpty) ...[
                  InkWell(
                    onTap: () => _handleLink(slide.link2),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      child: Text(
                        slide.cta2,
                        style: const TextStyle(
                          color: AppColors.cream,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}