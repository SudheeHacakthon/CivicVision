import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, child) {
        return Scaffold(
          backgroundColor: const Color(0xFFF3E5F5),
          body: SingleChildScrollView(
            child: Container (
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                colors: [Color(0xFFF3E5F5), Colors.white],
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 25),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 80),
                const Icon(
                  LucideIcons.sparkles,
                  color: Color(0xFF4A148C),
                  size: 30,
                ),
                const Text(
                  "CivicVision",
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF4A148C),
                    letterSpacing: -1,
                  ),
                ),
                Text(
                  auth.isAuthenticated ? "Welcome back!" : "Your City. Your Vision.",
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.purple.shade300,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 50),

                if (auth.role != UserRole.admin) ...[
                  _buildCard(
                    context,
                    "Report Emergency",
                    "Accidents, Hazards, Fires",
                    Colors.red.shade400,
                    LucideIcons.shield_alert,
                    '/emergency',
                  ),
                  const SizedBox(height: 30),
                  _buildCard(
                    context,
                    "Report Issue",
                    "Potholes, Trash, Streetlights",
                    const Color(0xFF7B1FA2),
                    LucideIcons.camera,
                    '/capture',
                  ),
                  const SizedBox(height: 20),
                ],

                // Role-based cards
                if (auth.isAuthenticated) ...[
                  if (auth.role == UserRole.user) ...[
                    _buildCard(
                      context,
                      "My Complaints",
                      "Track your submitted reports",
                      Colors.blue.shade400,
                      LucideIcons.file_text,
                      '/complaints',
                      onTap: () => Navigator.pushNamed(
                        context,
                        '/complaints',
                        arguments: {'scope': 'my'},
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildCard(
                      context,
                      "Public Issues",
                      "View & upvote community reports",
                      Colors.indigo.shade400,
                      LucideIcons.globe,
                      '/complaints',
                      onTap: () => Navigator.pushNamed(
                        context,
                        '/complaints',
                        arguments: {'scope': 'public'},
                      ),
                    ),
                  ],
                  if (auth.role == UserRole.admin) ...[
                    _buildCard(
                      context,
                      "Admin Dashboard",
                      "Monitor & manage complaints",
                      Colors.green.shade600,
                      LucideIcons.layout_dashboard,
                      '/admin_dashboard',
                    ),
                    const SizedBox(height: 20),
                    _buildCard(
                      context,
                      "Analytics",
                      "View city statistics",
                      Colors.orange.shade600,
                      LucideIcons.brain,
                      '/analytics',
                    ),
                  ],
                  const SizedBox(height: 20),
                  _buildCard(
                    context,
                    "Logout",
                    "Sign out of account",
                    Colors.grey.shade600,
                    LucideIcons.log_out,
                    '/',
                    onTap: () => context.read<AuthProvider>().logout(),
                  ),
                ] else ...[
                  _buildCard(context,
                    "User Login/Signup",
                    "Access personal features",
                    Colors.blue.shade400,
                    LucideIcons.user,
                    '/user_login',
                  ),
                  const SizedBox(height: 20),
                  _buildCard(context,
                    "Admin Login",
                    "Team management access",
                    Colors.green.shade600,
                    LucideIcons.shield,
                    '/admin_login',
                  ),
                ],

                const SizedBox(height: 40),

                Center(
                  child: TextButton.icon(
                    onPressed: () => Navigator.pushNamed(context, '/map'),
                    icon: const Icon(LucideIcons.map_pin, color: Color(0xFF7B1FA2)),
                    label: const Text(
                      "VIEW LIVE HEATMAP",
                      style: TextStyle(
                        color: Color(0xFF7B1FA2),
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
          ),
        );
      },
    );
  }


  Widget _buildCard(
    BuildContext context,
    String title,
    String sub,
    Color color,
    IconData icon,
    String route,
    {VoidCallback? onTap}
  ) {
    return GestureDetector(
      onTap: onTap ?? () => Navigator.pushNamed(context, route),
      child: Container(
        height: 150,
        width: double.infinity,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.4),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              right: -20,
              top: -20,
              child: Icon(
                icon,
                size: 150,
                color: Colors.white.withOpacity(0.1),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, color: Colors.white, size: 35),
                  const Spacer(),
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    sub,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
