import 'package:flutter/material.dart';
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
    final issueType = args?['issueType']?.toString() ?? "Unknown";
    final confidence = args?['confidence']?.toString() ?? "0";
    final complaintId = args?['complaintId']?.toString() ?? "N/A";
    final isEmergency = args?['isEmergency'] == true;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEmergency
              ? AppTranslations.get("emergency_report", lang)
              : AppTranslations.get("ai_evaluation", lang),
        ),
        backgroundColor: const Color(0xFF4A148C),
        foregroundColor: Colors.white,
        actions: [
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
      body: SingleChildScrollView(
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
                        : Image.file(File(imagePath), fit: BoxFit.cover)),
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
                    AppTranslations.get("confidence", lang),
                    isTranslating
                        ? "Translating..."
                        : (translatedConfidence ?? confidence),
                  ),
                  _infoTile(
                    AppTranslations.get("complaint_id", lang),
                    complaintId,
                  ),

                  if (isEmergency) ...[
                    const SizedBox(height: 8),
                    _buildEmergencyStatusCard(complaintId),
                  ],

                  const SizedBox(height: 25),

                  Text(
                    AppTranslations.get("complaint_letter", lang),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 10),

                  // LETTER BOX
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: isEditing
                        ? TextField(
                            controller: _letterController,
                            maxLines: null,
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                            ),
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
                    onPressed: isEmergency
                        ? null
                        : () {
                            // later we send edited letter to backend if needed
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  AppTranslations.get("letter_submitted", lang),
                                ),
                              ),
                            );
                          },
                    child: Text(
                      AppTranslations.get("submit_portal", lang),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
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
