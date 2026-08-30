import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../theme/app_colors.dart';
import '../../services/auth_service.dart';
import '../../services/temple_service.dart';
import 'widgets/category_chips.dart';
import 'widgets/hero_banner.dart';
import '../consultation/widgets/pandit_card.dart';
import 'widgets/quick_action_grid.dart';
import 'widgets/home_search_bar.dart';
import '../profile/profile_screen.dart';
import '../explore/divine_marketplace_screen.dart';
import '../explore/widgets/temple_details_screen.dart';
import '../darshan/widgets/temple_card.dart';
import '../darshan/widgets/vr_experience_card.dart';
import '../../models/temple.dart';
import '../../models/product.dart';
import '../../models/vr_experience.dart';
import '../../services/cart_service.dart';
import '../explore/order_summary_screen.dart';
import '../../widgets/app_network_image.dart';
import '../../utils/app_logger.dart';

class HomeScreen extends StatefulWidget {
  final void Function(int index, {String? filter})? onTabChanged;
  const HomeScreen({super.key, this.onTabChanged});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _activeCat = 0;
  List<Map<String, dynamic>>? _experts;
  List<Temple>? _liveTemples;
  List<Product>? _templeShop;
  List<VrExperience>? _vrExperiences;
  List<Map<String, dynamic>>? _categories;

  static const _fallbackPandits = [
    {
      'name': 'Pt. Raghavendra',
      'spec': 'Vedic Astrology',
      'rating': 4.9,
      'reviews': 312,
      'loc': 'Varanasi',
      'emoji': '',
      'avail': true,
    },
    {
      'name': 'Pt. Subramaniam',
      'spec': 'Agamic Rituals',
      'rating': 4.8,
      'reviews': 198,
      'loc': 'Madurai',
      'emoji': '',
      'avail': true,
    },
    {
      'name': 'Acharya Devendra',
      'spec': 'Vastu Shastra',
      'rating': 4.9,
      'reviews': 445,
      'loc': 'Haridwar',
      'emoji': '',
      'avail': false,
    },
  ];

  static const _festivals = [
    {
      'day': '28',
      'mon': 'May',
      'name': 'Vat Savitri Vrat',
      'detail': 'Full Moon · Jyeshtha',
    },
    {
      'day': '06',
      'mon': 'Jun',
      'name': 'Shani Jayanti',
      'detail': 'Amavasya · Shani Puja',
    },
  ];

  @override
  void initState() {
    super.initState();
    _fetchExperts();
    _fetchHomeData();
  }

  Future<void> _fetchHomeData() async {
    try {
      final templeService = context.read<TempleService>();
      final futures = await Future.wait([
        templeService.fetchTemples(),
        templeService.fetchProducts(),
        templeService.fetchVrExperiences(),
        templeService.fetchCategories(),
      ]);

      if (mounted) {
        setState(() {
          _liveTemples = (futures[0] as List<Temple>).where((t) => t.isLive).toList();
          _templeShop = futures[1] as List<Product>;
          _vrExperiences = futures[2] as List<VrExperience>;
          _categories = futures[3] as List<Map<String, dynamic>>;
        });
      }
    } catch (e) {
      logE('Failed to fetch home data', e);
    }
  }

  Future<void> _fetchExperts() async {
    try {
      final templeService = context.read<TempleService>();
      final data = await templeService.fetchExperts();
      if (mounted) {
        setState(() {
          _experts = data;
        });
      }
    } catch (e) {
      logE('Failed to fetch experts', e);
      // Leave _experts as null — the build method will use fallback data
    }
  }

  /// Map a backend category string to a display emoji.
  String _categoryEmoji(String? category) {
    switch (category?.toLowerCase()) {
      case 'astrology':
        return '';
      case 'vastu':
      case 'vastu shastra':
        return '';
      case 'rituals':
      case 'puja':
        return '';
      case 'numerology':
        return '';
      case 'palmistry':
        return '';
      default:
        return '';
    }
  }

  void _handleCategoryTap(int index) {
    if (index == 0) return; // 'All' - no routing action needed
    
    if (index == 1) { // 'Puja'
      widget.onTabChanged?.call(1);
    } else if (index == 2) { // 'Horoscope'
      widget.onTabChanged?.call(3);
    } else if (index == 3) { // 'Darshan'
      widget.onTabChanged?.call(2);
    } else if (index == 4) { // 'Events'
      widget.onTabChanged?.call(2, filter: 'all');
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 18),
          HeroBanner(onTabChanged: widget.onTabChanged),
          const SizedBox(height: 14),
          HomeSearchBar(onTabChanged: widget.onTabChanged),
          const SizedBox(height: 16),
          CategoryChips(
            activeIndex: _activeCat,
            onChanged: (i) {
              setState(() => _activeCat = i);
              _handleCategoryTap(i);
            },
          ),
          const SizedBox(height: 22),
          QuickActionGrid(onTabChanged: widget.onTabChanged),
          const SizedBox(height: 22),
          _buildLiveTemples(),
          const SizedBox(height: 22),
          _buildCategories(),
          const SizedBox(height: 22),
          _buildFeaturedPandits(),
          const SizedBox(height: 20),
          _buildTempleShop(),
          const SizedBox(height: 20),
          _buildVRExperiences(),
          const SizedBox(height: 20),
          // _buildUpcomingFestivals(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final user = context.watch<AuthService>().currentUser;
    final name = user?.name.isEmpty == false ? user!.name : 'Devotee';
    final initial = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : 'U';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 40, 20, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    'Namaste,',
                    style: TextStyle(
                      color: AppColors.saffron,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.1,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Image.asset('assets/images/namaste.png', height: 18, errorBuilder: (c, e, s) => const Icon(Icons.wb_sunny_rounded, color: AppColors.saffron, size: 16)),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                name,
                style: const TextStyle(
                  color: AppColors.cream,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                  shadows: [
                    Shadow(color: Color(0x33FCA311), blurRadius: 10, offset: Offset(0, 2)),
                  ],
                ),
              ),
            ],
          ),
          Row(
            children: [
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const OrderSummaryScreen()),
                  );
                },
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.card,
                    border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      const Icon(Icons.shopping_bag_outlined, color: AppColors.gold, size: 20),
                      if (context.watch<CartService>().cartItems.isNotEmpty)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: AppColors.red,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '${context.watch<CartService>().cartItems.length}',
                              style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ProfileScreen()),
                  );
                },
                child: Stack(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [AppColors.gold, AppColors.saffron],
                        ),
                      ),
                      alignment: Alignment.center,
                      child: user?.avatar != null && user!.avatar!.isNotEmpty
                          ? ClipOval(
                              child: AppNetworkImage(
                                url: user.avatar,
                                width: 44,
                                height: 44,
                                fit: BoxFit.cover,
                              ),
                            )
                          : Text(
                              initial,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: AppColors.bg,
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturedPandits() {
    // Use live data if available, otherwise fall back to static mock
    final pandits = _experts ?? _fallbackPandits;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            'Consultations',
            onViewAll: () => widget.onTabChanged?.call(4),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 380, // Increased height to prevent PanditCard overflow
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: pandits.length,
              separatorBuilder: (_, n) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final p = pandits[index];

                final name = (p['name'] as String?) ?? 'Expert';
                final spec = (p['title'] as String?) ?? (p['spec'] as String?) ?? '';
                final rating = (p['rating'] as num?)?.toDouble() ?? 0.0;
                final reviews = (p['reviews'] as num?)?.toInt() ?? 0;
                final loc = (p['location'] as String?) ?? (p['loc'] as String?) ?? '';
                final avail = p['avail'] as bool? ?? (p['status'] == 'online');

                // Create a cohesive map to pass down to PanditCard
                final expertMap = {
                  '_id': p['_id'] ?? 'fallback',
                  'name': name,
                  'category': spec,
                  'experience': '10+ YEARS', // Default fallback
                  'rating': rating,
                  'reviews': reviews,
                  'location': loc,
                  'status': avail ? 'online' : 'offline',
                  'pricing': p['pricing'] ?? {'chat': 100, 'audio': 200, 'video': 300},
                  'image': p['image'],
                };

                return PanditCard(
                  expert: expertMap,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // Widget _buildUpcomingFestivals() {
  //   return Padding(
  //     padding: const EdgeInsets.symmetric(horizontal: 20),
  //     child: Column(
  //       crossAxisAlignment: CrossAxisAlignment.start,
  //       children: [
  //         Row(
  //           mainAxisAlignment: MainAxisAlignment.spaceBetween,
  //           children: [
  //             const Flexible(
  //               child: Text(
  //                 'Upcoming Festivals',
  //                 style: TextStyle(
  //                   color: AppColors.cream,
  //                   fontSize: 16,
  //                   fontWeight: FontWeight.w700,
  //                 ),
  //               ),
  //             ),
  //             GestureDetector(
  //               onTap: () {},
  //               child: const Text(
  //                 'Calendar',
  //                 style: TextStyle(
  //                   color: AppColors.gold,
  //                   fontSize: 12,
  //                   fontWeight: FontWeight.w600,
  //                 ),
  //               ),
  //             ),
  //           ],
  //         ),
  //         const SizedBox(height: 14),
  //         for (final f in _festivals)
  //           Padding(
  //             padding: const EdgeInsets.only(bottom: 10),
  //             child: FestivalCard(
  //               day: f['day'] as String,
  //               mon: f['mon'] as String,
  //               name: f['name'] as String,
  //               detail: f['detail'] as String,
  //             ),
  //           ),
  //       ],
  //     ),
  //   );
  // }

  Widget _buildLiveTemples() {
    if (_liveTemples == null) return const Center(child: CircularProgressIndicator(color: AppColors.gold));
    if (_liveTemples!.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            'Happening Live Now',
            onViewAll: () => widget.onTabChanged?.call(2),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 230, // Increased height to prevent TempleCard overflow
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _liveTemples!.length > 5 ? 5 : _liveTemples!.length,
              separatorBuilder: (_, n) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                return SizedBox(
                  width: 280,
                  child: TempleCard(
                    temple: _liveTemples![index],
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => TempleDetailsScreen(templeId: _liveTemples![index].id),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTempleShop() {
    if (_templeShop == null || _templeShop!.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            'Popular Services & Items',
            subtitle: 'Hand-picked spiritual experiences and essentials',
            onViewAll: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DivineMarketplaceScreen())),
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 310,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _templeShop!.length > 5 ? 5 : _templeShop!.length,
              separatorBuilder: (_, n) => const SizedBox(width: 14),
              itemBuilder: (context, index) {
                final product = _templeShop![index];
                
                final bool isRitual = product.category.toLowerCase().contains('puja') || product.category.toLowerCase().contains('ritual');
                final tagColor = isRitual ? const Color(0xFFE56B3E) : const Color(0xFF2A2D34);
                final tagText = isRitual ? 'RITUAL' : 'PRODUCT';
                final unitText = isRitual ? '/puja' : '/unit';

                return Container(
                  width: 240,
                  decoration: BoxDecoration(
                    color: const Color(0xFF161122), // Dark background mimicking the image
                    border: Border.all(color: AppColors.border.withValues(alpha: 0.3)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Image with Tag
                      Stack(
                        children: [
                          Container(
                            height: 150,
                            width: double.infinity,
                            decoration: const BoxDecoration(
                              borderRadius: BorderRadius.vertical(top: Radius.circular(11)),
                              color: Colors.black26,
                            ),
                            child: ClipRRect(
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
                              child: product.image != null && product.image!.startsWith('http')
                                  ? AppNetworkImage(url: product.image, fit: BoxFit.cover)
                                  : const Icon(Icons.shopping_bag_outlined, color: AppColors.gold),
                            ),
                          ),
                          Positioned(
                            top: 10,
                            left: 10,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: tagColor,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isRitual ? Icons.local_fire_department_outlined : Icons.inventory_2_outlined,
                                    color: Colors.white,
                                    size: 10,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    tagText,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      
                      // Content
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                product.category.toUpperCase(),
                                style: const TextStyle(color: AppColors.muted, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                product.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: AppColors.cream, fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              const Spacer(),
                              
                              // Dashed line
                              Container(
                                height: 1,
                                width: double.infinity,
                                margin: const EdgeInsets.symmetric(vertical: 12),
                                child: LayoutBuilder(
                                  builder: (context, constraints) {
                                    final dashWidth = 4.0;
                                    final dashCount = (constraints.constrainWidth() / (2 * dashWidth)).floor();
                                    return Flex(
                                      direction: Axis.horizontal,
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: List.generate(dashCount, (_) {
                                        return SizedBox(
                                          width: dashWidth,
                                          height: 1,
                                          child: const DecoratedBox(decoration: BoxDecoration(color: AppColors.border)),
                                        );
                                      }),
                                    );
                                  },
                                ),
                              ),
                              
                              // Footer
                              Row(
                                children: [
                                  RichText(
                                    text: TextSpan(
                                      children: [
                                        TextSpan(
                                          text: '₹${product.price.toStringAsFixed(0)}',
                                          style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.w800, fontSize: 16),
                                        ),
                                        TextSpan(
                                          text: ' $unitText',
                                          style: const TextStyle(color: AppColors.muted, fontSize: 10),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Spacer(),
                                  // Cart Icon Button
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF231F32), // Dark inner
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: IconButton(
                                      padding: EdgeInsets.zero,
                                      icon: const Icon(Icons.add_shopping_cart_rounded, color: AppColors.muted, size: 16),
                                      onPressed: () {
                                        context.read<CartService>().addToCart(product);
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('${product.name} added to cart'),
                                            duration: const Duration(seconds: 1),
                                            backgroundColor: AppColors.saffron,
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // Buy Now Button
                                  SizedBox(
                                    height: 32,
                                    child: ElevatedButton(
                                      onPressed: () {
                                        context.read<CartService>().addToCart(product);
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(builder: (_) => const OrderSummaryScreen()),
                                        );
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.gold,
                                        foregroundColor: Colors.black,
                                        padding: const EdgeInsets.symmetric(horizontal: 12),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                      ),
                                      child: Text(
                                        isRitual ? 'Book Now' : 'Buy Now',
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVRExperiences() {
    if (_vrExperiences == null || _vrExperiences!.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            'VR Temple Experiences',
            onViewAll: () => widget.onTabChanged?.call(2, filter: 'vr'),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 450,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _vrExperiences!.length > 5 ? 5 : _vrExperiences!.length,
              separatorBuilder: (_, n) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                return SizedBox(
                  width: 320,
                  child: VrExperienceCard(
                    vr: _vrExperiences![index],
                    onStoreTap: () async {
                      final uri = Uri.tryParse(_vrExperiences![index].storeLink);
                      if (uri != null) {
                        try {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        } catch (e) {
                          logE('Error launching store', e);
                        }
                      }
                    },
                    onTrailerTap: () async {
                      final uri = Uri.tryParse(_vrExperiences![index].trailerLink);
                      if (uri != null) {
                        try {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        } catch (e) {
                          logE('Error launching trailer', e);
                        }
                      }
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategories() {
    if (_categories == null || _categories!.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            'Explore Categories',
            onViewAll: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DivineMarketplaceScreen())),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 110,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _categories!.length,
              separatorBuilder: (_, n) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final cat = _categories![index];
                final name = cat['name'] as String? ?? 'Category';
                final imageUrl = cat['image'] as String?;

                return GestureDetector(
                  onTap: () {
                    final filterKey = cat['filterKey'] as String? ?? 'all';
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => DivineMarketplaceScreen(initialCategory: filterKey),
                      ),
                    );
                  },
                  child: Container(
                    width: 100,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: imageUrl == null ? AppColors.gold.withValues(alpha: 0.1) : Colors.transparent,
                            shape: BoxShape.circle,
                          ),
                          child: ClipOval(
                            child: imageUrl != null && imageUrl.startsWith('http')
                                ? AppNetworkImage(url: imageUrl, fit: BoxFit.cover)
                                : const Icon(Icons.category_outlined, color: AppColors.gold),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.cream,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildSectionHeader(String title, {String? subtitle, VoidCallback? onViewAll}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: subtitle != null ? CrossAxisAlignment.end : CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.star_rounded, color: AppColors.saffron, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    title.toUpperCase(),
                    style: const TextStyle(
                      color: AppColors.cream,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (onViewAll != null)
          GestureDetector(
            onTap: onViewAll,
            child: const Row(
              children: [
                Text(
                  'View All ',
                  style: TextStyle(
                    color: AppColors.gold,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Icon(Icons.arrow_forward, color: AppColors.gold, size: 14),
              ],
            ),
          ),
      ],
    );
  }
}

