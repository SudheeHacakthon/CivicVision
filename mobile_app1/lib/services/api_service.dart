import 'dart:convert';
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ApiService {
  // Use --dart-define=API_BASE_URL=http://<your-ip>:8000 for real devices.
  static const String _envBaseUrl = String.fromEnvironment('API_BASE_URL');
  static const String _androidDeviceUrl = String.fromEnvironment(
    'API_ANDROID_DEVICE_URL',
    defaultValue: 'http://10.71.22.83:8000',
  );

  static List<String> _baseUrlCandidates() {
    if (_envBaseUrl.isNotEmpty) return [_envBaseUrl];
    if (kIsWeb) return ['http://127.0.0.1:8000'];

    if (defaultTargetPlatform == TargetPlatform.android) {
      // First URL is for Android emulator, second is for real devices on same LAN.
      return ['http://10.0.2.2:8000', _androidDeviceUrl];
    }

    return ['http://127.0.0.1:8000'];
  }

  static String get baseUrl {
    return _baseUrlCandidates().first;
  }

  // ---------------- PREDICT ----------------

  static Future<Map<String, dynamic>> predict(
    Uint8List imageBytes,
    double latitude,
    double longitude,
  ) async {
    // Base64 encode image bytes (works on web/mobile)
    final imageBase64 = base64Encode(imageBytes);

    Object? lastNetworkError;
    final tried = <String>[];

    for (final candidate in _baseUrlCandidates()) {
      final uri = Uri.parse('$candidate/predict');
      tried.add(candidate);

      try {
        final response = await http
            .post(
              uri,
              headers: {'Content-Type': 'application/json'},
              body: json.encode({
                'image': imageBase64,
                'latitude': latitude,
                'longitude': longitude,
              }),
            )
            .timeout(const Duration(seconds: 20));

        if (response.statusCode == 200) {
          return json.decode(response.body);
        }

        throw Exception(
          'Predict failed: ${response.statusCode} ${response.body}',
        );
      } on TimeoutException catch (e) {
        lastNetworkError = e;
      } on http.ClientException catch (e) {
        lastNetworkError = e;
      }
    }

    throw Exception(
      'Could not connect to backend. Tried: ${tried.join(', ')}. '
      'If you are using a real Android phone, run with '
      '--dart-define=API_BASE_URL=http://10.71.22.83:8000. '
      'Last error: $lastNetworkError',
    );
  }

  // ---------------- HEATMAP ----------------

  static Future<List<dynamic>> fetchHeatmap() async {
    final uri = Uri.parse("$baseUrl/heatmap");
    final res = await http.get(uri);

    if (res.statusCode == 200) {
      return json.decode(res.body);
    } else {
      throw Exception("Heatmap fetch failed: ${res.statusCode}");
    }
  }

  // ---------------- COMPLAINTS ----------------

  static Future<List<dynamic>> fetchComplaints() async {
    final uri = Uri.parse("$baseUrl/complaints");
    final res = await http.get(uri);

    if (res.statusCode == 200) {
      return json.decode(res.body);
    } else {
      throw Exception("Fetch complaints failed: ${res.statusCode}");
    }
  }

  // ---------------- SINGLE COMPLAINT ----------------

  static Future<Map<String, dynamic>> fetchComplaintById(
    String complaintId,
  ) async {
    final uri = Uri.parse("$baseUrl/complaint/$complaintId");
    final response = await http.get(uri);

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception("Failed to fetch complaint");
    }
  }

  // ---------------- DOWNLOAD ----------------

  static Future<void> downloadComplaint(String id) async {
    final uri = Uri.parse("$baseUrl/download/$id");
    final res = await http.get(uri);

    if (res.statusCode != 200) {
      throw Exception("Download failed: ${res.statusCode}");
    }
  }

  // ---------------- ADMIN DASHBOARD ----------------

  static Future<Map<String, dynamic>> fetchAdminDashboard() async {
    final uri = Uri.parse("$baseUrl/admin/dashboard");
    final res = await http.get(uri);

    if (res.statusCode == 200) {
      return json.decode(res.body);
    } else {
      throw Exception("Fetch admin dashboard failed");
    }
  }

  // ---------------- ANALYTICS ----------------

  static Future<Map<String, dynamic>> fetchAnalytics() async {
    final uri = Uri.parse("$baseUrl/analytics");
    final res = await http.get(uri);

    if (res.statusCode == 200) {
      return json.decode(res.body);
    } else {
      throw Exception("Fetch analytics failed");
    }
  }

  // ---------------- UPDATE STATUS ----------------

  static Future<Map<String, dynamic>> updateComplaintStatus(
    String complaintId,
    String status,
  ) async {
    final uri = Uri.parse("$baseUrl/complaint/$complaintId/status");

    final response = await http.put(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'status': status}),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception("Failed to update status");
    }
  }

  // ---------------- EMERGENCY ----------------

  static Future<Map<String, dynamic>> submitEmergency(
    Uint8List imageBytes,
    double latitude,
    double longitude,
    String category, {
    String? shortText,
  }) async {
    final uri = Uri.parse("$baseUrl/emergency/report");
    final imageBase64 = base64Encode(imageBytes);

    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'image': imageBase64,
        'latitude': latitude,
        'longitude': longitude,
        'category': category,
        'short_text': shortText,
      }),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception(
        "Emergency report failed: ${response.statusCode} ${response.body}",
      );
    }
  }

  static Future<Map<String, dynamic>> triggerSos(
    double latitude,
    double longitude, {
    String? note,
  }) async {
    final uri = Uri.parse("$baseUrl/emergency/sos");

    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'latitude': latitude,
        'longitude': longitude,
        'note': note,
      }),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception("SOS failed: ${response.statusCode} ${response.body}");
    }
  }

  static Future<Map<String, dynamic>> fetchEmergencyStatus(
    String complaintId,
  ) async {
    final uri = Uri.parse("$baseUrl/emergency/$complaintId/status");
    final response = await http.get(uri);

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception("Failed to fetch emergency status");
    }
  }
}
