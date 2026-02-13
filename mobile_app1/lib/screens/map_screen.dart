import 'package:flutter/material.dart';

class MapScreen extends StatelessWidget {
  const MapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("City Map"),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
      ),
      body: const Center(child: Text("Heatmap of issues will appear here.")),
    );
  }
}
