import 'package:flutter/material.dart';
import '../services/api_service.dart';

class ComplaintDetailScreen extends StatefulWidget {
  const ComplaintDetailScreen({super.key});

  @override
  State<ComplaintDetailScreen> createState() => _ComplaintDetailScreenState();
}

class _ComplaintDetailScreenState extends State<ComplaintDetailScreen> {
  Map<String, dynamic>? _complaintData;
  bool _isLoading = true;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadComplaint();
  }

  Future<void> _loadComplaint() async {
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final complaintId = args?['complaintId']?.toString();

    if (complaintId == null || complaintId.isEmpty) {
      setState(() {
        _error = 'No Complaint ID provided';
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final data = await ApiService.fetchComplaintById(complaintId);
      setState(() {
        _complaintData = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Submitted':
        return Colors.blue;
      case 'In Review':
        return Colors.orange;
      case 'In Progress':
      case 'Help Arriving':
        return Colors.purple;
      case 'Resolved':
      case 'Closed':
        return Colors.green;
      case 'Rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
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

  Widget _infoTile(String title, String? value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$title: ',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Expanded(
              child: Text(value?.isNotEmpty == true ? value! : 'N/A'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Issue Details'),
        backgroundColor: const Color(0xFF4A148C),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadComplaint,
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _buildContent(),
    );
  }

  Widget _buildContent() {
    final complaint = _complaintData ?? <String, dynamic>{};
    final id = complaint['complaint_id']?.toString() ?? 'N/A';
    final status = complaint['status']?.toString() ?? 'Unknown';
    final rawPath = complaint['image_path'] ?? '';

    String imageUrl = '';

    if (rawPath.startsWith('http')) {
      // cloudinary / external
      imageUrl = rawPath;
    } else {
      // local uploads
      imageUrl ='${ApiService.baseUrl}/${rawPath.toString().replaceAll("\\", "/")}';
    }

    final address = complaint['address'] is Map
        ? (complaint['address'] as Map).cast<String, dynamic>()
        : <String, dynamic>{};

    final locationText = complaint['location_name']?.toString() ??
        [
          address['suburb'],
          address['neighbourhood'],
          address['village'],
          address['town'],
          address['city'],
          address['state']
        ].where((e) => (e?.toString().trim().isNotEmpty ?? false)).join(', ');

    return RefreshIndicator(
      onRefresh: _loadComplaint,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: GestureDetector(
              onTap: () => _openImageZoom(imageUrl),
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  Image.network(
                    imageUrl,
                    height: 210,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      height: 210,
                      color: Colors.grey.shade100,
                      alignment: Alignment.center,
                      child: const Text('No image available'),
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
          const SizedBox(height: 14),
          _infoTile('Issue ID', id),
          _infoTile('Issue Type', complaint['category']?.toString()),
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                const Text('Status: ', style: TextStyle(fontWeight: FontWeight.bold)),
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
          _infoTile('Location', locationText),
          _infoTile('Reported Time', _formatAccurateTime(complaint['created_at']?.toString())),
          _infoTile('Upvotes', ((complaint['upvotes'] as num?)?.toInt() ?? 0).toString()),
          _infoTile('Reporter', complaint['reporter_email']?.toString()),
          const SizedBox(height: 10),
          const Text(
            'Complaint Form',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(complaint['letter']?.toString() ?? 'No complaint form content available'),
          ),
        ],
      ),
    );
  }
}
