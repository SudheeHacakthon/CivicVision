import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;

class ResultScreen extends StatefulWidget {
  const ResultScreen({super.key});

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  late TextEditingController _letterController;
  bool isEditing = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

    final letter = args?['letter']?.toString() ?? "";

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
    final issueType = args?['issueType']?.toString() ?? "Unknown";
    final confidence = args?['confidence']?.toString() ?? "0";
    final complaintId = args?['complaintId']?.toString() ?? "N/A";

    return Scaffold(
      appBar: AppBar(
        title: const Text("AI Evaluation"),
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
          )
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
              child: kIsWeb
                  ? Image.network(imagePath, fit: BoxFit.cover)
                  : Image.file(File(imagePath), fit: BoxFit.cover),
            ),

            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  _infoTile("Issue Type", issueType),
                  _infoTile("Confidence", confidence),
                  _infoTile("Complaint ID", complaintId),

                  const SizedBox(height: 25),

                  const Text(
                    "Official Complaint Letter",
                    style: TextStyle(
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
                        : Text(_letterController.text),
                  ),

                  const SizedBox(height: 30),

                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4A148C),
                      minimumSize: const Size(double.infinity, 55),
                    ),
                    onPressed: () {
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
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoTile(String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Row(
        children: [
          Text(
            "$title: ",
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
