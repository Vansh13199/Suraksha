import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/auth_provider.dart';
import '../core/theme/app_theme.dart';
import '../widgets/modern_card.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text("My Profile"),
        elevation: 0,
      ),
      body: user == null 
        ? const Center(child: Text("No Profile Data"))
        : SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: AppTheme.primaryBlue, width: 3),
                      ),
                      child: const CircleAvatar(
                        radius: 60,
                        backgroundColor: AppTheme.backgroundLight,
                        child: Icon(Icons.person, size: 70, color: AppTheme.primaryBlue),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryBlue,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(Icons.edit, color: Colors.white, size: 20),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  user.fullName,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textDark,
                  ),
                ),
                Text(
                  user.phoneNumber,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppTheme.textGrey,
                  ),
                ),
                const SizedBox(height: 32),

                _buildProfileItem(context, Icons.person_outline_rounded, "Full Name", user.fullName),
                _buildProfileItem(context, Icons.phone_android_rounded, "Phone Number", user.phoneNumber),
                _buildProfileItem(context, Icons.cake_outlined, "Date of Birth", 
                  user.dateOfBirth != null 
                    ? DateFormat('dd MMM yyyy').format(user.dateOfBirth!) 
                    : "Not set"),
                _buildProfileItem(context, Icons.wc_outlined, "Gender", user.gender ?? "Not set"),
                _buildProfileItem(context, Icons.favorite_border_rounded, "Blood Group", user.bloodGroup ?? "Not set"),
              ],
            ),
          ),
    );
  }

  Widget _buildProfileItem(BuildContext context, IconData icon, String label, String value) {
    return ModernCard(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.primaryBlue.withOpacity(0.05),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppTheme.primaryBlue, size: 24),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textGrey,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
