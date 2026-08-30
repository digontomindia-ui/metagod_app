import 'package:flutter/material.dart';
import '../../../models/vr_experience.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/vr_thumbnail_player.dart';

class VrExperienceCard extends StatelessWidget {
  final VrExperience vr;
  final VoidCallback onStoreTap;
  final VoidCallback onTrailerTap;

  const VrExperienceCard({
    super.key,
    required this.vr,
    required this.onStoreTap,
    required this.onTrailerTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Image with compatibility badge
            Stack(
              children: [
                Container(
                  height: 140,
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
                    color: Color(0xFF140D25),
                  ),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(17)),
                    child: VrThumbnailPlayer(
                      trailerLink: vr.trailerLink,
                      imageUrl: vr.img,
                      experienceId: vr.id,
                    ),
                  ),
                ),
                // Badge
                Positioned(
                  top: 10,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.gold,
                      borderRadius: BorderRadius.circular(6),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.gold.withValues(alpha: 0.2),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        )
                      ],
                    ),
                    child: Text(
                      vr.badge.toUpperCase(),
                      style: const TextStyle(
                        color: AppColors.bg,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            
            // Content
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        vr.tag.toUpperCase(),
                        style: const TextStyle(
                          color: AppColors.saffron,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                      Text(
                        vr.performance,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    vr.title,
                    style: const TextStyle(
                      color: AppColors.cream,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    vr.desc,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                  
                  const SizedBox(height: 14),
                  
                  // Device Specs pills
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _buildSpecPill('Mode: ${vr.mode}'),
                      _buildSpecPill('Lang: ${vr.language}'),
                      _buildSpecPill('Quest Exclusives'),
                    ],
                  ),
                  
                  const SizedBox(height: 18),
                  
                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: onTrailerTap,
                          icon: const Icon(Icons.play_circle_outline_rounded, color: AppColors.cream, size: 18),
                          label: const Text(
                            'Watch Trailer',
                            style: TextStyle(color: AppColors.cream, fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.border),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.gold,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.gold.withValues(alpha: 0.15),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              )
                            ],
                          ),
                          child: ElevatedButton.icon(
                            onPressed: onStoreTap,
                            icon: const Icon(Icons.shopping_bag_outlined, color: AppColors.bg, size: 18),
                            label: const Text(
                              'Meta Store',
                              style: TextStyle(color: AppColors.bg, fontWeight: FontWeight.w800, fontSize: 12),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
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
    );
  }

  Widget _buildSpecPill(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0C16),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.muted,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
