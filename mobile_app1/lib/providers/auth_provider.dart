import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';

enum UserRole { guest, user, admin }

class AuthProvider extends ChangeNotifier {
  UserRole _role = UserRole.guest;
  String? _token;
  String? _email;
  String? _lastError;
  bool _isLoading = false;

  UserRole get role => _role;
  String? get token => _token;
  String? get email => _email;
  String? get lastError => _lastError;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _role != UserRole.guest;

  AuthProvider() {
    _loadFromPrefs();
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('token');
    _email = prefs.getString('email');
    final roleStr = prefs.getString('role');
    if (roleStr != null) {
      _role = UserRole.values.firstWhere(
        (r) => r.toString().split('.').last == roleStr,
      );
    }
    notifyListeners();
  }

  Future<void> login(String token, UserRole role, {String? email}) async {
    _isLoading = true;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', token);
    await prefs.setString('role', role.toString().split('.').last);
    if (email != null && email.isNotEmpty) {
      await prefs.setString('email', email);
    }

    _token = token;
    _email = email ?? _email;
    _role = role;
    _isLoading = false;
    notifyListeners();
  }

  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('role');
    await prefs.remove('email');

    _token = null;
    _email = null;
    _role = UserRole.guest;
    _isLoading = false;
    notifyListeners();
  }

  Future<bool> adminSignup(String password) async {
    try {
      final res = await ApiService.adminSignup({'password': password});
      final token = (res['token'] ?? res['access_token']) as String?;
      final email = res['email']?.toString();
      if (token != null && token.isNotEmpty) {
        await login(token, UserRole.admin, email: email);
        return true;
      }
      return res['success'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> adminLogin(String email, String password) async {
    try {
      _lastError = null;
      final res = await ApiService.adminLogin({
        'email': email.trim().toLowerCase(),
        'password': password.trim(),
      });
      final token = (res['token'] ?? res['access_token']) as String?;
      if (token != null && token.isNotEmpty) {
        await login(token, UserRole.admin);
        return true;
      }
      _lastError = 'Invalid credentials';
      return false;
    } catch (e) {
      final message = e.toString().toLowerCase();
      if (message.contains('invalid admin credentials') || message.contains('invalid credentials') || message.contains(' 400 ')) {
        _lastError = 'Invalid credentials';
      } else {
        _lastError = 'Unable to login right now. Please try again.';
      }
      return false;
    }
  }

  Future<bool> userSignup(Map<String, dynamic> data) async {
    try {
      final res = await ApiService.userSignup(data);
      return res['success'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> verifyOtp(String email, String otp) async {
    try {
      final res = await ApiService.verifyOtp({'email': email, 'otp': otp});
      final token = (res['token'] ?? res['access_token']) as String?;
      final verifiedEmail = res['email']?.toString() ?? email;
      if (token != null && token.isNotEmpty) {
        await login(token, UserRole.user, email: verifiedEmail);
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> userLogin(String email, String password) async {
    try {
      final res = await ApiService.userLogin({'email': email, 'password': password});
      final token = (res['token'] ?? res['access_token']) as String?;
      final userEmail = res['email']?.toString() ?? email;
      if (token != null && token.isNotEmpty) {
        await login(token, UserRole.user, email: userEmail);
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<void> forgotPassword(String email) async {
    await ApiService.forgotPassword(email);
  }

  // Generic _authCall removed to keep per-flow parsing explicit and safer.
}

