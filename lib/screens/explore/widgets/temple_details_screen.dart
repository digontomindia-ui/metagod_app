import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'live_stream_player.dart';
import 'live_chat_tab.dart';
import '../../../models/temple.dart';
import '../../../models/product.dart';
import '../../../models/puja.dart';
import '../../../services/auth_service.dart';
import '../../../services/temple_service.dart';
import '../../../services/payment_service.dart';
import '../../../services/socket_service.dart';
import '../../../theme/app_colors.dart';
import '../../../utils/app_logger.dart';
import '../../../widgets/app_network_image.dart';
import '../../../widgets/universal_payment_modal.dart';
import 'booking_sheet.dart';
import '../../profile/my_orders_screen.dart';

class TempleDetailsScreen extends StatefulWidget {
  final String templeId;

  const TempleDetailsScreen({
    super.key,
    required this.templeId,
  });

  @override
  State<TempleDetailsScreen> createState() => _TempleDetailsScreenState();
}

class _TempleDetailsScreenState extends State<TempleDetailsScreen> with SingleTickerProviderStateMixin {
  final GlobalKey<LiveStreamPlayerState> _playerKey = GlobalKey<LiveStreamPlayerState>();
  LiveStreamPlayerState? _playerState;
  late TabController _tabController;
  Temple? _temple;
  List<Product>? _shopProducts;
  List<Product>? _templePrasads;
  List<Puja>? _templePujas;
  bool _isLoading = true;
  String? _errorMessage;

  String? _jwtToken;
  String _activeCam = 'Main Cam';
  bool _isMuted = true;

  // Donation state
  int _selectedPredefinedIndex = 2; // Bhog Arpan (Prasad) selected by default (index 2 in predefined list)
  final _donationController = TextEditingController();
  final _offeringNames = const [
    'Pushpanjali (Flowers)',
    'Deepam (Lamp)',
    'Bhog Arpan (Prasad)',
    'Maha Aarti Support',
  ];
  final _offeringAmounts = const [101.0, 251.0, 501.0, 1101.0];

  int _viewerCount = 0;
  StreamSubscription? _chatStreamSubscription;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadData();

    _chatStreamSubscription = SocketService().chatMessageStream.listen((data) {
      if (data['isViewerUpdate'] == true && data['viewerCount'] != null) {
        if (mounted) {
          setState(() {
            _viewerCount = data['viewerCount'];
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _donationController.dispose();
    _chatStreamSubscription?.cancel();
    // NOTE: do NOT disconnect the shared singleton socket here — other screens
    // (e.g. the live chat tab) rely on the same connection. Only this screen's
    // own stream subscription is cancelled above.
    super.dispose();
  }


  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final templeService = context.read<TempleService>();
      final authService = context.read<AuthService>();
      final templeDetail = await templeService.fetchTempleById(widget.templeId);

      List<Product> products = [];
      try {
        products = await templeService.fetchTempleProducts(widget.templeId);
      } catch (e) {
        logE('Error fetching temple products', e);
      }

      List<Product> allProducts = [];
      try {
        allProducts = await templeService.fetchProducts();
      } catch (e) {
        logE('Error fetching all products', e);
      }

      List<Puja> allPujas = [];
      try {
        allPujas = await templeService.fetchPujas();
      } catch (e) {
        logE('Error fetching all pujas', e);
      }

      List<Product> allPrasads = [];
      try {
        allPrasads = await templeService.fetchPrasadAsProducts();
      } catch (e) {
        logE('Error fetching all prasads', e);
      }

      // Fetch JWT token for the secure stream proxy
      final token = await authService.apiClient.getAccessToken();
      logD('[TempleDetails] Session token loaded: ${token != null && token.isNotEmpty}');

      setState(() {
        _temple = templeDetail;
        // Keep dynamically updated value if socket connected and updated it before load finished, else use API
        if (_viewerCount == 0) {
          _viewerCount = templeDetail.viewerCount ?? 0;
        }
        
        _shopProducts = products.where((p) => p.isTempleShop).toList();
        if (_shopProducts!.isEmpty) {
          _shopProducts = allProducts.where((p) => p.isTempleShop).toList();
        }
        
        _templePrasads = allPrasads.where((p) => p.templeId == widget.templeId || p.templeId == templeDetail.id).toList();
        if (_templePrasads!.isEmpty) {
          _templePrasads = allPrasads;
        }

        _templePujas = allPujas.where((p) => p.templeId?.id == widget.templeId || p.templeId?.id == templeDetail.id).toList();
        if (_templePujas!.isEmpty) {
          _templePujas = allPujas;
        }

        _jwtToken = token;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('ApiException: ', '');
        _isLoading = false;
      });
    }
  }





  Future<void> _handleDonate({
    required double amount,
    required String devoteeName,
    required String devoteePhone,
    required String orderId,
  }) async {
    if (_temple == null) return;
    
    final currentUser = context.read<AuthService>().currentUser;
    if (currentUser == null) return;

    String offeringName = _offeringNames[_selectedPredefinedIndex];

    setState(() {
      _isLoading = true;
    });

    try {
      final templeService = context.read<TempleService>();

      logD('Attempting Razorpay checkout');

      final success = await UniversalPaymentModal.show(
        context: context,
        amount: amount,
        itemName: offeringName,
        purposePrefix: 'Donation',
        referenceId: 'DONATION_${DateTime.now().millisecondsSinceEpoch}',
        createRazorpayOrder: () async {
          return orderId; // Already created by caller
        },
        verifyRazorpayPayment: (paymentResult) async {
          return await templeService.verifyDonationPayment(
            razorpayOrderId: paymentResult.orderId,
            razorpayPaymentId: paymentResult.paymentId,
            razorpaySignature: paymentResult.signature,
            donationData: {
              'templeId': _temple!.id,
              'amount': amount,
              'donorName': devoteeName,
              'donorEmail': currentUser.email,
              'donorPhone': devoteePhone,
              'offeringName': offeringName,
            },
          );
        },
      );

      setState(() {
        _isLoading = false;
      });

      if (success != null) {
        if (success == 'wallet') {
          await templeService.donateMock(
            templeId: _temple!.id,
            amount: amount,
            donorName: devoteeName,
            donorEmail: currentUser.email,
            donorPhone: devoteePhone,
            offeringName: offeringName,
            donationType: 'Wallet',
          );
        }

        _donationController.clear();
        _showSuccessDialog(
          title: 'Donation Successful',
          message: 'Thank you! Your donation of ₹${amount.toStringAsFixed(0)} for "$offeringName" at ${_temple!.name} has been processed successfully.',
        );
      }
    } on PaymentException catch (e) {
      setState(() {
        _isLoading = false;
      });
      // User cancelled or payment failed — not a server error
      String errorMsg = 'Payment failed: ${e.message}';
      if (e.code == 2 || e.code == 0) {
        errorMsg = 'Payment cancelled by user.';
      }
      _showSnackBar(errorMsg);
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showSnackBar('Donation failed: $e');
    }
  }

  void _showDevoteeDetailsSheet(int amount) {
    final nameSheetController = TextEditingController();
    final phoneSheetController = TextEditingController();
    final user = context.read<AuthService>().currentUser;
    if (user != null) {
      nameSheetController.text = user.name;
      phoneSheetController.text = user.phone ?? '';
    }

    bool sheetLoading = false;

    const inputBorder = OutlineInputBorder(
      borderSide: BorderSide(color: AppColors.border),
      borderRadius: BorderRadius.all(Radius.circular(12)),
    );
    const focusBorder = OutlineInputBorder(
      borderSide: BorderSide(color: AppColors.gold),
      borderRadius: BorderRadius.all(Radius.circular(12)),
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFF0F0C16),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                padding: const EdgeInsets.all(24),
                child: SafeArea(
                  bottom: true,
                  child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 48,
                          height: 4,
                          decoration: BoxDecoration(
                            color: AppColors.border,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Devotee Details',
                        style: TextStyle(
                          color: AppColors.cream,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Please provide details for the temple receipt.',
                        style: TextStyle(
                          color: AppColors.muted,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: nameSheetController,
                        style: const TextStyle(color: AppColors.cream, fontSize: 13),
                        decoration: const InputDecoration(
                          labelText: 'Full Name',
                          labelStyle: TextStyle(color: AppColors.muted, fontSize: 12),
                          enabledBorder: inputBorder,
                          focusedBorder: focusBorder,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: phoneSheetController,
                        style: const TextStyle(color: AppColors.cream, fontSize: 13),
                        keyboardType: TextInputType.phone,
                        maxLength: 10,
                        decoration: const InputDecoration(
                          labelText: 'Mobile Number',
                          labelStyle: TextStyle(color: AppColors.muted, fontSize: 12),
                          enabledBorder: inputBorder,
                          focusedBorder: focusBorder,
                          counterText: '',
                        ),
                      ),
                      const SizedBox(height: 24),
                      Container(
                        height: 50,
                        decoration: BoxDecoration(
                          color: AppColors.gold,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.gold.withValues(alpha: 0.2),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: sheetLoading
                              ? null
                              : () async {
                                  final name = nameSheetController.text.trim();
                                  final phone = phoneSheetController.text.trim();

                                  if (name.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Please enter Devotee name'),
                                        backgroundColor: AppColors.red,
                                      ),
                                    );
                                    return;
                                  }
                                  if (phone.isEmpty || phone.length != 10 || int.tryParse(phone) == null) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Please enter a valid 10-digit mobile number'),
                                        backgroundColor: AppColors.red,
                                      ),
                                    );
                                    return;
                                  }

                                  setModalState(() {
                                    sheetLoading = true;
                                  });

                                  try {
                                    final templeService = context.read<TempleService>();

                                    final isMaintenance = await templeService.checkMaintenanceMode();
                                    if (isMaintenance) {
                                      setModalState(() {
                                        sheetLoading = false;
                                      });
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('System is currently under maintenance. Payments and purchases are temporarily disabled.'),
                                            backgroundColor: AppColors.red,
                                          ),
                                        );
                                      }
                                      return;
                                    }

                                    // API call to fetch the order_id from the backend (POST /api/donations/create-order)
                                    final order = await templeService.createDonationOrder(
                                      amount: amount,
                                    );

                                    final orderId = order['id'] as String;

                                    setModalState(() {
                                      sheetLoading = false;
                                    });

                                    if (context.mounted) {
                                      Navigator.pop(context); // Close the sheet
                                      _handleDonate(
                                        amount: amount.toDouble(),
                                        devoteeName: name,
                                        devoteePhone: phone,
                                        orderId: orderId,
                                      );
                                    }
                                  } catch (e) {
                                    setModalState(() {
                                      sheetLoading = false;
                                    });
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Server Error: Could not generate order: $e'),
                                          backgroundColor: AppColors.red,
                                        ),
                                      );
                                    }
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: sheetLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.bg),
                                  ),
                                )
                              : Text(
                                  'Proceed to Pay ₹$amount',
                                  style: const TextStyle(
                                    color: AppColors.bg,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 14,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
              ),
            );
          },
        );
      },
    );
  }



  void _showCheckoutSheet(Product product) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CheckoutSheet(product: product),
    );
  }



  Future<void> _handleSubscription(BuildContext context) async {
    final authService = context.read<AuthService>();
    final user = authService.currentUser;
    if (user == null) {
      _showSnackBar('Please log in to subscribe.');
      return;
    }

    final success = await UniversalPaymentModal.show(
      context: context,
      amount: 499.0,
      itemName: 'Full Darshan Access',
      purposePrefix: 'Subscription',
      referenceId: 'SUB_${DateTime.now().millisecondsSinceEpoch}',
      createRazorpayOrder: () async {
        return 'MOCK_ORDER_${DateTime.now().millisecondsSinceEpoch}';
      },
      verifyRazorpayPayment: (result) async {
        return await authService.upgradeMembership();
      },
    );

    if (success != null) {
      _showSuccessDialog(
        title: 'Subscription Active',
        message: 'Welcome to the inner circle. You now have unlimited access to live darshan.',
      );
    }
  }

  void _showSnackBar(String message, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.red : AppColors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showSuccessDialog({required String title, required String message}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF16121F),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: AppColors.green, size: 28),
            const SizedBox(width: 12),
            Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(message, style: const TextStyle(color: Colors.white70, height: 1.4)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK', style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _temple == null) {
      return const Scaffold(
        backgroundColor: AppColors.bg,
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.gold),
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: AppColors.bg,
        appBar: AppBar(
          title: const Text('Temple Details'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded, size: 54, color: AppColors.red),
              const SizedBox(height: 16),
              Text(_errorMessage!, style: const TextStyle(color: AppColors.muted)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadData,
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold),
                child: const Text('Try Again', style: TextStyle(color: AppColors.bg)),
              ),
            ],
          ),
        ),
      );
    }

    final temple = _temple!;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text(
          temple.name,
          style: const TextStyle(color: AppColors.cream, fontWeight: FontWeight.w800, fontSize: 18),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.cream, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          if (temple.isVrReady)
            IconButton(
              icon: const Icon(Icons.vrpano_rounded, color: AppColors.gold),
              onPressed: () => _showSnackBar('VR Darshan Mode starting... ', isError: false),
            ),
        ],
      ),
      body: Column(
        children: [
          // Live Video Stream simulation or Cover image
          _buildPlayer(temple),

          // Tab Bar Selector
          Container(
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.border, width: 1)),
              color: AppColors.card,
            ),
            child: TabBar(
              controller: _tabController,
              indicatorColor: AppColors.gold,
              labelColor: AppColors.gold,
              unselectedLabelColor: AppColors.muted,
              labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              tabs: [
                const Tab(text: 'Offerings'),
                const Tab(text: 'Live Shop'),
                Tab(text: temple.isLive ? 'Live Chat' : 'Devotees'),
                const Tab(text: 'About'),
              ],
            ),
          ),

          // Tab Bar View content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildOfferingsTab(),
                _buildShopTab(),
                _buildChatTab(),
                _buildAboutTab(temple),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayer(Temple temple) {
    final isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    if (!temple.isLive) {
      return AspectRatio(
        aspectRatio: 16 / 9,
        child: Container(
          width: double.infinity,
          color: Colors.black,
        child: Stack(
          fit: StackFit.expand,
          children: [
            temple.coverImage != null && temple.coverImage!.startsWith('http')
                ? AppNetworkImage(url: temple.coverImage, fit: BoxFit.cover)
                : const Center(child: Icon(Icons.temple_hindu, size: 64, color: AppColors.border)),
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.transparent, Colors.black87],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
            Positioned(
              bottom: 16,
              left: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('UPCOMING RITUALS', style: TextStyle(color: AppColors.gold, fontSize: 11, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(temple.name, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Top Stats Row
        if (!isKeyboardOpen)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.red,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.fiber_manual_record, color: Colors.white, size: 10),
                      SizedBox(width: 4),
                      Text('LIVE', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text('$_viewerCount watching', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                ),
                const Spacer(),
                if (temple.resolutions != null && temple.resolutions!.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.settings_rounded, color: AppColors.gold, size: 10),
                        const SizedBox(width: 4),
                        Text(
                          temple.resolutions!.join(' / '),
                          style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

        // 2. Player Section
        AspectRatio(
          aspectRatio: 16 / 9,
          child: Container(
            width: double.infinity,
            color: Colors.black,
            child: Builder(
              builder: (context) {
                String? cameraUrl;
                if (temple.cameras != null && temple.cameras!.any((c) => c.angleName == _activeCam)) {
                  cameraUrl = temple.cameras!.firstWhere((c) => c.angleName == _activeCam).rtmpUrl;
                } else if (_activeCam == 'Side View' && temple.streamUrls.sideCam.isNotEmpty) {
                  cameraUrl = temple.streamUrls.sideCam;
                } else if (_activeCam == 'Altar Cam' && temple.streamUrls.altarCam.isNotEmpty) {
                  cameraUrl = temple.streamUrls.altarCam;
                }

                if (_jwtToken != null && _jwtToken!.isNotEmpty) {
                  return Builder(
                    builder: (context) {
                      final authService = context.watch<AuthService>();
                      final user = authService.currentUser;
                      
                      final bool isSubscribed = user != null && 
                          (user.subscriptionStatus == 'active' || 
                           user.plan == 'darshan' || 
                           ['ADMIN', 'SUPER_ADMIN'].contains(user.role));
                      final bool hasUsedTrial = user?.hasUsedTrial ?? false;

                      return ClipRect(
                        child: LiveStreamPlayer(
                          key: _playerKey,
                          templeId: temple.id,
                          jwtToken: _jwtToken!,
                          hasUsedTrial: hasUsedTrial,
                          isSubscribed: isSubscribed,
                          coverImage: temple.coverImage,
                          rtmpUrl: temple.rtmpUrl,
                          activeCam: _activeCam,
                          directStreamUrl: cameraUrl,
                          ads: temple.ads,
                          adVideoUrl: temple.adVideoUrl,
                          isAdSkippable: temple.isAdSkippable,
                          isMuted: _isMuted,
                          onSubscribeTap: () => _handleSubscription(context),
                          onPlayerReady: (state) {
                            if (mounted && _playerState != state) {
                              setState(() => _playerState = state);
                            }
                          },
                        ),
                      );
                    }
                  );
                } else {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(AppColors.gold),
                        ),
                        SizedBox(height: 10),
                        Text(
                          'Authenticating session…',
                          style: TextStyle(color: AppColors.muted, fontSize: 11),
                        ),
                      ],
                    ),
                  );
                }
              },
            ),
          ),
        ),

        // 3. Bottom Controls Row (Playback + Mute + Angle)
        if (!isKeyboardOpen)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: [
                if (temple.isLive) _buildPlaybackControls(),
                if (temple.isLive) const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildMuteButton(),
                    if (temple.isLive) _buildCameraSelector(temple),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildMuteButton() {
    return GestureDetector(
      onTap: () {
        setState(() {
          _isMuted = !_isMuted;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black45,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(
              _isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
              color: _isMuted ? AppColors.muted : Colors.white,
              size: 16,
            ),
            const SizedBox(width: 6),
            Text(
              _isMuted ? 'Muted' : 'Unmuted',
              style: TextStyle(
                color: _isMuted ? AppColors.muted : Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStaticControls({required bool isPlaying, required bool isAtLiveEdge, LiveStreamPlayerState? state}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // -10s Seek
        IconButton(
          onPressed: () {
            if (state != null) {
              state.seekBackward10s();
            } else {
              _showSnackBar('Player starting...', isError: false);
            }
          },
          icon: const Icon(Icons.replay_10_rounded, color: AppColors.cream),
          splashRadius: 24,
        ),
        const SizedBox(width: 16),
        
        // Play / Pause
        GestureDetector(
          onTap: () {
            if (state != null) {
              if (isPlaying) {
                state.pause();
              } else {
                state.play();
              }
            } else {
              _showSnackBar('Player starting...', isError: false);
            }
          },
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.gold,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.gold.withValues(alpha: 0.3),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Icon(
              isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color: Colors.black,
              size: 28,
            ),
          ),
        ),
        const SizedBox(width: 16),
        
        // Jump to LIVE
        GestureDetector(
          onTap: () {
            if (state != null) {
              state.jumpToLive();
            } else {
              _showSnackBar('Player starting...', isError: false);
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isAtLiveEdge ? AppColors.red.withValues(alpha: 0.1) : Colors.black45,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isAtLiveEdge ? AppColors.red : Colors.white24,
              ),
            ),
            child: Row(
              children: [
                if (isAtLiveEdge)
                  Container(
                    margin: const EdgeInsets.only(right: 6),
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                Text(
                  'LIVE',
                  style: TextStyle(
                    color: isAtLiveEdge ? AppColors.red : Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPlaybackControls() {
    final state = _playerState;
    if (state == null) {
      return _buildStaticControls(isPlaying: true, isAtLiveEdge: true);
    }
    
    return ValueListenableBuilder<bool>(
      valueListenable: state.isPlaying,
      builder: (context, isPlaying, child) {
        return ValueListenableBuilder<bool>(
          valueListenable: state.isAtLiveEdge,
          builder: (context, isAtLiveEdge, child) {
            return _buildStaticControls(
              isPlaying: isPlaying, 
              isAtLiveEdge: isAtLiveEdge, 
              state: state,
            );
          },
        );
      },
    );
  }

  Widget _buildCameraSelector(Temple temple) {
    // Generate available cameras. Main Cam is always available.
    final List<String> availableCams = ['Main Cam'];
    
    if (temple.cameras != null && temple.cameras!.isNotEmpty) {
      availableCams.addAll(temple.cameras!.map((c) => c.angleName));
    } else {
      // Fallback
      if (temple.streamUrls.sideCam.isNotEmpty) availableCams.add('Side View');
      if (temple.streamUrls.altarCam.isNotEmpty) availableCams.add('Altar Cam');
    }

    if (availableCams.length <= 1) return const SizedBox.shrink();

    return Container(
      height: 32,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: availableCams.map((cam) {
          final isSelected = _activeCam == cam;
          return GestureDetector(
            onTap: () {
              setState(() {
                _activeCam = cam;
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSelected ? AppColors.gold : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                cam,
                style: TextStyle(
                  color: isSelected ? Colors.black : Colors.white,
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildOfferingsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Title card mimicking the user's specs
          const Text(
            'Sacred Offerings',
            style: TextStyle(
              color: AppColors.cream,
              fontSize: 24,
              fontFamily: 'Georgia',
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'MAKE A DEVOTIONAL DONATION',
            style: TextStyle(
              color: AppColors.gold,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.8,
            ),
          ),
          const SizedBox(height: 20),

          // Offerings Grid (4 Cards)
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            childAspectRatio: 1.6,
            children: [
              for (int i = 0; i < 4; i++) _buildPredefinedOfferingCard(i),
            ],
          ),
          const SizedBox(height: 24),

          // Custom Donation Panel
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.card,
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'CUSTOM CONTRIBUTION',
                      style: TextStyle(
                        color: AppColors.gold,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                      ),
                    ),
                    Text(
                      'Min ₹11',
                      style: TextStyle(
                        color: AppColors.muted.withValues(alpha: 0.7),
                        fontSize: 10,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 52,
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F0C16),
                          border: Border.all(color: AppColors.border),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        alignment: Alignment.center,
                        child: Row(
                          children: [
                            const Text(
                              '₹',
                              style: TextStyle(
                                color: AppColors.gold,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: _donationController,
                                keyboardType: TextInputType.number,
                                style: const TextStyle(color: AppColors.cream, fontSize: 16),
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  hintText: 'Enter amount',
                                  hintStyle: TextStyle(color: Colors.white24, fontSize: 14),
                                  isDense: true,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Donate Button
                    Container(
                      height: 52,
                      decoration: BoxDecoration(
                        color: AppColors.gold,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.gold.withValues(alpha: 0.2),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: () {
                          final amountText = _donationController.text.trim();
                          if (amountText.isEmpty) return;

                          final amount = int.tryParse(amountText);
                          if (amount == null || amount < 11) {
                            _showSnackBar('Please enter a minimum contribution of ₹11');
                            return;
                          }

                          _showDevoteeDetailsSheet(amount);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'DONATE',
                              style: TextStyle(
                                color: AppColors.bg,
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                                letterSpacing: 1.2,
                              ),
                            ),
                            SizedBox(width: 6),
                            Icon(Icons.volunteer_activism_rounded, color: AppColors.bg, size: 16),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
            if (_templePujas != null && _templePujas!.isNotEmpty) ...[
              const SizedBox(height: 28),
              const Text(
                'Book Special Pujas',
                style: TextStyle(
                  color: AppColors.cream,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'BOOK AUTHENTIC RITUALS ONLINE',
                style: TextStyle(
                  color: AppColors.gold,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 14),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _templePujas!.length,
                itemBuilder: (context, index) {
                  final puja = _templePujas![index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            color: Colors.black26,
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: puja.image.startsWith('http')
                                ? AppNetworkImage(url: puja.image, fit: BoxFit.cover)
                                : const Icon(Icons.temple_hindu_outlined, color: AppColors.gold),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                puja.name,
                                style: const TextStyle(color: AppColors.cream, fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Benefits: ${puja.benefits}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: AppColors.muted, fontSize: 11),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Text(
                                    '₹${puja.price.toStringAsFixed(0)}',
                                    style: const TextStyle(color: AppColors.goldLight, fontWeight: FontWeight.w800, fontSize: 14),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    '⏱ ${puja.duration}',
                                    style: const TextStyle(color: AppColors.muted, fontSize: 11),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: () {
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (context) => BookingSheet(puja: puja),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.gold,
                            foregroundColor: AppColors.bg,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text('Book', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11)),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      );
    }

  Widget _buildPredefinedOfferingCard(int index) {
    final isSelected = _selectedPredefinedIndex == index;
    final name = _offeringNames[index];
    final amount = _offeringAmounts[index].toStringAsFixed(0);

    return InkWell(
      onTap: () {
        setState(() {
          _selectedPredefinedIndex = index;
          _donationController.text = amount;
          _donationController.selection = TextSelection.fromPosition(
            TextPosition(offset: _donationController.text.length),
          );
        });
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.gold : AppColors.card,
          border: Border.all(
            color: isSelected ? AppColors.gold : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.gold.withValues(alpha: 0.25),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  )
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              name,
              style: TextStyle(
                color: isSelected ? AppColors.bg : AppColors.muted,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
            Text(
              '₹$amount',
              style: TextStyle(
                color: isSelected ? AppColors.bg : AppColors.goldLight,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShopTab() {
    final hasProducts = _shopProducts != null && _shopProducts!.isNotEmpty;
    final hasPrasads = _templePrasads != null && _templePrasads!.isNotEmpty;

    if (!hasProducts && !hasPrasads) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.storefront_rounded, size: 48, color: AppColors.muted),
            SizedBox(height: 12),
            Text(
              'No items or Prasad available at this temple.',
              style: TextStyle(color: AppColors.muted, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasPrasads) ...[
            const Row(
              children: [
                Text(' ', style: TextStyle(fontSize: 16)),
                Text(
                  'SACRED PRASAD',
                  style: TextStyle(
                    color: AppColors.gold,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            for (final prasad in _templePrasads!)
              _buildShopItemCard(prasad),
            const SizedBox(height: 20),
          ],
          if (hasProducts) ...[
            const Row(
              children: [
                Text(' ', style: TextStyle(fontSize: 16)),
                Text(
                  'TEMPLE SHOP ITEMS',
                  style: TextStyle(
                    color: AppColors.gold,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            for (final product in _shopProducts!)
              _buildShopItemCard(product),
          ],
        ],
      ),
    );
  }

  Widget _buildShopItemCard(Product product) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          // Product image
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: Colors.black26,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: product.image != null && product.image!.startsWith('http')
                  ? AppNetworkImage(url: product.image, fit: BoxFit.cover)
                  : const Center(
                      child: Icon(Icons.shopping_bag_outlined, color: AppColors.gold, size: 28),
                    ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  style: const TextStyle(color: AppColors.cream, fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  product.category == 'prashad' ? 'Prasad' : product.category,
                  style: const TextStyle(color: AppColors.muted, fontSize: 11),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '₹${product.price.toStringAsFixed(0)}',
                      style: const TextStyle(color: AppColors.goldLight, fontWeight: FontWeight.w800, fontSize: 15),
                    ),
                    Text(
                      product.stock > 0 ? 'Stock: ${product.stock}' : 'Out of Stock',
                      style: TextStyle(
                        color: product.stock > 0 ? AppColors.green : AppColors.red,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: product.stock > 0 ? () => _showCheckoutSheet(product) : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.gold,
              foregroundColor: AppColors.bg,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Buy', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11)),
          ),
        ],
      ),
    );
  }

  Widget _buildChatTab() {
    return LiveChatTab(templeId: widget.templeId);
  }

  Widget _buildAboutTab(Temple temple) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('About the Temple', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Text(
            temple.description ?? 'A sacred temple dedicated to spiritual contemplation, offerings, and live interactions.',
            style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.5),
          ),
          const SizedBox(height: 24),
          const Text('Details', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          _buildInfoRow(' Location', temple.location),
          _buildInfoRow(' VR Experience', temple.isVrReady ? 'Available (360° Immersive)' : 'Coming Soon'),
          _buildInfoRow(' Created At', temple.createdAt.toLocal().toString().split(' ')[0]),
        ],
      ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String val) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              val,
              textAlign: TextAlign.right,
              style: const TextStyle(color: AppColors.cream, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}


class _CheckoutSheet extends StatefulWidget {
  final Product product;
  const _CheckoutSheet({required this.product});

  @override
  State<_CheckoutSheet> createState() => _CheckoutSheetState();
}

class _CheckoutSheetState extends State<_CheckoutSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _pincodeController = TextEditingController();

  bool _isSubmitting = false;
  String _deliveryMode = 'donate'; // 'donate' or 'home'

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthService>().currentUser;
    if (user != null) {
      _nameController.text = user.name;
      _phoneController.text = user.phone ?? '';
      _addressController.text = '123 Spiritual Lane';
      _cityController.text = 'Varanasi';
      _stateController.text = 'Uttar Pradesh';
      _pincodeController.text = '221001';
    }
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

  Future<void> _submitOrder() async {
    if (_deliveryMode == 'home') {
      if (!_formKey.currentState!.validate()) return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final templeService = context.read<TempleService>();

      final success = await UniversalPaymentModal.show(
        context: context,
        amount: widget.product.price,
        itemName: widget.product.name,
        purposePrefix: 'Purchase',
        referenceId: 'PURCHASE_${DateTime.now().millisecondsSinceEpoch}',
        createRazorpayOrder: () async {
          final order = await templeService.createProductOrder(
            amount: widget.product.price.toInt(),
            receipt: 'product_${widget.product.id}',
          );
          return order['orderId'] as String;
        },
        verifyRazorpayPayment: (paymentResult) async {
          return await templeService.verifyProductPayment(
            razorpayOrderId: paymentResult.orderId,
            razorpayPaymentId: paymentResult.paymentId,
            razorpaySignature: paymentResult.signature,
          );
        },
      );

      if (success == null) {
        setState(() => _isSubmitting = false);
        return;
      }

      // Step 4: Record order with shipping details
      await templeService.placeMockOrder(
        productId: widget.product.id,
        quantity: 1,
        shippingAddress: _deliveryMode == 'home' 
          ? {
              'name': _nameController.text.trim(),
              'phone': _phoneController.text.trim(),
              'address': _addressController.text.trim(),
              'city': _cityController.text.trim(),
              'state': _stateController.text.trim(),
              'pincode': _pincodeController.text.trim(),
            }
          : {
              'name': _nameController.text.trim(),
              'phone': _phoneController.text.trim(),
              'address': 'Donated to Temple',
              'city': 'Temple Location',
              'state': 'Temple State',
              'pincode': '000000',
            },
      );

      setState(() {
        _isSubmitting = false;
      });

      if (mounted) {
        Navigator.of(context).pop();
        _showSuccessDialog();
      }
    } on PaymentException catch (e) {
      setState(() {
        _isSubmitting = false;
      });
      if (mounted) {
        String errorMsg = 'Payment failed: ${e.message}';
        if (e.code == 2 || e.code == 0) {
          errorMsg = 'Payment cancelled by user.';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: AppColors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isSubmitting = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to place order: ${e.toString().replaceAll('ApiException: ', '')}'),
            backgroundColor: AppColors.red,
          ),
        );
      }
    }
  }

  void _showSuccessDialog() {
    final isDonation = _deliveryMode == 'donate';
    final navigator = Navigator.of(context);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF16121F),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: AppColors.green, size: 28),
            const SizedBox(width: 12),
            Text(isDonation ? 'Donation Successful' : 'Order Placed', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          isDonation 
            ? 'Thank you for your generous offering! Your donation of "${widget.product.name}" has been placed successfully.'
            : 'Your order for "${widget.product.name}" has been placed successfully!',
          style: const TextStyle(color: Colors.white70, height: 1.4),
        ),
      ),
    );

    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      // Pop the success dialog and return to root, then open My Orders — using a
      // captured navigator and a single guarded sequence to avoid double-nav.
      navigator.popUntil((route) => route.isFirst);
      navigator.push(
        MaterialPageRoute(builder: (_) => const MyOrdersScreen()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    const inputBorder = OutlineInputBorder(
      borderSide: BorderSide(color: AppColors.border),
      borderRadius: BorderRadius.all(Radius.circular(12)),
    );
    const focusBorder = OutlineInputBorder(
      borderSide: BorderSide(color: AppColors.gold),
      borderRadius: BorderRadius.all(Radius.circular(12)),
    );

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF0F0C16),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          bottom: true,
          child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 48,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              
              Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.black26,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: widget.product.image != null && widget.product.image!.startsWith('http')
                          ? AppNetworkImage(url: widget.product.image, fit: BoxFit.cover)
                          : const Icon(Icons.shopping_bag_outlined, color: AppColors.gold),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.product.name,
                          style: const TextStyle(color: AppColors.cream, fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.product.category.toUpperCase(),
                          style: const TextStyle(color: AppColors.muted, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '₹${widget.product.price.toStringAsFixed(0)}',
                    style: const TextStyle(color: AppColors.goldLight, fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Text(
                'OFFERING TYPE',
                style: TextStyle(color: AppColors.gold, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.5),
              ),
              const SizedBox(height: 12),
              
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _deliveryMode = 'donate'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _deliveryMode == 'donate' ? AppColors.gold.withValues(alpha: 0.15) : AppColors.card,
                          border: Border.all(color: _deliveryMode == 'donate' ? AppColors.gold : AppColors.border),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.temple_hindu_rounded, color: _deliveryMode == 'donate' ? AppColors.gold : AppColors.muted, size: 24),
                            const SizedBox(height: 6),
                            Text('Donate to Temple', style: TextStyle(color: _deliveryMode == 'donate' ? AppColors.gold : AppColors.cream, fontSize: 12, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _deliveryMode = 'home'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _deliveryMode == 'home' ? AppColors.gold.withValues(alpha: 0.15) : AppColors.card,
                          border: Border.all(color: _deliveryMode == 'home' ? AppColors.gold : AppColors.border),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.home_rounded, color: _deliveryMode == 'home' ? AppColors.gold : AppColors.muted, size: 24),
                            const SizedBox(height: 6),
                            Text('Buy for Home', style: TextStyle(color: _deliveryMode == 'home' ? AppColors.gold : AppColors.cream, fontSize: 12, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              if (_deliveryMode == 'home') ...[
                const Text(
                  'SHIPPING ADDRESS',
                  style: TextStyle(color: AppColors.gold, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.5),
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _nameController,
                  style: const TextStyle(color: AppColors.cream, fontSize: 13),
                  decoration: const InputDecoration(labelText: 'Name', labelStyle: TextStyle(color: AppColors.muted, fontSize: 12), enabledBorder: inputBorder, focusedBorder: focusBorder),
                  validator: (val) => val == null || val.trim().isEmpty ? 'Please enter name' : null,
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _phoneController,
                  style: const TextStyle(color: AppColors.cream, fontSize: 13),
                  decoration: const InputDecoration(labelText: 'Phone', labelStyle: TextStyle(color: AppColors.muted, fontSize: 12), enabledBorder: inputBorder, focusedBorder: focusBorder),
                  validator: (val) => val == null || val.trim().isEmpty ? 'Please enter phone' : null,
                ),
                const SizedBox(height: 12),


                TextFormField(
                  controller: _addressController,
                  style: const TextStyle(color: AppColors.cream, fontSize: 13),
                  decoration: const InputDecoration(labelText: 'Street Address', labelStyle: TextStyle(color: AppColors.muted, fontSize: 12), enabledBorder: inputBorder, focusedBorder: focusBorder),
                  validator: (val) => val == null || val.trim().isEmpty ? 'Please enter address' : null,
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _cityController,
                        style: const TextStyle(color: AppColors.cream, fontSize: 13),
                        decoration: const InputDecoration(labelText: 'City', labelStyle: TextStyle(color: AppColors.muted, fontSize: 12), enabledBorder: inputBorder, focusedBorder: focusBorder),
                        validator: (val) => val == null || val.trim().isEmpty ? 'City' : null,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _stateController,
                        style: const TextStyle(color: AppColors.cream, fontSize: 13),
                        decoration: const InputDecoration(labelText: 'State', labelStyle: TextStyle(color: AppColors.muted, fontSize: 12), enabledBorder: inputBorder, focusedBorder: focusBorder),
                        validator: (val) => val == null || val.trim().isEmpty ? 'State' : null,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _pincodeController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: AppColors.cream, fontSize: 13),
                        decoration: const InputDecoration(labelText: 'Pincode', labelStyle: TextStyle(color: AppColors.muted, fontSize: 12), enabledBorder: inputBorder, focusedBorder: focusBorder),
                        validator: (val) => val == null || val.trim().isEmpty ? 'Pincode' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],
              
              if (_deliveryMode == 'donate') ...[
                TextFormField(
                  controller: _nameController,
                  style: const TextStyle(color: AppColors.cream, fontSize: 13),
                  decoration: const InputDecoration(labelText: 'Name for Offering', labelStyle: TextStyle(color: AppColors.muted, fontSize: 12), enabledBorder: inputBorder, focusedBorder: focusBorder),
                ),
                const SizedBox(height: 24),
              ],

              Container(
                height: 50,
                decoration: BoxDecoration(
                  color: AppColors.gold,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.gold.withValues(alpha: 0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitOrder,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(AppColors.bg)),
                        )
                      : const Text(
                          'CONFIRM PURCHASE',
                          style: TextStyle(
                            color: AppColors.bg,
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                            letterSpacing: 1.2,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
      ),
      ),
    );
  }
}
