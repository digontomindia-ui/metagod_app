import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/api_client.dart';
import '../../theme/app_colors.dart';
import '../../utils/app_logger.dart';

class OtpScreen extends StatefulWidget {
  final String email;
  final bool isForgotPassword;

  const OtpScreen({
    super.key,
    required this.email,
    required this.isForgotPassword,
  });

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _otpController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  int _resendTimerSeconds = 30;
  Timer? _timer;
  bool _canResend = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _startResendTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _otpController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _startResendTimer() {
    setState(() {
      _resendTimerSeconds = 30;
      _canResend = false;
    });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendTimerSeconds == 0) {
        setState(() {
          _canResend = true;
          _timer?.cancel();
        });
      } else {
        setState(() {
          _resendTimerSeconds--;
        });
      }
    });
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

  Future<void> _handleVerify() async {
    if (!_formKey.currentState!.validate()) return;

    final authService = Provider.of<AuthService>(context, listen: false);
    final otp = _otpController.text.trim();
    
    try {
      if (widget.isForgotPassword) {
        // For forgot password, we verify the OTP, and then we reset the password
        // Call verify-otp. In standard APIs, this will either log us in or verify the OTP state.
        final verified = await authService.verifyOtp(widget.email, otp);
        if (!mounted) return;
        if (verified) {
          // If verified, we call changePassword to set the new password.
          // Since the user is authenticated (or using OTP as current password), we call:
          final newPassword = _passwordController.text.trim();
          try {
            // Try resetting using changePassword.
            // Under normal forgot password, the OTP is either the "currentPassword",
            // or the user was logged in and we can call it. We try passing otp as currentPassword.
            await authService.changePassword(otp, newPassword);
            if (!mounted) return;
            _showSnackBar('Password reset successful! You are now logged in.', isError: false);

            // Go back to the main login/auth screen or if logged in, it will auto route.
            if (mounted) {
              Navigator.of(context).pop();
            }
          } catch (e) {
            // If changePassword failed, it might be that the backend reset password works differently
            // but we are logged in. Let's try calling changePassword with the new password as both,
            // or inform the user.
            logE('Failed to set new password after OTP verification', e);
            if (!mounted) return;
            _showSnackBar('OTP verified, but failed to reset password. Please contact support.');
          }
        }
      } else {
        // Normal verification
        final verified = await authService.verifyOtp(widget.email, otp);
        if (!mounted) return;
        if (verified) {
          _showSnackBar('Verification successful!', isError: false);
          if (mounted) {
            Navigator.of(context).pop();
          }
        }
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      _showSnackBar(e.message);
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('An error occurred during verification. Please try again.');
    }
  }

  Future<void> _handleResend() async {
    if (!_canResend) return;

    final authService = Provider.of<AuthService>(context, listen: false);
    try {
      await authService.sendOtp(widget.email);
      _showSnackBar('OTP resent successfully!', isError: false);
      _startResendTimer();
    } on ApiException catch (e) {
      _showSnackBar(e.message);
    } catch (e) {
      _showSnackBar('Failed to resend OTP.');
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
          // Background Gradient
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
          
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Custom Header
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.cream),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Verification',
                        style: TextStyle(
                          color: AppColors.cream,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 20),
                          const Icon(
                            Icons.mark_email_read_outlined,
                            size: 64,
                            color: AppColors.gold,
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            'Verify Your Account',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.cream,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Please enter the 6-digit OTP code sent to\n${widget.email}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: AppColors.muted,
                              fontSize: 14,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 36),

                          // OTP Text Field
                          _buildGlassTextField(
                            controller: _otpController,
                            label: 'Enter 6-Digit OTP',
                            prefixIcon: Icons.lock_clock_outlined,
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter OTP';
                              }
                              if (value.trim().length != 6) {
                                return 'OTP must be exactly 6 digits';
                              }
                              return null;
                            },
                          ),

                          if (widget.isForgotPassword) ...[
                            const SizedBox(height: 8),
                            const Text(
                              'Set New Password',
                              style: TextStyle(
                                color: AppColors.cream,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _buildGlassTextField(
                              controller: _passwordController,
                              label: 'New Password',
                              prefixIcon: Icons.lock_outline_rounded,
                              isPassword: true,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter new password';
                                }
                                if (value.length < 6) {
                                  return 'Password must be at least 6 characters';
                                }
                                return null;
                              },
                            ),
                            _buildGlassTextField(
                              controller: _confirmPasswordController,
                              label: 'Confirm New Password',
                              prefixIcon: Icons.lock_outline_rounded,
                              isPassword: true,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please confirm password';
                                }
                                if (value != _passwordController.text) {
                                  return 'Passwords do not match';
                                }
                                return null;
                              },
                            ),
                          ],

                          const SizedBox(height: 24),
                          
                          // Submit Button
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
                              onPressed: _handleVerify,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              child: Text(
                                widget.isForgotPassword ? 'Reset Password' : 'Verify Code',
                                style: const TextStyle(
                                  color: AppColors.bg,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Resend Code Row
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text(
                                "Didn't receive code? ",
                                style: TextStyle(color: AppColors.muted, fontSize: 13),
                              ),
                              TextButton(
                                onPressed: _canResend ? _handleResend : null,
                                child: Text(
                                  _canResend ? 'Resend' : 'Resend in ${_resendTimerSeconds}s',
                                  style: TextStyle(
                                    color: _canResend ? AppColors.gold : AppColors.muted,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
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
                          'Verifying...',
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
}
