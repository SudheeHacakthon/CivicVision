import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

class ApiService {
  // Update baseUrl to your backend address. For Android emulator use 10.0.2.2
  static const String baseUrl = 'http://10.207.96.240:8000';




  static Future<Map<String, dynamic>> predict(
  File imageFile,
  double latitude,
  double longitude,
) async {
  final uri = Uri.parse('$baseUrl/predict');
  final request = http.MultipartRequest('POST', uri);

  final stream = http.ByteStream(imageFile.openRead());
  final length = await imageFile.length();

  final multipartFile = http.MultipartFile(
    'file',
    stream,
    length,
    filename: imageFile.path.split(Platform.pathSeparator).last,
  );

  request.files.add(multipartFile);

  request.fields['latitude'] = latitude.toString();
  request.fields['longitude'] = longitude.toString();

  final response = await request.send();
  final body = await response.stream.bytesToString();

  if (response.statusCode >= 200 && response.statusCode < 300) {
    final decoded = json.decode(body) as Map<String, dynamic>;
    return decoded;
  } else {
    throw Exception('Predict failed: ${response.statusCode} $body');
  }
}

  static Future<List<dynamic>> fetchHeatmap() async {
    final uri = Uri.parse('$baseUrl/heatmap');
    final res = await http.get(uri);
    if (res.statusCode == 200) {
      final decoded = json.decode(res.body) as List<dynamic>;
      return decoded;
    } else {
      throw Exception('Heatmap fetch failed: ${res.statusCode}');
    }
  }

  static Future<List<dynamic>> fetchComplaints() async {
    final uri = Uri.parse('$baseUrl/complaints');
    final res = await http.get(uri);
    if (res.statusCode == 200) {
      final decoded = json.decode(res.body) as List<dynamic>;
      return decoded;
    } else {
      throw Exception('Fetch complaints failed: ${res.statusCode} ${res.body}');
    }
  }

  static Future<Map<String, dynamic>> fetchComplaintById(String complaintId) async {
    final uri = Uri.parse('$baseUrl/complaint/$complaintId');
    final response = await http.get(uri);

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to fetch complaint: ${response.body}');
    }
  }

  static Future<void> downloadComplaint(String id) async {
    final uri = Uri.parse('$baseUrl/download/$id');
    final res = await http.get(uri);
    if (res.statusCode == 200) {
      // Download successful
    } else {
      throw Exception('Download complaint failed: ${res.statusCode} ${res.body}');
    }
  }

  static Future<Map<String, dynamic>> fetchAdminDashboard() async {
    final uri = Uri.parse('$baseUrl/admin/dashboard');
    final res = await http.get(uri);
    if (res.statusCode == 200) {
      final decoded = json.decode(res.body) as Map<String, dynamic>;
      return decoded;
    } else {
      throw Exception('Fetch admin dashboard failed: ${res.statusCode} ${res.body}');
    }
  }

  static Future<Map<String, dynamic>> fetchAnalytics() async {
    final uri = Uri.parse('$baseUrl/analytics');
    final res = await http.get(uri);
    if (res.statusCode == 200) {
      final decoded = json.decode(res.body) as Map<String, dynamic>;
      return decoded;
    } else {
      throw Exception('Fetch analytics failed: ${res.statusCode} ${res.body}');
    }
  }

  static Future<Map<String, dynamic>> updateComplaintStatus(
    String complaintId,
    String status,
  ) async {
    final uri = Uri.parse('$baseUrl/complaint/$complaintId/status');

    final response = await http.put(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'status': status}),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to update status: ${response.body}');
    }
  }
}
