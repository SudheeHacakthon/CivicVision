import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ApiService {
  // Use --dart-define=API_BASE_URL=http://<your-ip>:8000 for real devices.
  static const String _envBaseUrl = String.fromEnvironment('API_BASE_URL');
  static const String _androidDeviceUrl = String.fromEnvironment(
    'API_ANDROID_DEVICE_URL',
    defaultValue: '',
  );

  static List<String> _baseUrlCandidates() {
    if (_envBaseUrl.isNotEmpty) return [_envBaseUrl];
    if (kIsWeb) return ['http://127.0.0.1:8000'];

    if (defaultTargetPlatform == TargetPlatform.android) {
      final candidates = <String>[];
      if (_androidDeviceUrl.isNotEmpty) {
        // Real-device URL must be supplied explicitly to avoid stale LAN IP defaults.
        candidates.add(_androidDeviceUrl);
      }
      // Android emulator host loopback.
      candidates.add('http://10.0.2.2:8000');
      return candidates;
    }

    return ['http://127.0.0.1:8000'];
  }

  static String get baseUrl {
    return _baseUrlCandidates().first;
  }

  static Future<Map<String, dynamic>> _postJsonWithFallback(
    String path,
    Map<String, dynamic> data, {
    Duration timeout = const Duration(seconds: 10),
    Set<int> successStatusCodes = const {200},
  }) async {
    Object? lastNetworkError;
    Object? lastHttpError;
    final tried = <String>[];

    for (final candidate in _baseUrlCandidates()) {
      final uri = Uri.parse('$candidate$path');
      tried.add(candidate);

      try {
        final response = await http
            .post(
              uri,
              headers: {'Content-Type': 'application/json'},
              body: json.encode(data),
            )
            .timeout(timeout);

        if (successStatusCodes.contains(response.statusCode)) {
          return json.decode(response.body) as Map<String, dynamic>;
        }

        // Try next candidate for likely host mismatch; preserve API errors to report if all fail.
        lastHttpError = Exception(
          'Request failed at $candidate$path: ${response.statusCode} ${response.body}',
        );

        // For explicit client validation/auth failures, fail fast.
        if (response.statusCode == 400 ||
            response.statusCode == 401 ||
            response.statusCode == 422) {
          throw lastHttpError;
        }
      } on TimeoutException catch (e) {
        lastNetworkError = e;
      } on http.ClientException catch (e) {
        lastNetworkError = e;
      } on Exception catch (e) {
        lastHttpError = e;
        // Continue trying other hosts only if this wasn't an explicit fail-fast client error.
        if (e.toString().contains(' 400 ') ||
            e.toString().contains(' 401 ') ||
            e.toString().contains(' 422 ')) {
          rethrow;
        }
      }
    }

    throw Exception(
      'Could not connect to backend for $path. Tried: ${tried.join(', ')}. '
      'Last error: ${lastHttpError ?? lastNetworkError}',
    );
  }

  static Future<Map<String, dynamic>> _getMapWithFallback(
    String path, {
    Duration timeout = const Duration(seconds: 10),
    Set<int> successStatusCodes = const {200},
  }) async {
    Object? lastNetworkError;
    Object? lastHttpError;
    final tried = <String>[];

    for (final candidate in _baseUrlCandidates()) {
      final uri = Uri.parse('$candidate$path');
      tried.add(candidate);

      try {
        final response = await http.get(uri).timeout(timeout);
        if (successStatusCodes.contains(response.statusCode)) {
          return json.decode(response.body) as Map<String, dynamic>;
        }

        lastHttpError = Exception(
          'Request failed at $candidate$path: ${response.statusCode} ${response.body}',
        );

        if (response.statusCode == 400 ||
            response.statusCode == 401 ||
            response.statusCode == 422) {
          throw lastHttpError;
        }
      } on TimeoutException catch (e) {
        lastNetworkError = e;
      } on http.ClientException catch (e) {
        lastNetworkError = e;
      } on Exception catch (e) {
        lastHttpError = e;
        if (e.toString().contains(' 400 ') ||
            e.toString().contains(' 401 ') ||
            e.toString().contains(' 422 ')) {
          rethrow;
        }
      }
    }

    throw Exception(
      'Could not connect to backend for $path. Tried: ${tried.join(', ')}. '
      'Last error: ${lastHttpError ?? lastNetworkError}',
    );
  }

  static Future<List<dynamic>> _getListWithFallback(
    String path, {
    Duration timeout = const Duration(seconds: 10),
    Set<int> successStatusCodes = const {200},
  }) async {
    Object? lastNetworkError;
    Object? lastHttpError;
    final tried = <String>[];

    for (final candidate in _baseUrlCandidates()) {
      final uri = Uri.parse('$candidate$path');
      tried.add(candidate);

      try {
        final response = await http.get(uri).timeout(timeout);
        if (successStatusCodes.contains(response.statusCode)) {
          return json.decode(response.body) as List<dynamic>;
        }

        lastHttpError = Exception(
          'Request failed at $candidate$path: ${response.statusCode} ${response.body}',
        );

        if (response.statusCode == 400 ||
            response.statusCode == 401 ||
            response.statusCode == 422) {
          throw lastHttpError;
        }
      } on TimeoutException catch (e) {
        lastNetworkError = e;
      } on http.ClientException catch (e) {
        lastNetworkError = e;
      } on Exception catch (e) {
        lastHttpError = e;
        if (e.toString().contains(' 400 ') ||
            e.toString().contains(' 401 ') ||
            e.toString().contains(' 422 ')) {
          rethrow;
        }
      }
    }

    throw Exception(
      'Could not connect to backend for $path. Tried: ${tried.join(', ')}. '
      'Last error: ${lastHttpError ?? lastNetworkError}',
    );
  }

  static Future<Map<String, dynamic>> _putJsonWithFallback(
    String path,
    Map<String, dynamic> data, {
    Duration timeout = const Duration(seconds: 10),
    Set<int> successStatusCodes = const {200},
  }) async {
    Object? lastNetworkError;
    Object? lastHttpError;
    final tried = <String>[];

    for (final candidate in _baseUrlCandidates()) {
      final uri = Uri.parse('$candidate$path');
      tried.add(candidate);

      try {
        final response = await http
            .put(
              uri,
              headers: {'Content-Type': 'application/json'},
              body: json.encode(data),
            )
            .timeout(timeout);

        if (successStatusCodes.contains(response.statusCode)) {
          return json.decode(response.body) as Map<String, dynamic>;
        }

        lastHttpError = Exception(
          'Request failed at $candidate$path: ${response.statusCode} ${response.body}',
        );

        if (response.statusCode == 400 ||
            response.statusCode == 401 ||
            response.statusCode == 422) {
          throw lastHttpError;
        }
      } on TimeoutException catch (e) {
        lastNetworkError = e;
      } on http.ClientException catch (e) {
        lastNetworkError = e;
      } on Exception catch (e) {
        lastHttpError = e;
        if (e.toString().contains(' 400 ') ||
            e.toString().contains(' 401 ') ||
            e.toString().contains(' 422 ')) {
          rethrow;
        }
      }
    }

    throw Exception(
      'Could not connect to backend for $path. Tried: ${tried.join(', ')}. '
      'Last error: ${lastHttpError ?? lastNetworkError}',
    );
  }

  // ---------------- PREDICT ----------------

  static Future<Map<String, dynamic>> predict(
    Uint8List imageBytes,
    double latitude,
    double longitude,
    String? reporterEmail,
  ) async {
    // Base64 encode image bytes (works on web/mobile)
    final imageBase64 = base64Encode(imageBytes);

    Object? lastNetworkError;
    Object? lastHttpError;
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
                'reporter_email': (reporterEmail ?? '').trim().toLowerCase(),
              }),
            )
            .timeout(const Duration(seconds: 20));

        if (response.statusCode == 200) {
          return json.decode(response.body);
        }

        lastHttpError = Exception(
          'Predict failed at $candidate/predict: ${response.statusCode} ${response.body}',
        );

        if (response.statusCode == 400 ||
            response.statusCode == 401 ||
            response.statusCode == 422) {
          throw lastHttpError;
        }
      } on TimeoutException catch (e) {
        lastNetworkError = e;
      } on http.ClientException catch (e) {
        lastNetworkError = e;
      } on Exception catch (e) {
        lastHttpError = e;
        if (e.toString().contains(' 400 ') ||
            e.toString().contains(' 401 ') ||
            e.toString().contains(' 422 ')) {
          rethrow;
        }
      }
    }

    throw Exception(
      'Could not connect to backend. Tried: ${tried.join(', ')}. '
      'If you are using a real Android phone, run with '
      '--dart-define=API_ANDROID_DEVICE_URL=http://192.168.29.74:8000. '
      'Last error: ${lastHttpError ?? lastNetworkError}',
    );
  }

  // ---------------- HEATMAP ----------------

  static Future<List<dynamic>> fetchHeatmap() async {
    return _getListWithFallback('/heatmap');
  }

  // ---------------- COMPLAINTS ----------------

  static Future<List<dynamic>> fetchComplaints() async {
    return _getListWithFallback('/complaints');
  }

  static Future<List<dynamic>> fetchMyComplaints(String email) async {
    final encoded = Uri.encodeQueryComponent(email.trim().toLowerCase());
    return _getListWithFallback('/complaints/my?email=$encoded');
  }

  // ---------------- SINGLE COMPLAINT ----------------

  static Future<Map<String, dynamic>> fetchComplaintById(
    String complaintId,
  ) async {
    return _getMapWithFallback('/complaint/$complaintId');
  }

  static Future<Map<String, dynamic>> upvoteComplaint(
    String complaintId,
  ) async {
    return _postJsonWithFallback(
      '/complaint/$complaintId/upvote',
      const {},
      successStatusCodes: const {200},
    );
  }

  // ---------------- DOWNLOAD ----------------

  static Future<void> downloadComplaint(String id) async {
    Object? lastNetworkError;
    Object? lastHttpError;
    final tried = <String>[];

    for (final candidate in _baseUrlCandidates()) {
      final uri = Uri.parse('$candidate/download/$id');
      tried.add(candidate);

      try {
        final res = await http.get(uri).timeout(const Duration(seconds: 20));
        if (res.statusCode == 200) return;

        lastHttpError = Exception(
          'Download failed at $candidate/download/$id: ${res.statusCode}',
        );
      } on TimeoutException catch (e) {
        lastNetworkError = e;
      } on http.ClientException catch (e) {
        lastNetworkError = e;
      }
    }

    throw Exception(
      'Download failed. Tried: ${tried.join(', ')}. '
      'Last error: ${lastHttpError ?? lastNetworkError}',
    );
  }

  // ---------------- ADMIN DASHBOARD ----------------

  static Future<Map<String, dynamic>> fetchAdminDashboard() async {
    return _getMapWithFallback('/admin/dashboard');
  }

  // ---------------- ANALYTICS ----------------

  static Future<Map<String, dynamic>> fetchAnalytics() async {
    return _getMapWithFallback('/analytics');
  }

  // ---------------- UPDATE STATUS ----------------

  static Future<Map<String, dynamic>> updateComplaintStatus(
    String complaintId,
    String status,
  ) async {
    return _putJsonWithFallback('/complaint/$complaintId/status', {
      'status': status,
    });
  }

  // ---------------- AUTH ----------------

  static Future<Map<String, dynamic>> adminSignup(
    Map<String, dynamic> data,
  ) async {
    return _postJsonWithFallback(
      '/auth/admin/signup',
      data,
      successStatusCodes: const {200, 201},
    );
  }

  static Future<Map<String, dynamic>> adminLogin(
    Map<String, dynamic> data,
  ) async {
    return _postJsonWithFallback('/auth/admin/login', data);
  }

  static Future<Map<String, dynamic>> userSignup(
    Map<String, dynamic> data,
  ) async {
    return _postJsonWithFallback(
      '/auth/user/signup',
      data,
      successStatusCodes: const {200, 201},
    );
  }

  static Future<Map<String, dynamic>> verifyOtp(
    Map<String, dynamic> data,
  ) async {
    return _postJsonWithFallback('/auth/verify-otp', data);
  }

  static Future<Map<String, dynamic>> userLogin(
    Map<String, dynamic> data,
  ) async {
    return _postJsonWithFallback('/auth/user/login', data);
  }

  static Future<void> forgotPassword(String email) async {
    Object? lastNetworkError;
    final tried = <String>[];

    for (final candidate in _baseUrlCandidates()) {
      final uri = Uri.parse(
        '$candidate/auth/forgot-password?email=${Uri.encodeQueryComponent(email)}',
      );
      tried.add(candidate);

      try {
        final response = await http
            .post(uri)
            .timeout(const Duration(seconds: 10));
        if (response.statusCode == 200) {
          return;
        }
        throw Exception('Forgot password failed: ${response.body}');
      } on TimeoutException catch (e) {
        lastNetworkError = e;
      } on http.ClientException catch (e) {
        lastNetworkError = e;
      }
    }

    throw Exception(
      'Could not send OTP. Tried: ${tried.join(', ')}. Last error: $lastNetworkError',
    );
  }

  // ---------------- EMERGENCY ----------------

  static Future<Map<String, dynamic>> submitEmergency(
    Uint8List imageBytes,
    double latitude,
    double longitude,
    String category, {
    String? shortText,
    String? reporterEmail,
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
        'reporter_email': (reporterEmail ?? '').trim().toLowerCase(),
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
    String? reporterEmail,
  }) async {
    final uri = Uri.parse("$baseUrl/emergency/sos");

    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'latitude': latitude,
        'longitude': longitude,
        'note': note,
        'reporter_email': (reporterEmail ?? '').trim().toLowerCase(),
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
