import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../theme/app_colors.dart';
import '../consultation_chat_screen.dart';
import '../../../services/temple_service.dart';
import '../../../widgets/universal_payment_modal.dart';
import '../../../config/env.dart';
import 'package:cached_network_image/cached_network_image.dart';

class PanditCard extends StatefulWidget {
  final Map<String, dynamic> expert;

  const PanditCard({
    super.key,
    required this.expert,
  });

  @override
  State<PanditCard> createState() => _PanditCardState();
}

class _PanditCardState extends State<PanditCard> {
  String _selectedMode = 'chat'; // 'chat', 'audio', 'video'
  bool _isLoading = false;
  Map<String, dynamic>? _balance;
  bool _isBalanceLoading = true;
  bool _isSaved = false;

  @override
  void initState() {
    super.initState();
    _checkIfSaved();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchBalance();
    });
  }

  Future<void> _checkIfSaved() async {
    final prefs = await SharedPreferences.getInstance();
    final savedList = prefs.getStringList('saved_pandits') ?? [];
    final id = widget.expert['_id'] ?? widget.expert['id'] ?? '';
    if (mounted) {
      setState(() {
        _isSaved = savedList.contains(id);
      });
    }
  }

  Future<void> _toggleSave() async {
    final prefs = await SharedPreferences.getInstance();
    final savedList = prefs.getStringList('saved_pandits') ?? [];
    final id = widget.expert['_id'] ?? widget.expert['id'] ?? '';
    
    if (id.isEmpty) return;

    if (savedList.contains(id)) {
      savedList.remove(id);
    } else {
      savedList.add(id);
    }
    
    await prefs.setStringList('saved_pandits', savedList);
    
    // Also save the expert JSON string so we can display them later without API
    final savedDataList = prefs.getStringList('saved_pandits_data') ?? [];
    savedDataList.removeWhere((item) {
      try {
        final map = jsonDecode(item);
        return (map['_id'] ?? map['id']) == id;
      } catch (e) {
        return false;
      }
    });
    
    if (savedList.contains(id)) {
      savedDataList.add(jsonEncode(widget.expert));
    }
    await prefs.setStringList('saved_pandits_data', savedDataList);

    if (mounted) {
      setState(() {
        _isSaved = savedList.contains(id);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isSaved ? 'Expert saved to your list!' : 'Expert removed from saved list.'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _fetchBalance() async {
    try {
      final templeService = context.read<TempleService>();
      final balance = await templeService.getConsultationBalance(widget.expert['_id'] ?? '');
      if (mounted) {
        setState(() {
          _isBalanceLoading = false;
          _balance = balance;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isBalanceLoading = false);
    }
  }

  int _getSecondsForMode(String mode) {
    if (_balance == null) return 0;
    if (mode == 'chat') {
      return (_balance!['chatSeconds'] as num? ?? 0).toInt() + (_balance!['remainingSeconds'] as num? ?? 0).toInt();
    } else if (mode == 'audio' || mode == 'call') {
      return (_balance!['audioSeconds'] as num? ?? 0).toInt();
    } else if (mode == 'video') {
      return (_balance!['videoSeconds'] as num? ?? 0).toInt();
    }
    return 0;
  }

  void _bookConsultation() async {
    final int existingSeconds = _getSecondsForMode(_selectedMode);
    if (existingSeconds > 0) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ConsultationChatScreen(
          expertId: widget.expert['_id'] ?? widget.expert['id'] ?? '',
          panditName: widget.expert['name'] ?? 'Expert', 
          panditEmoji: widget.expert['emoji'] ?? '🙏', 
          isSessionActive: true,
        )),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final templeService = context.read<TempleService>();
      final priceMap = widget.expert['pricing'] ?? {};
      final num basePrice = priceMap[_selectedMode] ?? 0;
      final num defaultPrice = _selectedMode == 'chat' ? 100 : (_selectedMode == 'audio' ? 200 : 300);
      final double price = (basePrice == 0 ? defaultPrice : basePrice).toDouble();

      // Launch Universal Payment Modal
      final String? paymentMethod = await UniversalPaymentModal.show(
        context: context,
        amount: price,
        itemName: '10 Min ${_selectedMode.toUpperCase()} with ${widget.expert['name'] ?? 'Expert'}',
        purposePrefix: 'CONSULTATION',
        createRazorpayOrder: () async {
          final order = await templeService.createProductOrder(
            amount: price.toInt(),
            receipt: 'consult_${DateTime.now().millisecondsSinceEpoch}',
          );
          return order['orderId'] as String? ?? '';
        },
        verifyRazorpayPayment: (paymentResult) async {
          return await templeService.verifyProductPayment(
            razorpayOrderId: paymentResult.orderId,
            razorpayPaymentId: paymentResult.paymentId,
            razorpaySignature: paymentResult.signature,
          );
        },
      );

      if (paymentMethod == null) {
        // User cancelled the payment modal
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final success = await templeService.bookConsultation(
        expertId: widget.expert['_id'] ?? '',
        expertName: widget.expert['name'] ?? 'Expert',
        type: _selectedMode,
        duration: 10,
        price: price,
        customerName: 'User', // Would come from auth service
      );

      if (!mounted) return;

      if (success) {
        // Refresh balance after successful purchase
        await _fetchBalance();
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sacred consultation booked successfully!')),
        );
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ConsultationChatScreen(
            expertId: widget.expert['_id'] ?? widget.expert['id'] ?? '',
            panditName: widget.expert['name'] ?? 'Expert', 
            panditEmoji: widget.expert['emoji'] ?? '🙏', 
            isSessionActive: true,
          )),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showProfileSheet() {
    final expert = widget.expert;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          color: Color(0xFF131016),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Drag handle
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 20),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: AppColors.card2,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.gold, width: 2),
                            image: (expert['image'] as String?)?.isNotEmpty == true
                                ? DecorationImage(
                                    image: CachedNetworkImageProvider(Env.mediaUrl(expert['image'] as String? ?? '')),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                          ),
                          alignment: Alignment.center,
                          child: !((expert['image'] as String?)?.isNotEmpty == true)
                              ? Text(expert['emoji'] ?? '🙏', style: const TextStyle(fontSize: 36))
                              : null,
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                expert['name'] ?? 'Expert',
                                style: const TextStyle(color: AppColors.cream, fontSize: 24, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                expert['category']?.toString().toUpperCase() ?? 'ASTROLOGER',
                                style: const TextStyle(color: AppColors.saffron, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 1),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Icon(Icons.star_rounded, color: AppColors.gold, size: 16),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${expert['rating'] ?? 4.5} (${expert['reviews'] ?? 0} reviews)',
                                    style: const TextStyle(color: AppColors.muted, fontSize: 13),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    
                    // Stats Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildStatBox(Icons.work_history_rounded, 'Experience', expert['experience'] ?? '10+ Yrs'),
                        _buildStatBox(Icons.language_rounded, 'Languages', (expert['languages'] as List<dynamic>?)?.join(', ') ?? 'Hindi, English'),
                      ],
                    ),
                    const SizedBox(height: 32),

                    // About
                    const Text('About', style: TextStyle(color: AppColors.cream, fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Text(
                      expert['about'] ?? 'An experienced and highly rated expert providing spiritual, astrological, and ritual consultation services. Connect to seek guidance and remedies for a harmonious life.',
                      style: const TextStyle(color: AppColors.muted, fontSize: 14, height: 1.5),
                    ),
                    const SizedBox(height: 32),

                    // Skills
                    if (expert['skills'] != null && (expert['skills'] as List).isNotEmpty) ...[
                      const Text('Expertise', style: TextStyle(color: AppColors.cream, fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: (expert['skills'] as List).map((skill) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                          ),
                          child: Text(skill.toString(), style: const TextStyle(color: AppColors.cream, fontSize: 12)),
                        )).toList(),
                      ),
                      const SizedBox(height: 32),
                    ],

                    // Weekly Schedule
                    const Text('Weekly Schedule', style: TextStyle(color: AppColors.cream, fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.03),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                      ),
                      child: Column(
                        children: [
                          _buildScheduleRow('Monday', expert['schedule']?['monday'] ?? '09:00 AM - 06:00 PM'),
                          _buildScheduleRow('Tuesday', expert['schedule']?['tuesday'] ?? '09:00 AM - 06:00 PM'),
                          _buildScheduleRow('Wednesday', expert['schedule']?['wednesday'] ?? '09:00 AM - 06:00 PM'),
                          _buildScheduleRow('Thursday', expert['schedule']?['thursday'] ?? '09:00 AM - 06:00 PM'),
                          _buildScheduleRow('Friday', expert['schedule']?['friday'] ?? '09:00 AM - 06:00 PM'),
                          _buildScheduleRow('Saturday', expert['schedule']?['saturday'] ?? '10:00 AM - 04:00 PM'),
                          _buildScheduleRow('Sunday', expert['schedule']?['sunday'] ?? 'Closed', isLast: true),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScheduleRow(String day, String time, {bool isLast = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(day, style: const TextStyle(color: AppColors.muted, fontSize: 14)),
          Text(time, style: TextStyle(color: time.toLowerCase() == 'closed' ? AppColors.red : AppColors.cream, fontSize: 14, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildStatBox(IconData icon, String title, String value) {
    return Container(
      width: 140,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.gold, size: 24),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(color: AppColors.muted, fontSize: 11)),
          const SizedBox(height: 4),
          Text(value, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.cream, fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final expert = widget.expert;
    final bool isOnline = expert['status']?.toString().toLowerCase() == 'online';
    final String name = expert['name'] ?? 'TestAstro';
    final String category = expert['category']?.toString().toUpperCase() ?? 'ASTROLOGER';
    final String experience = expert['experience'] ?? '10+ YEARS';
    final double rating = (expert['rating'] ?? 4.5).toDouble();
    final int reviews = expert['reviews'] ?? 0;
    final String location = expert['location'] ?? 'Ganga Ghat, Haridwar, uttarakhand';
    Map<String, dynamic> pricing = expert['pricing'] ?? {};
    
    // Fallbacks if price is missing or 0
    final num chatPrice = (pricing['chat'] == null || pricing['chat'] == 0) ? 100 : pricing['chat'];
    final num audioPrice = (pricing['audio'] == null || pricing['audio'] == 0) ? 200 : pricing['audio'];
    final num videoPrice = (pricing['video'] == null || pricing['video'] == 0) ? 300 : pricing['video'];
    
    final Map<String, num> safePricing = {
      'chat': chatPrice,
      'audio': audioPrice,
      'video': videoPrice,
    };
    
    final int currentSeconds = _getSecondsForMode(_selectedMode);

    return Container(
      width: 320,
      margin: const EdgeInsets.only(right: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1A16),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top section
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Avatar
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: AppColors.card2,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border),
                            image: (expert['image'] as String?)?.isNotEmpty == true
                                ? DecorationImage(
                                    image: CachedNetworkImageProvider(Env.mediaUrl(expert['image'] as String? ?? '')),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                          ),
                          alignment: Alignment.center,
                          child: !((expert['image'] as String?)?.isNotEmpty == true)
                              ? Text(
                                  expert['emoji'] ?? '🙏',
                                  style: const TextStyle(fontSize: 28),
                                )
                              : null,
                        ),
                        if (isOnline)
                          Positioned(
                            right: -4,
                            bottom: -4,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFF1E1A16), width: 2),
                              ),
                              child: const Text(
                                'ONLINE',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 14),
                    // Details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.cream,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.star_rounded, color: Color(0xFFFFB800), size: 14),
                              const SizedBox(width: 4),
                              Text(
                                rating.toStringAsFixed(1),
                                style: const TextStyle(color: AppColors.cream, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '($reviews)',
                                style: const TextStyle(color: AppColors.muted, fontSize: 11),
                              ),
                              const SizedBox(width: 8),
                              Container(width: 4, height: 4, decoration: const BoxDecoration(color: AppColors.muted, shape: BoxShape.circle)),
                              const SizedBox(width: 8),
                              Text(
                                experience,
                                style: const TextStyle(color: AppColors.muted, fontSize: 11),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // Tags
                          Wrap(
                            spacing: 6.0,
                            runSpacing: 4.0,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFCA311).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  category,
                                  style: const TextStyle(color: Color(0xFFFCA311), fontSize: 9, fontWeight: FontWeight.bold),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.location_on_rounded, color: AppColors.muted, size: 10),
                                    const SizedBox(width: 4),
                                    Text(
                                      location,
                                      style: const TextStyle(color: AppColors.muted, fontSize: 9, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              // Divider
              Container(height: 1, color: Colors.white.withValues(alpha: 0.05)),

              // Consultation Modes
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Expanded(child: _buildModeSelector('chat', Icons.chat_bubble_rounded, 'Chat')),
                    const SizedBox(width: 8),
                    Expanded(child: _buildModeSelector('audio', Icons.phone_rounded, 'Call')),
                    const SizedBox(width: 8),
                    Expanded(child: _buildModeSelector('video', Icons.videocam_rounded, 'Video')),
                  ],
                ),
              ),

              // Bottom Action Area
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                decoration: const BoxDecoration(
                  color: Color(0xFF131016),
                  border: Border(top: BorderSide(color: Colors.white12)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading || _isBalanceLoading ? null : _bookConsultation,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.gold,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        child: _isLoading || _isBalanceLoading
                          ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                          : currentSeconds > 0 
                              ? Text(
                                  'OPEN SESSION (${currentSeconds ~/ 60}m left)',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 1.0),
                                )
                              : Text(
                                  'BUY 10 MIN ${_selectedMode.toUpperCase()} (₹${safePricing[_selectedMode]})',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                                ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _showProfileSheet,
                          icon: const Icon(Icons.person_rounded, size: 14),
                          label: const Text('View Profile', style: TextStyle(fontSize: 11)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.cream,
                            side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          ),
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => ConsultationChatScreen(
                                expertId: expert['_id'] ?? expert['id'] ?? '',
                                panditName: name, 
                                panditEmoji: expert['emoji'] ?? '🙏',
                                isSessionActive: currentSeconds > 0,
                              )),
                            );
                          },
                          icon: const Icon(Icons.chat_bubble_outline, size: 14),
                          label: const Text('Open Chat', style: TextStyle(fontSize: 11)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.cream,
                            side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          // Absolute Top-Right Save Icon for the entire card
          Positioned(
            top: 10,
            right: 10,
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(20),
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: _toggleSave,
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Icon(
                    _isSaved ? Icons.favorite : Icons.favorite_border,
                    color: _isSaved ? AppColors.red : Colors.white70,
                    size: 20,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeSelector(String modeId, IconData icon, String label) {
    final bool isSelected = _selectedMode == modeId;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedMode = modeId;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFCA311).withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? const Color(0xFFFCA311) : Colors.white.withValues(alpha: 0.1),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? const Color(0xFFFCA311) : AppColors.muted,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? const Color(0xFFFCA311) : AppColors.muted,
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
