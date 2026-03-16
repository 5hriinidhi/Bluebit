import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/config.dart';

class ApiService {
  // Existing submitSos method...
  static Future<Map<String, dynamic>?> submitSos({
    required double lat,
    required double lng,
    required String message,
    required String source,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final response = await http.post(
        Uri.parse("${Config.backendUrl}/api/sos"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "lat": lat,
          "lng": lng,
          "message": message,
          "source": source,
          "metadata": metadata ?? {},
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // NEW: Add this generic post method for Task 5C
  static Future<Map<String, dynamic>?> post(String endpoint, Map<String, dynamic> data) async {
    try {
      final response = await http.post(
        Uri.parse("${Config.backendUrl}$endpoint"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(data),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<bool> checkBackendHealth() async {
    try {
      final response = await http.get(Uri.parse("${Config.backendUrl}/health"))
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // Task 5D: Fetch resource locations (Shelters, Depots)
  static Future<List<dynamic>> fetchResources() async {
    try {
      final response = await http.get(Uri.parse("${Config.backendUrl}/api/resources"))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) return jsonDecode(response.body);
      return [];
    } catch (_) {
      return [];
    }
  }
}