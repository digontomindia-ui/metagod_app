import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/wallet_service.dart';
import '../../services/payment_service.dart';
import '../../theme/app_colors.dart';
import '../../services/auth_service.dart';
import '../../services/temple_service.dart';
import '../../utils/app_logger.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  double _balance = 0;
  List<dynamic> _transactions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchWalletDetails();
  }

  Future<void> _fetchWalletDetails() async {
    setState(() => _isLoading = true);
    final walletService = context.read<WalletService>();
    final authService = context.read<AuthService>();
    try {
      final details = await walletService.fetchWalletDetails();
      if (!mounted) return;
      setState(() {
        _balance = (details['balance'] as num?)?.toDouble() ?? 0;
        _transactions = details['transactions'] ?? [];
      });
      // Refresh auth profile to update walletBalance everywhere
      await authService.refreshProfile();
    } catch (e) {
      logE('Failed to load wallet', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load wallet: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showAddFundsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => const _AddFundsSheet(),
    ).then((_) {
      _fetchWalletDetails();
    });
  }

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
          'My Wallet',
          style: TextStyle(
            color: AppColors.cream,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.gold),
              ),
            )
          : RefreshIndicator(
              onRefresh: _fetchWalletDetails,
              color: AppColors.gold,
              backgroundColor: AppColors.card,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Wallet Card
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.gold, Color(0xFFE56B2E)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.gold.withValues(alpha: 0.3),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'SACRED WALLET BALANCE',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 2,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '₹${_balance.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 40,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const Icon(Icons.account_balance_wallet_rounded, color: Colors.white54, size: 40),
                            ],
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton(
                            onPressed: _showAddFundsSheet,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: AppColors.gold,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'ADD FUNDS',
                              style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    const Text(
                      'Transaction History',
                      style: TextStyle(
                        color: AppColors.cream,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_transactions.isEmpty)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32.0),
                          child: Text(
                            'No transactions yet.',
                            style: TextStyle(color: AppColors.muted),
                          ),
                        ),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _transactions.length,
                        itemBuilder: (context, index) {
                          final tx = _transactions[index];
                          final isCredit = tx['type'] == 'CREDIT';
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.card,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: isCredit
                                        ? Colors.green.withValues(alpha: 0.1)
                                        : Colors.red.withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    isCredit ? Icons.add : Icons.remove,
                                    color: isCredit ? Colors.green : Colors.red,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        tx['purpose'] ?? 'Transaction',
                                        style: const TextStyle(
                                          color: AppColors.cream,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        tx['createdAt'] != null
                                            ? (DateTime.tryParse(tx['createdAt']?.toString() ?? '') ?? DateTime.now()).toLocal().toString().split('.')[0]
                                            : '',
                                        style: const TextStyle(
                                          color: AppColors.muted,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '${isCredit ? '+' : '-'}₹${tx['amount']}',
                                      style: TextStyle(
                                        color: isCredit ? Colors.green : Colors.red,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    Text(
                                      (tx['status'] ?? '').toString().toUpperCase(),
                                      style: const TextStyle(
                                        color: AppColors.muted,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _AddFundsSheet extends StatefulWidget {
  const _AddFundsSheet();

  @override
  State<_AddFundsSheet> createState() => _AddFundsSheetState();
}

class _AddFundsSheetState extends State<_AddFundsSheet> {
  final _amountController = TextEditingController();
  final _giftCardController = TextEditingController();
  bool _isProcessing = false;

  @override
  void dispose() {
    _amountController.dispose();
    _giftCardController.dispose();
    super.dispose();
  }

  Future<void> _processAddFunds() async {
    final amountText = _amountController.text.trim();
    if (amountText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a valid amount')));
      return;
    }
    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a valid amount')));
      return;
    }

    final templeService = context.read<TempleService>();
    final isMaintenance = await templeService.checkMaintenanceMode();
    if (isMaintenance) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('System is currently under maintenance. Payments and purchases are temporarily disabled.'),
            backgroundColor: AppColors.red,
          ),
        );
      }
      return;
    }

    final giftCard = _giftCardController.text.trim();
    final walletService = context.read<WalletService>();

    setState(() => _isProcessing = true);

    try {
      if (giftCard.isNotEmpty) {
        final success = await walletService.addFundsWithGiftCard(amount: amount, giftCardCode: giftCard);
        if (success) {
          if (mounted) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Funds added successfully!')));
          }
        }
      } else {
        // Razorpay Recharge Flow
        final user = context.read<AuthService>().currentUser;
        if (user == null) throw Exception('Not logged in');

        // Create Order via TempleService or directly hitting /razorpay/create-order
        final templeService = context.read<TempleService>();
        final orderRes = await templeService.createProductOrder(amount: amount.toInt(), receipt: 'wallet_recharge');
        
        final paymentResult = await PaymentService.instance.openCheckout(
          amount: amount,
          name: user.name,
          description: 'Wallet Recharge',
          contact: user.phone ?? '',
          email: user.email,
          orderId: orderRes['orderId'],
        );

        final verifyRes = await walletService.verifyRecharge(
          razorpayOrderId: paymentResult.orderId,
          razorpayPaymentId: paymentResult.paymentId,
          razorpaySignature: paymentResult.signature,
          amount: amount,
        );

        if (verifyRes && mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Wallet recharged successfully!')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20,
        right: 20,
        top: 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Recharge Wallet',
            style: TextStyle(
              color: AppColors.cream,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: AppColors.cream),
            decoration: InputDecoration(
              labelText: 'Amount (₹)',
              labelStyle: const TextStyle(color: AppColors.muted),
              filled: true,
              fillColor: AppColors.bg,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _giftCardController,
            style: const TextStyle(color: AppColors.cream),
            decoration: InputDecoration(
              labelText: 'Gift Card Code (Optional)',
              labelStyle: const TextStyle(color: AppColors.muted),
              filled: true,
              fillColor: AppColors.bg,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Leave gift card blank to pay via Online Payment (Razorpay).',
            style: TextStyle(color: AppColors.muted, fontSize: 11),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _isProcessing ? null : _processAddFunds,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.gold,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _isProcessing
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                : const Text('PROCEED', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
