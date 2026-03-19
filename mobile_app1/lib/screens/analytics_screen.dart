import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/api_service.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  late Future<_AnalyticsData> _future;
  final MapController _mapController = MapController();
  double _mapZoom = 11;

  @override
  void initState() {
    super.initState();
    _future = _loadData();
  }

  Future<_AnalyticsData> _loadData() async {
    final results = await Future.wait<dynamic>([
      ApiService.fetchAnalytics(),
      ApiService.fetchAdminDashboard(),
      ApiService.fetchHeatmap(),
    ]);

    final analytics = results[0] as Map<String, dynamic>;
    final admin = results[1] as Map<String, dynamic>;
    final heatmap = results[2] as List<dynamic>;

    final rawCategoryData = analytics['complaints_by_category'] as List<dynamic>? ?? [];
    final categoryData = <String, int>{};
    for (final item in rawCategoryData) {
      final row = item as Map<String, dynamic>;
      final name = row['_id']?.toString() ?? 'Unknown';
      final count = (row['count'] as num?)?.toInt() ?? 0;
      categoryData[name] = count;
    }

    final statusBreakdown =
        admin['status_breakdown'] as Map<String, dynamic>? ?? <String, dynamic>{};

    final statusData = <String, int>{
      'Submitted': (statusBreakdown['submitted'] as num?)?.toInt() ?? 0,
      'In Review': (statusBreakdown['in_review'] as num?)?.toInt() ?? 0,
      'In Progress': (statusBreakdown['in_progress'] as num?)?.toInt() ?? 0,
      'Resolved': (statusBreakdown['resolved'] as num?)?.toInt() ?? 0,
      'Rejected': (statusBreakdown['rejected'] as num?)?.toInt() ?? 0,
    };

    final total = (admin['total_complaints'] as num?)?.toInt() ?? 0;
    final pending = statusData['Submitted']! +
        statusData['In Review']! +
        statusData['In Progress']!;
    final resolved = statusData['Resolved']!;

    final points = <MapPoint>[];
    for (final item in heatmap) {
      final row = item as Map<String, dynamic>;
      final lat = (row['lat'] as num?)?.toDouble();
      final lng = (row['lng'] as num?)?.toDouble();
      if (lat == null || lng == null) continue;
      points.add(MapPoint(
        point: LatLng(lat, lng),
        category: row['category']?.toString() ?? 'Other',
      ));
    }

    return _AnalyticsData(
      total: total,
      pending: pending,
      resolved: resolved,
      categoryData: categoryData,
      statusData: statusData,
      mapPoints: points,
    );
  }

  Color _categoryColor(String key) {
    switch (key.toLowerCase()) {
      case 'pothole':
        return Colors.red.shade500;
      case 'garbage':
        return Colors.orange.shade600;
      case 'road crack':
      case 'crack':
        return Colors.purple.shade500;
      case 'no issue':
        return Colors.green.shade600;
      default:
        return Colors.blueGrey;
    }
  }

  Color _statusColor(String key) {
    switch (key) {
      case 'Resolved':
        return Colors.green.shade600;
      case 'Rejected':
        return Colors.red.shade500;
      case 'In Progress':
        return Colors.purple.shade500;
      case 'In Review':
        return Colors.orange.shade600;
      default:
        return Colors.blue.shade500;
    }
  }

  Widget _summaryCard(String label, int value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            '$value',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildBars({
    required String title,
    required Map<String, int> data,
    required Color Function(String key) colorResolver,
  }) {
    final sorted = data.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final maxValue = sorted.isEmpty ? 1 : sorted.first.value.clamp(1, 1 << 30);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 14),
          if (sorted.isEmpty)
            const Text('No data available', style: TextStyle(color: Colors.black54))
          else
            ...sorted.map((entry) {
              final color = colorResolver(entry.key);
              final ratio = entry.value / maxValue;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            entry.key,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        Text(
                          '${entry.value}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: ratio,
                        minHeight: 10,
                        backgroundColor: color.withOpacity(0.18),
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics Dashboard'),
        backgroundColor: const Color(0xFF4A148C),
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<_AnalyticsData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData) {
            return const Center(child: Text('No data available'));
          } else {
            final data = snapshot.data!;
            final center = data.mapPoints.isNotEmpty
                ? data.mapPoints.first.point
                : const LatLng(17.3850, 78.4867);

            return RefreshIndicator(
              onRefresh: () async {
                setState(() {
                  _future = _loadData();
                });
                await _future;
              },
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _summaryCard(
                          'Total',
                          data.total,
                          Colors.indigo,
                          Icons.assessment_outlined,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _summaryCard(
                          'Pending',
                          data.pending,
                          Colors.orange,
                          Icons.pending_actions_outlined,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _summaryCard(
                          'Resolved',
                          data.resolved,
                          Colors.green,
                          Icons.task_alt_outlined,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildBars(
                    title: 'Category Chart',
                    data: data.categoryData,
                    colorResolver: _categoryColor,
                  ),
                  const SizedBox(height: 16),
                  _buildBars(
                    title: 'Status Chart',
                    data: data.statusData,
                    colorResolver: _statusColor,
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Map Visualization',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 260,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Stack(
                              children: [
                                FlutterMap(
                                  mapController: _mapController,
                                  options: MapOptions(
                                    initialCenter: center,
                                    initialZoom: 11,
                                    interactionOptions: const InteractionOptions(
                                      flags: InteractiveFlag.all,
                                    ),
                                    onPositionChanged: (position, _) {
                                      final zoom = position.zoom;
                                      if (zoom != null) {
                                        _mapZoom = zoom;
                                      }
                                    },
                                  ),
                                  children: [
                                    TileLayer(
                                      urlTemplate:
                                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                      userAgentPackageName: 'com.civicvision.app',
                                    ),
                                    CircleLayer(
                                      circles: data.mapPoints
                                          .map(
                                            (item) => CircleMarker(
                                              point: item.point,
                                              radius: 14,
                                              color: _categoryColor(item.category)
                                                  .withOpacity(0.45),
                                              borderColor:
                                                  _categoryColor(item.category),
                                              borderStrokeWidth: 1.2,
                                            ),
                                          )
                                          .toList(),
                                    ),
                                  ],
                                ),
                                Positioned(
                                  right: 10,
                                  bottom: 10,
                                  child: Column(
                                    children: [
                                      FloatingActionButton.small(
                                        heroTag: 'analytics_zoom_in',
                                        onPressed: () {
                                          _mapZoom += 1;
                                          _mapController.move(
                                            _mapController.camera.center,
                                            _mapZoom,
                                          );
                                        },
                                        child: const Icon(Icons.add),
                                      ),
                                      const SizedBox(height: 8),
                                      FloatingActionButton.small(
                                        heroTag: 'analytics_zoom_out',
                                        onPressed: () {
                                          _mapZoom -= 1;
                                          _mapController.move(
                                            _mapController.camera.center,
                                            _mapZoom,
                                          );
                                        },
                                        child: const Icon(Icons.remove),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Showing ${data.mapPoints.length} complaint locations',
                          style: const TextStyle(color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }
        },
      ),
    );
  }
}

class _AnalyticsData {
  final int total;
  final int pending;
  final int resolved;
  final Map<String, int> categoryData;
  final Map<String, int> statusData;
  final List<MapPoint> mapPoints;

  _AnalyticsData({
    required this.total,
    required this.pending,
    required this.resolved,
    required this.categoryData,
    required this.statusData,
    required this.mapPoints,
  });
}

class MapPoint {
  final LatLng point;
  final String category;

  MapPoint({required this.point, required this.category});
}
