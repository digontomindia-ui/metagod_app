import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/wallet_service.dart';
import '../services/payment_service.dart';
import '../services/auth_service.dart';
import '../services/temple_service.dart';
import '../theme/app_colors.dart';

class UniversalPaymentModal extends StatefulWidget {
  final double amount;
  final String itemName;
  final String purposePrefix;
  final String? referenceId;
  final Future<String> Function() createRazorpayOrder;
  // Required: payment must be verified server-side before being treated as
  // successful. A client SDK success callback alone is spoofable.
  final Future<bool> Function(PaymentResult result) verifyRazorpayPayment;

  const UniversalPaymentModal({
    super.key,
    required this.amount,
    required this.itemName,
    required this.purposePrefix,
    this.referenceId,
    required this.createRazorpayOrder,
    required this.verifyRazorpayPayment,
  });

  /// Shows the modal and returns the method used ('wallet' or 'razorpay') if successful.
  static Future<String?> show({
    required BuildContext context,
    required double amount,
    required String itemName,
    required String purposePrefix,
    String? referenceId,
    required Future<String> Function() createRazorpayOrder,
    required Future<bool> Function(PaymentResult result) verifyRazorpayPayment,
  }) async {
    // Check maintenance mode first
    final templeService = context.read<TempleService>();
    final isMaintenance = await templeService.checkMaintenanceMode();
    if (isMaintenance) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('System is currently under maintenance. Payments and purchases are temporarily disabled.'),
            backgroundColor: AppColors.red,
          ),
        );
      }
      return null;
    }

    if (!context.mounted) return null;

    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => UniversalPaymentModal(
        amount: amount,
        itemName: itemName,
        purposePrefix: purposePrefix,
        referenceId: referenceId,
        createRazorpayOrder: createRazorpayOrder,
        verifyRazorpayPayment: verifyRazorpayPayment,
      ),
    );
  }

  @override
  State<UniversalPaymentModal> createState() => _UniversalPaymentModalState();
}

class _UniversalPaymentModalState extends State<UniversalPaymentModal> {
  String? _selectedMethod;
  bool _isProcessing = false;
  bool _isLoadingBalance = false;

  void _handleSelectMethod(String method) async {
    setState(() {
      _selectedMethod = method;
    });
    if (method == 'wallet') {
      setState(() => _isLoadingBalance = true);
      final authService = context.read<AuthService>();
      await authService.refreshProfile();
      if (mounted) {
        setState(() => _isLoadingBalance = false);
      }
    }
  }

  Future<void> _handlePayment() async {
    if (_selectedMethod == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a payment method')));
      return;
    }

    final user = context.read<AuthService>().currentUser;
    if (user == null) return;

    setState(() => _isProcessing = true);

    try {
      if (_selectedMethod == 'wallet') {
        final walletService = context.read<WalletService>();
        final authService = context.read<AuthService>();
        await walletService.payWithWallet(
          amount: widget.amount,
          purpose: '${widget.purposePrefix}: ${widget.itemName}',
          referenceId: widget.referenceId ?? 'PURCHASE_${DateTime.now().millisecondsSinceEpoch}',
        );
        
        // Refresh balance after payment
        await authService.refreshProfile();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment Successful via Wallet!')));
          Navigator.of(context).pop('wallet');
        }
      } else if (_selectedMethod == 'razorpay') {
        final orderId = await widget.createRazorpayOrder();
        
        final result = await PaymentService.instance.openCheckout(
          amount: widget.amount,
          name: user.name,
          description: '${widget.purposePrefix}: ${widget.itemName}',
          contact: user.phone ?? '',
          email: user.email,
          orderId: orderId,
        );

        // Always verify server-side before treating the payment as successful.
        final verified = await widget.verifyRazorpayPayment(result);
        if (!mounted) return;
        if (verified) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment Successful!')));
          Navigator.of(context).pop('razorpay');
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment verification failed')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceAll('ApiException: ', ''))));
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().currentUser;
    final walletBalance = user?.walletBalance ?? 0.0;
    final isWalletInsufficient = walletBalance < widget.amount;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        bottom: true,
        child: SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                const Icon(Icons.verified_user_rounded, color: AppColors.gold),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text('MetaGod Pay', style: TextStyle(color: AppColors.gold, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                    Text('SECURE GATEWAY', style: TextStyle(color: AppColors.muted, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.bg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.itemName, style: const TextStyle(color: AppColors.gold, fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(widget.purposePrefix.toUpperCase(), style: const TextStyle(color: AppColors.muted, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                      ],
                    ),
                  ),
                  Text('₹${widget.amount.toStringAsFixed(0)}', style: const TextStyle(color: Color(0xFFE56B2E), fontSize: 24, fontWeight: FontWeight.w900)),
                ],
              ),
            ),
            const SizedBox(height: 24),
            if (_selectedMethod == 'wallet') ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isWalletInsufficient ? Colors.red.withValues(alpha: 0.1) : Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isWalletInsufficient ? Colors.red.withValues(alpha: 0.3) : Colors.green.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('AVAILABLE BALANCE', style: TextStyle(color: AppColors.muted, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                        _isLoadingBalance
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.gold))
                            : Text(
                                '₹${walletBalance.toStringAsFixed(2)}',
                                style: TextStyle(color: isWalletInsufficient ? Colors.red : Colors.green, fontSize: 14, fontWeight: FontWeight.bold),
                              ),
                      ],
                    ),
                    if (!_isLoadingBalance && isWalletInsufficient)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text('Insufficient funds. Please recharge your wallet.', style: TextStyle(color: Colors.red, fontSize: 11, fontStyle: FontStyle.italic)),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
            const Text('SELECT PAYMENT METHOD', style: TextStyle(color: AppColors.muted, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
            const SizedBox(height: 12),
            _buildMethodCard(
              id: 'wallet',
              title: 'Meta God Wallet',
              subtitle: 'Pay using your sacred balance',
              icon: Icons.account_balance_wallet_rounded,
            ),
            const SizedBox(height: 12),
            _buildMethodCard(
              id: 'razorpay',
              title: 'Online Payment',
              subtitle: 'UPI, Cards, NetBanking',
              icon: Icons.payments_rounded,
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _isProcessing || _isLoadingBalance || _selectedMethod == null || (_selectedMethod == 'wallet' && isWalletInsufficient) ? null : _handlePayment,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.gold,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: _isProcessing
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('COMPLETE PAYMENT', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                        SizedBox(width: 8),
                        Icon(Icons.lock_rounded, size: 16),
                      ],
                    ),
            ),
          ],
        ),
      ),
      ),
      ),
    );
  }

  Widget _buildMethodCard({required String id, required String title, required String subtitle, required IconData icon}) {
    final isSelected = _selectedMethod == id;
    return InkWell(
      onTap: () => _handleSelectMethod(id),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFE56B2E).withValues(alpha: 0.1) : AppColors.bg,
          border: Border.all(color: isSelected ? const Color(0xFFE56B2E) : AppColors.border),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? const Color(0xFFE56B2E) : AppColors.muted, size: 24),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(color: isSelected ? const Color(0xFFE56B2E) : AppColors.cream, fontWeight: FontWeight.bold, fontSize: 14)),
                  Text(subtitle, style: const TextStyle(color: AppColors.muted, fontSize: 10)),
                ],
              ),
            ),
            if (isSelected) const Icon(Icons.check_circle_rounded, color: Color(0xFFE56B2E)),
          ],
        ),
      ),
    );
  }
}
