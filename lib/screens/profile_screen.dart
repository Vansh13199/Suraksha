import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import '../providers/auth_provider.dart';
import '../core/theme/app_theme.dart';
import '../widgets/modern_card.dart';
import '../services/auth_service.dart';
import 'ekyc_verification_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ImagePicker _picker = ImagePicker();
  final AuthService _authService = AuthService();
  
  bool _isUploading = false;
  String? _signedImageUrl;

  @override
  void initState() {
    super.initState();
    _loadProfilePicture();
  }

  void _loadProfilePicture() async {
    final user = context.read<AuthProvider>().currentUser;
    if (user?.profilePicUrl != null && user!.profilePicUrl!.isNotEmpty) {
      final url = await _authService.getProfilePictureUrl(user.profilePicUrl!);
      if (mounted) {
        setState(() {
          _signedImageUrl = url;
        });
      }
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(source: source);
      if (image != null) {
        setState(() {
          _isUploading = true;
        });
        
        final success = await _authService.uploadProfilePicture(image.path);
        
        if (success) {
          if (mounted) {
            await context.read<AuthProvider>().refreshUser();
            _loadProfilePicture();
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Failed to upload image'), backgroundColor: AppTheme.alertRed),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.alertRed),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }



  void _showProfilePictureOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Choose from Gallery'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Take a Photo'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    if (user != null && user.profilePicUrl != null && _signedImageUrl == null && !_isUploading) {
      _loadProfilePicture();
    }

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
                GestureDetector(
                  onTap: _isUploading ? null : _showProfilePictureOptions,
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: AppTheme.primaryBlue, width: 3),
                        ),
                        child: CircleAvatar(
                          radius: 60,
                          backgroundColor: AppTheme.backgroundLight,
                          backgroundImage: _signedImageUrl != null ? NetworkImage(_signedImageUrl!) : null,
                          child: _isUploading 
                            ? const CircularProgressIndicator()
                            : (_signedImageUrl == null) 
                                ? const Icon(Icons.person, size: 70, color: AppTheme.primaryBlue) 
                                : null,
                        ),
                      ),
                      if (!_isUploading)
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
                const SizedBox(height: 12),

                // eKYC Verification Badge
                _buildEkycBadge(context, user.isEkycVerified),

                const SizedBox(height: 32),

                _buildProfileItem(context, Icons.person_outline_rounded, "Full Name", user.fullName),
                _buildProfileItem(context, Icons.email_outlined, "Email", user.email),
                _buildProfileItem(context, Icons.phone_android_rounded, "Phone Number", user.phoneNumber),
                _buildProfileItem(context, Icons.cake_outlined, "Date of Birth", 
                  user.dateOfBirth != null 
                    ? DateFormat('dd MMM yyyy').format(user.dateOfBirth!) 
                    : "Not set"),
                if (user.age != null)
                  _buildProfileItem(context, Icons.hourglass_bottom_rounded, "Age", "${user.age} years"),
                _buildProfileItem(context, Icons.wc_outlined, "Gender", user.gender ?? "Not set"),
                _buildProfileItem(context, Icons.favorite_border_rounded, "Blood Group", user.bloodGroup ?? "Not set"),
                
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.primaryBlue.withOpacity(0.1)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded, color: AppTheme.primaryBlue),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          "To change any profile details, please message our support team at support@dev-vansh.in",
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppTheme.textDark,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
    );
  }

  Widget _buildEkycBadge(BuildContext context, bool isVerified) {
    if (isVerified) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.successGreen.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.successGreen.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.verified_rounded, color: AppTheme.successGreen, size: 18),
            const SizedBox(width: 6),
            Text(
              "eKYC Verified",
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.successGreen,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF3E0),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFFFB74D)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.warning_amber_rounded, color: Color(0xFFE65100), size: 18),
              const SizedBox(width: 6),
              Text(
                "eKYC Not Verified",
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(0xFFE65100),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const EkycVerificationScreen()),
            );
          },
          child: const Text(
            "Verify Now →",
            style: TextStyle(
              color: AppTheme.primaryBlue,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
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
