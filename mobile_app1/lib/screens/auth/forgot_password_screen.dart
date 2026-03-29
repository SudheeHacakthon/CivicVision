import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _otpSent = false;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  String? _error;
  final _formKey = GlobalKey<FormState>();

  Future<void> _sendOtp() async {
    if (_emailController.text.isEmpty) return;
    setState(() => _isLoading = true);
    await context.read<AuthProvider>().forgotPassword(_emailController.text);
    setState(() {
      _otpSent = true;
      _isLoading = false;
    });
  }

  Future<void> _resetPassword() async {
    if (!_formKey.currentState!.validate()) return;
    if (_passwordController.text != _confirmController.text) {
      setState(() => _error = 'Passwords do not match');
      return;
    }
    // Call backend reset API stubbed in auth_provider
    setState(() {
      _error = 'Reset success - login now';
      _isLoading = true;
    });
    await Future.delayed(const Duration(seconds: 2));
    setState(() => _isLoading = false);
    if (mounted) Navigator.pushNamed(context, _emailController.text.contains('rizwik') ? '/admin_login' : '/user_login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3E5F5),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 80),
              const Icon(Icons.lock_reset, color: Colors.orange, size: 60),
              const SizedBox(height: 16),
              const Text('Reset Password', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF4A148C))),
              const SizedBox(height: 8),
              Text('Enter email to receive OTP', style: TextStyle(fontSize: 16, color: Colors.purple.shade400)),
              const SizedBox(height: 40),
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
              const SizedBox(height: 24),
              if (!_otpSent) ...[
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _sendOtp,
                    icon: const Icon(Icons.email_outlined),
                    label: Text(_isLoading ? 'Sending...' : 'Send OTP'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade600),
                  ),
                ),
              ] else ...[
                TextFormField(
                  controller: _otpController,
                  decoration: InputDecoration(
                    labelText: 'OTP',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  validator: (v) => v!.length != 6 ? '6 digit OTP' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'New Password',
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
                    labelText: 'Confirm New Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                      icon: Icon(_obscureConfirm ? Icons.visibility_off : Icons.visibility),
                    ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Confirm';
                    if (v.length < 8) return 'Min 8 chars';
                    return null;
                  },
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(_error!, style: TextStyle(color: Colors.green.shade600)),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _resetPassword,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade600),
                    child: _isLoading 
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Reset Password', style: TextStyle(fontSize: 18, color: Colors.white)),
                  ),
                ),
              ],
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pushNamed(context, '/user_login'),
                    child: const Text('User Login'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pushNamed(context, '/admin_login'),
                    child: const Text('Admin Login'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

