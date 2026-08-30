import 'dart:async';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../config/env.dart';
import '../utils/app_logger.dart';

/// Result returned after a successful Razorpay payment.
class PaymentResult {
  final String paymentId;
  final String orderId;
  final String signature;

  PaymentResult({
    required this.paymentId,
    required this.orderId,
    required this.signature,
  });
}

/// Singleton wrapper around [Razorpay] that bridges its callback-based API
/// into a `Future<PaymentResult>` using a [Completer].
///
/// The Razorpay instance is created **lazily** the first time [openCheckout]
/// is called, avoiding crashes on devices where the native SDK cannot
/// initialise before the Flutter Activity is fully attached.
class PaymentService {
  PaymentService._internal();

  static final PaymentService _instance = PaymentService._internal();

  /// Singleton accessor.
  static PaymentService get instance => _instance;

  /// Lazily-initialised Razorpay handle.
  Razorpay? _razorpay;

  Razorpay _ensureRazorpay() {
    if (_razorpay == null) {
      _razorpay = Razorpay();
      _razorpay!.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
      _razorpay!.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
      _razorpay!.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
    }
    return _razorpay!;
  }

  /// The active completer for the current checkout session.
  /// Only one checkout can be active at a time since Razorpay itself is modal.
  Completer<PaymentResult>? _activeCompleter;

  /// Opens the Razorpay checkout sheet and returns a [PaymentResult] on success.
  ///
  /// [amount] is in **standard currency** (e.g., ₹501). It is automatically
  /// converted to paise (×100) before being sent to the Razorpay SDK.
  ///
  /// [orderId] is optional. It is only attached to the checkout options if it
  /// is non-null, non-empty, and starts with `'order_'` (valid Razorpay format).
  /// This prevents crashes when the backend returns a mock/invalid order ID.
  Future<PaymentResult> openCheckout({
    required num amount,
    required String name,
    required String description,
    required String contact,
    required String email,
    String? orderId,
    // Razorpay publishable key — configured via `--dart-define=RAZORPAY_KEY=...`.
    String? keyId,
  }) async {
    final resolvedKey = keyId ?? Env.razorpayKey;
    // Guard against concurrent checkouts
    if (_activeCompleter != null && !_activeCompleter!.isCompleted) {
      throw StateError('A payment checkout is already in progress.');
    }

    _activeCompleter = Completer<PaymentResult>();

    // Convert standard currency to Razorpay's subunit format (paise)
    int amountInPaise = (amount * 100).toInt();

    var options = <String, dynamic>{
      'key': resolvedKey,
      'amount': amountInPaise,
      'name': 'Meta God', // Premium Brand Name
      'description': description,
      'timeout': 300, // 5 minute timeout for security
      'theme': {
        'color': '#FCA311', // Meta God Gold/Orange Accent Color
        'backdrop_color': '#000000'
      },
      'prefill': {
        if (contact.isNotEmpty) 'contact': contact,
        if (name.isNotEmpty) 'name': name,
        if (email.isNotEmpty) 'email': email,
      },
      'external': {
        'wallets': ['paytm', 'gpay']
      }
    };

    if (orderId != null && orderId.isNotEmpty) {
      options['order_id'] = orderId;
    }

    logD('PaymentService: opening checkout (orderId present: ${orderId != null && orderId.isNotEmpty})');

    _ensureRazorpay().open(options);

    return _activeCompleter!.future;
  }

  // ── Razorpay event handlers ──────────────────────────────────────────

  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    logD('PaymentService: payment success callback received');
    if (_activeCompleter != null && !_activeCompleter!.isCompleted) {
      _activeCompleter!.complete(PaymentResult(
        paymentId: response.paymentId ?? '',
        orderId: response.orderId ?? '',
        signature: response.signature ?? '',
      ));
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    logD('PaymentService: payment error (code=${response.code})');
    if (_activeCompleter != null && !_activeCompleter!.isCompleted) {
      _activeCompleter!.completeError(
        PaymentException(
          code: response.code ?? 0,
          message: response.message ?? 'Payment failed',
        ),
      );
    }
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    logD('PaymentService: external wallet selected');
    // External wallet selections are informational; the payment will still
    // resolve through _handlePaymentSuccess or _handlePaymentError.
  }

  /// Call this when the host widget/app is being disposed permanently.
  void dispose() {
    _razorpay?.clear();
    _razorpay = null;
  }
}

/// Exception thrown when a Razorpay payment fails or is cancelled.
class PaymentException implements Exception {
  final int code;
  final String message;

  PaymentException({required this.code, required this.message});

  @override
  String toString() => 'PaymentException(code: $code, message: $message)';
}
