import 'dart:convert';
import 'api_client.dart';

class WalletService {
  final ApiClient _apiClient;

  WalletService(this._apiClient);

  Future<Map<String, dynamic>> fetchWalletDetails() async {
    final response = await _apiClient.get('/wallet/details');
    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      if (body['success'] == true) {
        return body;
      }
    }
    throw ApiException('Failed to fetch wallet details', response.statusCode);
  }

  Future<Map<String, dynamic>> payWithWallet({
    required double amount,
    required String purpose,
    required String referenceId,
  }) async {
    final response = await _apiClient.post(
      '/wallet/pay',
      body: {
        'amount': amount,
        'purpose': purpose,
        'referenceId': referenceId,
      },
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final body = jsonDecode(response.body);
      if (body['success'] == true) {
        return body;
      }
    }
    final errorBody = jsonDecode(response.body);
    throw ApiException(errorBody['message'] ?? 'Wallet payment failed', response.statusCode);
  }

  Future<bool> addFundsWithGiftCard({
    required double amount,
    required String giftCardCode,
  }) async {
    final response = await _apiClient.post(
      '/wallet/add-funds',
      body: {
        'amount': amount,
        'giftCardCode': giftCardCode,
      },
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final body = jsonDecode(response.body);
      return body['success'] == true;
    }
    final errorBody = jsonDecode(response.body);
    throw ApiException(errorBody['message'] ?? 'Failed to add funds', response.statusCode);
  }

  Future<bool> verifyRecharge({
    required String razorpayOrderId,
    required String razorpayPaymentId,
    required String razorpaySignature,
    required double amount,
  }) async {
    final response = await _apiClient.post(
      '/wallet/verify-recharge',
      body: {
        'razorpay_order_id': razorpayOrderId,
        'razorpay_payment_id': razorpayPaymentId,
        'razorpay_signature': razorpaySignature,
        'amount': amount,
      },
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final body = jsonDecode(response.body);
      return body['success'] == true;
    }
    throw ApiException('Failed to verify recharge', response.statusCode);
  }
}
