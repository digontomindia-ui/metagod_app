import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../theme/app_colors.dart';
import 'widgets/profile_header.dart';
import 'widgets/stats_row.dart';
import 'widgets/menu_list.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.cream, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'My Profile',
          style: TextStyle(
            color: AppColors.cream,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: Column(
          children: [
            const ProfileHeader(),
            const SizedBox(height: 24),
            const StatsRow(),
            const SizedBox(height: 24),
            const MenuList(),
            const SizedBox(height: 24),
            InkWell(
              onTap: () {
                // Confirm logout dialog
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    backgroundColor: const Color(0xFF16121F),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    title: const Text(
                      'Sign Out',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    content: const Text(
                      'Are you sure you want to sign out of your account?',
                      style: TextStyle(color: Colors.white70),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                      ),
                      TextButton(
                        onPressed: () {
                          // Close dialog
                          Navigator.of(context).pop();
                          // Pop everything off the stack to reveal TempleApp (which will show AuthScreen)
                          Navigator.of(context).popUntil((route) => route.isFirst);
                          // Trigger logout
                          context.read<AuthService>().logout();
                        },
                        child: const Text('Sign Out', style: TextStyle(color: Color(0xFFFC8181))),
                      ),
                    ],
                  ),
                );
              },
              borderRadius: BorderRadius.circular(14),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0x18E53E3E),
                  border: Border.all(color: const Color(0x44E53E3E)),
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: const Text(
                  'Sign Out',
                  style: TextStyle(
                    color: Color(0xFFFC8181),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
