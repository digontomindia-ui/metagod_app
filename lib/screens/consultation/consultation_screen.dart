import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/temple_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/app_logger.dart';
import 'widgets/pandit_card.dart';

class ConsultationScreen extends StatefulWidget {
  const ConsultationScreen({super.key});

  @override
  State<ConsultationScreen> createState() => _ConsultationScreenState();
}

class _ConsultationScreenState extends State<ConsultationScreen> {
  List<Map<String, dynamic>>? _experts;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchExperts();
  }

  Future<void> _fetchExperts() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final templeService = context.read<TempleService>();
      final data = await templeService.fetchExperts();
      if (mounted) {
        setState(() {
          _experts = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      logE('Failed to fetch experts', e);
      if (mounted) {
        setState(() {
          _isLoading = false;
          _experts = [];
        });
      }
    }
  }

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

  @override
  Widget build(BuildContext context) {
    final list = (_experts == null || _experts!.isEmpty) ? _fallbackPandits : _experts!;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Spiritual Consultation',
                style: TextStyle(
                  color: AppColors.cream,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Connect with verified Vedic pandits and astrologers',
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(AppColors.gold),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 120),
                        itemCount: list.length,
                        itemBuilder: (context, index) {
                          final item = list[index];
                          
                          final name = (item['name'] as String?) ?? 'Expert';
                          final spec = (item['title'] as String?) ?? (item['spec'] as String?) ?? item['category']?.toString() ?? 'Astrology';
                          final rating = (item['rating'] as num?)?.toDouble() ?? 0.0;
                          final reviews = (item['reviews'] as num?)?.toInt() ?? 0;
                          final loc = (item['location'] as String?) ?? (item['loc'] as String?) ?? '';
                          final avail = item['avail'] as bool? ?? (item['status'] == 'online');

                          final expertMap = {
                            '_id': item['_id'] ?? 'fallback',
                            'name': name,
                            'category': spec,
                            'experience': item['experience'] ?? '10+ YEARS',
                            'rating': rating,
                            'reviews': reviews,
                            'location': loc,
                            'status': avail ? 'online' : 'offline',
                            'pricing': item['pricing'] ?? {'chat': 100, 'audio': 200, 'video': 300},
                            'image': item['image'],
                          };

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: PanditCard(
                              expert: expertMap,
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
