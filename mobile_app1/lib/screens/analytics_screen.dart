import 'package:flutter/material.dart';
import '../services/api_service.dart';

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Analytics"),
        backgroundColor: const Color(0xFF4A148C),
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: ApiService.fetchAnalytics(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData) {
            return const Center(child: Text('No data available'));
          } else {
            final data = snapshot.data!;
            return ListView(
              padding: const EdgeInsets.all(16),
              children: data.entries.map((entry) {
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  child: ListTile(
                    title: Text(entry.key.replaceAll('_', ' ').toUpperCase()),
                    subtitle: Text(entry.value?.toString() ?? 'N/A'),
                  ),
                );
              }).toList(),
            );
          }
        },
      ),
    );
  }
}
