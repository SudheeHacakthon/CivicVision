import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'screens/home_screen.dart';
import 'screens/capture_screen.dart';
import 'screens/result_screen.dart';
import 'screens/map_screen.dart';
import 'screens/complaints_screen.dart';
import 'screens/complaint_detail_screen.dart';
import 'screens/admin_dashboard_screen.dart';
import 'screens/analytics_screen.dart';
import 'screens/emergency_screen.dart';
import 'screens/auth/admin_signup_screen.dart';
import 'screens/auth/admin_login_screen.dart';
import 'screens/auth/user_signup_screen.dart';
import 'screens/auth/user_login_screen.dart';
import 'screens/auth/forgot_password_screen.dart';
import 'providers/auth_provider.dart';

List<CameraDescription> globalCameras = [];

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    globalCameras = await availableCameras();
  } catch (e) {
    debugPrint("Camera Error: $e");
  }
  runApp(const CivicVisionApp());
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, child) {
        if (auth.isLoading) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (auth.isAuthenticated) {
          return const HomeScreen();
        }
        return const UserLoginScreen(); // Default to user login
      },
    );
  }
}

class CivicVisionApp extends StatelessWidget {
  const CivicVisionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => AuthProvider(),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'CivicVision',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4A148C)),
          textTheme: GoogleFonts.poppinsTextTheme(),
          useMaterial3: true,
        ),
        initialRoute: '/',
        routes: {
          '/': (context) => const AuthGate(),
          '/admin_signup': (context) => const AdminSignupScreen(),
          '/admin_login': (context) => const AdminLoginScreen(),
          '/user_signup': (context) => const UserSignupScreen(),
          '/user_login': (context) => const UserLoginScreen(),
          '/forgot_password': (context) => const ForgotPasswordScreen(),
          '/capture': (context) => CaptureScreen(cameras: globalCameras),
          '/emergency': (context) => EmergencyScreen(cameras: globalCameras),
          '/result': (context) => const ResultScreen(),
          '/map': (context) => const MapScreen(),
          '/complaints': (context) => const ComplaintsScreen(),
          '/complaint_detail': (context) => const ComplaintDetailScreen(),
          '/admin_dashboard': (context) => const AdminDashboardScreen(),
          '/analytics': (context) => const AnalyticsScreen(),
        },
      ),
    );
  }
}
