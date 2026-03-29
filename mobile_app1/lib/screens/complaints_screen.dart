import 'package:flutter/material.dart';
import '../services/api_service.dart';

class ComplaintsScreen extends StatelessWidget {
  const ComplaintsScreen({super.key});

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

    final location = complaint['location_name']?.toString() ?? complaint['location']?.toString();
    if (location != null && location.trim().isNotEmpty) {
      final parts = location.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      if (parts.length >= 2) return parts[1];
      return parts.first;
    }

    return 'Hyderabad';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("My Complaints"),
        backgroundColor: const Color(0xFF4A148C),
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<List<dynamic>>(
        future: ApiService.fetchComplaints(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No complaints found'));
          } else {
            final complaints = List<dynamic>.from(snapshot.data!);
            complaints.sort((a, b) {
              final mapA = a as Map<String, dynamic>;
              final mapB = b as Map<String, dynamic>;

              final dateA = DateTime.tryParse(mapA['created_at']?.toString() ?? '');
              final dateB = DateTime.tryParse(mapB['created_at']?.toString() ?? '');

              // Keep newest complaints first; unknown dates go to the bottom.
              if (dateA == null && dateB == null) return 0;
              if (dateA == null) return 1;
              if (dateB == null) return -1;
              return dateB.compareTo(dateA);
            });
            return ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: complaints.length,
              itemBuilder: (context, index) {
                final complaint = complaints[index] as Map<String, dynamic>;
                final id = complaint['complaint_id']?.toString() ?? 'N/A';
                final readableId = _toReadableId(id);
                final category = complaint['category']?.toString() ?? 'N/A';
                final status = complaint['status']?.toString() ?? 'N/A';
                final createdAt = complaint['created_at']?.toString();
                final city = _cityFromComplaint(complaint);

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () {
                      Navigator.pushNamed(
                        context,
                        '/complaint_detail',
                        arguments: {'complaintId': id},
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.report_problem_outlined,
                                  color: Color(0xFF4A148C), size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  category,
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: status == 'Resolved'
                                      ? Colors.green.withOpacity(0.15)
                                      : Colors.orange.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  status,
                                  style: TextStyle(
                                    color: status == 'Resolved'
                                        ? Colors.green.shade800
                                        : Colors.orange.shade800,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
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
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          }
        },
      ),
    );
  }
}
