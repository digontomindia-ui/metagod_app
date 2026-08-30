import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/temple_service.dart';
import '../../models/puja.dart';
import '../../theme/app_colors.dart';
import 'widgets/puja_card.dart';
import 'widgets/booking_sheet.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  List<Puja>? _pujas;
  List<Puja>? _filteredPujas;
  bool _isLoading = true;
  String? _errorMessage;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadPujas();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPujas() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final templeService = context.read<TempleService>();
      final list = await templeService.fetchPujas();
      if (mounted) {
        setState(() {
          _pujas = list;
          _filteredPujas = list;
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

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase().trim();
    if (_pujas == null) return;
    setState(() {
      if (query.isEmpty) {
        _filteredPujas = _pujas;
      } else {
        _filteredPujas = _pujas!
            .where((p) =>
                p.name.toLowerCase().contains(query) ||
                (p.templeId?.name.toLowerCase().contains(query) ?? false) ||
                p.benefits.toLowerCase().contains(query))
            .toList();
      }
    });
  }

  void _showBookingSheet(Puja puja) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => BookingSheet(puja: puja),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 40, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Divine Marketplace',
                style: TextStyle(
                  color: AppColors.cream,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded, color: AppColors.gold),
                onPressed: _loadPujas,
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Search input field
          Container(
            decoration: BoxDecoration(
              color: AppColors.card,
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(14),
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
                      hintText: 'Search marketplace, pujas, temples...',
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
          const SizedBox(height: 16),

          Expanded(
            child: _buildBody(),
          ),
        ],
      ),
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
              onPressed: _loadPujas,
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

    final list = _filteredPujas ?? [];

    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_off_rounded, size: 48, color: AppColors.muted),
            const SizedBox(height: 16),
            Text(
              _searchController.text.isEmpty
                  ? 'No items available in the marketplace at this moment.'
                  : 'No marketplace items matching your query.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.muted, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.only(bottom: 120),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.82, // adjusted aspect ratio for image layout
      ),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final puja = list[index];
        return PujaCard(
          puja: puja,
          onTap: () => _showBookingSheet(puja),
        );
      },
    );
  }
}
