import 'package:flutter/material.dart';
import '../services/api_service.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  List<dynamic>? complaints;
  bool isLoading = true;
  String? error;

  final List<String> statusOptions = [
    'Submitted',
    'In Review',
    'In Progress',
    'Resolved',
    'Rejected'
  ];

  @override
  void initState() {
    super.initState();
    _loadComplaints();
  }

  Future<void> _loadComplaints() async {
    setState(() {
      isLoading = true;
      error = null;
    });
    try {
      final data = await ApiService.fetchComplaints();
      setState(() {
        complaints = data;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        error = e.toString();
        isLoading = false;
      });
    }
  }

  Future<void> _updateStatus(String complaintId, String newStatus) async {
    try {
      await ApiService.updateComplaintStatus(complaintId, newStatus);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Status updated to $newStatus')),
      );
      _loadComplaints(); // Reload the list
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update status: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Admin Dashboard"),
        backgroundColor: const Color(0xFF4A148C),
        foregroundColor: Colors.white,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? Center(child: Text('Error: $error'))
              : complaints == null || complaints!.isEmpty
                  ? const Center(child: Text('No complaints found'))
                  : RefreshIndicator(
                      onRefresh: _loadComplaints,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: complaints!.length,
                        itemBuilder: (context, index) {
                          final complaint = complaints![index] as Map<String, dynamic>;
                          final complaintId = complaint['complaint_id']?.toString() ?? 'N/A';
                          final category = complaint['category']?.toString() ?? 'N/A';
                          final currentStatus = complaint['status']?.toString() ?? 'Submitted';

                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Complaint ID: $complaintId',
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 8),
                                  Text('Category: $category'),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      const Text('Status: '),
                                      DropdownButton<String>(
                                        value: currentStatus,
                                        items: statusOptions.map((status) {
                                          return DropdownMenuItem<String>(
                                            value: status,
                                            child: Text(status),
                                          );
                                        }).toList(),
                                        onChanged: (newStatus) {
                                          if (newStatus != null && newStatus != currentStatus) {
                                            _updateStatus(complaintId, newStatus);
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
