import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';

class CategoryChips extends StatelessWidget {
  final int activeIndex;
  final ValueChanged<int> onChanged;

  const CategoryChips({
    super.key,
    required this.activeIndex,
    required this.onChanged,
  });

  static const _categories = ['All', 'Puja', 'Horoscope', 'Darshan', 'Events'];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(left: 20),
        itemCount: _categories.length,
        separatorBuilder: (_, n) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final isActive = activeIndex == index;
          return GestureDetector(
            onTap: () => onChanged(index),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: isActive
                    ? const LinearGradient(
                        colors: [AppColors.gold, AppColors.saffron],
                      )
                    : null,
                color: isActive ? null : AppColors.card,
                border: isActive ? null : Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                _categories[index],
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isActive ? AppColors.bg : AppColors.muted,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
