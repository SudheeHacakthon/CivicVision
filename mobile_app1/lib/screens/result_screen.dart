import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../services/api_service.dart';

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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

    final letter = args?['letter']?.toString() ?? "";
    _emergencyStatus = args?['status']?.toString();

    _letterController = TextEditingController(text: letter);
  }

  @override
  void dispose() {
    _letterController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
        title: Text(isEmergency ? "Emergency Report" : "AI Evaluation"),
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
                  _infoTile("Issue Type", issueType),
                  _infoTile("Confidence", confidence),
                  _infoTile("Complaint ID", complaintId),

                  if (isEmergency) ...[
                    const SizedBox(height: 8),
                    _buildEmergencyStatusCard(complaintId),
                  ],

                  const SizedBox(height: 25),

                  const Text(
                    "Official Complaint Letter",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                        : Text(_letterController.text),
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
                              const SnackBar(
                                content: Text("Letter Submitted Successfully"),
                              ),
                            );
                          },
                    child: const Text(
                      "SUBMIT TO PORTAL",
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
