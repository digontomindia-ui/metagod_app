import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../models/user.dart';
import '../utils/app_logger.dart';
import 'api_client.dart';

class AuthService extends ChangeNotifier {
  late final ApiClient _apiClient;
  
  User? _currentUser;
  bool _isLoading = false;
  bool _isInitialized = false;

  AuthService() {
    _apiClient = ApiClient(onSessionExpired: _handleSessionExpired);
    loadSession();
  }

  User? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;

  ApiClient get apiClient => _apiClient;

  // Manually refresh user profile to update wallet balances etc.
  Future<void> refreshProfile() => _fetchUserProfile();

  // Load session from SharedPreferences on startup
  Future<void> loadSession() async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString('user_data');
      final accessToken = await _apiClient.getAccessToken();

      if (userJson != null && accessToken != null) {
        _currentUser = User.fromJson(jsonDecode(userJson) as Map<String, dynamic>);
        notifyListeners();
        
        // Refresh profile from API in the background to ensure it is accurate
        _fetchUserProfile();
      }
    } catch (e) {
      logE('Failed to load session', e);
    } finally {
      _isLoading = false;
      _isInitialized = true;
      notifyListeners();
    }
  }

  // Fetch the current user profile from `/auth/me`
  Future<void> _fetchUserProfile() async {
    try {
      final response = await _apiClient.get('/auth/me');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final userData = data['user'] ?? data['data'];
        if (data['success'] == true && userData != null) {
          final user = User.fromJson(userData as Map<String, dynamic>);
          _currentUser = user;
          
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('user_data', jsonEncode(user.toJson()));
          notifyListeners();
        }
      }
    } catch (e) {
      logE('Failed to refresh user profile', e);
    }
  }

  // Upgrade Membership via backend
  Future<bool> upgradeMembership() async {
    try {
      final response = await _apiClient.post('/users/upgrade-membership');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          await _fetchUserProfile();
          return true;
        }
      }
      return false;
    } catch (e) {
      logE('Failed to upgrade membership', e);
      return false;
    }
  }

  // Login implementation
  Future<void> login(String email, String password) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _apiClient.post(
        '/auth/login',
        body: {'email': email, 'password': password},
      );

      // Safely parse response — server may return HTML during downtime
      Map<String, dynamic> body;
      try {
        body = jsonDecode(response.body) as Map<String, dynamic>;
      } on FormatException {
        throw ApiException(
          'Server is temporarily unavailable. Please try again in a moment.',
          response.statusCode,
        );
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (body['success'] == true) {
          final data = body['data'] is Map ? body['data'] : null;
          
          final tokensMap = (data != null ? data['tokens'] : body['tokens']) as Map<String, dynamic>?;
          
          final accessToken = tokensMap?['accessToken'] as String? ?? 
                              (data != null ? data['accessToken'] as String? : null) ?? 
                              body['accessToken'] as String? ?? 
                              body['token'] as String?;
                              
          final refreshToken = tokensMap?['refreshToken'] as String? ?? 
                               (data != null ? data['refreshToken'] as String? : null) ?? 
                               body['refreshToken'] as String?;
                               
          final userMap = (data != null ? data['user'] : null) as Map<String, dynamic>? ?? 
                          body['user'] as Map<String, dynamic>?;

          if (accessToken != null && userMap != null) {
            final user = User.fromJson(userMap);
            
            // Save locally
            await _apiClient.saveTokens(
              accessToken: accessToken, 
              refreshToken: refreshToken ?? '',
            );
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('user_data', jsonEncode(user.toJson()));

            _currentUser = user;
            notifyListeners();
            return;
          }
        }
      }
      
      final errorMsg = body['message'] as String? ?? 'Failed to login';
      throw ApiException(errorMsg, response.statusCode);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Register implementation
  Future<void> register(String name, String email, String password, String? phone) async {
    _isLoading = true;
    notifyListeners();

    try {
      final bodyPayload = {
        'name': name,
        'email': email,
        'password': password,
        'role': 'USER',
      };
      if (phone != null && phone.isNotEmpty) {
        bodyPayload['phone'] = phone;
      }

      final response = await _apiClient.post(
        '/auth/register',
        body: bodyPayload,
      );

      // Safely parse response — server may return HTML during downtime
      Map<String, dynamic> body;
      try {
        body = jsonDecode(response.body) as Map<String, dynamic>;
      } on FormatException {
        throw ApiException(
          'Server is temporarily unavailable. Please try again in a moment.',
          response.statusCode,
        );
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (body['success'] == true && body['user'] != null) {
          final userMap = body['user'] as Map<String, dynamic>;
          final tokensMap = body['tokens'] as Map<String, dynamic>?;
          
          final accessToken = tokensMap?['accessToken'] as String? ?? body['accessToken'] as String?;
          final refreshToken = tokensMap?['refreshToken'] as String? ?? body['refreshToken'] as String?;

          if (accessToken != null && refreshToken != null) {
            final user = User.fromJson(userMap);
            
            await _apiClient.saveTokens(accessToken: accessToken, refreshToken: refreshToken);
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('user_data', jsonEncode(user.toJson()));

            _currentUser = user;
            notifyListeners();
            return;
          }
        }
        
        // Fallback to manual login if response structure differs
        await login(email, password);
        return;
      }

      final errorMsg = body['message'] as String? ?? 'Failed to register';
      throw ApiException(errorMsg, response.statusCode);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Send OTP (for Forgot Password / Verify Email)
  Future<void> sendOtp(String email) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _apiClient.post(
        '/auth/send-otp',
        body: {'email': email},
      );

      final body = jsonDecode(response.body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        return;
      }

      final errorMsg = body['message'] as String? ?? 'Failed to send OTP';
      throw ApiException(errorMsg, response.statusCode);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Verify OTP
  // Note: if it returns credentials, save them so user is logged in
  Future<bool> verifyOtp(String email, String otp) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _apiClient.post(
        '/auth/verify-otp',
        body: {'email': email, 'otp': otp},
      );

      final body = jsonDecode(response.body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        if (body['success'] == true) {
          final tokensMap = body['tokens'] as Map<String, dynamic>?;
          
          final accessToken = tokensMap?['accessToken'] as String? ?? 
                              body['accessToken'] as String? ?? 
                              body['token'] as String?;
                              
          final refreshToken = tokensMap?['refreshToken'] as String? ?? 
                               body['refreshToken'] as String?;
                               
          final userMap = body['user'] as Map<String, dynamic>? ?? 
                          body['data']?['user'] as Map<String, dynamic>?;

          if (accessToken != null) {
            await _apiClient.saveTokens(
              accessToken: accessToken,
              refreshToken: refreshToken ?? '',
            );
            if (userMap != null) {
              final user = User.fromJson(userMap);
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString('user_data', jsonEncode(user.toJson()));
              _currentUser = user;
            }
            notifyListeners();
          }
        }
        return true;
      }

      final errorMsg = body['message'] as String? ?? 'Failed to verify OTP';
      throw ApiException(errorMsg, response.statusCode);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Change Password
  Future<void> changePassword(String currentPassword, String newPassword) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _apiClient.post(
        '/auth/change-password',
        body: {
          'currentPassword': currentPassword,
          'newPassword': newPassword,
        },
      );

      final body = jsonDecode(response.body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        return;
      }

      final errorMsg = body['message'] as String? ?? 'Failed to change password';
      throw ApiException(errorMsg, response.statusCode);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Update Profile
  Future<bool> updateProfile(String name, String phone) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _apiClient.put(
        '/users/profile',
        body: {'name': name, 'phone': phone},
      );

      final body = jsonDecode(response.body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        if (body['success'] == true) {
          // The backend returns the updated user object directly
          if (body['user'] != null) {
            final updatedUser = User.fromJson(body['user'] as Map<String, dynamic>);
            _currentUser = updatedUser;
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('user_data', jsonEncode(updatedUser.toJson()));
            notifyListeners();
          } else {
            await _fetchUserProfile();
          }
          return true;
        }
      }

      final errorMsg = body['message'] as String? ?? 'Failed to update profile';
      throw ApiException(errorMsg, response.statusCode);
    } catch (e) {
      logE('Failed to update profile', e);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> uploadProfilePicture(String filePath) async {
    _isLoading = true;
    notifyListeners();

    try {
      final token = await _apiClient.getAccessToken();
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiClient.baseUrl}/upload/image?folder=users'),
      );
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }
      
      final ext = filePath.split('.').last.toLowerCase();
      String mimeType = 'jpeg';
      if (ext == 'png') mimeType = 'png';
      else if (ext == 'webp') mimeType = 'webp';

      request.files.add(await http.MultipartFile.fromPath(
        'image', 
        filePath,
        contentType: MediaType('image', mimeType),
      ));

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);
      
      final body = jsonDecode(response.body);
      logD('Upload response status: ${response.statusCode}');
      if (response.statusCode == 200 || response.statusCode == 201) {
        if (body['success'] == true) {
          final imageUrl = body['data']['url'];

          final updateResponse = await _apiClient.put(
            '/users/profile',
            body: {'profileImage': imageUrl},
          );

          final updateBody = jsonDecode(updateResponse.body);
          logD('Update profile response status: ${updateResponse.statusCode}');
          if (updateResponse.statusCode == 200 || updateResponse.statusCode == 201) {
            if (updateBody['success'] == true) {
              if (updateBody['user'] != null) {
                final updatedUser = User.fromJson(updateBody['user'] as Map<String, dynamic>);
                _currentUser = updatedUser;
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('user_data', jsonEncode(updatedUser.toJson()));
                notifyListeners();
              } else {
                await _fetchUserProfile();
              }
              return true;
            }
          }
        }
      }
      return false;
    } catch (e) {
      logE('Failed to upload profile picture', e);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Logout implementation
  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _apiClient.post('/auth/logout');
    } catch (e) {
      logE('Logout API failed', e);
    } finally {
      await _clearLocalSession();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _clearLocalSession() async {
    await _apiClient.clearTokens();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_data');
    _currentUser = null;
  }

  void _handleSessionExpired() {
    _clearLocalSession().then((_) {
      notifyListeners();
    });
  }
}
