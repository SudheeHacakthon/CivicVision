import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/location_service.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

class UserSignupScreen extends StatefulWidget {
  const UserSignupScreen({super.key});

  @override
  State<UserSignupScreen> createState() => _UserSignupScreenState();
}

class _UserSignupScreenState extends State<UserSignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _emergencyController = TextEditingController();
  final _otpController = TextEditingController();
  final _locationController = TextEditingController();
  bool _isGpsLoading = false;
  bool _otpSent = false;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  String? _error;

  Future<void> _getLocation() async {
    setState(() => _isGpsLoading = true);
    final pos = await LocationService.getCurrentLocation();
    if (pos != null) {
      setState(() => _locationController.text = '${pos.latitude}, ${pos.longitude}');
    }
    setState(() => _isGpsLoading = false);
  }

  Future<void> _sendOtp() async {
    if (!_formKey.currentState!.validate()) return;
    if (_passwordController.text != _confirmController.text) {
      setState(() => _error = 'Passwords do not match');
      return;
    }
    if (_locationController.text.isEmpty) {
      setState(() => _error = 'Location required');
      return;
    }

    final data = {
      'name': _nameController.text,
      'email': _emailController.text,
      'phone': _phoneController.text,
      'password': _passwordController.text,
      'location': _locationController.text,
      'emergency_contact': _emergencyController.text,
    };

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final signupSuccess = await context.read<AuthProvider>().userSignup(data);
      if (signupSuccess && mounted) {
        setState(() {
          _otpSent = true;
        });
      } else if (mounted) {
        setState(() {
          _error = 'Could not send OTP. Please try again.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Could not send OTP. Check backend/network and try again.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _verifyOtpAndSignup() async {
    setState(() => _error = null);
    if (_otpController.text.length != 6) {
      setState(() => _error = 'Enter a valid 6-digit OTP');
      return;
    }

    setState(() => _isLoading = true);
    final verifySuccess = await context.read<AuthProvider>().verifyOtp(
      _emailController.text,
      _otpController.text,
    );
    if (verifySuccess && mounted) {
      Navigator.pushReplacementNamed(context, '/');
    } else {
      setState(() => _error = 'Invalid or expired OTP. Please try again.');
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3E5F5),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              Icon(LucideIcons.user_plus, color: Colors.green.shade600, size: 60),
              const SizedBox(height: 16),
              const Text('User Signup', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF4A148C))),
              const SizedBox(height: 32),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Full Name',
                  prefixIcon: const Icon(Icons.person_outline),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                ),
                validator: (v) => v!.isEmpty ? 'Name required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Email',
                  prefixIcon: const Icon(Icons.email_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                ),
                validator: (v) => v!.isEmpty ? 'Email required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Phone Number',
                  prefixIcon: const Icon(Icons.phone_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                ),
                validator: (v) => v!.length < 10 ? 'Valid phone required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                  ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                ),
                validator: (v) => v!.length < 8 ? 'Min 8 chars' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _confirmController,
                obscureText: _obscureConfirm,
                decoration: InputDecoration(
                  labelText: 'Confirm Password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                    icon: Icon(_obscureConfirm ? Icons.visibility_off : Icons.visibility),
                  ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Confirm password';
                  if (v.length < 8) return 'Min 8 chars';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emergencyController,
                decoration: InputDecoration(
                  labelText: 'Emergency Contact',
                  prefixIcon: const Icon(Icons.emergency_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isGpsLoading ? null : _getLocation,
                      icon: const Icon(Icons.location_on_outlined),
                      label: Text(_isGpsLoading ? 'Detecting...' : 'Auto GPS'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _locationController,
                decoration: InputDecoration(
                  labelText: 'Location (auto-filled or manual)',
                  prefixIcon: const Icon(Icons.location_city_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  helperText: 'e.g., Kathmandu or 27.7172, 85.3240',
                ),
                validator: (v) => v!.isEmpty ? 'Location required' : null,
              ),
              const SizedBox(height: 24),
              if (!_otpSent) ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _sendOtp,
                    icon: const Icon(Icons.email_outlined),
                    label: Text(_isLoading ? 'Sending...' : 'Send OTP'),
                  ),
                ),
              ] else ...[
                TextFormField(
                  controller: _otpController,
                  decoration: InputDecoration(
                    labelText: 'Enter OTP sent to your email',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  validator: (v) => v!.length != 6 ? '6 digit OTP' : null,
                ),
                const SizedBox(height: 12),
                TextButton(onPressed: _sendOtp, child: const Text('Resend OTP')),
              ],
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: TextStyle(color: Colors.red.shade600)),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading || !_otpSent ? null : _verifyOtpAndSignup,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade600),
                  child: _isLoading 
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Complete Signup', style: TextStyle(fontSize: 18, color: Colors.white)),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.pushNamed(context, '/user_login'),
                child: const Text('Have account? Login'),
              ),
              const SizedBox(height: 24),
              TextButton.icon(
                onPressed: () => Navigator.pushNamed(context, '/admin_login'),
                icon: const Icon(Icons.admin_panel_settings_outlined),
                label: const Text('Admin Login'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

