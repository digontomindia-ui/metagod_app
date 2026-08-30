import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/temple_service.dart';
import '../../models/booking.dart';
import '../../theme/app_colors.dart';

class PujaBookingsScreen extends StatefulWidget {
  const PujaBookingsScreen({super.key});

  @override
  State<PujaBookingsScreen> createState() => _PujaBookingsScreenState();
}

class _PujaBookingsScreenState extends State<PujaBookingsScreen> {
  List<Booking>? _bookings;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadBookings();
  }

  Future<void> _loadBookings() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final templeService = context.read<TempleService>();
      final list = await templeService.fetchBookings();
      if (mounted) {
        setState(() {
          _bookings = list..sort((a, b) => b.createdAt.compareTo(a.createdAt));
          _isLoading = false;
        });
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

  Widget _buildStatusBadge(String status) {
    Color bgColor;
    Color textColor;

    switch (status.toLowerCase()) {
      case 'completed':
        bgColor = AppColors.green.withValues(alpha: 0.13);
        textColor = AppColors.green;
        break;
      case 'failed':
        bgColor = AppColors.red.withValues(alpha: 0.13);
        textColor = AppColors.red;
        break;
      case 'pending':
      default:
        bgColor = AppColors.gold.withValues(alpha: 0.13);
        textColor = AppColors.gold;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: textColor.withValues(alpha: 0.3)),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: textColor,
          fontSize: 9,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text(
          'My Puja Bookings',
          style: TextStyle(color: AppColors.cream, fontWeight: FontWeight.w800, fontSize: 18),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.cream, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.gold),
            onPressed: _loadBookings,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
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
              const Icon(Icons.cloud_off_rounded, size: 48, color: AppColors.red),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.muted, fontSize: 14),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadBookings,
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

    final list = _bookings ?? [];

    if (list.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.calendar_today_rounded, size: 54, color: AppColors.muted),
              const SizedBox(height: 18),
              const Text(
                'No Bookings Yet',
                style: TextStyle(color: AppColors.cream, fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 8),
              const Text(
                'You haven\'t scheduled any Pujas yet. Start your spiritual journey today!',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.muted, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  foregroundColor: AppColors.bg,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: const Text('Explore Marketplace', style: TextStyle(fontWeight: FontWeight.w900)),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadBookings,
      color: AppColors.gold,
      backgroundColor: AppColors.card,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        itemCount: list.length,
        itemBuilder: (context, index) {
          final booking = list[index];
          final pujaImg = booking.getPujaImage();
          final formattedBookingDate = booking.date;

          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.card,
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        color: Colors.black26,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: pujaImg.startsWith('http')
                            ? Image.network(pujaImg, fit: BoxFit.cover)
                            : const Icon(Icons.temple_hindu_outlined, color: AppColors.gold, size: 24),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            booking.getPujaName(),
                            style: const TextStyle(
                              color: AppColors.cream,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            booking.getTempleName(),
                            style: const TextStyle(
                              color: AppColors.muted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildStatusBadge(booking.status),
                  ],
                ),
                
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Divider(color: AppColors.border, height: 1),
                ),
                
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Devotee:',
                      style: TextStyle(color: AppColors.muted, fontSize: 12),
                    ),
                    Text(
                      booking.name,
                      style: const TextStyle(color: AppColors.cream, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Gothra / Sankalp:',
                      style: TextStyle(color: AppColors.muted, fontSize: 12),
                    ),
                    Expanded(
                      child: Text(
                        '${booking.gothra} / ${booking.sankalp}',
                        textAlign: TextAlign.right,
                        style: const TextStyle(color: AppColors.cream, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Scheduled Date:',
                      style: TextStyle(color: AppColors.muted, fontSize: 12),
                    ),
                    Row(
                      children: [
                        const Icon(Icons.event_available_rounded, color: AppColors.gold, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          formattedBookingDate,
                          style: const TextStyle(color: AppColors.gold, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),
                
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Divider(color: AppColors.border, height: 1),
                ),
                
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Booked on ${booking.createdAt.day}/${booking.createdAt.month}/${booking.createdAt.year}',
                      style: const TextStyle(color: AppColors.muted, fontSize: 11, fontStyle: FontStyle.italic),
                    ),
                    Text(
                      '₹${booking.getPujaPrice().toStringAsFixed(0)}',
                      style: const TextStyle(
                        color: AppColors.goldLight,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
