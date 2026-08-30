import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/api_client.dart';
import '../../theme/app_colors.dart';
import 'otp_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _formKeyLogin = GlobalKey<FormState>();
  final _formKeyRegister = GlobalKey<FormState>();
  final _formKeyForgot = GlobalKey<FormState>();

  // Controllers
  final _emailLoginController = TextEditingController();
  final _passwordLoginController = TextEditingController();

  final _nameRegisterController = TextEditingController();
  final _emailRegisterController = TextEditingController();
  final _phoneRegisterController = TextEditingController();
  final _passwordRegisterController = TextEditingController();

  final _emailForgotController = TextEditingController();

  bool _isForgotPasswordMode = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _emailLoginController.dispose();
    _passwordLoginController.dispose();
    _nameRegisterController.dispose();
    _emailRegisterController.dispose();
    _phoneRegisterController.dispose();
    _passwordRegisterController.dispose();
    _emailForgotController.dispose();
    super.dispose();
  }

  void _showSnackBar(String message, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        backgroundColor: isError ? AppColors.red : AppColors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Future<void> _handleLogin() async {
    if (!_formKeyLogin.currentState!.validate()) return;

    final authService = Provider.of<AuthService>(context, listen: false);
    try {
      await authService.login(
        _emailLoginController.text.trim(),
        _passwordLoginController.text.trim(),
      );
      _showSnackBar('Welcome back!', isError: false);
    } on ApiException catch (e) {
      _showSnackBar(e.message);
    } catch (e) {
      _showSnackBar('Unexpected error: $e');
    }
  }

  Future<void> _handleRegister() async {
    if (!_formKeyRegister.currentState!.validate()) return;

    final authService = Provider.of<AuthService>(context, listen: false);
    try {
      await authService.register(
        _nameRegisterController.text.trim(),
        _emailRegisterController.text.trim(),
        _passwordRegisterController.text.trim(),
        _phoneRegisterController.text.trim().isEmpty ? null : _phoneRegisterController.text.trim(),
      );
      _showSnackBar('Account created successfully!', isError: false);
    } on ApiException catch (e) {
      _showSnackBar(e.message);
    } catch (e) {
      _showSnackBar('Unexpected error: $e');
    }
  }

  Future<void> _handleForgotPassword() async {
    if (!_formKeyForgot.currentState!.validate()) return;

    final authService = Provider.of<AuthService>(context, listen: false);
    final email = _emailForgotController.text.trim();
    try {
      await authService.sendOtp(email);
      _showSnackBar('OTP sent to your email!', isError: false);
      setState(() {
        _isForgotPasswordMode = false;
      });
      // Navigate to OTP Reset Password Screen
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => OtpScreen(email: email, isForgotPassword: true),
          ),
        );
      }
    } on ApiException catch (e) {
      _showSnackBar(e.message);
    } catch (e) {
      _showSnackBar('Failed to send OTP. Please check your network.');
    }
  }

  Widget _buildGlassTextField({
    required TextEditingController controller,
    required String label,
    required IconData prefixIcon,
    bool isPassword = false,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.card.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
      ),
      child: TextFormField(
        controller: controller,
        obscureText: isPassword && _obscurePassword,
        keyboardType: keyboardType,
        validator: validator,
        style: const TextStyle(color: AppColors.cream, fontSize: 14),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: AppColors.muted, fontSize: 13),
          prefixIcon: Icon(prefixIcon, color: AppColors.gold, size: 20),
          suffixIcon: isPassword
              ? IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    color: AppColors.muted,
                    size: 20,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          floatingLabelBehavior: FloatingLabelBehavior.never,
          hintText: label,
          hintStyle: const TextStyle(color: AppColors.muted, fontSize: 14),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);

    return Scaffold(
      body: Stack(
        children: [
          // Background Gradient Pattern
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF0F0A1E), Color(0xFF06040A)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
          // Circular glow gradients for premium look
          Positioned(
            top: -100,
            right: -50,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.gold.withValues(alpha: 0.08),
                backgroundBlendMode: BlendMode.screen,
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            left: -50,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.saffron.withValues(alpha: 0.06),
                backgroundBlendMode: BlendMode.screen,
              ),
            ),
          ),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Brand Logo / Icon
                    Center(
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [AppColors.gold, AppColors.saffron],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.saffron.withValues(alpha: 0.3),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.temple_hindu_rounded,
                          color: AppColors.bg,
                          size: 38,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Center(
                      child: Text(
                        'MetaGodCreator',
                        style: TextStyle(
                          color: AppColors.cream,
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 4,
                        ),
                      ),
                    ),
                    const Center(
                      child: Text(
                        'Your Spiritual Temple',
                        style: TextStyle(
                          color: AppColors.muted,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(height: 36),

                    if (_isForgotPasswordMode) ...[
                      // Forgot Password View
                      _buildForgotPasswordForm()
                    ] else ...[
                      // Normal Tabs View (Login / Register)
                      _buildAuthTabsForm(),
                    ],
                  ],
                ),
              ),
            ),
          ),

          // Loading Overlay
          if (authService.isLoading)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.6),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(AppColors.gold),
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Please wait...',
                          style: TextStyle(
                            color: AppColors.cream,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildForgotPasswordForm() {
    return Form(
      key: _formKeyForgot,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.cream, size: 18),
                onPressed: () {
                  setState(() {
                    _isForgotPasswordMode = false;
                  });
                },
              ),
              const Text(
                'Forgot Password',
                style: TextStyle(
                  color: AppColors.cream,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Enter your registered email address below. We will send you an OTP code to verify and reset your password.',
            style: TextStyle(color: AppColors.muted, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 24),
          _buildGlassTextField(
            controller: _emailForgotController,
            label: 'Email Address',
            prefixIcon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter your email';
              }
              if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value.trim())) {
                return 'Please enter a valid email address';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          Container(
            height: 52,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: const LinearGradient(
                colors: [AppColors.gold, AppColors.saffron],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.saffron.withValues(alpha: 0.2),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: _handleForgotPassword,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text(
                'Send OTP Code',
                style: TextStyle(
                  color: AppColors.bg,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAuthTabsForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Premium Tabs TabBar
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: AppColors.card.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border.withValues(alpha: 0.3)),
          ),
          child: TabBar(
            controller: _tabController,
            indicator: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: const LinearGradient(
                colors: [AppColors.gold, AppColors.saffron],
              ),
            ),
            labelColor: AppColors.bg,
            unselectedLabelColor: AppColors.muted,
            labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
            tabs: const [
              Tab(text: 'Sign In'),
              Tab(text: 'Register'),
            ],
            dividerColor: Colors.transparent,
            indicatorSize: TabBarIndicatorSize.tab,
          ),
        ),
        const SizedBox(height: 24),
        
        // TabBar View Content
        SizedBox(
          height: 380,
          child: TabBarView(
            controller: _tabController,
            children: [
              // LOGIN FORM
              Form(
                key: _formKeyLogin,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildGlassTextField(
                      controller: _emailLoginController,
                      label: 'Email Address',
                      prefixIcon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) return 'Enter email';
                        return null;
                      },
                    ),
                    _buildGlassTextField(
                      controller: _passwordLoginController,
                      label: 'Password',
                      prefixIcon: Icons.lock_outline_rounded,
                      isPassword: true,
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Enter password';
                        if (value.length < 6) return 'Password must be at least 6 characters';
                        return null;
                      },
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {
                          setState(() {
                            _isForgotPasswordMode = true;
                          });
                        },
                        child: const Text(
                          'Forgot Password?',
                          style: TextStyle(
                            color: AppColors.gold,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      height: 52,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        gradient: const LinearGradient(
                          colors: [AppColors.gold, AppColors.saffron],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.saffron.withValues(alpha: 0.2),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: _handleLogin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: const Text(
                          'Sign In',
                          style: TextStyle(
                            color: AppColors.bg,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              // REGISTER FORM
              Form(
                key: _formKeyRegister,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildGlassTextField(
                        controller: _nameRegisterController,
                        label: 'Full Name',
                        prefixIcon: Icons.person_outline_rounded,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) return 'Enter name';
                          return null;
                        },
                      ),
                      _buildGlassTextField(
                        controller: _emailRegisterController,
                        label: 'Email Address',
                        prefixIcon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) return 'Enter email';
                          if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value.trim())) {
                            return 'Enter a valid email';
                          }
                          return null;
                        },
                      ),
                      _buildGlassTextField(
                        controller: _phoneRegisterController,
                        label: 'Phone Number (Optional)',
                        prefixIcon: Icons.phone_outlined,
                        keyboardType: TextInputType.phone,
                      ),
                      _buildGlassTextField(
                        controller: _passwordRegisterController,
                        label: 'Password',
                        prefixIcon: Icons.lock_outline_rounded,
                        isPassword: true,
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'Enter password';
                          if (value.length < 6) return 'At least 6 characters';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      Container(
                        height: 52,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          gradient: const LinearGradient(
                            colors: [AppColors.gold, AppColors.saffron],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.saffron.withValues(alpha: 0.2),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: _handleRegister,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: const Text(
                            'Create Account',
                            style: TextStyle(
                              color: AppColors.bg,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20), // buffer space
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
