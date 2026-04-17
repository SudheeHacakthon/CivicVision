import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mobile_app1/services/api_service.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  LatLng? currentLocation;
  final LatLng fallbackLocation = const LatLng(17.3850, 78.4867); // Hyderabad
  final MapController _mapController = MapController();
  double _currentZoom = 12.0;

  List<CircleMarker> heatmapCircles = [];
  List<Map<String, dynamic>> mapIssues = [];

  @override
  void initState() {
    super.initState();
    _loadLocation();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

    final bool heatmap = args?['heatmap'] == true;

    if (heatmap && heatmapCircles.isEmpty) {
      _loadHeatmap();
    }
  }

  // ================= LOCATION =================

  Future<void> _loadLocation() async {
    LocationPermission permission = await Geolocator.requestPermission();

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      setState(() {
        currentLocation = fallbackLocation;
      });
      return;
    }

    Position position = await Geolocator.getCurrentPosition();

    setState(() {
      currentLocation = LatLng(position.latitude, position.longitude);
    });
  }

  // ================= HEATMAP =================

  Future<void> _loadHeatmap() async {
    try {
      final data = await ApiService.fetchComplaints();

      final List<CircleMarker> circles = [];
      final List<Map<String, dynamic>> issues = [];

      for (var item in data) {
        final double? lat = item['lat']?.toDouble();
        final double? lng = item['lng']?.toDouble();
        final latFromComplaint = (item['latitude'] as num?)?.toDouble();
        final lngFromComplaint = (item['longitude'] as num?)?.toDouble();
        final double? finalLat = lat ?? latFromComplaint;
        final double? finalLng = lng ?? lngFromComplaint;
        final String category = item['category']?.toString() ?? "Other";

        if (finalLat == null || finalLng == null) continue;

        Color color;

        switch (category) {
          case 'Pothole':
            color = Colors.red.withOpacity(0.5);
            break;
          case 'Garbage Dump':
            color = Colors.orange.withOpacity(0.5);
            break;
          case 'Broken Streetlight':
            color = Colors.yellow.withOpacity(0.5);
            break;
          case 'Accident':
            color = Colors.purple.withOpacity(0.5);
            break;
          default:
            color = Colors.blue.withOpacity(0.5);
        }

        circles.add(
          CircleMarker(
            point: LatLng(finalLat, finalLng),
            radius: 35,
            color: color,
            borderColor: Colors.black.withOpacity(0.3),
            borderStrokeWidth: 1,
          ),
        );

        issues.add({
          'complaint_id': item['complaint_id']?.toString() ?? 'N/A',
          'category': category,
          'status': item['status']?.toString() ?? 'Submitted',
          'city': item['city']?.toString() ?? 'Unknown',
          'location_name': item['location_name']?.toString() ?? '',
          'confidence': item['confidence']?.toString() ?? 'N/A',
          'created_at': item['created_at']?.toString(),
          'lat': finalLat,
          'lng': finalLng,
        });
      }

      setState(() {
        heatmapCircles = circles;
        mapIssues = issues;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load heatmap: $e')));
      }
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

  void _showIssueDetails(Map<String, dynamic> issue) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        final rawId = issue['complaint_id']?.toString() ?? 'N/A';
        final lat = issue['lat']?.toString() ?? 'N/A';
        final lng = issue['lng']?.toString() ?? 'N/A';
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Complaint Details',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 14),
              Text(
                'ID: ${_toReadableId(rawId)}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text('Category: ${issue['category'] ?? 'N/A'}'),
              const SizedBox(height: 8),
              Text('Status: ${issue['status'] ?? 'N/A'}'),
              const SizedBox(height: 8),
              Text('City: ${issue['city'] ?? 'Unknown'}'),
              if ((issue['location_name']?.toString() ?? '').isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('Location: ${issue['location_name']}'),
              ],
              const SizedBox(height: 8),
              Text('Coordinates: $lat, $lng'),
              const SizedBox(height: 8),
              Text('Confidence: ${issue['confidence'] ?? 'N/A'}'),
              const SizedBox(height: 8),
              Text(
                'Reported: ${_formatTimeAgo(issue['created_at']?.toString())}',
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: rawId == 'N/A'
                      ? null
                      : () {
                          Navigator.pop(context);
                          Navigator.pushNamed(
                            this.context,
                            '/complaint_detail',
                            arguments: {'complaintId': rawId},
                          );
                        },
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('View Full Complaint'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ================= BUILD =================

  @override
  Widget build(BuildContext context) {
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

    final double? lat = args?['latitude'];
    final double? lng = args?['longitude'];
    final bool isHeatmap = args?['heatmap'] == true;

    final bool hasPassedLocation = lat != null && lng != null;
    final LatLng centerLocation = isHeatmap && heatmapCircles.isNotEmpty
        ? heatmapCircles.first.point
        : hasPassedLocation
        ? LatLng(lat, lng)
        : (currentLocation ?? fallbackLocation);

    return Scaffold(
      appBar: AppBar(
        title: Text(isHeatmap ? "City Heatmap" : "Issue Location"),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: centerLocation,
              initialZoom: hasPassedLocation ? 15.0 : 12.0,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all,
              ),
              onPositionChanged: (position, _) {
                final zoom = position.zoom;
                _currentZoom = zoom;
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.civicvision.app',
              ),

              if (isHeatmap && heatmapCircles.isNotEmpty)
                CircleLayer(circles: heatmapCircles),

              if (isHeatmap && mapIssues.isNotEmpty)
                MarkerLayer(
                  markers: mapIssues.map((issue) {
                    return Marker(
                      point: LatLng(
                        issue['lat'] as double,
                        issue['lng'] as double,
                      ),
                      width: 40,
                      height: 40,
                      child: GestureDetector(
                        onTap: () => _showIssueDetails(issue),
                        child: const Icon(
                          Icons.location_on,
                          color: Colors.red,
                          size: 26,
                        ),
                      ),
                    );
                  }).toList(),
                )
              else if (!isHeatmap)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: centerLocation,
                      width: 80,
                      height: 80,
                      child: const Icon(
                        Icons.location_on,
                        color: Colors.red,
                        size: 40,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          Positioned(
            right: 12,
            bottom: 24,
            child: Column(
              children: [
                FloatingActionButton.small(
                  heroTag: 'zoom_in_btn',
                  onPressed: () {
                    _currentZoom += 1;
                    _mapController.move(
                      _mapController.camera.center,
                      _currentZoom,
                    );
                  },
                  child: const Icon(Icons.add),
                ),
                const SizedBox(height: 8),
                FloatingActionButton.small(
                  heroTag: 'zoom_out_btn',
                  onPressed: () {
                    _currentZoom -= 1;
                    _mapController.move(
                      _mapController.camera.center,
                      _currentZoom,
                    );
                  },
                  child: const Icon(Icons.remove),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
