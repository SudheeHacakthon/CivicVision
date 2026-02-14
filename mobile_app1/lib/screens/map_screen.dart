import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  LatLng? currentLocation;
  final LatLng fallbackLocation = LatLng(17.3850, 78.4867); // Hyderabad

  @override
  void initState() {
    super.initState();
    _loadLocation();
  }

  Future<void> _loadLocation() async {
    // Check permission
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

  @override
  Widget build(BuildContext context) {
    // Check if location was passed through Navigator
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

    final double? lat = args?['latitude'];
    final double? lng = args?['longitude'];

    final bool hasPassedLocation = lat != null && lng != null;

    final LatLng centerLocation = hasPassedLocation
        ? LatLng(lat, lng)
        : (currentLocation ?? fallbackLocation);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Issue Location"),
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
