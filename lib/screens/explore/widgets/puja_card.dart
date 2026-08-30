import 'package:flutter/material.dart';
import '../../../models/puja.dart';
import '../../../theme/app_colors.dart';

class PujaCard extends StatelessWidget {
  final Puja puja;
  final VoidCallback onTap;

  const PujaCard({
    super.key,
    required this.puja,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail Image
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: double.infinity,
                  color: Colors.black26,
                  child: puja.image.startsWith('http')
                      ? Image.network(
                          puja.image,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => const Center(
                            child: Icon(Icons.temple_hindu_outlined, size: 28, color: AppColors.gold),
                          ),
                        )
                      : const Center(
                          child: Icon(Icons.temple_hindu_outlined, size: 28, color: AppColors.gold),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              puja.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.cream,
                fontWeight: FontWeight.w700,
                fontSize: 13,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '⏱ ${puja.duration}',
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 10,
                  ),
                ),
                Text(
                  '₹${puja.price.toStringAsFixed(0)}',
                  style: const TextStyle(
                    color: AppColors.goldLight,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
