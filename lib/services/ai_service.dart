import 'dart:convert';
import '../utils/app_logger.dart';
import 'api_client.dart';

/// Singleton service for the Sanctuary Oracle AI chat proxy.
class AiService {
  AiService._internal();

  static final AiService _instance = AiService._internal();

  static AiService get instance => _instance;

  ApiClient? _apiClient;
  ApiClient get _client => _apiClient ??= ApiClient();

  Future<String> askOracle({
    required String message,
    required List<Map<String, String>> history,
  }) async {
    try {
      final response = await _client.post(
        '/chat',
        body: {
          'message': message,
          'include_jyotish': true,
          'history': history,
        },
      );

      final body = jsonDecode(response.body);
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        if (body['success'] == true && body['data'] != null) {
          return body['data']['reply'] as String? ??
              'The Oracle is in deep meditation. Please try again.';
        }
      } else {
        // Handle explicit backend errors
        if (body['message'] != null) {
          return body['message'] as String;
        }
      }

      logD('AiService: Unexpected status ${response.statusCode}');
      return 'The Oracle could not process your request. Please try again later.';
    } catch (e) {
      logE('AiService error', e);
      return 'Connection to the Oracle was disrupted. Please check your network and try again.';
    }
  }
}
