import 'package:flutter/material.dart';
import '../../../theme/app_colors.dart';

class SuggestionCard extends StatelessWidget {
  final String text;
  final VoidCallback onTap;

  const SuggestionCard({
    super.key,
    required this.text,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.card,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  color: AppColors.cream,
                  fontSize: 12,
                ),
              ),
            ),
            const Text(
              '›',
              style: TextStyle(color: AppColors.gold, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
