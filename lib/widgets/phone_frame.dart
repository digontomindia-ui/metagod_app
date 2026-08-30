import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// A cosmetic phone-shaped frame used on **web** to show a mobile preview.
/// On Android / iOS the child is rendered edge-to-edge without the frame.
class PhoneFrame extends StatelessWidget {
  final Widget child;

  const PhoneFrame({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    // On real mobile devices, skip the phone frame entirely.
    if (!kIsWeb) {
      return child;
    }

    // Web: render inside a faux phone bezel.
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 844),
      child: Container(
        width: 390,
        decoration: BoxDecoration(
          color: AppColors.bg,
          borderRadius: BorderRadius.circular(44),
          boxShadow: const [
            BoxShadow(
              color: Color(0x80000000),
              blurRadius: 80,
              offset: Offset(0, 40),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(44),
          child: child,
        ),
      ),
    );
  }
}
