import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

class AdminSignupScreen extends StatefulWidget {
  const AdminSignupScreen({super.key});

  @override
  State<AdminSignupScreen> createState() => _AdminSignupScreenState();
}

class _AdminSignupScreenState extends State<AdminSignupScreen> {
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _error;

  bool _isStrongPassword(String pw) {
    if (pw.length < 12) return false;
    if (!RegExp(r'(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[!@#$%^&*])').hasMatch(pw)) return false;
    return true;
  }

  Future<void> _signup() async {
    if (!_formKey.currentState!.validate()) return;
    if (_passwordController.text != _confirmController.text) {
      setState(() => _error = 'Passwords do not match');
      return;
    }
    if (!_isStrongPassword(_passwordController.text)) {
      setState(() => _error = 'Password must be 12+ chars with upper, lower, number, symbol');
      return;
    }

setState(() {
      _isLoading = true;
      _error = null;
    });
    final success = await context.read<AuthProvider>().adminSignup(_passwordController.text);
    setState(() => _isLoading = false);

    if (success) {
      if (mounted) Navigator.pushReplacementNamed(context, '/');
    } else {
      setState(() => _error = 'Signup failed. Contact developer or try login.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3E5F5),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 60),
                Icon(LucideIcons.shield, color: Colors.purple.shade700, size: 60),
                const SizedBox(height: 16),
                const Text('Admin Signup', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF4A148C))),
                Text('For authorized team only', style: TextStyle(fontSize: 16, color: Colors.purple.shade400)),
                const SizedBox(height: 40),
                const Text('Email: rizwik475@gmail.com (fixed)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Strong Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  validator: (v) => v!.length < 8 ? 'Too short' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _confirmController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Confirm Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  validator: (v) => v!.isEmpty ? 'Required' : null,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(_error!, style: TextStyle(color: Colors.red.shade600)),
                ],
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _signup,
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4A148C)),
                    child: _isLoading 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)))
                      : const Text('Create Admin Account', style: TextStyle(fontSize: 18, color: Colors.white)),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => Navigator.pushNamed(context, '/admin_login'),
                  child: const Text('Already have account? Login'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

