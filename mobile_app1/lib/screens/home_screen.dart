import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/language_provider.dart';
import '../utils/app_translations.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, child) {
        String lang = context.watch<LanguageProvider>().currentLang;

        return Scaffold(
          backgroundColor: const Color(0xFFF3E5F5),
          body: SingleChildScrollView(
            child: Container(
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

                  /// 🌍 Language Dropdown
                  Consumer<LanguageProvider>(
                    builder: (context, langProvider, child) {
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          DropdownButton<String>(
                            value: langProvider.currentLang,
                            items: const [
                              DropdownMenuItem(
                                value: "en",
                                child: Text("English"),
                              ),
                              DropdownMenuItem(
                                value: "hi",
                                child: Text("Hindi"),
                              ),
                              DropdownMenuItem(
                                value: "te",
                                child: Text("Telugu"),
                              ),
                              DropdownMenuItem(
                                value: "ur",
                                child: Text("Urdu"),
                              ),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                langProvider.changeLanguage(value);
                              }
                            },
                          ),
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: 10),

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

                  if (auth.isAuthenticated)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        "Welcome back, ${(auth.email != null && auth.email!.contains('@')) ? auth.email!.split('@').first : 'Admin'}!",
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.purple.shade400,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                  else
                    Text(
                      AppTranslations.get("tagline", lang),
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.purple.shade300,
                        fontWeight: FontWeight.w500,
                      ),
                    ),

                  const SizedBox(height: 50),

                  /// 👤 USER CARDS
                  if (auth.role != UserRole.admin) ...[
                    _buildCard(
                      context,
                      AppTranslations.get("report_emergency", lang),
                      AppTranslations.get("emergency_desc", lang),
                      Colors.red.shade400,
                      LucideIcons.shield_alert,
                      '/emergency',
                    ),
                    const SizedBox(height: 30),
                    _buildCard(
                      context,
                      AppTranslations.get("report_issue", lang),
                      AppTranslations.get("issue_desc", lang),
                      const Color(0xFF7B1FA2),
                      LucideIcons.camera,
                      '/capture',
                    ),
                    const SizedBox(height: 20),
                  ],

                  /// 🔐 AUTH BASED CARDS
                  if (auth.isAuthenticated) ...[
                    if (auth.role == UserRole.user) ...[
                      _buildCard(
                        context,
                        AppTranslations.get("my_complaints", lang),
                        AppTranslations.get("my_complaints_desc", lang),
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
                        AppTranslations.get("public_issues", lang),
                        AppTranslations.get("public_issues_desc", lang),
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
                        AppTranslations.get("admin_dashboard", lang),
                        AppTranslations.get("admin_dashboard_desc", lang),
                        Colors.green.shade600,
                        LucideIcons.layout_dashboard,
                        '/admin_dashboard',
                      ),
                      const SizedBox(height: 20),
                      _buildCard(
                        context,
                        AppTranslations.get("analytics", lang),
                        AppTranslations.get("analytics_desc", lang),
                        Colors.orange.shade600,
                        LucideIcons.brain,
                        '/analytics',
                      ),
                    ],
                    const SizedBox(height: 20),
                    _buildCard(
                      context,
                      AppTranslations.get("logout", lang),
                      AppTranslations.get("logout_desc", lang),
                      Colors.grey.shade600,
                      LucideIcons.log_out,
                      '/',
                      onTap: () => context.read<AuthProvider>().logout(),
                    ),
                  ] else ...[
                    _buildCard(
                      context,
                      AppTranslations.get("user_login", lang),
                      AppTranslations.get("user_login_desc", lang),
                      Colors.blue.shade400,
                      LucideIcons.user,
                      '/user_login',
                    ),
                    const SizedBox(height: 20),
                    _buildCard(
                      context,
                      AppTranslations.get("admin_login", lang),
                      AppTranslations.get("admin_login_desc", lang),
                      Colors.green.shade600,
                      LucideIcons.shield,
                      '/admin_login',
                    ),
                  ],

                  const SizedBox(height: 40),

                  const SizedBox(height: 20),

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
    String route, {
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap ?? () => Navigator.pushNamed(context, route),
      child: Container(
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
                  const SizedBox(height: 15),
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
