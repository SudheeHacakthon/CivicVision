import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/auth_provider.dart';
import '../services/api_service.dart';

class EmergencyScreen extends StatefulWidget {
  final List<CameraDescription>? cameras;

  const EmergencyScreen({super.key, this.cameras});

  @override
  State<EmergencyScreen> createState() => _EmergencyScreenState();
}

class _EmergencyScreenState extends State<EmergencyScreen> {
  CameraController? _controller;
  Position? _position;
  bool _cameraReady = false;
  bool _isSubmitting = false;

  final List<_EmergencyCategory> _categories = const [
    _EmergencyCategory('Fire', Icons.local_fire_department, 'FIRE'),
    _EmergencyCategory('Accident', Icons.car_crash, 'ACCIDENT'),
    _EmergencyCategory('Live Wire', Icons.electrical_services, 'LIVE_WIRE'),
    _EmergencyCategory('Fallen Tree', Icons.park, 'FALLEN_TREE'),
    _EmergencyCategory('Flood / Leak', Icons.flood, 'FLOOD_WATER_LEAK'),
  ];

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _resolveLocation();
  }

  Future<void> _initializeCamera() async {
    if (widget.cameras == null || widget.cameras!.isEmpty) {
      return;
    }

    _controller = CameraController(
      widget.cameras!.first,
      ResolutionPreset.high,
      enableAudio: false,
    );

    try {
      await _controller!.initialize();
      if (!mounted) return;
      setState(() => _cameraReady = true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _cameraReady = false);
    }
  }

  Future<void> _resolveLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return;
    }

    final current = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );

    if (!mounted) return;
    setState(() => _position = current);
  }

  Future<void> _callNumber(String number) async {
    final uri = Uri(scheme: 'tel', path: number);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _reportEmergency() async {
    if (_isSubmitting || !_cameraReady || _controller == null) return;

    final selectedCategory = await _showCategoryPicker();
    if (selectedCategory == null) return;

    setState(() => _isSubmitting = true);

    try {
      final image = await _controller!.takePicture();
      final imageBytes = await image.readAsBytes();

      if (_position == null) {
        await _resolveLocation();
      }

      final latitude = _position?.latitude ?? 0.0;
      final longitude = _position?.longitude ?? 0.0;
      final reporterEmail = context.read<AuthProvider>().email;

      final result = await ApiService.submitEmergency(
        imageBytes,
        latitude,
        longitude,
        selectedCategory.apiValue,
        reporterEmail: reporterEmail,
      );

      final complaint = result['complaint'] as Map<String, dynamic>?;
      if (complaint == null) {
        throw Exception('Emergency report failed: Missing complaint details');
      }

      if (!mounted) return;
      Navigator.pushNamed(
        context,
        '/result',
        arguments: {
          'imagePath': image.path,
          'imageBytes': imageBytes,
          'issueType':
              complaint['category']?.toString() ?? selectedCategory.label,
          'confidence': 'Critical',
          'complaintId': complaint['complaint_id']?.toString() ?? 'N/A',
          'letter': 'Emergency alert sent to authorities.',
          'isEmergency': true,
          'status': complaint['status']?.toString() ?? 'Reported',
        },
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Emergency submission failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _sendSos() async {
    if (_isSubmitting) return;

    setState(() => _isSubmitting = true);
    try {
      if (_position == null) {
        await _resolveLocation();
      }

      final latitude = _position?.latitude ?? 0.0;
      final longitude = _position?.longitude ?? 0.0;
      final reporterEmail = context.read<AuthProvider>().email;
      final result = await ApiService.triggerSos(
        latitude,
        longitude,
        reporterEmail: reporterEmail,
      );
      final complaint = result['complaint'] as Map<String, dynamic>?;

      if (!mounted) return;
      Navigator.pushNamed(
        context,
        '/result',
        arguments: {
          'imagePath': '',
          'issueType': 'SOS',
          'confidence': 'Critical',
          'complaintId': complaint?['complaint_id']?.toString() ?? 'N/A',
          'letter': 'SOS alert sent with live location.',
          'isEmergency': true,
          'status': complaint?['status']?.toString() ?? 'Reported',
        },
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('SOS failed: $e')));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<_EmergencyCategory?> _showCategoryPicker() async {
    return showModalBottomSheet<_EmergencyCategory>(
      context: context,
      backgroundColor: const Color(0xFF121212),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Select Emergency Type',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _categories
                    .map(
                      (category) => InkWell(
                        onTap: () => Navigator.pop(context, category),
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          width: 150,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                category.icon,
                                color: Colors.white,
                                size: 34,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                category.label,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (_cameraReady && _controller != null)
            Center(
              child: AspectRatio(
                aspectRatio: _controller!.value.aspectRatio,
                child: CameraPreview(_controller!),
              ),
            )
          else
            Container(color: Colors.black),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.25),
                  Colors.black.withOpacity(0.55),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'Emergency Mode',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red.shade700,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: const Text(
                          'CRITICAL',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children:
                        const [
                          _CallChip(label: 'Ambulance 108', number: '108'),
                          _CallChip(label: 'Fire 101', number: '101'),
                          _CallChip(label: 'Police 100', number: '100'),
                          _CallChip(label: 'Emergency 112', number: '112'),
                        ].map((chip) {
                          return _CallChipWrapper(chip: chip);
                        }).toList(),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.55),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ElevatedButton.icon(
                          onPressed: _isSubmitting ? null : _reportEmergency,
                          icon: const Icon(
                            Icons.warning_amber_rounded,
                            size: 30,
                          ),
                          label: const Text(
                            'REPORT EMERGENCY',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.4,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red.shade700,
                            foregroundColor: Colors.white,
                            minimumSize: const Size.fromHeight(56),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: _isSubmitting ? null : _sendSos,
                          icon: const Icon(Icons.sos),
                          label: const Text('SOS - Send Location Alert'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white54),
                            minimumSize: const Size.fromHeight(46),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _position == null
                              ? 'Detecting location...'
                              : 'Location auto-captured',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmergencyCategory {
  final String label;
  final IconData icon;
  final String apiValue;

  const _EmergencyCategory(this.label, this.icon, this.apiValue);
}

class _CallChip {
  final String label;
  final String number;

  const _CallChip({required this.label, required this.number});
}

class _CallChipWrapper extends StatelessWidget {
  final _CallChip chip;

  const _CallChipWrapper({required this.chip});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final uri = Uri(scheme: 'tel', path: chip.number);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
        }
      },
      borderRadius: BorderRadius.circular(30),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.16),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Text(
          chip.label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
