import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/home_screen.dart';
import 'screens/capture_screen.dart';
import 'screens/result_screen.dart';
import 'screens/map_screen.dart';
import 'screens/complaints_screen.dart';
import 'screens/complaint_detail_screen.dart';
import 'screens/admin_dashboard_screen.dart';
import 'screens/analytics_screen.dart';
import 'screens/emergency_screen.dart';

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

class CivicVisionApp extends StatelessWidget {
  const CivicVisionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'CivicVision',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4A148C)),
        textTheme: GoogleFonts.poppinsTextTheme(),
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const HomeScreen(),
        '/capture': (context) => CaptureScreen(cameras: globalCameras),
        '/emergency': (context) => EmergencyScreen(cameras: globalCameras),
        '/result': (context) => const ResultScreen(),
        '/map': (context) => const MapScreen(),
        '/complaints': (context) => const ComplaintsScreen(),
        '/complaint_detail': (context) => const ComplaintDetailScreen(),
        '/admin_dashboard': (context) => const AdminDashboardScreen(),
        '/analytics': (context) => const AnalyticsScreen(),
      },
    );
  }
}
