import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/config.dart';

class ApiService {
  static final _client = http.Client();
  static String get _base => Config.backendUrl;

  // POST /api/sos — returns the saved record with id
  static Future<Map<String,dynamic>> submitSos({
    required double lat,
    required double lng,
    required String message,
    required String source,
    String? nodeId,
    Map<String,dynamic>? metadata,
  }) async {
    final body = {
      'lat': lat,
      'lng': lng,
      'message': message,
      'source': source,
      'node_id': nodeId,       // send null when not iot_node
      'metadata': metadata ?? {},
    };
    
    final resp = await _client
      .post(Uri.parse('$_base/api/sos'),
            headers: {'Content-Type':'application/json'},
            body: jsonEncode(body))
      .timeout(const Duration(seconds: Config.apiTimeoutSeconds));
      
    if (resp.statusCode == 201) return jsonDecode(resp.body);
    throw Exception('SOS submit failed: HTTP ${resp.statusCode} — ${resp.body}');
  }

  // GET /health — returns {status, db, redis}
  static Future<Map<String,dynamic>> checkHealth() async {
    final resp = await _client
      .get(Uri.parse('$_base/health'))
      .timeout(const Duration(seconds: 5));
    return jsonDecode(resp.body);
  }

  // Generic POST for /api/status etc.
  static Future<Map<String,dynamic>?> post(String endpoint, Map<String,dynamic> body) async {
    try {
      final resp = await _client
        .post(Uri.parse('$_base$endpoint'),
              headers: {'Content-Type':'application/json'},
              body: jsonEncode(body))
        .timeout(const Duration(seconds: Config.apiTimeoutSeconds));
      if (resp.statusCode == 200 || resp.statusCode == 201) {
        return jsonDecode(resp.body);
      }
    } catch (e) {
      print('ApiService.post failed: $e');
    }
    return null;
  }
}