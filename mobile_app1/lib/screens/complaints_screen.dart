import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../providers/auth_provider.dart';

class ComplaintsScreen extends StatefulWidget {
  const ComplaintsScreen({super.key});

  @override
  State<ComplaintsScreen> createState() => _ComplaintsScreenState();
}

class _ComplaintsScreenState extends State<ComplaintsScreen> {
  bool _initialized = false;
  bool _isPublicScope = false;
  bool _isLoading = true;
  List<Map<String, dynamic>> _complaints = [];
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;

    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final scope = (args?['scope']?.toString() ?? 'my').toLowerCase();
    _isPublicScope = scope == 'public';
    _initialized = true;
    _loadComplaints();
  }

  Future<void> _loadComplaints() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final auth = context.read<AuthProvider>();
      final data = _isPublicScope
          ? await ApiService.fetchComplaints()
          : await ApiService.fetchMyComplaints(auth.email ?? '');

      final complaints = data
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();

      complaints.sort((a, b) {
        final dateA = DateTime.tryParse(a['created_at']?.toString() ?? '');
        final dateB = DateTime.tryParse(b['created_at']?.toString() ?? '');

        if (dateA == null && dateB == null) return 0;
        if (dateA == null) return 1;
        if (dateB == null) return -1;
        return dateB.compareTo(dateA);
      });

      setState(() {
        _complaints = complaints;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _upvoteComplaint(int index) async {
    final id = _complaints[index]['complaint_id']?.toString();
    if (id == null || id.isEmpty || id == 'N/A') return;

    try {
      final auth = context.read<AuthProvider>();
      final email = auth.email ?? '';
      if (email.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please log in to upvote')),
        );
        return;
      }
      final res = await ApiService.upvoteComplaint(id, email);
      final updatedVotes = (res['upvotes'] as num?)?.toInt() ?? ((_complaints[index]['upvotes'] as num?)?.toInt() ?? 0) + 1;
      setState(() {
        _complaints[index]['upvotes'] = updatedVotes;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not upvote right now (Maybe already upvoted)')),
      );
    }
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
            errorBuilder: (_, __, ___) => const SizedBox(
              height: 240,
              child: Center(child: Text('Unable to load image')),
            ),
          ),
        ),
      ),
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

    final location = complaint['location_name']?.toString() ?? complaint['location']?.toString();
    if (location != null && location.trim().isNotEmpty) {
      final parts = location.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isPublicScope ? 'Public Issues' : 'My Complaints'),
        backgroundColor: const Color(0xFF4A148C),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('Error: $_error'))
              : _complaints.isEmpty
                  ? Center(child: Text(_isPublicScope ? 'No public issues found' : 'No complaints found'))
                  : RefreshIndicator(
                      onRefresh: _loadComplaints,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _complaints.length,
                        itemBuilder: (context, index) {
                          final complaint = _complaints[index];
                          final id = complaint['complaint_id']?.toString() ?? 'N/A';
                          final readableId = _toReadableId(id);
                          final category = complaint['category']?.toString() ?? 'N/A';
                          final status = complaint['status']?.toString() ?? 'N/A';
                          final createdAt = complaint['created_at']?.toString();
                          final city = _cityFromComplaint(complaint);
                          final place = _placeFromComplaint(complaint);
                          final addressLabels = _addressLabels(complaint);
                          final upvotes = (complaint['upvotes'] as num?)?.toInt() ?? 0;
                          final rawImageUrl = complaint['image_url']?.toString();
                          final imageUrl = (rawImageUrl != null && rawImageUrl.isNotEmpty)
                              ? rawImageUrl
                              : '${ApiService.baseUrl}/complaint/$id/image';


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
                                  if (!_isPublicScope && status.toLowerCase().contains('rejected')) ...[
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(12),
                                      margin: const EdgeInsets.only(bottom: 12),
                                      decoration: BoxDecoration(
                                        color: Colors.red.shade50,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: Colors.red.shade200),
                                      ),
                                      child: const Text(
                                        'Your reported issue was marked as No Issue by our reviewers.',
                                        style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                  ],
                                  if (id != 'N/A') ...[
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
                                              errorBuilder: (_, __, ___) => Container(
                                                height: 170,
                                                color: Colors.grey.shade100,
                                                alignment: Alignment.center,
                                                child: const Text('No image preview'),
                                              ),
                                            ),
                                            Container(
                                              margin: const EdgeInsets.all(8),
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: Colors.black54,
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: const Text(
                                                'Tap to zoom',
                                                style: TextStyle(color: Colors.white, fontSize: 11),
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
                                              : status.toLowerCase().contains('rejected')
                                                  ? Colors.red.withOpacity(0.15)
                                                  : Colors.orange.withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          status,
                                          style: TextStyle(
                                            color: status == 'Resolved'
                                                ? Colors.green.shade800
                                                : status.toLowerCase().contains('rejected')
                                                    ? Colors.red.shade800
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
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      const Icon(Icons.place_outlined, size: 18, color: Colors.black54),
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
                                    style: const TextStyle(color: Colors.black54, fontSize: 12),
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      const Icon(Icons.access_time, size: 18, color: Colors.black54),
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
                                      if (_isPublicScope) ...[
                                        IconButton(
                                          icon: const Icon(Icons.thumb_up_alt_outlined),
                                          color: Colors.indigo,
                                          onPressed: () => _upvoteComplaint(index),
                                        ),
                                        Text(
                                          '$upvotes',
                                          style: const TextStyle(fontWeight: FontWeight.w700),
                                        ),
                                        const Spacer(),
                                      ],
                                      TextButton.icon(
                                        onPressed: () {
                                          Navigator.pushNamed(
                                            context,
                                            '/complaint_detail',
                                            arguments: {'complaintId': id},
                                          );
                                        },
                                        icon: const Icon(Icons.info_outline),
                                        label: const Text('More details'),
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
