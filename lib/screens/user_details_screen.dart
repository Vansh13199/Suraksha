import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../models/user_model.dart';
import '../../widgets/primary_button.dart';
import '../../core/theme/app_theme.dart';
import 'home_dashboard_screen.dart';

class UserDetailsScreen extends StatefulWidget {
  const UserDetailsScreen({super.key});

  @override
  State<UserDetailsScreen> createState() => _UserDetailsScreenState();
}

class _UserDetailsScreenState extends State<UserDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  
  DateTime? _selectedDate;
  String _selectedGender = 'Male';
  String _selectedBloodGroup = 'O+';

  final List<String> _genders = ['Male', 'Female', 'Other'];
  final List<String> _bloodGroups = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }

  void _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 18),
      firstDate: DateTime(1900),
      lastDate: now,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppTheme.primaryBlue,
              onPrimary: Colors.white,
              onSurface: AppTheme.textDark,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select your date of birth")),
      );
      return;
    }

    final auth = context.read<AuthProvider>();
    
    // Create updated user model
    // Note: phoneNumber and id should already be in auth.currentUser or auth.tempPhoneNumber logic
    // But typically we are creating a NEW profile record here.
    
    // We need the phone number from the current auth state if available
    // final phone = auth.currentUser?.phoneNumber ?? auth.tempPhoneNumber ?? ""; // This line is removed

    final newUser = UserModel(
      uid: auth.currentUser?.uid ?? "", 
      phoneNumber: auth.currentUser?.phoneNumber ?? auth.tempPhoneNumber ?? "",
      firstName: _firstNameController.text.trim(),
      lastName: _lastNameController.text.trim(),
      dateOfBirth: _selectedDate!,
      gender: _selectedGender,
      bloodGroup: _selectedBloodGroup,
    );

    try {
      await auth.updateUserDetails(newUser);
      
      if (auth.errorMessage == null && mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomeDashboardScreen()),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(auth.errorMessage ?? "Failed to save profile."),
            backgroundColor: AppTheme.alertRed,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final loading = context.watch<AuthProvider>().isLoading;

    return Scaffold(
      appBar: AppBar(title: const Text("Complete Profile")),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 16),
                Text(
                  "Tell us about yourself",
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "This information helps in emergency situations",
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textGrey,
                  ),
                ),
                const SizedBox(height: 32),

                // Name Fields
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _firstNameController,
                        textCapitalization: TextCapitalization.words,
                        validator: (val) => val == null || val.isEmpty ? "Required" : null,
                        decoration: const InputDecoration(
                          labelText: "First Name",
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _lastNameController,
                        textCapitalization: TextCapitalization.words,
                        validator: (val) => val == null || val.isEmpty ? "Required" : null,
                        decoration: const InputDecoration(
                          labelText: "Last Name",
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Date of Birth
                InkWell(
                  onTap: _pickDate,
                  borderRadius: BorderRadius.circular(12),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: "Date of Birth",
                      prefixIcon: Icon(Icons.calendar_today_outlined),
                    ),
                    child: Text(
                      _selectedDate == null
                          ? "Select Date"
                          : DateFormat('dd MMM yyyy').format(_selectedDate!),
                      style: TextStyle(
                        color: _selectedDate == null ? AppTheme.textGrey : AppTheme.textDark,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Gender & Blood Group
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedGender,
                        items: _genders.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                        onChanged: (val) => setState(() => _selectedGender = val!),
                        decoration: const InputDecoration(
                          labelText: "Gender",
                          prefixIcon: Icon(Icons.wc_outlined),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedBloodGroup,
                        items: _bloodGroups.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                        onChanged: (val) => setState(() => _selectedBloodGroup = val!),
                        decoration: const InputDecoration(
                          labelText: "Blood Group",
                          prefixIcon: Icon(Icons.bloodtype_outlined),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 48),

                PrimaryButton(
                  text: "Save & Continue",
                  isLoading: loading,
                  onPressed: _saveProfile,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
