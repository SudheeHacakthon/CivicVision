import 'package:flutter/material.dart';
import '../services/api_service.dart';

class ComplaintDetailScreen extends StatefulWidget {
  const ComplaintDetailScreen({super.key});

  @override
  State<ComplaintDetailScreen> createState() => _ComplaintDetailScreenState();
}

class _ComplaintDetailScreenState extends State<ComplaintDetailScreen> {
  Map<String, dynamic>? complaintData;
  bool isLoading = true;
  String? error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadComplaint();
  }

  Future<void> _loadComplaint() async {
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

    final complaintId = args?['complaintId'];

    if (complaintId == null) {
      setState(() {
        error = "No Complaint ID provided";
        isLoading = false;
      });
      return;
    }

    try {
      final data =
          await ApiService.fetchComplaintById(complaintId.toString());

      setState(() {
        complaintData = data;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        error = e.toString();
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Complaint Status"),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadComplaint,
          )
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? Center(child: Text(error!))
              : _buildContent(),
    );
  }

  Widget _buildContent() {
    final complaint = complaintData?['complaint'];
    final status = complaint?['status']?.toString() ?? 'Unknown';

    return RefreshIndicator(
      onRefresh: _loadComplaint,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _infoTile("Complaint ID", complaint?['complaint_id']?.toString()),
          _infoTile("Category", complaint?['category']),
          Padding(
            padding: const EdgeInsets.only(bottom: 15),
            child: Row(
              children: [
                const Text(
                  "Status: ",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _statusColor(status),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    status,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          _infoTile("Confidence",
              complaint?['confidence']?.toString()),
          const SizedBox(height: 30),
          const Text(
            "Official Letter",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Text(complaintData?['letter']?.toString() ?? "No letter found"),
        ],
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case "Submitted":
        return Colors.blue;
      case "In Review":
        return Colors.orange;
      case "In Progress":
        return Colors.purple;
      case "Resolved":
        return Colors.green;
      case "Rejected":
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Widget _infoTile(String title, String? value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Text(
              "$title: ",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Expanded(
              child: Text(value ?? "N/A"),
            ),
          ],
        ),
      ),
    );
  }
}
