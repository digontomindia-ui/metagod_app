import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/temple.dart';
import '../../../models/product.dart';
import '../../../models/puja.dart';
import '../../../services/temple_service.dart';
import '../../../theme/app_colors.dart';
import '../../explore/widgets/temple_details_screen.dart';
import '../../explore/widgets/booking_sheet.dart';
import '../../explore/divine_marketplace_screen.dart';
import '../../../utils/app_logger.dart';

class HomeSearchBar extends StatefulWidget {
  final void Function(int index, {String? filter})? onTabChanged;
  const HomeSearchBar({super.key, this.onTabChanged});

  @override
  State<HomeSearchBar> createState() => _HomeSearchBarState();
}

class _HomeSearchBarState extends State<HomeSearchBar> {
  final FocusNode _focusNode = FocusNode();
  final TextEditingController _controller = TextEditingController();
  bool _isFocused = false;

  List<Temple> _temples = [];
  List<Product> _products = [];
  List<Puja> _pujas = [];
  bool _isLoadingData = false;

  List<Temple> _searchedTemples = [];
  List<Product> _searchedProducts = [];
  List<Puja> _searchedPujas = [];

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (!mounted) return;
      setState(() {
        _isFocused = _focusNode.hasFocus;
      });
      if (_focusNode.hasFocus) {
        _loadSearchData();
      }
    });
    _controller.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadSearchData() async {
    if (_temples.isNotEmpty) return;
    setState(() {
      _isLoadingData = true;
    });
    try {
      final service = context.read<TempleService>();
      final tList = await service.fetchTemples();
      final pList = await service.fetchProducts();
      final prasadList = await service.fetchPrasadAsProducts();
      final pujaList = await service.fetchPujas();

      if (mounted) {
        setState(() {
          _temples = tList;
          _products = [...pList.where((p) => !p.isTempleShop), ...prasadList];
          _pujas = pujaList;
          _isLoadingData = false;
        });
      }
    } catch (e) {
      logE('Failed to load search data', e);
      if (mounted) {
        setState(() {
          _isLoadingData = false;
        });
      }
    }
  }

  void _onSearchChanged() {
    final query = _controller.text.toLowerCase().trim();
    if (query.isEmpty) {
      setState(() {
        _searchedTemples = [];
        _searchedProducts = [];
        _searchedPujas = [];
      });
      return;
    }

    setState(() {
      _searchedTemples = _temples
          .where((t) => t.name.toLowerCase().contains(query) || t.location.toLowerCase().contains(query))
          .toList();
      _searchedProducts = _products
          .where((p) => p.name.toLowerCase().contains(query) || p.category.toLowerCase().contains(query))
          .toList();
      _searchedPujas = _pujas
          .where((puja) => puja.name.toLowerCase().contains(query) || puja.benefits.toLowerCase().contains(query))
          .toList();
    });
  }

  void _handleCategoryTap(String category) {
    _focusNode.unfocus();
    if (category == 'Temples') {
      widget.onTabChanged?.call(2); // Darshan tab displays temples list
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const DivineMarketplaceScreen(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasResults = _searchedTemples.isNotEmpty || _searchedProducts.isNotEmpty || _searchedPujas.isNotEmpty;
    final isQueryNotEmpty = _controller.text.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search Pill
          Container(
            height: 56, // Increased height for premium feel
            decoration: BoxDecoration(
              color: AppColors.card.withValues(alpha: 0.6), // Glassmorphic translucency
              border: Border.all(
                color: _isFocused ? AppColors.gold : Colors.white.withValues(alpha: 0.1),
                width: _isFocused ? 1.5 : 1.0,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: _isFocused 
                      ? AppColors.gold.withValues(alpha: 0.25) 
                      : Colors.black.withValues(alpha: 0.2),
                  blurRadius: _isFocused ? 20 : 10,
                  spreadRadius: _isFocused ? 2 : 0,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            alignment: Alignment.center,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(
                  Icons.search_rounded, 
                  size: 22, 
                  color: _isFocused ? AppColors.gold : AppColors.muted,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    style: const TextStyle(
                      color: AppColors.cream, 
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: 'Search Mandirs, Pujas or Prasad...',
                      hintStyle: TextStyle(color: AppColors.muted, fontSize: 14),
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                if (isQueryNotEmpty)
                  GestureDetector(
                    onTap: () {
                      _controller.clear();
                    },
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close_rounded, color: AppColors.cream, size: 14),
                    ),
                  ),
              ],
            ),
          ),

          // Horizontal Category Chip Tray (Reveals dynamically on focus)
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            child: Container(
              height: _isFocused ? 62.0 : 0.0,
              padding: EdgeInsets.only(top: _isFocused ? 14.0 : 0.0),
              child: _isFocused
                  ? SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildCategoryChip(Icons.temple_hindu_outlined, 'Temples', 'Temples'),
                          const SizedBox(width: 8),
                          _buildCategoryChip(Icons.local_fire_department_outlined, 'Puja Items', 'Pooja Items'),
                          const SizedBox(width: 8),
                          _buildCategoryChip(Icons.fastfood_outlined, 'Prasads', 'Prasad'),
                          const SizedBox(width: 8),
                          _buildCategoryChip(Icons.checkroom_outlined, 'Attire', 'Dharmik Vastra'),
                        ],
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ),

          // Dynamic Unified Search Results Container
          if (_isFocused && isQueryNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: AppColors.card,
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(16),
              ),
              constraints: const BoxConstraints(maxHeight: 300),
              child: _isLoadingData
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(20.0),
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(AppColors.gold),
                        ),
                      ),
                    )
                  : !hasResults
                      ? const Padding(
                          padding: EdgeInsets.all(20.0),
                          child: Center(
                            child: Text(
                              'No matching Mandirs, Pujas or Prasad found.',
                              style: TextStyle(color: AppColors.muted, fontSize: 12),
                            ),
                          ),
                        )
                      : Scrollbar(
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (_searchedTemples.isNotEmpty) ...[
                                  _buildSectionHeader('MANDIRS (TEMPLES)'),
                                  for (final t in _searchedTemples)
                                    _buildSearchResultRow(
                                      icon: Icons.temple_hindu_outlined,
                                      title: t.name,
                                      subtitle: t.location,
                                      onTap: () {
                                        _focusNode.unfocus();
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => TempleDetailsScreen(templeId: t.id),
                                          ),
                                        );
                                      },
                                    ),
                                ],
                                if (_searchedPujas.isNotEmpty) ...[
                                  _buildSectionHeader('PUJAS & RITUALS'),
                                  for (final p in _searchedPujas)
                                    _buildSearchResultRow(
                                      icon: Icons.local_fire_department_outlined,
                                      title: p.name,
                                      subtitle: '₹${p.price.toStringAsFixed(0)} · Benefits: ${p.benefits}',
                                      onTap: () {
                                        _focusNode.unfocus();
                                        showModalBottomSheet(
                                          context: context,
                                          isScrollControlled: true,
                                          backgroundColor: Colors.transparent,
                                          builder: (context) => BookingSheet(puja: p),
                                        );
                                      },
                                    ),
                                ],
                                if (_searchedProducts.isNotEmpty) ...[
                                  _buildSectionHeader('ESSENTIALS & PRASAD'),
                                  for (final prod in _searchedProducts)
                                    _buildSearchResultRow(
                                      icon: prod.category == 'prashad' ? Icons.fastfood_outlined : Icons.shopping_bag_outlined,
                                      title: prod.name,
                                      subtitle: '₹${prod.price.toStringAsFixed(0)}',
                                      onTap: () {
                                        _focusNode.unfocus();
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => const DivineMarketplaceScreen(),
                                          ),
                                        );
                                      },
                                    ),
                                ],
                              ],
                            ),
                          ),
                        ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCategoryChip(IconData icon, String label, String value) {
    return InkWell(
      onTap: () => _handleCategoryTap(value),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.card2,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: AppColors.gold),
            const SizedBox(width: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.cream,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
      child: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: AppColors.gold,
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildSearchResultRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      dense: true,
      leading: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: AppColors.card2,
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: Icon(icon, size: 18, color: AppColors.gold),
      ),
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: AppColors.cream, fontSize: 13, fontWeight: FontWeight.bold),
      ),
      subtitle: Text(
        subtitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: AppColors.muted, fontSize: 11),
      ),
      onTap: onTap,
    );
  }
}
