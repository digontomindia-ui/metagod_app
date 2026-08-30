import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/address.dart';
import '../utils/app_logger.dart';
import 'api_client.dart';

class AddressService extends ChangeNotifier {
  final ApiClient _apiClient;
  List<Address> _addresses = [];
  bool _isLoading = false;
  String? _error;

  AddressService(this._apiClient);

  List<Address> get addresses => _addresses;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Address? get defaultAddress {
    if (_addresses.isEmpty) return null;
    try {
      return _addresses.firstWhere((a) => a.isDefault);
    } catch (_) {
      return _addresses.first;
    }
  }

  Future<void> fetchAddresses() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _apiClient.get('/addresses');
      final data = jsonDecode(response.body);
      
      if (data['success'] == true && data['data'] != null) {
        _addresses = (data['data'] as List)
            .map((item) => Address.fromJson(item))
            .toList();
      } else {
        _addresses = [];
      }
    } catch (e) {
      _error = e.toString().replaceAll('ApiException: ', '');
      logE('Error fetching addresses', e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> addAddress(Address address) async {
    try {
      final response = await _apiClient.post('/addresses', body: address.toJson());
      final data = jsonDecode(response.body);
      
      if (data['success'] == true) {
        await fetchAddresses();
        return true;
      }
      throw Exception(data['message'] ?? 'Failed to add address');
    } catch (e) {
      throw Exception(e.toString().replaceAll('ApiException: ', ''));
    }
  }

  Future<bool> updateAddress(Address address) async {
    try {
      final response = await _apiClient.put('/addresses/${address.id}', body: address.toJson());
      final data = jsonDecode(response.body);
      
      if (data['success'] == true) {
        await fetchAddresses();
        return true;
      }
      throw Exception(data['message'] ?? 'Failed to update address');
    } catch (e) {
      throw Exception(e.toString().replaceAll('ApiException: ', ''));
    }
  }

  Future<bool> deleteAddress(String id) async {
    try {
      final response = await _apiClient.delete('/addresses/$id');
      final data = jsonDecode(response.body);
      
      if (data['success'] == true) {
        await fetchAddresses();
        return true;
      }
      throw Exception(data['message'] ?? 'Failed to delete address');
    } catch (e) {
      throw Exception(e.toString().replaceAll('ApiException: ', ''));
    }
  }

  Future<bool> setDefaultAddress(String id) async {
    try {
      final response = await _apiClient.patch('/addresses/$id/set-default');
      final data = jsonDecode(response.body);
      
      if (data['success'] == true) {
        await fetchAddresses();
        return true;
      }
      throw Exception(data['message'] ?? 'Failed to set default address');
    } catch (e) {
      throw Exception(e.toString().replaceAll('ApiException: ', ''));
    }
  }
}
