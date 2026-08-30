import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../config/env.dart';
import '../theme/app_colors.dart';

/// A caching network image with a consistent placeholder and error fallback.
///
/// Wraps [CachedNetworkImage] so remote images are cached (no repeated
/// downloads on rebuild/scroll), failed loads degrade gracefully instead of
/// throwing a red error box, and relative paths are resolved via [Env.mediaUrl].
class AppNetworkImage extends StatelessWidget {
  final String? url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? errorWidget;
  final Widget? placeholder;
  final BorderRadius? borderRadius;

  const AppNetworkImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.errorWidget,
    this.placeholder,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final resolved = Env.mediaUrl(url);
    final Widget child = resolved.isEmpty
        ? _fallback()
        : CachedNetworkImage(
            imageUrl: resolved,
            width: width,
            height: height,
            fit: fit,
            // Downscale decoded image to ~2x display size to cut memory use.
            memCacheWidth:
                (width != null && width!.isFinite) ? (width! * 2).round() : null,
            placeholder: (_, _) => _placeholder(),
            errorWidget: (_, _, _) => _fallback(),
          );

    if (borderRadius != null) {
      return ClipRRect(borderRadius: borderRadius!, child: child);
    }
    return child;
  }

  Widget _placeholder() =>
      placeholder ??
      Container(width: width, height: height, color: AppColors.card);

  Widget _fallback() =>
      errorWidget ??
      Container(
        width: width,
        height: height,
        color: AppColors.card,
        alignment: Alignment.center,
        child: const Icon(Icons.broken_image_outlined,
            color: AppColors.muted, size: 24),
      );
}
