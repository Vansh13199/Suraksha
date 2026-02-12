import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/auth_provider.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text("Profile")),
      body: user == null 
        ? const Center(child: Text("No Profile Data"))
        : SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.blueAccent,
                  child: Icon(Icons.person, size: 60, color: Colors.white),
                ),
                const SizedBox(height: 24),

                _buildProfileItem(Icons.person, "Name", user.fullName),
                _buildProfileItem(Icons.phone, "Phone", user.phoneNumber),
                _buildProfileItem(Icons.cake, "Date of Birth", 
                  user.dateOfBirth != null 
                    ? DateFormat('yyyy-MM-dd').format(user.dateOfBirth!) 
                    : "Not set"),
                _buildProfileItem(Icons.wc, "Gender", user.gender ?? "Not set"),
                _buildProfileItem(Icons.favorite, "Blood Group", user.bloodGroup ?? "Not set"),
              ],
            ),
          ),
    );
  }

  Widget _buildProfileItem(IconData icon, String label, String value) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: ListTile(
        leading: Icon(icon, color: Colors.blue),
        title: Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        subtitle: Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
