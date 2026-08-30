import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../theme/app_colors.dart';
import '../../../services/auth_service.dart';
import '../bookings_screen.dart';
import '../my_orders_screen.dart';
import '../wallet_screen.dart';
import '../page_detail_screen.dart';
import '../saved_pandits_screen.dart';
import '../addresses_screen.dart';
import '../../../utils/app_logger.dart';

class MenuList extends StatefulWidget {
  const MenuList({super.key});

  @override
  State<MenuList> createState() => _MenuListState();
}

class _MenuListState extends State<MenuList> {
  List<Map<String, dynamic>> _dynamicPages = [];
  bool _isLoadingPages = true;

  static const List<Map<String, dynamic>> _staticItems = [
    {'icon': Icons.account_balance_wallet_outlined, 'label': 'My Wallet'},
    {'icon': Icons.calendar_today_outlined, 'label': 'My Bookings'},
    {'icon': Icons.shopping_bag_outlined, 'label': 'My Orders'},
    {'icon': Icons.location_on_outlined, 'label': 'Saved Addresses'},
    {'icon': Icons.star_border, 'label': 'Saved Pandits'},
  ];

  @override
  void initState() {
    super.initState();
    _fetchDynamicPages();
  }

  Future<void> _fetchDynamicPages() async {
    try {
      final apiClient = context.read<AuthService>().apiClient;
      // The pages controller returns { success: true, data: [{ slug, title, isVisibleInFooter }, ...] }
      // We will fetch all pages and then fetch content when clicked, or fetch content now?
      // Since we just need title, we can use the list, and then fetch content on tap.
      final response = await apiClient.get('/pages');
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body['success'] == true) {
          final pagesList = List<Map<String, dynamic>>.from(body['data']);
          if (mounted) {
            setState(() {
              _dynamicPages = pagesList;
              _isLoadingPages = false;
            });
          }
          return;
        }
      }
    } catch (e) {
      logE('Failed to fetch dynamic pages', e);
    }
    if (mounted) {
      setState(() {
        _isLoadingPages = false;
      });
    }
  }

  Future<void> _openDynamicPage(String slug, String title) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator(color: AppColors.gold)),
      );

      final apiClient = context.read<AuthService>().apiClient;
      final response = await apiClient.get('/pages/$slug');
      
      if (mounted) Navigator.pop(context); // close loading

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body['success'] == true && body['data'] != null) {
          final content = body['data']['content'] ?? 'No content available.';
          if (mounted) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => PageDetailScreen(title: title, content: content),
              ),
            );
          }
          return;
        }
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load page content')),
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context); // close loading
      logE('Failed to open dynamic page', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Combine static items and dynamic pages
    final List<Map<String, dynamic>> combinedItems = [
      ..._staticItems,
      ..._dynamicPages.map((page) => {
        'icon': Icons.description_outlined,
        'label': page['title'],
        'slug': page['slug'],
        'isDynamic': true,
      }),
    ];

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          children: [
            for (int i = 0; i < combinedItems.length; i++) ...[
              InkWell(
                onTap: () {
                  final item = combinedItems[i];
                  if (item['isDynamic'] == true) {
                    _openDynamicPage(item['slug'] as String, item['label'] as String);
                  } else {
                    final label = item['label'] as String;
                    if (label == 'My Wallet') {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const WalletScreen(),
                        ),
                      );
                    } else if (label == 'My Bookings') {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const PujaBookingsScreen(),
                        ),
                      );
                    } else if (label == 'My Orders') {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const MyOrdersScreen(),
                        ),
                      );
                    } else if (label == 'Saved Addresses') {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const AddressesScreen(),
                        ),
                      );
                    } else if (label == 'Saved Pandits') {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const SavedPanditsScreen(),
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('$label clicked'),
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    }
                  }
                },
                borderRadius: BorderRadius.vertical(
                  top: i == 0 ? const Radius.circular(18) : Radius.zero,
                  bottom: i == combinedItems.length - 1 ? const Radius.circular(18) : Radius.zero,
                ),
                child: _buildMenuItem(combinedItems[i], i < combinedItems.length - 1),
              ),
            ],
            if (_isLoadingPages)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(color: AppColors.gold, strokeWidth: 2),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem(Map<String, dynamic> item, bool showBorder) {
    final label = item['label'];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        border: showBorder ? const Border(bottom: BorderSide(color: AppColors.border)) : null,
      ),
      child: Row(
        children: [
          Icon(item['icon'] as IconData, size: 20, color: AppColors.gold),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label as String,
              style: const TextStyle(
                color: AppColors.cream,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const Text(
            '›',
            style: TextStyle(
              color: AppColors.muted,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}
