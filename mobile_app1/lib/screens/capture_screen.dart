import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import 'package:geolocator/geolocator.dart';
import '../providers/auth_provider.dart';
import '../utils/app_translations.dart';
import '../providers/language_provider.dart';

class CaptureScreen extends StatefulWidget {
  final List<CameraDescription>? cameras;
  const CaptureScreen({super.key, this.cameras});

  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

Future<Position?> _getCurrentLocation(BuildContext context) async {
  bool serviceEnabled;
  LocationPermission permission;

  serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) {
    // Show dialog to enable location
    final shouldEnable =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Location Services Disabled'),
            content: const Text(
              'Enable location services for better complaint tracking with GPS?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Skip'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Enable'),
              ),
            ],
          ),
        ) ??
        false;

    if (shouldEnable) {
      await Geolocator.openLocationSettings();
      return null; // Retry handled by user
    }
    return null;
  }

  permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }

  if (permission == LocationPermission.denied ||
      permission == LocationPermission.deniedForever) {
    return null;
  }

  return await Geolocator.getCurrentPosition(
    locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
  );
}

class _CaptureScreenState extends State<CaptureScreen> {
  CameraController? _controller;
  bool _isProcessing = false;
  String? _capturedImagePath; // To show the freeze-frame

  void showDuplicateDialog(BuildContext context, String issueId) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final email = auth.email;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Icon(Icons.info_outline, color: Colors.orange, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                "Issue Already Reported",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
            ),
          ],
        ),
        content: const Text(
          "Our AI detected that this issue has already been reported by another citizen and is currently being tracked.\n\nWould you like to upvote it to highlight its importance and track its progress?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF007AFF),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () async {
              try {
                await ApiService.upvoteComplaint(issueId, email);
                if (context.mounted) {
                  Navigator.pop(context); // Close dialog
                  // Navigate to complaints screen
                  Navigator.pushReplacementNamed(context, '/complaints');
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Error upvoting: $e")),
                  );
                }
              }
            },
            child: const Text("Upvote & Track"),
          ),
        ],
      ),
    );
  }

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
      setState(() {
        _capturedImagePath = image.path;
      });

      // 📍 Get GPS Location (nullable)
      final position = await _getCurrentLocation(context);
      final lat = position?.latitude ?? 0.0;
      final lng = position?.longitude ?? 0.0;

      if (position == null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Location skipped. Complaint will be created without GPS.',
            ),
            duration: Duration(seconds: 3),
          ),
        );
      }

      // Read image bytes directly from XFile to support web and mobile.
      final imageBytes = await image.readAsBytes();
      
      if (imageBytes.isEmpty) {
        throw Exception("Failed to capture image data. Please check your device storage.");
      }

      // 🤖 Call Backend API
      final reporterEmail = context.read<AuthProvider>().email;
      final result = await ApiService.predict(
        imageBytes,
        lat,
        lng,
        reporterEmail,
      );

      print("FULL RESPONSE: $result");
      print("Duplicate value: ${result["duplicate"]}");

      print("BACKEND RESPONSE: $result");

      // 🔥 HANDLE DUPLICATE FIRST
      if (result["duplicate"] == true) {
        showDuplicateDialog(context, result["issue_id"]);
        setState(() => _isProcessing = false);
        return;
      }

// ✅ THEN handle normal response
      final complaint = result['complaint'];

    //   if (complaint == null) {
    //     throw Exception(
    //     "Backend error: ${result['detail'] ?? 'Complaint data is null'}",
    //   );
    //  }

      if (complaint == null) {
        throw Exception(
          "Backend error: ${result['detail'] ?? 'Complaint data is null'}",
        );
      }

      // 🔥 Dispose camera before navigation and null it so dispose() doesn't double-free
      await _controller?.dispose();
      _controller = null;

      if (mounted) {
        if (complaint['status'] == 'Rejected (Auto)') {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Column(
                children: [
                  Icon(Icons.check_circle_outline, color: Colors.green, size: 50),
                  SizedBox(height: 10),
                  Text('All Clear!', textAlign: TextAlign.center),
                ],
              ),
              content: const Text(
                "Our AI analyzed the photo and found no civic issues. Thank you for keeping the city monitored!\n\nThis report has not been submitted.",
                textAlign: TextAlign.center,
              ),
              actionsAlignment: MainAxisAlignment.center,
              actions: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(120, 45),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    )
                  ),
                  onPressed: () {
                    Navigator.of(context).pop(); // close dialog
                    Navigator.of(context).pop(); // close capture screen
                  },
                  child: const Text('Got it'),
                ),
              ],
            ),
          );
          return;
        }

        Navigator.pushReplacementNamed(
          context,
          '/result',
          arguments: {
            'imagePath': image.path,
            'imageBytes': imageBytes,
            'issueType': complaint['category']?.toString() ?? "Unknown",
            'confidence': complaint['confidence']?.toString() ?? "0",
            'complaintId': complaint['complaint_id']?.toString() ?? "N/A",
            'letter': result['letter']?.toString() ?? "Letter not generated",
            'deadlineDays': result['deadline_days'] ?? 5,
            'imageUrl': result['image_url'],
          },
        );
      }
    } catch (e) {
      debugPrint("Capture Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }

    if (mounted) {
      setState(() {
        _isProcessing = false;
        _capturedImagePath = null; // Reset so they can try again if there was an error
      });
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
          Center(
            child: _capturedImagePath != null
                ? Image.file(
                    File(_capturedImagePath!),
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                  )
                : CameraPreview(_controller!),
          ),
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
              Consumer<LanguageProvider>(
                builder: (context, langProvider, child) {
                  String lang = langProvider.currentLang;
                  return Text(
                    AppTranslations.get("ai_analyzing", lang),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  );
                },
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
