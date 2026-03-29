import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

class ApiService {
  // 🔥 IMPORTANT: Make this static - works on web/mobile
  static const String baseUrl = "http://127.0.0.1:8000";

  // ---------------- PREDICT ----------------

  static Future<Map<String, dynamic>> predict(
    Uint8List imageBytes,
    double latitude,
    double longitude,
  ) async {
    final uri = Uri.parse("$baseUrl/predict");

    // Base64 encode image bytes (works on web/mobile)
    final imageBase64 = base64Encode(imageBytes);

    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'image': imageBase64,
        'latitude': latitude,
        'longitude': longitude,
      }),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception(
        "Predict failed: ${response.statusCode} ${response.body}",
      );
    }
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
}
