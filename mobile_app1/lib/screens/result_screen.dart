import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;

class ResultScreen extends StatelessWidget {
  const ResultScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Safely retrieve arguments passed from CaptureScreen
    final args =
        ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
    final String path = args['imagePath'];

    return Scaffold(
      appBar: AppBar(
        title: const Text("AI Evaluation"),
        backgroundColor: const Color(0xFF4A148C),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              height: 320,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey[900],
                boxShadow: const [
                  BoxShadow(color: Colors.black26, blurRadius: 10),
                ],
              ),
              // FIX: This prevents the 'Image.file is not supported on Web' error
              child: kIsWeb
                  ? Image.network(path, fit: BoxFit.cover)
                  : Image.file(File(path), fit: BoxFit.cover),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // FIX: Corrected icon names to prevent 'undefined_getter' errors
                  _buildResultRow(
                    "Detected Issue",
                    args['issueType'],
                    LucideIcons.triangle_alert,
                    Colors.orange,
                  ),
                  _buildResultRow(
                    "AI Confidence",
                    args['confidence'] ?? "94.2%",
                    LucideIcons.brain,
                    Colors.blue,
                  ),
                  _buildResultRow(
                    "Priority",
                    args['severity'],
                    LucideIcons.zap,
                    Colors.red,
                  ),
                  const SizedBox(height: 40),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4A148C),
                      minimumSize: const Size(double.infinity, 60),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    onPressed: () =>
                        Navigator.popUntil(context, ModalRoute.withName('/')),
                    child: const Text(
                      "SUBMIT TO PORTAL",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
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

  Widget _buildResultRow(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
