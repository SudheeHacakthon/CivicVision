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
      final sorted = List<dynamic>.from(data);
      sorted.sort((a, b) {
        final mapA = a as Map<String, dynamic>;
        final mapB = b as Map<String, dynamic>;
        final dateA = DateTime.tryParse(mapA['created_at']?.toString() ?? '');
        final dateB = DateTime.tryParse(mapB['created_at']?.toString() ?? '');
        if (dateA == null && dateB == null) return 0;
        if (dateA == null) return 1;
        if (dateB == null) return -1;
        return dateB.compareTo(dateA);
      });
      setState(() {
        complaints = sorted;
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

  String _toReadableId(String rawId) {
    if (rawId == 'N/A' || rawId.trim().isEmpty) return 'N/A';
    final clean = rawId.replaceAll('-', '').toUpperCase();
    if (clean.length >= 8) {
      return 'CV-${clean.substring(0, 4)}-${clean.substring(clean.length - 4)}';
    }
    return 'CV-$clean';
  }

  String _formatTimeAgo(String? createdAtRaw) {
    if (createdAtRaw == null || createdAtRaw.isEmpty) return 'Recently';
    final createdAt = DateTime.tryParse(createdAtRaw);
    if (createdAt == null) return 'Recently';

    final diff = DateTime.now().difference(createdAt.toLocal());
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} h ago';
    return '${diff.inDays} d ago';
  }

  String _cityFromComplaint(Map<String, dynamic> complaint) {
    final city = complaint['city']?.toString();
    if (city != null && city.trim().isNotEmpty) return city;

    final location =
        complaint['location_name']?.toString() ?? complaint['location']?.toString();
    if (location != null && location.trim().isNotEmpty) {
      final parts = location
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      if (parts.length >= 2) return parts[1];
      return parts.first;
    }

    return 'Unknown';
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Resolved':
        return Colors.green;
      case 'Rejected':
        return Colors.red;
      case 'In Progress':
        return Colors.purple;
      case 'In Review':
        return Colors.orange;
      default:
        return Colors.blue;
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
                          final readableId = _toReadableId(complaintId);
                          final category = complaint['category']?.toString() ?? 'N/A';
                          final currentStatus = complaint['status']?.toString() ?? 'Submitted';
                          final createdAt = complaint['created_at']?.toString();
                          final city = _cityFromComplaint(complaint);

                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.report_problem_outlined,
                                          size: 20, color: Color(0xFF4A148C)),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          category,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: _statusColor(currentStatus).withOpacity(0.12),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          currentStatus,
                                          style: TextStyle(
                                            color: _statusColor(currentStatus),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      const Icon(Icons.badge_outlined,
                                          size: 18, color: Colors.black54),
                                      const SizedBox(width: 6),
                                      Text(
                                        'ID: $readableId',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      const Icon(Icons.location_city_outlined,
                                          size: 18, color: Colors.black54),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          '$city • ${_formatTimeAgo(createdAt)}',
                                          style: const TextStyle(color: Colors.black54),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      const Text(
                                        'Update Status:',
                                        style: TextStyle(fontWeight: FontWeight.w600),
                                      ),
                                      const SizedBox(width: 12),
                                      DropdownButton<String>(
                                        value: currentStatus,
                                        borderRadius: BorderRadius.circular(12),
                                        items: statusOptions.map((status) {
                                          return DropdownMenuItem<String>(
                                            value: status,
                                            child: Text(status),
                                          );
                                        }).toList(),
                                        onChanged: (newStatus) {
                                          if (newStatus != null &&
                                              newStatus != currentStatus) {
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
