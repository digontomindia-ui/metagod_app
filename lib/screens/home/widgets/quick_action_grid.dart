import 'package:flutter/material.dart';
import '../../../theme/app_colors.dart';
import '../../explore/divine_marketplace_screen.dart';

class QuickActionGrid extends StatelessWidget {
  final void Function(int index, {String? filter})? onTabChanged;

  const QuickActionGrid({
    super.key,
    this.onTabChanged,
  });

  static const _actions = [
    _ActionData(icon: Icons.local_fire_department_outlined, label: 'Book Puja'),
    _ActionData(icon: Icons.temple_hindu_outlined, label: 'Darshan'),
    _ActionData(icon: Icons.shopping_bag_outlined, label: 'Essentials'),
    _ActionData(icon: Icons.visibility_outlined, label: 'VR'),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          for (int i = 0; i < _actions.length; i++) ...[
            if (i > 0) const SizedBox(width: 10),
            Expanded(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    final label = _actions[i].label;
                    if (label == 'Book Puja') {
                      onTabChanged?.call(1); // Explore tab
                    } else if (label == 'Darshan') {
                      onTabChanged?.call(2); // Darshan tab (all)
                    } else if (label == 'Essentials') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const DivineMarketplaceScreen(),
                        ),
                      );
                    } else if (label == 'VR') {
                      onTabChanged?.call(2, filter: 'vr'); // Shift tab to Darshan with VR filter
                    }
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                    child: Column(
                      children: [
                        Icon(_actions[i].icon, size: 28, color: AppColors.gold),
                        const SizedBox(height: 6),
                        Text(
                          _actions[i].label,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppColors.muted,
                            height: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ActionData {
  final IconData icon;
  final String label;
  const _ActionData({required this.icon, required this.label});
}
