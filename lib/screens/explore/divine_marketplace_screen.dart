import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/temple_service.dart';
import '../../services/cart_service.dart';
import '../../models/product.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_network_image.dart';
import 'order_summary_screen.dart';

class DivineMarketplaceScreen extends StatefulWidget {
  final String initialCategory;

  const DivineMarketplaceScreen({super.key, this.initialCategory = 'all'});

  @override
  State<DivineMarketplaceScreen> createState() => _DivineMarketplaceScreenState();
}

class _DivineMarketplaceScreenState extends State<DivineMarketplaceScreen> {
  List<Product>? _allProducts;
  List<Product>? _filteredProducts;
  List<Map<String, dynamic>>? _categories;
  
  late String _selectedCategory;
  bool _isLoading = true;
  String? _errorMessage;
  final _searchController = TextEditingController();
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.initialCategory;
    _loadMarketplaceData();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadMarketplaceData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final templeService = context.read<TempleService>();
      
      // Fetch categories, products, and prasad concurrently
      final categoryList = await templeService.fetchCategories();
      final productsList = await templeService.fetchProducts();
      final prasadList = await templeService.fetchPrasadAsProducts();

      // Filter products (only those with isTempleShop == false)
      final filteredRegularProducts = productsList.where((p) => !p.isTempleShop).toList();

      // Combine both regular products and prasad products
      final combined = [...filteredRegularProducts, ...prasadList];

      if (mounted) {
        setState(() {
          _categories = categoryList;
          _allProducts = combined;
          _isLoading = false;
        });
        _applyFilter();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('ApiException: ', '');
          _isLoading = false;
        });
      }
    }
  }

  void _onSearchChanged() {
    // Debounce so the list isn't re-filtered on every keystroke.
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 280), _applyFilter);
  }

  void _applyFilter() {
    if (_allProducts == null) return;
    
    final query = _searchController.text.toLowerCase().trim();
    
    setState(() {
      var list = List<Product>.from(_allProducts!);

      // Apply category filter
      if (_selectedCategory != 'all') {
        list = list.where((p) => p.category == _selectedCategory).toList();
      }

      // Apply search query filter
      if (query.isNotEmpty) {
        list = list.where((p) => 
          p.name.toLowerCase().contains(query) || 
          p.category.toLowerCase().contains(query)
        ).toList();
      }

      _filteredProducts = list;
    });
  }

  String _formatCategory(String category) {
    switch (category) {
      case 'all':
        return 'All Items';
      case 'pooja_items':
        return 'Pooja Items';
      case 'premium_idols':
        return 'Premium Idols';
      case 'spiritual_books':
        return 'Spiritual Books';
      case 'dharmik_vastra':
        return 'Dharmik Vastra';
      case 'gemstones':
        return 'Gemstones';
      case 'prashad':
        return 'Prasad / Prashad';
      default:
        return category.replaceAll('_', ' ').toUpperCase();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text(
          'Divine Marketplace',
          style: TextStyle(color: AppColors.cream, fontWeight: FontWeight.w800, fontSize: 18),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.cream, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          // Cart icon badge — rebuilds only when the cart quantity changes.
          Selector<CartService, int>(
            selector: (_, c) => c.totalQuantity,
            builder: (context, totalQuantity, _) {
              if (totalQuantity == 0) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(right: 4),
                child: IconButton(
                  icon: Badge(
                    label: Text(
                      totalQuantity.toString(),
                      style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800),
                    ),
                    backgroundColor: AppColors.saffron,
                    child: const Icon(Icons.shopping_bag_rounded, color: AppColors.gold),
                  ),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const OrderSummaryScreen()),
                    );
                  },
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.gold),
            onPressed: _loadMarketplaceData,
          ),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                // Search Input
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Row(
                      children: [
                        const Text('', style: TextStyle(fontSize: 16)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            style: const TextStyle(color: AppColors.cream, fontSize: 14),
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              hintText: 'Search marketplace essentials...',
                              contentPadding: EdgeInsets.symmetric(vertical: 14),
                              hintStyle: TextStyle(color: AppColors.muted, fontSize: 13),
                              isDense: true,
                            ),
                          ),
                        ),
                        if (_searchController.text.isNotEmpty)
                          GestureDetector(
                            onTap: () => _searchController.clear(),
                            child: const Icon(Icons.clear_rounded, color: AppColors.muted, size: 18),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                
                // Category Chips Horizontal view
                if (_categories != null) _buildCategoryChips(),
                const SizedBox(height: 10),

                // Main body grid
                Expanded(
                  child: _buildMainBody(),
                ),
              ],
            ),

            // Floating Cart Bar — isolated so only it rebuilds on cart changes.
            Consumer<CartService>(
              builder: (context, cart, _) {
                if (cart.totalQuantity == 0) return const SizedBox.shrink();
                return Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: _buildFloatingCartBar(cart),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingCartBar(CartService cart) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const OrderSummaryScreen()),
        );
      },
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFE8A930), Color(0xFFF5C842)],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.gold.withValues(alpha: 0.4),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            // Items count badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${cart.totalQuantity} ${cart.totalQuantity == 1 ? 'Item' : 'Items'}',
                style: const TextStyle(
                  color: Color(0xFF1A1205),
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '₹${cart.totalAmount.toStringAsFixed(0)}',
              style: const TextStyle(
                color: Color(0xFF1A1205),
                fontWeight: FontWeight.w900,
                fontSize: 16,
              ),
            ),
            const Spacer(),
            const Text(
              'View Cart',
              style: TextStyle(
                color: Color(0xFF1A1205),
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_forward_rounded, color: Color(0xFF1A1205), size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryChips() {
    final list = [
      {'name': 'All Items', 'filterKey': 'all'},
      ..._categories!
    ];
    
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Row(
        children: [
          for (final cat in list) ...[
            InkWell(
              onTap: () {
                setState(() {
                  _selectedCategory = cat['filterKey'] as String;
                  _applyFilter();
                });
              },
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: _selectedCategory == cat['filterKey'] ? AppColors.gold : AppColors.card,
                  border: Border.all(
                    color: _selectedCategory == cat['filterKey'] ? AppColors.gold : AppColors.border,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  cat['name'] as String,
                  style: TextStyle(
                    color: _selectedCategory == cat['filterKey'] ? AppColors.bg : AppColors.cream,
                    fontSize: 11,
                    fontWeight: _selectedCategory == cat['filterKey'] ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  Widget _buildMainBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.gold),
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.cloud_off_rounded, size: 48, color: AppColors.muted),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.muted, fontSize: 14),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadMarketplaceData,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  foregroundColor: AppColors.bg,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Try Again', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      );
    }

    final list = _filteredProducts ?? [];

    if (list.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.shopping_bag_outlined, size: 48, color: AppColors.muted),
              const SizedBox(height: 16),
              Text(
                _searchController.text.isEmpty
                    ? 'No products available in this category.'
                    : 'No products matching your search.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.muted, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    return GridView.builder(
      padding: EdgeInsets.fromLTRB(20, 20, 20,
          context.select<CartService, bool>((c) => c.totalQuantity > 0) ? 100 : 20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        childAspectRatio: 0.68,
      ),
      itemCount: list.length,
      itemBuilder: (context, index) {
        return _buildProductCard(list[index]);
      },
    );
  }

  Widget _buildProductCard(Product product) {
    final bool isPrasad = product.category.toLowerCase() == 'prashad';
    final tagText = isPrasad ? 'PRASAD' : 'ITEMS';

    return Selector<CartService, int>(
      selector: (_, c) => c.quantityOf(product.id),
      builder: (context, qty, _) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white, // White card as in the image
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          // Image
          Expanded(
            flex: 5,
            child: Stack(
              children: [
                Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                    color: Colors.black12,
                  ),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    child: product.image != null && product.image!.startsWith('http')
                        ? AppNetworkImage(url: product.image, fit: BoxFit.cover)
                        : const Icon(Icons.shopping_bag_outlined, color: AppColors.gold, size: 32),
                  ),
                ),
                // Badge
                Positioned(
                  top: 10,
                  left: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4),
                      ],
                    ),
                    child: Text(
                      tagText,
                      style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Content
          Expanded(
            flex: 6,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.black87,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'Serif',
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  // Subtitle (Temple name placeholder)
                  const Text(
                    'SHIV TEMPLE',
                    style: TextStyle(
                      color: AppColors.saffron,
                      fontSize: 8,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Description
                  const Text(
                    'Authentic spiritual item crafted for your daily rituals and sacred space.',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.black45,
                      fontSize: 9,
                      height: 1.3,
                    ),
                  ),
                  
                  const Spacer(),
                  
                  // Price and Buttons Row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Price Column
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '₹${product.price.toStringAsFixed(0)}',
                              style: const TextStyle(
                                color: AppColors.saffron,
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const Text(
                              'INCL. GST',
                              style: TextStyle(
                                color: Colors.black38,
                                fontSize: 7,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      // Action buttons
                      if (qty == 0) ...[
                        // Buy Now
                        GestureDetector(
                          onTap: () {
                            context.read<CartService>().addToCart(product);
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const OrderSummaryScreen()),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.04),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'Buy Now',
                              style: TextStyle(
                                color: Colors.black87,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        // Add to Cart button (orange square)
                        GestureDetector(
                          onTap: () => context.read<CartService>().addToCart(product),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: AppColors.saffron,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(Icons.add_shopping_cart_rounded, color: Colors.white, size: 14),
                          ),
                        ),
                      ] else ...[
                        _buildQuantityStepper(product, qty),
                      ],
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
    );
  }

  /// Compact circular "+" button for initial add-to-cart
  Widget _buildAddButton(Product product) {
    return Material(
      color: AppColors.gold,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          context.read<CartService>().addToCart(product);
        },
        child: const SizedBox(
          width: 34,
          height: 34,
          child: Icon(Icons.add_rounded, color: Color(0xFF1A1205), size: 20),
        ),
      ),
    );
  }

  /// Pill-shaped [ - | qty | + ] stepper
  Widget _buildQuantityStepper(Product product, int qty) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.saffron,
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: AppColors.saffron.withValues(alpha: 0.3),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _stepperButton(
            icon: Icons.remove_rounded,
            onTap: () => context.read<CartService>().decrementQuantity(product.id),
          ),
          Container(
            constraints: const BoxConstraints(minWidth: 20),
            alignment: Alignment.center,
            child: Text(
              '$qty',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 12,
              ),
            ),
          ),
          _stepperButton(
            icon: Icons.add_rounded,
            onTap: () => context.read<CartService>().incrementQuantity(product.id),
          ),
        ],
      ),
    );
  }

  Widget _stepperButton({required IconData icon, required VoidCallback onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Icon(icon, size: 14, color: Colors.white),
        ),
      ),
    );
  }
}
