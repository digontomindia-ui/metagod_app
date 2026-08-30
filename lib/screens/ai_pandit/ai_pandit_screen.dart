import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../services/ai_service.dart';
import 'widgets/chat_bubble.dart';
import 'widgets/suggestion_card.dart';

class AIPanditScreen extends StatefulWidget {
  const AIPanditScreen({super.key});

  @override
  State<AIPanditScreen> createState() => _AIPanditScreenState();
}

class _AIPanditScreenState extends State<AIPanditScreen> {
  final List<_Message> _messages = [
    _Message(
      role: 'assistant',
      text:
          ' Namaste! I am Meta God AI. Ask me anything about Hindu rituals, astrology, festivals, mantras, or spiritual guidance.',
    ),
  ];
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _loading = false;

  static const _suggestions = [
    'Best muhurat for marriage 2026',
    'Meaning of Om Namah Shivaya',
    'How to perform Satyanarayan Puja?',
  ];

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _sendMessage() {
    final q = _controller.text.trim();
    if (q.isEmpty || _loading) return;
    setState(() {
      _messages.add(_Message(role: 'user', text: q));
      _controller.clear();
      _loading = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

    // Map local chat state into the backend's history format.
    // The API expects role "oracle" for assistant messages.
    final history = _messages.map((m) {
      return {
        'role': m.role == 'assistant' ? 'oracle' : m.role,
        'text': m.text,
      };
    }).toList();

    AiService.instance.askOracle(message: q, history: history).then((reply) {
      if (mounted) {
        setState(() {
          _messages.add(_Message(role: 'assistant', text: reply));
          _loading = false;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHeader(),
        Expanded(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: _buildMessages(),
          ),
        ),
        _buildInput(),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 48, 20, 14),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1A0F2E), Colors.transparent],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
            onPressed: () {
              // Since it might be a tab, we can use Navigator.maybePop or fallback
              // But if it's a tab inside app.dart, popping might exit the app.
              // To handle being a tab without a BottomNavBar, we can just trigger a back navigation.
              final NavigatorState navigator = Navigator.of(context);
              if (navigator.canPop()) {
                navigator.pop();
              } else {
                // To trigger PopScope on root
                WidgetsBinding.instance.handlePopRoute();
              }
            },
          ),
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Color(0xFF7B5EA7), AppColors.gold],
              ),
            ),
            alignment: Alignment.center,
            child: const Text(
              'ॐ',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Meta God AI',
                style: TextStyle(
                  color: AppColors.cream,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                '● Online · Always available',
                style: TextStyle(
                  color: AppColors.green,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMessages() {
    return ListView.builder(
      controller: _scrollController,
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      itemCount: _messages.length + (_loading ? 1 : 0) + (_messages.length <= 1 ? 1 : 0),
      itemBuilder: (context, index) {
        int msgIdx = index;
        if (msgIdx < _messages.length) {
          final m = _messages[msgIdx];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: ChatBubble(text: m.text, isUser: m.role == 'user'),
          );
        }

        // Loading dots
        if (_loading) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.card2,
                  border: Border.all(color: AppColors.border),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(18),
                    topRight: Radius.circular(18),
                    bottomRight: Radius.circular(18),
                    bottomLeft: Radius.circular(4),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _Dot(delay: 0),
                    SizedBox(width: 5),
                    _Dot(delay: 150),
                    SizedBox(width: 5),
                    _Dot(delay: 300),
                  ],
                ),
              ),
            ),
          );
        }

        // Suggestions
        if (_messages.length <= 1) {
          return Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text(
                    'SUGGESTED',
                    style: TextStyle(
                      color: AppColors.muted,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                for (final s in _suggestions)
                  SuggestionCard(
                    text: s,
                    onTap: () {
                      _controller.text = s;
                      setState(() {}); // Refreshes state to enable send button
                    },
                  ),
              ],
            ),
          );
        }

        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildInput() {
    final bool isTyping = _controller.text.trim().isNotEmpty;
    
    // Scaffold consumes viewInsets.bottom, so we read the raw view to detect the keyboard
    final rawKeyboardHeight = View.of(context).viewInsets.bottom;
    final isKeyboardOpen = rawKeyboardHeight > 0;
    
    // Since the bottom navigation bar is now hidden on this screen,
    // we just need a standard bottom padding of 24.0 plus safe area when the keyboard is closed.
    final bottomPadding = isKeyboardOpen ? 12.0 : (24.0 + MediaQuery.of(context).padding.bottom);

    return Container(
      padding: EdgeInsets.fromLTRB(12, 8, 12, bottomPadding),
      decoration: const BoxDecoration(
        color: AppColors.card,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFF0F0C16),
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(22),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.center,
              child: TextField(
                controller: _controller,
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _sendMessage(),
                textInputAction: TextInputAction.send,
                maxLines: null,
                keyboardType: TextInputType.multiline,
                style: const TextStyle(color: AppColors.cream, fontSize: 13),
                decoration: const InputDecoration(
                  hintText: 'Ask your spiritual question...',
                  hintStyle: TextStyle(color: Colors.white24, fontSize: 12),
                  border: InputBorder.none,
                  isDense: true,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isTyping && !_loading ? const Color(0xFFFCA311) : AppColors.card,
              border: isTyping && !_loading ? null : Border.all(color: AppColors.border),
            ),
            child: IconButton(
              icon: Icon(
                Icons.send_rounded,
                color: isTyping && !_loading ? AppColors.bg : AppColors.muted,
                size: 16,
              ),
              onPressed: isTyping && !_loading ? _sendMessage : null,
              padding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }
}

class _Message {
  final String role;
  final String text;
  const _Message({required this.role, required this.text});
}

class _Dot extends StatefulWidget {
  final int delay;
  const _Dot({required this.delay});

  @override
  State<_Dot> createState() => _DotState();
}

class _DotState extends State<_Dot> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _animation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.4)),
    );
    Future.delayed(Duration(milliseconds: widget.delay), () {
      _controller.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.scale(
          scale: _animation.value,
          child: Opacity(
            opacity: _animation.value < 0.8 ? 0.4 : 1.0,
            child: Container(
              width: 7,
              height: 7,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.gold,
              ),
            ),
          ),
        );
      },
    );
  }
}
