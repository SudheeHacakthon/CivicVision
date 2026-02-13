import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/home_screen.dart';
import 'screens/capture_screen.dart';
import 'screens/result_screen.dart';
import 'screens/map_screen.dart';

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
        '/result': (context) => const ResultScreen(),
        '/map': (context) => const MapScreen(),
      },
    );
  }
}
