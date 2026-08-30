import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../services/auth_service.dart';
import '../../../services/temple_service.dart';
import '../../../theme/app_colors.dart';
import '../../../utils/app_logger.dart';

class StatsRow extends StatefulWidget {
  const StatsRow({super.key});

  @override
  State<StatsRow> createState() => _StatsRowState();
}

class _StatsRowState extends State<StatsRow> {
  int? _bookingsCount;
  int? _ordersCount;
  bool _isLoadingBookings = true;
  bool _isLoadingOrders = true;

  @override
  void initState() {
    super.initState();
    _fetchBookingsCount();
    _fetchOrdersCount();
  }

  Future<void> _fetchBookingsCount() async {
    try {
      final templeService = context.read<TempleService>();
      final bookings = await templeService.fetchBookings();
      if (mounted) {
        setState(() {
          _bookingsCount = bookings.length;
          _isLoadingBookings = false;
        });
      }
    } catch (e) {
      logE('Failed to fetch bookings count', e);
      if (mounted) {
        setState(() {
          _isLoadingBookings = false;
        });
      }
    }
  }

  Future<void> _fetchOrdersCount() async {
    try {
      final templeService = context.read<TempleService>();
      final orders = await templeService.fetchMyOrders();
      if (mounted) {
        setState(() {
          _ordersCount = orders.length;
          _isLoadingOrders = false;
        });
      }
    } catch (e) {
      logE('Failed to fetch orders count', e);
      if (mounted) {
        setState(() {
          _isLoadingOrders = false;
        });
      }
    }
  }

  String _formatBalance(double balance) {
    if (balance >= 1000) {
      return '₹${(balance / 1000).toStringAsFixed(1)}k';
    } else {
      return '₹${balance.toStringAsFixed(0)}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().currentUser;
    final walletValue = user != null ? _formatBalance(user.walletBalance) : '₹0';
    final bookingsValue = _isLoadingBookings ? '...' : (_bookingsCount?.toString() ?? '0');
    final ordersValue = _isLoadingOrders ? '...' : (_ordersCount?.toString() ?? '0');

    final stats = [
      {'value': bookingsValue, 'label': 'Pujas'},
      {'value': ordersValue, 'label': 'Orders'},
      {'value': walletValue, 'label': 'Spent'},
    ];

    return Row(
      children: [
        for (final stat in stats) ...[
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
              decoration: BoxDecoration(
                color: AppColors.card,
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  Text(
                    stat['value']!,
                    style: const TextStyle(
                      color: AppColors.goldLight,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    stat['label']!,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (stat != stats.last) const SizedBox(width: 10),
        ],
      ],
    );
  }
}
