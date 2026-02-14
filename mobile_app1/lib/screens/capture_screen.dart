import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'dart:io';
import '../services/api_service.dart';
import 'package:geolocator/geolocator.dart';

class CaptureScreen extends StatefulWidget {
  final List<CameraDescription>? cameras;
  const CaptureScreen({super.key, this.cameras});

  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}


Future<Position> _getCurrentLocation() async {
  bool serviceEnabled;
  LocationPermission permission;

  serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) {
    throw Exception('Location services are disabled.');
  }

  permission = await Geolocator.checkPermission();

  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }

  if (permission == LocationPermission.denied ||
      permission == LocationPermission.deniedForever) {
    throw Exception('Location permission denied');
  }

  return await Geolocator.getCurrentPosition(
    locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.high,
    ),
  );
}

class _CaptureScreenState extends State<CaptureScreen> {
  CameraController? _controller;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    if (widget.cameras != null && widget.cameras!.isNotEmpty) {
      _controller = CameraController(widget.cameras![0], ResolutionPreset.high);
      _controller!.initialize().then((_) => setState(() {}));
    }
  }

  Future<void> _takePictureAndTag() async {
    if (_isProcessing ||
        _controller == null ||
        !_controller!.value.isInitialized) {
      return;
    }

    setState(() => _isProcessing = true);

    try {
      // 📸 Take Picture
      final XFile image = await _controller!.takePicture();

      // 📍 Get GPS Location
      final position = await _getCurrentLocation();

      // 🤖 Call Backend API
      final result = await ApiService.predict(
        File(image.path),
        position.latitude,
        position.longitude,
      );

      print("BACKEND RESPONSE: $result");

      final complaint = result['complaint'];

      if (complaint == null) {
        throw Exception("Backend error: ${result['detail'] ?? 'Complaint data is null'}");
      }

      final category = complaint['category'] ?? "Unknown";
      final confidence = complaint['confidence']?.toString() ?? "0";
      final complaintId = complaint['complaint_id'] ?? "N/A";

      if (mounted) {
        Navigator.pushReplacementNamed(
          context,
          '/result',
          arguments: {
            'imagePath': image.path,
            'issueType': category,
            'confidence': confidence,
            'complaintId': complaintId,
          },
        );
      }
    } catch (e) {
      debugPrint("Capture Error: $e");
    }

    if (mounted) {
      setState(() => _isProcessing = false);
    }
  }


  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.purple)),
      );
    }
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(child: CameraPreview(_controller!)),
          _buildOverlay(),
          Positioned(
            bottom: 50,
            left: 0,
            right: 0,
            child: _buildShutterButton(),
          ),
        ],
      ),
    );
  }

  Widget _buildOverlay() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 30),
              onPressed: () => Navigator.pop(context),
            ),
            if (_isProcessing)
              const Text(
                "AI ANALYZING...",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildShutterButton() {
    return GestureDetector(
      onTap: _takePictureAndTag,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            height: 85,
            width: 85,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 4),
            ),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: _isProcessing ? 60 : 70,
            width: _isProcessing ? 60 : 70,
            decoration: BoxDecoration(
              color: _isProcessing
                  ? Colors.purple.withOpacity(0.4)
                  : Colors.white,
              shape: BoxShape.circle,
            ),
            child: _isProcessing
                ? const Padding(
                    padding: EdgeInsets.all(15),
                    child: CircularProgressIndicator(
                      color: Colors.purple,
                      strokeWidth: 3,
                    ),
                  )
                : const Icon(
                    LucideIcons.camera,
                    color: Colors.purple,
                    size: 32,
                  ),
          ),
        ],
      ),
    );
  }
}
