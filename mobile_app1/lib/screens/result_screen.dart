import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../services/api_service.dart';
import '../services/translation_service.dart';
import '../providers/language_provider.dart';
import 'package:provider/provider.dart';
import '../utils/app_translations.dart';

class ResultScreen extends StatefulWidget {
  const ResultScreen({super.key});

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  late TextEditingController _letterController;
  bool isEditing = false;
  String? _emergencyStatus;
  bool _loadingStatus = false;
  String? translatedIssue;
  String? translatedLetter;
  bool isTranslating = true;
  String? translatedConfidence;
  String? lastLang;
  String? translationError;
  int retryCount = 0;
  static const int maxRetries = 3;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final lang = context.watch<LanguageProvider>().currentLang;

    if (lastLang == lang) return; // ✅ prevent unnecessary calls

    lastLang = lang;

    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

    final letter = args?['letter']?.toString() ?? "";
    final issue = args?['issueType']?.toString() ?? "";
    final confidence = args?['confidence']?.toString() ?? "";

    _letterController = TextEditingController(text: letter);

    _translateData(issue, letter, confidence);
  }

  Future<void> _translateData(
    String issue,
    String letter,
    String confidence,
  ) async {
    String lang = context.read<LanguageProvider>().currentLang;
    translationError = null;
    retryCount = 0;

    if (lang == "en") {
      setState(() {
        translatedIssue = issue;
        translatedLetter = letter;
        translatedConfidence = confidence;
        isTranslating = false;
      });
      return;
    }

    setState(() => isTranslating = true);

    while (retryCount < maxRetries) {
      try {
        print(
          "🔄 Translation attempt ${retryCount + 1}/$maxRetries (lang: $lang)",
        );

        final tIssue = await TranslationService.translate(
          text: issue,
          targetLang: lang,
        );
        List<String> lines = letter.split("\n");

        List<String> translatedLines = [];

        for (String line in lines) {
          if (line.trim().isEmpty) {
            translatedLines.add("");
            continue;
          }

          final tLine = await TranslationService.translate(
            text: line,
            targetLang: lang,
          );

          translatedLines.add(tLine);
        }

        final tLetter = translatedLines.join("\n");
        final tConfidence = await TranslationService.translate(
          text: confidence,
          targetLang: lang,
        );

        setState(() {
          translatedIssue = tIssue;
          translatedLetter = tLetter;
          translatedConfidence = tConfidence;
          _letterController.text = tLetter;
          isTranslating = false;
          translationError = null;
        });
        print("🎉 Translation success!");
        return;
      } catch (e) {
        retryCount++;
        print("❌ Attempt $retryCount failed: $e");
        if (retryCount >= maxRetries) {
          setState(() {
            translatedIssue = issue;
            translatedLetter = letter;
            translatedConfidence = confidence;
            isTranslating = false;
            translationError = AppTranslations.get("translation_failed", lang);
          });
          print("💥 All retries failed. Showing English + error.");
        } else {
          setState(() {
            isTranslating = true;
          });
          await Future.delayed(Duration(seconds: retryCount));
        }
      }
    }
  }

  @override
  void didUpdateWidget(covariant ResultScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

    final letter = args?['letter']?.toString() ?? "";
    final issue = args?['issueType']?.toString() ?? "";
    final confidence = args?['confidence']?.toString() ?? "";

    _translateData(issue, letter, confidence);
  }

  @override
  void dispose() {
    _letterController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String lang = context.watch<LanguageProvider>().currentLang;
    if (lastLang != lang) {
      lastLang = lang;

      final args =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

      final letter = args?['letter']?.toString() ?? "";
      final issue = args?['issueType']?.toString() ?? "";
      final confidence = args?['confidence']?.toString() ?? "";

      _translateData(issue, letter, confidence);
    }
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

    final imagePath = args?['imagePath']?.toString() ?? "";
    final imageBytes = args?['imageBytes'] as Uint8List?;
    final imageUrl = args?['imageUrl']?.toString();
    final issueType = args?['issueType']?.toString() ?? "Unknown";
    final confidence = args?['confidence']?.toString() ?? "0";
    final complaintId = args?['complaintId']?.toString() ?? "N/A";
    final isEmergency = args?['isEmergency'] == true;
    final isSos = issueType.toUpperCase().contains('SOS');

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isSos ? "LIVE SOS ACTIVE" : (isEmergency
              ? AppTranslations.get("emergency_report", lang)
              : AppTranslations.get("ai_evaluation", lang)),
        ),
        backgroundColor: isSos ? Colors.red.shade900 : Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: isSos ? null : [
          IconButton(
            icon: Icon(isEditing ? Icons.check : Icons.edit),
            onPressed: () {
              setState(() {
                isEditing = !isEditing;
              });
            },
          ),
        ],
      ),
      body: isSos ? _buildSosView(args, lang) : _buildRegularView(args, lang),
    );
  }

  Widget _buildSosView(Map<String, dynamic>? args, String lang) {
    final lat = args?['latitude'] as double? ?? 0.0;
    final lng = args?['longitude'] as double? ?? 0.0;

    return Container(
      color: Colors.black,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 30),
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.red.shade900.withOpacity(0.1),
              border: Border(bottom: BorderSide(color: Colors.red.shade900.withOpacity(0.3))),
            ),
            child: const Column(
              children: [
                _PulseIcon(),
                SizedBox(height: 15),
                Text(
                  "HELP IS ON THE WAY",
                  style: TextStyle(
                    color: Colors.red,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  "Authorities have been notified of your location",
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  options: MapOptions(
                    initialCenter: LatLng(lat, lng),
                    initialZoom: 16.0,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.mobile_app1',
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: LatLng(lat, lng),
                          width: 80,
                          height: 80,
                          child: const Icon(
                            Icons.location_on,
                            color: Colors.red,
                            size: 45,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Positioned(
                  bottom: 20,
                  left: 20,
                  right: 20,
                  child: Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.85),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.shade900),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "BROADCAST LOCATION",
                          style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 10),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Lat: ${lat.toStringAsFixed(6)}, Lng: ${lng.toStringAsFixed(6)}",
                          style: const TextStyle(color: Colors.white, fontSize: 16, fontFamily: 'monospace'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(20),
            color: const Color(0xFF1A1A1A),
            child: Column(
              children: [
                const Row(
                  children: [
                    Icon(Icons.shield, color: Colors.green, size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "Stay calm and wait for response. Help is being dispatched.",
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(0.05),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 50),
                    side: const BorderSide(color: Colors.white24),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text("I AM SAFE (DISMISS)"),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRegularView(Map<String, dynamic>? args, String lang) {
    final imagePath = args?['imagePath']?.toString() ?? "";
    final imageBytes = args?['imageBytes'] as Uint8List?;
    final issueType = args?['issueType']?.toString() ?? "Unknown";
    final confidence = args?['confidence']?.toString() ?? "0";
    final complaintId = args?['complaintId']?.toString() ?? "N/A";
    final isEmergency = args?['isEmergency'] == true;

    return SingleChildScrollView(
      child: Column(
        children: [
          // IMAGE
          Container(
            height: 300,
            width: double.infinity,
            color: Colors.grey[300],
            child: imageBytes != null
                ? Image.memory(imageBytes, fit: BoxFit.cover)
                : imagePath.isEmpty
                ? const Center(
                    child: Icon(
                      Icons.sos,
                      size: 70,
                      color: Color(0xFF4A148C),
                    ),
                  )
                : (kIsWeb
                      ? Image.network(imagePath, fit: BoxFit.cover)
                      : Image.file(
                          File(imagePath),
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => const Center(
                            child: Icon(
                              Icons.image_not_supported,
                              size: 70,
                              color: Colors.grey,
                            ),
                          ),
                        )),
          ),

          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _infoTile(
                  AppTranslations.get("issue_type", lang),
                  isTranslating
                      ? "Translating..."
                      : (translatedIssue ?? issueType),
                ),

                _infoTile(
                  AppTranslations.get("complaint_id", lang),
                  complaintId,
                ),
                
                const SizedBox(height: 10),
                
                // Deadline Banner
                if (!isEmergency && complaintId != 'N/A')
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today, color: Colors.blue.shade700, size: 22),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'The issue will be resolved mostly within ${args?["deadlineDays"] ?? 5} days.',
                            style: TextStyle(
                              color: Colors.blue.shade900,
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                if (isEmergency) ...[
                  const SizedBox(height: 8),
                  _buildEmergencyStatusCard(complaintId),
                ],

                const SizedBox(height: 25),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      AppTranslations.get("complaint_letter", lang),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          isEditing = !isEditing;
                        });
                      },
                      icon: Icon(isEditing ? Icons.check_circle : Icons.edit),
                      label: Text(isEditing ? "Finish Editing" : "Edit Letter"),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // LETTER BOX
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                    border: isEditing ? Border.all(color: const Color(0xFF4A148C), width: 1.5) : null,
                  ),
                  child: isEditing
                      ? TextField(
                          controller: _letterController,
                          maxLines: null,
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            hintText: "Enter your complaint details here...",
                          ),
                          style: const TextStyle(fontSize: 14, height: 1.4),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isTranslating
                                  ? AppTranslations.get(
                                      "retrying_translation",
                                      lang,
                                    )
                                  : (translatedLetter ??
                                        _letterController.text),
                              style: const TextStyle(fontSize: 14, height: 1.4),
                            ),
                            if (translationError != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  translationError!,
                                  style: TextStyle(
                                    color: Colors.orange[700],
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                          ],
                        ),
                ),

                const SizedBox(height: 30),

                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4A148C),
                    minimumSize: const Size(double.infinity, 55),
                  ),
                  onPressed: () async {
                    try {
                      if (isEditing) setState(() => isEditing = false);
                      await ApiService.updateLetter(complaintId, _letterController.text);
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(AppTranslations.get("letter_submitted", lang)),
                          backgroundColor: Colors.green,
                        ),
                      );
                      Navigator.of(context).popUntil((route) => route.isFirst);
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Submission failed: $e'), backgroundColor: Colors.red),
                      );
                    }
                  },
                  child: Text(
                    AppTranslations.get("submit_portal", lang),
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmergencyStatusCard(String complaintId) {
    final flow = ['Reported', 'In Progress', 'Help Arriving'];
    final currentStatus = _emergencyStatus ?? 'Reported';
    final currentIndex = flow.indexWhere((step) => step == currentStatus);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.emergency, color: Colors.red),
              const SizedBox(width: 8),
              const Text(
                'Emergency Status',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: _loadingStatus
                    ? null
                    : () => _refreshEmergencyStatus(complaintId),
                icon: _loadingStatus
                    ? const SizedBox(
                        height: 14,
                        width: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
                label: const Text('Refresh'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: flow.asMap().entries.map((entry) {
              final i = entry.key;
              final step = entry.value;
              final reached = currentIndex >= i;
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: reached ? Colors.red.shade700 : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  step,
                  style: TextStyle(
                    color: reached ? Colors.white : Colors.black54,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Future<void> _refreshEmergencyStatus(String complaintId) async {
    if (complaintId == 'N/A') return;
    setState(() => _loadingStatus = true);
    try {
      final statusRes = await ApiService.fetchEmergencyStatus(complaintId);
      setState(() {
        _emergencyStatus = statusRes['status']?.toString() ?? _emergencyStatus;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Status refresh failed: $e')));
    } finally {
      if (mounted) setState(() => _loadingStatus = false);
    }
  }

  Widget _infoTile(String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Row(
        children: [
          Text("$title: ", style: const TextStyle(fontWeight: FontWeight.bold)),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class _PulseIcon extends StatefulWidget {
  const _PulseIcon();

  @override
  State<_PulseIcon> createState() => _PulseIconState();
}

class _PulseIconState extends State<_PulseIcon> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.red.withOpacity(1.0 - _controller.value),
            border: Border.all(
              color: Colors.red.withOpacity(_controller.value),
              width: 4 * _controller.value,
            ),
          ),
          child: const Center(
            child: Icon(
              Icons.sos,
              color: Colors.white,
              size: 40,
            ),
          ),
        );
      },
    );
  }
}
