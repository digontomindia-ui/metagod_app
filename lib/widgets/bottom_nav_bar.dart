import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class BottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTabChanged;

  const BottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTabChanged,
  });

  static const _tabs = [
    _TabData(icon: Icons.home_outlined, activeIcon: Icons.home_rounded, label: 'Home'),
    _TabData(icon: Icons.search_outlined, activeIcon: Icons.search_rounded, label: 'Explore'),
    _TabData(icon: Icons.temple_hindu_outlined, activeIcon: Icons.temple_hindu_rounded, label: 'Darshan'),
    _TabData(icon: null, activeIcon: null, customTextIcon: 'ॐ', label: 'MetaGod AI'),
    _TabData(icon: Icons.chat_bubble_outline, activeIcon: Icons.chat_bubble_rounded, label: 'Consult'),
  ];

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    return Container(
      margin: EdgeInsets.fromLTRB(16, 0, 16, 24 + bottomPadding), // Floating margin adapts to system nav
      decoration: BoxDecoration(
        color: AppColors.card.withValues(alpha: 0.7), // Glassmorphic base
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: AppColors.gold.withValues(alpha: 0.05),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final tabWidth = constraints.maxWidth / _tabs.length;
                return Stack(
                  children: [
                    // Sliding Active Indicator
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 350),
                      curve: Curves.easeOutCubic,
                      left: tabWidth * currentIndex,
                      top: 0,
                      bottom: 0,
                      width: tabWidth,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.gold.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: AppColors.gold.withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                      ),
                    ),
                    // Tabs
                    Row(
                      children: [
                        for (int i = 0; i < _tabs.length; i++)
                          SizedBox(
                            width: tabWidth,
                            child: _buildTabItem(i),
                          ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabItem(int index) {
    final tab = _tabs[index];
    final isActive = currentIndex == index;
    return GestureDetector(
      onTap: () => onTabChanged(index),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
              child: tab.customTextIcon != null
                  ? Text(
                      tab.customTextIcon!,
                      key: ValueKey<bool>(isActive),
                      style: TextStyle(
                        fontSize: isActive ? 24 : 20,
                        fontWeight: FontWeight.w700,
                        color: isActive ? AppColors.gold : Colors.white60,
                        height: 1.1,
                      ),
                    )
                  : Icon(
                      isActive ? tab.activeIcon : tab.icon,
                      key: ValueKey<bool>(isActive),
                      size: isActive ? 26 : 22,
                      color: isActive ? AppColors.gold : Colors.white60,
                    ),
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 250),
                style: TextStyle(
                  fontSize: isActive ? 10.5 : 9.5,
                  fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                  color: isActive ? AppColors.gold : AppColors.muted,
                  letterSpacing: 0.2,
                ),
                child: Text(tab.label),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TabData {
  final IconData? icon;
  final IconData? activeIcon;
  final String? customTextIcon;
  final String label;
  const _TabData({this.icon, this.activeIcon, this.customTextIcon, required this.label});
}
