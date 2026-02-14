import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

class ApiService {
  // Update baseUrl to your backend address. For Android emulator use 10.0.2.2
  static const String baseUrl = 'http://10.0.2.2:8000';

  static Future<Map<String, dynamic>> predict(File imageFile) async {
    final uri = Uri.parse('$baseUrl/predict');
    final request = http.MultipartRequest('POST', uri);
    final stream = http.ByteStream(imageFile.openRead());
    final length = await imageFile.length();
    final multipartFile = http.MultipartFile(
      'image',
      stream,
      length,
      filename: imageFile.path.split(Platform.pathSeparator).last,
    );
    request.files.add(multipartFile);
    final response = await request.send();
    final body = await response.stream.bytesToString();
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final decoded = json.decode(body) as Map<String, dynamic>;
      return decoded;
    } else {
      throw Exception('Predict failed: ${response.statusCode} ${body}');
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
}
