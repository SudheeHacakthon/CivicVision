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

  List<CircleMarker> heatmapCircles = [];

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
      final data = await ApiService.fetchHeatmap();

      final List<CircleMarker> circles = [];

      for (var item in data) {
        final double? lat = item['lat']?.toDouble();
        final double? lng = item['lng']?.toDouble();
        final String category = item['category']?.toString() ?? "Other";

        if (lat == null || lng == null) continue;

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
            point: LatLng(lat, lng),
            radius: 35,
            color: color,
            borderColor: Colors.black.withOpacity(0.3),
            borderStrokeWidth: 1,
          ),
        );
      }

      setState(() {
        heatmapCircles = circles;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load heatmap: $e')),
        );
      }
    }
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
        ? LatLng(lat!, lng!)
        : (currentLocation ?? fallbackLocation);


    return Scaffold(
      appBar: AppBar(
        title: Text(isHeatmap ? "City Heatmap" : "Issue Location"),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
      ),
      body: FlutterMap(
        options: MapOptions(
          initialCenter: centerLocation,
          initialZoom: hasPassedLocation ? 15.0 : 12.0,
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.civicvision.app',
          ),

          // HEATMAP MODE
          if (isHeatmap && heatmapCircles.isNotEmpty)
            CircleLayer(circles: heatmapCircles)

          // SINGLE LOCATION MODE
          else
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
    );
  }
}
