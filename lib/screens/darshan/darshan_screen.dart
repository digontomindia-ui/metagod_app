import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/temple_service.dart';
import '../../models/temple.dart';
import '../../models/vr_experience.dart';
import '../../theme/app_colors.dart';
import 'package:url_launcher/url_launcher.dart';
import 'widgets/temple_card.dart';
import 'widgets/vr_experience_card.dart';
import '../explore/widgets/temple_details_screen.dart';
import '../../utils/app_logger.dart';

class DarshanScreen extends StatefulWidget {
  final String initialFilter;
  const DarshanScreen({super.key, this.initialFilter = 'all'});

  @override
  State<DarshanScreen> createState() => _DarshanScreenState();
}

class _DarshanScreenState extends State<DarshanScreen> {
  List<Temple>? _temples;
  List<VrExperience>? _vrExperiences;
  bool _isLoading = false;
  String? _errorMessage;
  late String _activeFilter;

  @override
  void initState() {
    super.initState();
    _activeFilter = widget.initialFilter;
    _loadTemples();
  }

  Future<void> _loadTemples() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final templeService = context.read<TempleService>();
      final templeList = await templeService.fetchTemples();
      final vrList = await templeService.fetchVrExperiences();
      if (mounted) {
        setState(() {
          _temples = templeList;
          _vrExperiences = vrList;
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

  List<Temple> _getFilteredAndSortedTemples() {
    if (_temples == null) return [];
    
    // Start with a copy of the list
    var list = List<Temple>.from(_temples!);
    
    // Sort: Live temples at the top
    list.sort((a, b) {
      if (a.isLive && !b.isLive) return -1;
      if (!a.isLive && b.isLive) return 1;
      return 0;
    });
    
    // Apply filters
    if (_activeFilter == 'live') {
      return list.where((t) => t.isLive).toList();
    }
    
    return list;
  }

  Widget _buildFilterChip(String value, String label) {
    final isSelected = _activeFilter == value;
    return InkWell(
      onTap: () {
        setState(() {
          _activeFilter = value;
        });
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.gold : AppColors.card,
          border: Border.all(
            color: isSelected ? AppColors.gold : AppColors.border,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? AppColors.bg : AppColors.cream,
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 48, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Live Darshan',
                    style: TextStyle(
                      color: AppColors.cream,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Watch sacred rituals in real time',
                    style: TextStyle(
                      color: AppColors.muted,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded, color: AppColors.gold),
                onPressed: _loadTemples,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Horizontal Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('all', 'All Temples'),
                const SizedBox(width: 8),
                _buildFilterChip('live', 'Live Streams'),
                const SizedBox(width: 8),
                _buildFilterChip('vr', ' VR Experience'),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Dynamic Body (Temples list)
          Expanded(
            child: _buildBody(),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading && (_temples == null || _temples!.isEmpty)) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.gold),
        ),
      );
    }

    if (_errorMessage != null && (_temples == null || _temples!.isEmpty)) {
      return Center(
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
              onPressed: _loadTemples,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.gold,
                foregroundColor: AppColors.bg,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Try Again', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    }

    // VR Filter Custom View
    if (_activeFilter == 'vr') {
      final list = _vrExperiences;
      if (list == null || list.isEmpty) {
        return RefreshIndicator(
          onRefresh: _loadTemples,
          color: AppColors.gold,
          backgroundColor: AppColors.card,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: const [
              SizedBox(height: 100),
              Icon(Icons.vrpano_rounded, size: 48, color: AppColors.muted),
              SizedBox(height: 16),
              Text(
                'No VR experiences available.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.muted, fontSize: 14),
              ),
            ],
          ),
        );
      }

      return RefreshIndicator(
        onRefresh: _loadTemples,
        color: AppColors.gold,
        backgroundColor: AppColors.card,
        child: ListView.builder(
          padding: const EdgeInsets.only(bottom: 120),
          itemCount: list.length,
          itemBuilder: (context, index) {
            final vr = list[index];
            return VrExperienceCard(
              vr: vr,
              onStoreTap: () async {
                final uri = Uri.tryParse(vr.storeLink);
                if (uri != null) {
                  try {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  } catch (e) {
                    logE('Error launching store', e);
                  }
                }
              },
              onTrailerTap: () async {
                final uri = Uri.tryParse(vr.trailerLink);
                if (uri != null) {
                  try {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  } catch (e) {
                    logE('Error launching trailer', e);
                  }
                }
              },
            );
          },
        ),
      );
    }

    // Normal temples list
    final displayTemples = _getFilteredAndSortedTemples();

    if (displayTemples.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadTemples,
        color: AppColors.gold,
        backgroundColor: AppColors.card,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 100),
            const Icon(Icons.temple_hindu_outlined, size: 48, color: AppColors.muted),
            const SizedBox(height: 16),
            Text(
              _activeFilter == 'live'
                  ? 'No temples are currently live.'
                  : 'No temples found.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.muted, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadTemples,
      color: AppColors.gold,
      backgroundColor: AppColors.card,
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 120),
        itemCount: displayTemples.length,
        itemBuilder: (context, index) {
          final t = displayTemples[index];
          return TempleCard(
            temple: t,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => TempleDetailsScreen(templeId: t.id),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
