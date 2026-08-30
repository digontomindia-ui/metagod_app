import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../../services/auth_service.dart';
import '../../../theme/app_colors.dart';

class ProfileHeader extends StatelessWidget {
  const ProfileHeader({super.key});

  String _getInitials(String name) {
    if (name.isEmpty) return 'U';
    final parts = name.trim().split(' ');
    if (parts.length > 1) {
      return (parts[0][0] + parts[1][0]).toUpperCase();
    }
    return name[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().currentUser;
    
    if (user == null) {
      return const SizedBox.shrink();
    }

    final initials = _getInitials(user.name);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2A1A05), Color(0xFF1A0F2E)],
        ),
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () async {
              final picker = ImagePicker();
              final pickedFile = await picker.pickImage(source: ImageSource.gallery);
              if (pickedFile != null && context.mounted) {
                final auth = context.read<AuthService>();
                final success = await auth.uploadProfilePicture(pickedFile.path);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(success ? 'Profile picture updated' : 'Failed to update profile picture'),
                      backgroundColor: success ? Colors.green : Colors.red,
                    ),
                  );
                }
              }
            },
            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [AppColors.gold, AppColors.saffron],
                    ),
                  ),
                  child: ClipOval(
                    child: user.avatar != null && user.avatar!.startsWith('http')
                        ? Image.network(
                            user.avatar!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Center(
                              child: Text(
                                initials,
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.bg,
                                ),
                              ),
                            ),
                          )
                        : Center(
                            child: Text(
                              initials,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: AppColors.bg,
                              ),
                            ),
                          ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppColors.gold,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.bg, width: 2),
                  ),
                  child: const Icon(
                    Icons.add_a_photo_rounded,
                    size: 10,
                    color: AppColors.bg,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.name.isEmpty ? 'Devotee' : user.name,
                  style: const TextStyle(
                    color: AppColors.cream,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  user.email,
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 13,
                  ),
                ),
                if (user.phone != null && user.phone!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    user.phone!,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 13,
                    ),
                  ),
                ],
              ],
            ),
          ),
          GestureDetector(
            onTap: () {
              final nameController = TextEditingController(text: user.name);
              final phoneController = TextEditingController(text: user.phone ?? '');
              
              showDialog(
                context: context,
                builder: (context) {
                  bool isUpdating = false;
                  return StatefulBuilder(
                    builder: (context, setState) {
                      return AlertDialog(
                        backgroundColor: const Color(0xFF16121F),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                        title: const Text(
                          'Edit Profile',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextField(
                              controller: nameController,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                labelText: 'Name',
                                labelStyle: const TextStyle(color: Colors.white70),
                                enabledBorder: OutlineInputBorder(
                                  borderSide: const BorderSide(color: Colors.white24),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderSide: const BorderSide(color: AppColors.gold),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: phoneController,
                              style: const TextStyle(color: Colors.white),
                              keyboardType: TextInputType.phone,
                              decoration: InputDecoration(
                                labelText: 'Phone',
                                labelStyle: const TextStyle(color: Colors.white70),
                                enabledBorder: OutlineInputBorder(
                                  borderSide: const BorderSide(color: Colors.white24),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderSide: const BorderSide(color: AppColors.gold),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ],
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                          ),
                          TextButton(
                            onPressed: isUpdating ? null : () async {
                              setState(() => isUpdating = true);
                              final auth = context.read<AuthService>();
                              final success = await auth.updateProfile(
                                nameController.text.trim(),
                                phoneController.text.trim(),
                              );
                              
                              if (context.mounted) {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(success ? 'Profile updated successfully' : 'Failed to update profile'),
                                    backgroundColor: success ? Colors.green : Colors.red,
                                  ),
                                );
                              }
                            },
                            child: isUpdating 
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(color: AppColors.gold, strokeWidth: 2),
                                )
                              : const Text('Save', style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      );
                    }
                  );
                },
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.gold.withValues(alpha: 0.08),
                border: Border.all(color: AppColors.gold.withValues(alpha: 0.2)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'Edit',
                style: TextStyle(
                  color: AppColors.gold,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
