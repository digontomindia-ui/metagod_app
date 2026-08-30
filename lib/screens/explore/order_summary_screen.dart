import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/cart_service.dart';
import '../../services/auth_service.dart';
import '../../services/payment_service.dart';
import '../../services/temple_service.dart';
import '../../theme/app_colors.dart';
import '../profile/my_orders_screen.dart';
import '../../widgets/universal_payment_modal.dart';
import '../profile/addresses_screen.dart';
import '../../models/address.dart';
import '../../services/address_service.dart';

class OrderSummaryScreen extends StatefulWidget {
  const OrderSummaryScreen({super.key});

  @override
  State<OrderSummaryScreen> createState() => _OrderSummaryScreenState();
}

class _OrderSummaryScreenState extends State<OrderSummaryScreen> {
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _addressController;
  late TextEditingController _cityController;
  late TextEditingController _stateController;
  late TextEditingController _pincodeController;

  String contactName = '';
  String contactNumber = '';
  String deliveryAddress = '';

  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    final authService = context.read<AuthService>();
    final user = authService.currentUser;

    contactName = user?.name ?? '';
    contactNumber = user?.phone ?? '';
    deliveryAddress = '123 Spiritual Lane, Varanasi, UP 221001';

    _nameController = TextEditingController(text: contactName);
    _phoneController = TextEditingController(text: contactNumber);
    _addressController =
        TextEditingController(text: '123 Spiritual Lane, Varanasi');
    _cityController = TextEditingController(text: 'Varanasi');
    _stateController = TextEditingController(text: 'UP');
    _pincodeController = TextEditingController(text: '221001');

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final addressService = context.read<AddressService>();
      await addressService.fetchAddresses();
      final defaultAddr = addressService.defaultAddress;
      if (defaultAddr != null && mounted) {
        setState(() {
          contactName = defaultAddr.name;
          contactNumber = defaultAddr.phone;
          deliveryAddress = defaultAddr.formattedAddress;
        });
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _pincodeController.dispose();
    super.dispose();
  }

  Future<void> _handlePayment() async {
    if (contactName.trim().isEmpty || deliveryAddress.trim().isEmpty || contactNumber.trim().isEmpty) {
      // Auto-open the address selection screen so the user can add/select an address
      final result = await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const AddressesScreen(isSelectionMode: true)),
      );
      if (result != null && result is Address) {
        setState(() {
          contactName = result.name;
          contactNumber = result.phone;
          deliveryAddress = result.formattedAddress;
        });
        // After selecting, we don't automatically submit, let them see it and click again
      }
      return;
    }

    setState(() => _isProcessing = true);

    final cart = context.read<CartService>();
    final templeService = context.read<TempleService>();
    final double deliveryFee = cart.cartItems.isEmpty ? 0 : 40;
    final double finalTotal = cart.totalAmount + deliveryFee;

    try {
      final success = await UniversalPaymentModal.show(
        context: context,
        amount: finalTotal,
        itemName: 'Divine Marketplace Order',
        purposePrefix: 'Purchase',
        referenceId: 'ORDER_${DateTime.now().millisecondsSinceEpoch}',
        createRazorpayOrder: () async {
          // The backend expects `/razorpay/create-order` to create generic order
          final orderRes = await templeService.createProductOrder(amount: finalTotal.toInt());
          return orderRes['orderId'] as String;
        },
        verifyRazorpayPayment: (paymentResult) async {
          // Verify with backend
          return await templeService.verifyProductPayment(
            razorpayOrderId: paymentResult.orderId,
            razorpayPaymentId: paymentResult.paymentId,
            razorpaySignature: paymentResult.signature,
          );
        },
      );

      if (success == null) {
        setState(() => _isProcessing = false);
        return;
      }

      // Record each order item in the backend database
      for (final item in cart.cartItems) {
        await templeService.placeMockOrder(
          productId: item.product.id,
          quantity: item.quantity,
          shippingAddress: {
            'name': contactName,
            'phone': contactNumber,
            'address': deliveryAddress,
          },
        );
      }

      // Clear the CartProvider
      cart.clearCart();

      if (!mounted) return;

      // Show "Order Placed Successfully" checkmark dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle_rounded,
                  color: AppColors.green, size: 64),
              SizedBox(height: 16),
              Text(
                'Order Placed Successfully!',
                style: TextStyle(
                  color: AppColors.cream,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );

      // Delay 2 seconds
      await Future.delayed(const Duration(seconds: 2));

      if (!mounted) return;

      // Navigator.popUntil dashboard
      Navigator.of(context).popUntil((route) => route.isFirst);

      if (!mounted) return;

      // Push MyOrdersScreen
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => const MyOrdersScreen(),
        ),
      );
    } on PaymentException catch (e) {
      if (!mounted) return;
      
      String errorMsg = 'Payment failed: ${e.message} (Error Code: ${e.code})';
      // Razorpay code 2 or 0 usually means the user closed the modal
      if (e.code == 2 || e.code == 0) {
        errorMsg = 'Payment cancelled by user.';
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMsg),
          backgroundColor: AppColors.red,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: AppColors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartService>();
    final double deliveryFee = cart.cartItems.isEmpty ? 0 : 40;
    final double finalTotal = cart.totalAmount + deliveryFee;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: AppColors.cream),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Order Summary',
          style: TextStyle(
            color: AppColors.cream,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Shipping Address Card ──
            _buildShippingAddressCard(),

            const SizedBox(height: 20),

            // ── Order Items Section ──
            _buildOrderItemsSection(cart),

            const SizedBox(height: 20),

            // ── Bill Summary Card ──
            _buildBillSummaryCard(cart, finalTotal, deliveryFee),

            const SizedBox(height: 100),
          ],
        ),
      ),
      bottomNavigationBar: _buildStickyFooter(cart, finalTotal),
    );
  }

  // ───────────────────────────────────────────────
  //  Shipping Address Card
  // ───────────────────────────────────────────────
  Widget _buildShippingAddressCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.location_on_rounded,
                  color: AppColors.gold, size: 22),
              const SizedBox(width: 8),
              const Text(
                'Delivery Address',
                style: TextStyle(
                  color: AppColors.cream,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AddressesScreen(isSelectionMode: true),
                    ),
                  );
                  if (result != null && result is Address) {
                    setState(() {
                      contactName = result.name;
                      contactNumber = result.phone;
                      deliveryAddress = result.formattedAddress;
                    });
                  }
                },
                child: const Text(
                  'Change',
                  style: TextStyle(
                    color: AppColors.gold,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            contactName.isNotEmpty ? contactName : 'Guest',
            style: const TextStyle(
              color: AppColors.cream,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (contactNumber.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              contactNumber,
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 13,
              ),
            ),
          ],
          const SizedBox(height: 4),
          Text(
            deliveryAddress.isNotEmpty ? deliveryAddress : 'No address provided',
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  // (Address Bottom Sheet removed in favor of AddressesScreen)

  // ───────────────────────────────────────────────
  //  Order Items Section
  // ───────────────────────────────────────────────
  Widget _buildOrderItemsSection(CartService cart) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'YOUR ITEMS',
          style: TextStyle(
            color: AppColors.gold,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        ...cart.cartItems.map((item) => _buildCartItemTile(item, cart)),
      ],
    );
  }

  Widget _buildCartItemTile(CartItem item, CartService cart) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          // Product image
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: item.product.image != null && item.product.image!.isNotEmpty
                ? Image.network(
                    item.product.image!,
                    width: 50,
                    height: 50,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => _buildFallbackIcon(),
                  )
                : _buildFallbackIcon(),
          ),
          const SizedBox(width: 12),

          // Name + category
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.product.name,
                  style: const TextStyle(
                    color: AppColors.cream,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  item.product.category,
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // Price + quantity stepper
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '₹${item.totalPrice.toStringAsFixed(0)}',
                style: const TextStyle(
                  color: AppColors.cream,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              _buildQuantityStepper(item, cart),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFallbackIcon() {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: AppColors.card2,
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Icon(Icons.shopping_bag_rounded,
          color: AppColors.muted, size: 24),
    );
  }

  Widget _buildQuantityStepper(CartItem item, CartService cart) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card2,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _stepperButton(
            icon: Icons.remove,
            onTap: () => cart.decrementQuantity(item.product.id),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              '${item.quantity}',
              style: const TextStyle(
                color: AppColors.cream,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          _stepperButton(
            icon: Icons.add,
            onTap: () => cart.incrementQuantity(item.product.id),
          ),
        ],
      ),
    );
  }

  Widget _stepperButton({required IconData icon, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Icon(icon, size: 16, color: AppColors.gold),
      ),
    );
  }

  // ───────────────────────────────────────────────
  //  Bill Summary Card
  // ───────────────────────────────────────────────
  Widget _buildBillSummaryCard(CartService cart, double finalTotal, double deliveryFee) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          _billRow('Item Total', '₹${cart.totalAmount.toStringAsFixed(0)}'),
          const SizedBox(height: 10),
          _billRow('Delivery Fee', '₹${deliveryFee.toStringAsFixed(0)}'),
          const SizedBox(height: 10),
          Divider(color: AppColors.border, thickness: 1),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'To Pay',
                style: TextStyle(
                  color: AppColors.gold,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '₹${finalTotal.toStringAsFixed(0)}',
                style: const TextStyle(
                  color: AppColors.goldLight,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _billRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(color: AppColors.muted, fontSize: 14),
        ),
        Text(
          value,
          style: const TextStyle(color: AppColors.cream, fontSize: 14),
        ),
      ],
    );
  }

  // ───────────────────────────────────────────────
  //  Sticky Footer
  // ───────────────────────────────────────────────
  Widget _buildStickyFooter(CartService cart, double finalTotal) {
    return SafeArea(
      child: Container(
        height: 70,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: const BoxDecoration(
          color: AppColors.gold,
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 10,
              offset: Offset(0, -4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Left – total
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Total',
                  style: TextStyle(
                    color: Colors.black.withValues(alpha: 0.55),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '₹${finalTotal.toStringAsFixed(0)}',
                  style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Spacer(),

            // Right – confirm button
            ElevatedButton(
              onPressed: (_isProcessing || cart.cartItems.isEmpty) ? null : _handlePayment,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.bg,
                foregroundColor: AppColors.gold,
                disabledBackgroundColor: AppColors.card2,
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                elevation: 0,
              ),
              child: _isProcessing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.gold,
                      ),
                    )
                  : const Text(
                      'CONFIRM PURCHASE',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
