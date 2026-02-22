import 'package:flutter/material.dart';
import '../services/api_service.dart';

class ComplaintsScreen extends StatelessWidget {
  const ComplaintsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Complaints"),
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
            final complaints = snapshot.data!;
            return ListView.builder(
              itemCount: complaints.length,
              itemBuilder: (context, index) {
                final complaint = complaints[index] as Map<String, dynamic>;
                final id = complaint['complaint_id']?.toString() ?? 'N/A';
                final category = complaint['category']?.toString() ?? 'N/A';
                final status = complaint['status']?.toString() ?? 'N/A';
                return Card(
                  margin: const EdgeInsets.all(8),
                  child: ListTile(
                    title: Text('Complaint $id'),
                    subtitle: Text('Category: $category, Status: $status'),
                    onTap: () {
                      Navigator.pushNamed(
                        context,
                        '/complaint_detail',
                        arguments: {'complaintId': id},
                      );
                    },
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
