import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
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
  String _sortBy = 'Priority'; // 'Priority' or 'Time'

  final List<String> statusOptions = [
    'Reported',
    'Submitted',
    'In Review',
    'In Progress',
    'Help Arriving',
    'Resolved',
    'Rejected',
    'Closed',
  ];

  @override
  void initState() {
    super.initState();
    _loadComplaints();
  }

  void _sortComplaintsList(List<dynamic> list) {
    list.sort((a, b) {
      final mapA = a as Map<String, dynamic>;
      final mapB = b as Map<String, dynamic>;

      final dateA = DateTime.tryParse(mapA['created_at']?.toString() ?? '');
      final dateB = DateTime.tryParse(mapB['created_at']?.toString() ?? '');

      if (_sortBy == 'Time') {
        if (dateA == null && dateB == null) return 0;
        if (dateA == null) return 1;
        if (dateB == null) return -1;
        return dateB.compareTo(dateA);
      } else {
        final pa = (mapA['priority_score'] ?? 0).toDouble();
        final pb = (mapB['priority_score'] ?? 0).toDouble();

        if (pa != pb) return pb.compareTo(pa);

        if (dateA == null && dateB == null) return 0;
        if (dateA == null) return 1;
        if (dateB == null) return -1;
        return dateB.compareTo(dateA);
      }
    });
  }

  Future<void> _loadComplaints() async {
    setState(() {
      isLoading = true;
      error = null;
    });
    try {
      final data = await ApiService.fetchAdminComplaints();
      final sorted = List<dynamic>.from(data);
      _sortComplaintsList(sorted);
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Status updated to $newStatus')));
      _loadComplaints(); // Reload the list
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to update status: $e')));
    }
  }

  void _openVerifyDialog(String complaintId) {
    String selectedCategory = 'Pothole';
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Verify Category'),
              content: DropdownButton<String>(
                value: selectedCategory,
                items: ['Pothole', 'Road Crack', 'Garbage', 'No Issue']
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (val) {
                  if (val != null) setDialogState(() => selectedCategory = val);
                },
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    try {
                      await ApiService.verifyComplaintCategory(
                        complaintId,
                        selectedCategory,
                      );
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Verified as $selectedCategory')),
                      );
                      _loadComplaints();
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed: $e')),
                      );
                    }
                  },
                  child: const Text('Verify'),
                ),
              ],
            );
          },
        );
      },
    );
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

  String _formatAccurateTime(String? createdAtRaw) {
    if (createdAtRaw == null || createdAtRaw.isEmpty) return 'Unknown time';
    final parsed = DateTime.tryParse(createdAtRaw);
    if (parsed == null) return 'Unknown time';
    final local = parsed.toLocal();

    String two(int v) => v.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}:${two(local.second)}';
  }

  String _cityFromComplaint(Map<String, dynamic> complaint) {
    final city = complaint['city']?.toString();
    if (city != null && city.trim().isNotEmpty) return city;

    final location =
        complaint['location_name']?.toString() ??
        complaint['location']?.toString();
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

  String _placeFromComplaint(Map<String, dynamic> complaint) {
    final locationName = complaint['location_name']?.toString();
    if (locationName != null && locationName.trim().isNotEmpty) {
      return locationName;
    }

    final fallback = complaint['location']?.toString();
    if (fallback != null && fallback.trim().isNotEmpty) {
      return fallback;
    }

    return _cityFromComplaint(complaint);
  }

  String _addressLabels(Map<String, dynamic> complaint) {
    final dynamic rawAddress = complaint['address'];
    if (rawAddress is Map) {
      final address = rawAddress.cast<String, dynamic>();
      final parts = <String>[];

      void addLabel(String label, String key) {
        final value = address[key]?.toString();
        if (value != null && value.trim().isNotEmpty) {
          parts.add('$label: ${value.trim()}');
        }
      }

      addLabel('Locality', 'suburb');
      addLabel('Neighbourhood', 'neighbourhood');
      addLabel('Village', 'village');
      addLabel('Town', 'town');
      addLabel('City', 'city');
      addLabel('State', 'state');

      if (parts.isNotEmpty) return parts.join(' | ');
    }

    return _placeFromComplaint(complaint);
  }

  void _openImageZoom(String imageUrl) {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(12),
        child: InteractiveViewer(
          minScale: 0.8,
          maxScale: 4.0,
          child: Image.network(
            imageUrl,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => const SizedBox(
              height: 240,
              child: Center(child: Text('Unable to load image')),
            ),
          ),
        ),
      ),
    );
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

  Color _priorityColor(String? priority) {
    switch (priority) {
      case 'HIGH':
        return Colors.red;
      case 'MEDIUM':
        return Colors.orange;
      case 'LOW':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Color getScoreColor(double score) {
    if (score >= 0.7) return Colors.red;
    if (score >= 0.4) return Colors.orange;
    return Colors.green;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Admin Dashboard"),
        backgroundColor: const Color(0xFF4A148C),
        foregroundColor: Colors.white,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort),
            tooltip: 'Sort by',
            onSelected: (value) {
              setState(() {
                _sortBy = value;
                if (complaints != null) {
                  _sortComplaintsList(complaints!);
                }
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'Priority',
                child: Text('Sort by Priority'),
              ),
              const PopupMenuItem(
                value: 'Time',
                child: Text('Sort by Time (Newest)'),
              ),
            ],
          ),
        ],
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
                itemCount: (complaints?.length ?? 0) + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    final adminEmail = context.read<AuthProvider>().email ?? 'Admin';
                    final adminName = adminEmail.split('@').first;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 20, left: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Welcome, $adminName",
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF4A148C),
                            ),
                          ),
                          const Text(
                            "Here is your city's activity overview",
                            style: TextStyle(color: Colors.black54),
                          ),
                        ],
                      ),
                    );
                  }
                  final complaint = complaints![index - 1] as Map<String, dynamic>;
                  final complaintId =
                      complaint['complaint_id']?.toString() ?? 'N/A';
                  final readableId = _toReadableId(complaintId);
                  final category = complaint['category']?.toString() ?? 'N/A';
                  final currentStatus =
                      complaint['status']?.toString() ?? 'Submitted';
                  final createdAt = complaint['created_at']?.toString();
                  final city = _cityFromComplaint(complaint);
                  final place = _placeFromComplaint(complaint);
                  final addressLabels = _addressLabels(complaint);
                  final rawImageUrl = complaint['image_url']?.toString();
                  final imageUrl = (rawImageUrl != null && rawImageUrl.isNotEmpty)
                      ? rawImageUrl
                      : '${ApiService.baseUrl}/complaint/$complaintId/image';

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (complaintId != 'N/A') ...[
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: GestureDetector(
                                onTap: () => _openImageZoom(imageUrl),
                                child: Stack(
                                  alignment: Alignment.bottomRight,
                                  children: [
                                    Image.network(
                                      imageUrl,
                                      height: 170,
                                      width: double.infinity,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, _, _) => Container(
                                        height: 170,
                                        color: Colors.grey.shade100,
                                        alignment: Alignment.center,
                                        child: const Text('No image preview'),
                                      ),
                                    ),
                                    Container(
                                      margin: const EdgeInsets.all(8),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.black54,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Text(
                                        'Tap to zoom',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                          Row(
                            children: [
                              const Icon(
                                Icons.report_problem_outlined,
                                color: Color(0xFF4A148C),
                                size: 20,
                              ),
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
                                  color: _statusColor(
                                    currentStatus,
                                  ).withOpacity(0.15),
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
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: _priorityColor(
                                    complaint['priority'],
                                  ).withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  complaint['priority'] ?? 'LOW',
                                  style: TextStyle(
                                    color: _priorityColor(
                                      complaint['priority'],
                                    ),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          Row(
                            children: [
                              const Icon(
                                Icons.badge_outlined,
                                size: 18,
                                color: Colors.black54,
                              ),
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

                          const SizedBox(height: 6),
                          Builder(
                            builder: (context) {
                              final score = (complaint['priority_score'] ?? 0)
                                  .toDouble();
                              return Row(
                                children: [
                                  const Icon(
                                    Icons.analytics_outlined,
                                    size: 18,
                                    color: Colors.black54,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Priority Score: ${score.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: getScoreColor(score),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(
                                Icons.location_city_outlined,
                                size: 18,
                                color: Colors.black54,
                              ),
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
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(
                                Icons.place_outlined,
                                size: 18,
                                color: Colors.black54,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  place,
                                  style: const TextStyle(color: Colors.black54),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 2,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            addressLabels,
                            style: const TextStyle(
                              color: Colors.black54,
                              fontSize: 12,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(
                                Icons.access_time,
                                size: 18,
                                color: Colors.black54,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Reported at: ${_formatAccurateTime(createdAt)}',
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
                              if (currentStatus == 'Needs Review')
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.orange,
                                    foregroundColor: Colors.white,
                                  ),
                                  onPressed: () => _openVerifyDialog(complaintId),
                                  child: const Text('Verify Category'),
                                )
                              else
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
                          const SizedBox(height: 6),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              onPressed: () {
                                Navigator.pushNamed(
                                  context,
                                  '/complaint_detail',
                                  arguments: {'complaintId': complaintId},
                                );
                              },
                              icon: const Icon(Icons.info_outline),
                              label: const Text('More details'),
                            ),
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
