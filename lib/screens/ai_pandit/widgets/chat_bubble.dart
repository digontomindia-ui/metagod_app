import 'package:flutter/material.dart';
import '../../../theme/app_colors.dart';

class ChatBubble extends StatelessWidget {
  final String text;
  final bool isUser;

  const ChatBubble({
    super.key,
    required this.text,
    required this.isUser,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: isUser
              ? const LinearGradient(colors: [AppColors.gold, AppColors.saffron])
              : null,
          color: isUser ? null : AppColors.card2,
          border: isUser ? null : Border.all(color: AppColors.border),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: isUser ? const Radius.circular(18) : const Radius.circular(4),
            bottomRight: isUser ? const Radius.circular(4) : const Radius.circular(18),
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isUser ? AppColors.bg : AppColors.cream,
            fontSize: 13,
            height: 1.6,
            fontWeight: isUser ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}
