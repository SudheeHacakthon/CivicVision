import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:geolocator/geolocator.dart'; // Added for location

class CaptureScreen extends StatefulWidget {
  final List<CameraDescription>? cameras;
  const CaptureScreen({super.key, this.cameras});

  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
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

  // New helper method to handle GPS permissions and fetching
  Future<Position?> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return null;
    }

    if (permission == LocationPermission.deniedForever) return null;

    return await Geolocator.getCurrentPosition();
  }

  Future<void> _takePictureAndTag() async {
    if (_isProcessing ||
        _controller == null ||
        !_controller!.value.isInitialized)
      return;

    setState(() => _isProcessing = true);
    try {
      // 1. Capture the image
      final XFile image = await _controller!.takePicture();

      // 2. Fetch location while the user sees "AI ANALYZING..."
      Position? position = await _getCurrentLocation();

      // Simulate AI Processing Delay for the "Wow" factor
      await Future.delayed(const Duration(milliseconds: 1500));

      if (mounted) {
        Navigator.pushReplacementNamed(
          context,
          '/result',
          arguments: {
            'imagePath': image.path,
            'issueType': 'Pothole Detected',
            'severity': 'High',
            'confidence': '94.2%',
            // 3. Pass location data to the next screen
            'latitude': position?.latitude,
            'longitude': position?.longitude,
          },
        );
      }
    } catch (e) {
      debugPrint("Capture Error: $e");
      if (mounted) setState(() => _isProcessing = false);
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
