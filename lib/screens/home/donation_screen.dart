import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/temple_service.dart';
import '../../theme/app_colors.dart';
import '../../models/temple.dart';
import '../../widgets/universal_payment_modal.dart';
import '../../utils/app_logger.dart';

class DonationScreen extends StatefulWidget {
  const DonationScreen({super.key});

  @override
  State<DonationScreen> createState() => _DonationScreenState();
}

class _DonationScreenState extends State<DonationScreen> {
  List<Temple>? _temples;
  Temple? _selectedTemple;
  bool _isLoading = false;
  int _selectedPredefinedIndex = 2; // Bhog Arpan by default (index 2)
  final _customAmountController = TextEditingController();

  final _offeringNames = const [
    'Pushpanjali (Flowers)',
    'Deepam (Lamp)',
    'Bhog Arpan (Prasad)',
    'Maha Aarti Support',
  ];
  final _offeringAmounts = const [101.0, 251.0, 501.0, 1101.0];

  @override
  void initState() {
    super.initState();
    _loadTemples();
  }

  @override
  void dispose() {
    _customAmountController.dispose();
    super.dispose();
  }

  Future<void> _loadTemples() async {
    setState(() => _isLoading = true);
    try {
      final list = await context.read<TempleService>().fetchTemples();
      setState(() {
        _temples = list;
        if (list.isNotEmpty) {
          _selectedTemple = list.first;
        }
        _isLoading = false;
      });
    } catch (e) {
      logE('Failed to load temples for donation', e);
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleDonate() async {
    if (_selectedTemple == null) {
      _showSnackBar('Please select a temple to support');
      return;
    }

    final currentUser = context.read<AuthService>().currentUser;
    if (currentUser == null) return;

    double amount = 0;
    String offeringName = 'Custom Contribution';

    final customText = _customAmountController.text.trim();
    if (customText.isNotEmpty) {
      final parsed = double.tryParse(customText);
      if (parsed == null || parsed <= 0) {
        _showSnackBar('Please enter a valid amount');
        return;
      }
      amount = parsed;
    } else {
      amount = _offeringAmounts[_selectedPredefinedIndex];
      offeringName = _offeringNames[_selectedPredefinedIndex];
    }

    if (amount < 11) {
      _showSnackBar('Minimum donation amount is ₹11');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final templeService = context.read<TempleService>();

      final success = await UniversalPaymentModal.show(
        context: context,
        amount: amount,
        itemName: offeringName,
        purposePrefix: 'Donation',
        referenceId: 'DONATION_${DateTime.now().millisecondsSinceEpoch}',
        createRazorpayOrder: () async {
          final order = await templeService.createDonationOrder(amount: amount.toInt());
          return order['id'] as String;
        },
        verifyRazorpayPayment: (paymentResult) async {
          return await templeService.verifyDonationPayment(
            razorpayOrderId: paymentResult.orderId,
            razorpayPaymentId: paymentResult.paymentId,
            razorpaySignature: paymentResult.signature,
            donationData: {
              'templeId': _selectedTemple!.id,
              'amount': amount,
              'donorName': currentUser.name,
              'donorEmail': currentUser.email,
              'donorPhone': currentUser.phone ?? '9876543210',
              'offeringName': offeringName,
            },
          );
        },
      );

      setState(() => _isLoading = false);

      if (success != null) {
        if (success == 'wallet') {
          await templeService.donateMock(
            templeId: _selectedTemple!.id,
            amount: amount,
            donorName: currentUser.name,
            donorEmail: currentUser.email,
            donorPhone: currentUser.phone ?? '9876543210',
            offeringName: offeringName,
            donationType: 'Wallet',
          );
        }

        _showSuccessDialog(
          title: 'Donation Successful',
          message: 'Thank you! Your donation of ₹${amount.toStringAsFixed(0)} for "$offeringName" at ${_selectedTemple!.name} has been processed successfully.',
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar(e.toString().replaceAll('ApiException: ', ''));
    }
  }

  void _showSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red[800]),
    );
  }

  void _showSuccessDialog({required String title, required String message}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppColors.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: AppColors.border),
          ),
          title: Row(
            children: [
              const Text('  ', style: TextStyle(fontSize: 22)),
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.gold,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          content: Text(
            message,
            style: const TextStyle(color: AppColors.cream, fontSize: 13, height: 1.5),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('DHANYAWAD (OK)', style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold)),
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop(); // Go back to previous screen
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.cream),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Devotional Donation',
          style: TextStyle(
            color: AppColors.cream,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: _isLoading && _temples == null
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.gold),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Support Sacred Mandirs',
                    style: TextStyle(
                      color: AppColors.cream,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Select a temple and make a devotional contribution.',
                    style: TextStyle(
                      color: AppColors.muted,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Temple Selector Dropdown
                  if (_temples != null) ...[
                    const Text(
                      'SELECT MANDIR',
                      style: TextStyle(
                        color: AppColors.gold,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        border: Border.all(color: AppColors.border),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<Temple>(
                          value: _selectedTemple,
                          dropdownColor: AppColors.card,
                          isExpanded: true,
                          hint: const Text('Select a Temple', style: TextStyle(color: AppColors.muted)),
                          items: _temples!.map((Temple t) {
                            return DropdownMenuItem<Temple>(
                              value: t,
                              child: Text(t.name, style: const TextStyle(color: AppColors.cream, fontSize: 14)),
                            );
                          }).toList(),
                          onChanged: (Temple? value) {
                            setState(() {
                              _selectedTemple = value;
                            });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Offerings Cards Grid
                  const Text(
                    'SELECT OFFERING TYPE',
                    style: TextStyle(
                      color: AppColors.gold,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.6,
                    children: [
                      for (int i = 0; i < 4; i++)
                        InkWell(
                          onTap: () {
                            setState(() {
                              _selectedPredefinedIndex = i;
                              _customAmountController.clear();
                            });
                          },
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            decoration: BoxDecoration(
                              color: _selectedPredefinedIndex == i && _customAmountController.text.isEmpty
                                  ? AppColors.gold.withValues(alpha: 0.1)
                                  : AppColors.card,
                              border: Border.all(
                                color: _selectedPredefinedIndex == i && _customAmountController.text.isEmpty
                                    ? AppColors.gold
                                    : AppColors.border,
                              ),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _offeringNames[i],
                                  style: TextStyle(
                                    color: _selectedPredefinedIndex == i && _customAmountController.text.isEmpty
                                        ? AppColors.gold
                                        : AppColors.cream,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '₹${_offeringAmounts[i].toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    color: AppColors.cream,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Custom Amount Field
                  const Text(
                    'OR ENTER CUSTOM AMOUNT (₹)',
                    style: TextStyle(
                      color: AppColors.gold,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      controller: _customAmountController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: AppColors.cream, fontWeight: FontWeight.bold),
                      decoration: const InputDecoration(
                        hintText: 'Enter amount',
                        hintStyle: TextStyle(color: AppColors.muted, fontSize: 13),
                        border: InputBorder.none,
                      ),
                      onChanged: (val) {
                        setState(() {});
                      },
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Donation Button
                  ElevatedButton(
                    onPressed: _isLoading ? null : _handleDonate,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                            ),
                          )
                        : const Text(
                            'PROCEED TO PAY',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                  ),
                ],
              ),
            ),
    );
  }
}
