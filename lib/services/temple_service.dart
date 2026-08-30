import 'dart:convert';
import '../models/temple.dart';
import '../models/product.dart';
import '../models/vr_experience.dart';
import '../models/hero_slide.dart';
import '../models/puja.dart';
import '../models/booking.dart';
import 'api_client.dart';

class TempleService {
  final ApiClient _apiClient;

  TempleService(this._apiClient);

  // Check if system is in maintenance mode
  Future<bool> checkMaintenanceMode() async {
    try {
      final response = await _apiClient.get('/settings');
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body['success'] == true && body['data'] != null) {
          return body['data']['maintenanceMode'] == true;
        }
      }
      return false;
    } catch (_) {
      return false; // Fail open if settings can't be fetched
    }
  }

  // Fetch all temples
  Future<List<Temple>> fetchTemples() async {
    final response = await _apiClient.get('/temples');
    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      if (body['success'] == true && body['data'] != null) {
        final List list = body['data'] as List;
        return list.map((item) => Temple.fromJson(item as Map<String, dynamic>)).toList();
      }
    }
    throw ApiException('Failed to fetch temples', response.statusCode);
  }

  // Fetch a temple detail
  Future<Temple> fetchTempleById(String id) async {
    final response = await _apiClient.get('/temples/$id');
    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      if (body['success'] == true && body['data'] != null) {
        return Temple.fromJson(body['data'] as Map<String, dynamic>);
      }
    }
    throw ApiException('Failed to fetch temple detail', response.statusCode);
  }

  // Fetch products for a specific temple
  Future<List<Product>> fetchTempleProducts(String templeId) async {
    final response = await _apiClient.get('/temples/$templeId/products');
    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      if (body['success'] == true && body['data'] != null) {
        final List list = body['data'] as List;
        return list.map((item) => Product.fromJson(item as Map<String, dynamic>)).toList();
      }
    }
    throw ApiException('Failed to fetch temple products', response.statusCode);
  }

  // Record a mock donation
  Future<bool> donateMock({
    required String templeId,
    required double amount,
    required String donorName,
    required String donorEmail,
    required String donorPhone,
    required String offeringName,
    required String donationType,
  }) async {
    final response = await _apiClient.post(
      '/donations/mock-save',
      body: {
        'templeId': templeId,
        'amount': amount,
        'donorName': donorName,
        'donorEmail': donorEmail,
        'donorPhone': donorPhone,
        'offeringName': offeringName,
        'donationType': donationType,
      },
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final body = jsonDecode(response.body);
      return body['success'] == true;
    }
    throw ApiException('Failed to complete mock donation', response.statusCode);
  }

  // Place mock order
  Future<bool> placeMockOrder({
    required String productId,
    required int quantity,
    required Map<String, String> shippingAddress,
  }) async {
    final response = await _apiClient.post(
      '/orders',
      body: {
        'productId': productId,
        'type': 'SELF',
        'quantity': quantity,
        'shippingAddress': shippingAddress,
      },
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final body = jsonDecode(response.body);
      return body['success'] == true;
    }
    String errorMsg = 'Failed to place order';
    try {
      final body = jsonDecode(response.body);
      if (body['message'] != null) errorMsg = body['message'];
    } catch (_) {}
    throw ApiException(errorMsg, response.statusCode);
  }

  // Book a Consultation
  Future<bool> bookConsultation({
    required String expertId,
    required String expertName,
    required String type, // 'chat', 'audio', 'video'
    required int duration,
    required double price,
    required String customerName,
  }) async {
    final response = await _apiClient.post(
      '/consultations/buy',
      body: {
        'expertId': expertId,
        'minutes': duration,
        'amount': price.toInt(),
        'type': type,
      },
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final body = jsonDecode(response.body);
      return body['success'] == true;
    }
    throw ApiException('Failed to book consultation', response.statusCode);
  }

  Future<Map<String, dynamic>?> getConsultationBalance(String expertId) async {
    try {
      final response = await _apiClient.get('/consultations/balance/$expertId');
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body['success'] == true) {
          return body['data'];
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Fetch all VR experiences
  Future<List<VrExperience>> fetchVrExperiences() async {
    final response = await _apiClient.get('/vr-experiences');
    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      if (body['success'] == true && body['data'] != null) {
        final List list = body['data'] as List;
        return list.map((item) => VrExperience.fromJson(Map<String, dynamic>.from(item as Map))).toList();
      }
    }
    throw ApiException('Failed to fetch VR experiences', response.statusCode);
  }

  // Fetch all Hero Slides
  Future<List<HeroSlide>> fetchHeroSlides() async {
    final response = await _apiClient.get('/hero');
    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      if (body['success'] == true && body['data'] != null) {
        final List list = body['data'] as List;
        return list.map((item) => HeroSlide.fromJson(Map<String, dynamic>.from(item as Map))).toList();
      }
    }
    throw ApiException('Failed to fetch hero slides', response.statusCode);
  }

  // Fetch all pujas
  Future<List<Puja>> fetchPujas() async {
    final response = await _apiClient.get('/pujas');
    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      if (body['success'] == true && body['data'] != null) {
        final List list = body['data'] as List;
        return list.map((item) => Puja.fromJson(Map<String, dynamic>.from(item as Map))).toList();
      }
    }
    throw ApiException('Failed to fetch pujas', response.statusCode);
  }

  // Book a puja
  Future<bool> bookPuja({
    required String pujaId,
    required String templeId,
    required String date,
    required String name,
    required String phone,
    required String gothra,
    required String sankalp,
    required double price,
  }) async {
    final response = await _apiClient.post(
      '/puja-orders',
      body: {
        'itemType': 'Puja',
        'itemId': pujaId,
        'templeId': templeId,
        'customerName': name,
        'customerPhone': phone,
        'price': price.toInt(),
      },
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final body = jsonDecode(response.body);
      return body['success'] == true;
    }
    throw ApiException('Failed to book puja', response.statusCode);
  }

  // Fetch my puja bookings
  Future<List<Booking>> fetchBookings() async {
    final response = await _apiClient.get('/puja-orders');
    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      if (body['success'] == true && body['data'] != null) {
        final List list = body['data'] as List;
        return list.map((item) => Booking.fromJson(Map<String, dynamic>.from(item as Map))).toList();
      }
    }
    throw ApiException('Failed to fetch bookings', response.statusCode);
  }

  // Fetch marketplace categories (and add prashad)
  Future<List<Map<String, dynamic>>> fetchCategories() async {
    final response = await _apiClient.get('/categories');
    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      if (body['success'] == true && body['data'] != null) {
        final List list = body['data'] as List;
        final categories = list.map((item) {
          if (item is Map) {
            return Map<String, dynamic>.from(item);
          }
          return {'name': item.toString(), 'filterKey': item.toString()};
        }).toList();
        
        if (!categories.any((c) => c['filterKey'] == 'prashad')) {
          categories.add({'name': 'Prashad', 'filterKey': 'prashad'});
        }
        return categories;
      }
    }
    throw ApiException('Failed to fetch categories', response.statusCode);
  }

  // Fetch all marketplace products
  Future<List<Product>> fetchProducts() async {
    final response = await _apiClient.get('/products');
    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      if (body['success'] == true && body['data'] != null) {
        final List list = body['data'] as List;
        return list.map((item) => Product.fromJson(Map<String, dynamic>.from(item as Map))).toList();
      }
    }
    throw ApiException('Failed to fetch marketplace products', response.statusCode);
  }

  // Fetch all prasad offerings as products
  Future<List<Product>> fetchPrasadAsProducts() async {
    final response = await _apiClient.get('/prasad');
    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      if (body['success'] == true && body['data'] != null) {
        final List list = body['data'] as List;
        return list.map((item) {
          final map = Map<String, dynamic>.from(item as Map);
          map['category'] = 'prashad';
          map['isTempleShop'] = false;
          map['stock'] = map['stock'] ?? 10;
          return Product.fromJson(map);
        }).toList();
      }
    }
    throw ApiException('Failed to fetch prasad products', response.statusCode);
  }

  // ── Razorpay Payment Integration ─────────────────────────────────────

  /// Create a Razorpay order for a donation.
  /// Returns the raw order map: {id, entity, amount (paise), currency, receipt}.
  Future<Map<String, dynamic>> createDonationOrder({required int amount}) async {
    final response = await _apiClient.post(
      '/donations/create-order',
      body: {'amount': amount},
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final body = jsonDecode(response.body);
      if (body['success'] == true && body['data'] != null) {
        return Map<String, dynamic>.from(body['data'] as Map);
      }
    }
    throw ApiException('Failed to create donation order', response.statusCode);
  }

  /// Verify a donation payment with Razorpay signature + persist the donation record.
  Future<bool> verifyDonationPayment({
    required String razorpayOrderId,
    required String razorpayPaymentId,
    required String razorpaySignature,
    required Map<String, dynamic> donationData,
  }) async {
    final response = await _apiClient.post(
      '/donations/verify-payment',
      body: {
        'razorpay_order_id': razorpayOrderId,
        'razorpay_payment_id': razorpayPaymentId,
        'razorpay_signature': razorpaySignature,
        'donationData': donationData,
      },
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final body = jsonDecode(response.body);
      return body['success'] == true;
    }
    throw ApiException('Failed to verify donation payment', response.statusCode);
  }

  /// Create a generic Razorpay order for a product purchase.
  /// Returns the raw order map: {orderId, amount (paise), currency}.
  Future<Map<String, dynamic>> createProductOrder({
    required int amount,
    String? receipt,
  }) async {
    final response = await _apiClient.post(
      '/razorpay/create-order',
      body: {
        'amount': amount,
        'currency': 'INR',
        // ignore: use_null_aware_elements
        if (receipt != null) 'receipt': receipt,
      },
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final body = jsonDecode(response.body);
      if (body['success'] == true) {
        // The API returns orderId at root level, not nested under data
        return {
          'orderId': body['orderId'],
          'amount': body['amount'],
          'currency': body['currency'] ?? 'INR',
        };
      }
    }
    throw ApiException('Failed to create product order', response.statusCode);
  }

  /// Verify a generic Razorpay product payment.
  Future<bool> verifyProductPayment({
    required String razorpayOrderId,
    required String razorpayPaymentId,
    required String razorpaySignature,
  }) async {
    final response = await _apiClient.post(
      '/razorpay/verify-payment',
      body: {
        'razorpay_order_id': razorpayOrderId,
        'razorpay_payment_id': razorpayPaymentId,
        'razorpay_signature': razorpaySignature,
      },
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final body = jsonDecode(response.body);
      return body['success'] == true;
    }
    throw ApiException('Failed to verify product payment', response.statusCode);
  }

  // ── Phase 4: Dashboard & Profile Hydration ─────────────────────────────

  /// Fetch the list of spiritual experts (pandits).
  /// Returns raw maps matching the backend schema.
  Future<List<Map<String, dynamic>>> fetchExperts() async {
    final response = await _apiClient.get('/experts');

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      if (body['success'] == true && body['data'] != null) {
        return List<Map<String, dynamic>>.from(
          (body['data'] as List).map((e) => Map<String, dynamic>.from(e as Map)),
        );
      }
    }
    throw ApiException('Failed to fetch experts', response.statusCode);
  }

  /// Fetch all puja/prasad orders for the current user.
  /// Returns the raw list + a convenience count.
  Future<List<Map<String, dynamic>>> fetchPujaOrders() async {
    final response = await _apiClient.get('/puja-orders');

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      if (body['success'] == true && body['data'] != null) {
        return List<Map<String, dynamic>>.from(
          (body['data'] as List).map((e) => Map<String, dynamic>.from(e as Map)),
        );
      }
    }
    throw ApiException('Failed to fetch puja orders', response.statusCode);
  }

  /// Fetch the unread notification count for the badge.
  Future<int> fetchUnreadNotificationCount() async {
    final response = await _apiClient.get('/notifications/unread/count');

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      if (body['success'] == true) {
        return (body['unreadCount'] as num?)?.toInt() ?? 0;
      }
    }
    return 0; // Silently default to 0 on failure — don't crash the UI
  }

  /// Fetch all physical marketplace/product orders for the current user.
  Future<List<Map<String, dynamic>>> fetchMyOrders() async {
    final response = await _apiClient.get('/orders/my');

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      if (body['success'] == true && body['data'] != null) {
        return List<Map<String, dynamic>>.from(
          (body['data'] as List).map((e) => Map<String, dynamic>.from(e as Map)),
        );
      }
    }
    throw ApiException('Failed to fetch user orders', response.statusCode);
  }
}
