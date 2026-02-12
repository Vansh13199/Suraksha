import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/user_model.dart';
import '../providers/auth_provider.dart';
import '../widgets/primary_button.dart';
import 'permissions_screen.dart';
import 'package:uuid/uuid.dart';

class UserDetailsScreen extends StatefulWidget {
  const UserDetailsScreen({super.key});

  @override
  State<UserDetailsScreen> createState() => _UserDetailsScreenState();
}

class _UserDetailsScreenState extends State<UserDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _dobController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  
  String? _selectedGender;
  String? _selectedBloodGroup;
  DateTime? _selectedDate;

  final List<String> _genders = ["Male", "Female", "Other"];
  final List<String> _bloodGroups = [
    "A+", "A-", "B+", "B-", "O+", "O-", "AB+", "AB-"
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_phoneController.text.isEmpty) {
       final phone = context.read<AuthProvider>().tempPhoneNumber;
       if (phone != null) _phoneController.text = phone;
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _dobController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000), 
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _dobController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  void _onContinue() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select Date of Birth")),
      );
      return;
    }

    final auth = context.read<AuthProvider>();
    
    // Create new user object
    final newUser = UserModel(
      uid: const Uuid().v4(), // Generate random UID for demo
      phoneNumber: _phoneController.text.trim(),
      firstName: _firstNameController.text.trim(),
      lastName: _lastNameController.text.trim(),
      dateOfBirth: _selectedDate,
      gender: _selectedGender,
      bloodGroup: _selectedBloodGroup,
    );

    await auth.updateUserDetails(newUser);

    if (!mounted) return;
    
    // Navigate to Permissions logic (existing flow)
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const PermissionsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loading = context.watch<AuthProvider>().isLoading;
    final phone = context.read<AuthProvider>().tempPhoneNumber ?? "Unknown";

    return Scaffold(
      appBar: AppBar(title: const Text("Enter Details")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Tell us about yourself",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text("This helps during emergencies."),
              const SizedBox(height: 24),
              
              // Phone Number
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: "Phone Number *",
                  prefixIcon: Icon(Icons.phone),
                  hintText: "+91...",
                ),
                keyboardType: TextInputType.phone,
                validator: (val) {
                  if (val == null || val.isEmpty) return "Required";
                  if (val.length < 10) return "Enter valid number";
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // First Name
              TextFormField(
                controller: _firstNameController,
                decoration: const InputDecoration(labelText: "First Name *"),
                validator: (val) => val == null || val.isEmpty ? "Required" : null,
              ),
              const SizedBox(height: 16),

              // Last Name
              TextFormField(
                controller: _lastNameController,
                decoration: const InputDecoration(labelText: "Last Name *"),
                validator: (val) => val == null || val.isEmpty ? "Required" : null,
              ),
              const SizedBox(height: 16),

              // Date of Birth
              TextFormField(
                controller: _dobController,
                readOnly: true,
                onTap: _pickDate,
                decoration: const InputDecoration(
                  labelText: "Date of Birth *",
                  suffixIcon: Icon(Icons.calendar_today),
                ),
                validator: (val) => val == null || val.isEmpty ? "Required" : null,
              ),
              const SizedBox(height: 16),

              // Gender
              DropdownButtonFormField<String>(
                value: _selectedGender,
                items: _genders.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                onChanged: (val) => setState(() => _selectedGender = val),
                 decoration: const InputDecoration(
                  labelText: "Gender (Optional)",
                ),
              ),
              const SizedBox(height: 16),

              // Blood Group
              DropdownButtonFormField<String>(
                value: _selectedBloodGroup,
                items: _bloodGroups.map((b) => DropdownMenuItem(value: b, child: Text(b))).toList(),
                onChanged: (val) => setState(() => _selectedBloodGroup = val),
                 decoration: const InputDecoration(
                  labelText: "Blood Group (Optional)",
                ),
              ),
              
              const SizedBox(height: 40),

              PrimaryButton(
                text: "Continue",
                isLoading: loading,
                onPressed: _onContinue,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
