import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/primary_button.dart';
import 'otp_verification_screen.dart';

class RegisterPhoneScreen extends StatefulWidget {
  const RegisterPhoneScreen({super.key});

  @override
  State<RegisterPhoneScreen> createState() => _RegisterPhoneScreenState();
}

class _RegisterPhoneScreenState extends State<RegisterPhoneScreen> {
  final _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  void _sendOtp() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthProvider>();
    final rawPhone = _phoneController.text.trim();
    final phone = rawPhone.startsWith('+')
        ? rawPhone
        : '+91$rawPhone';


    try {
      final success = await auth.sendOtp(phone);

      if (mounted) {
        if (success) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const OtpVerificationScreen(),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(auth.errorMessage ?? "Failed to send OTP. Please try again."),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final loading = context.watch<AuthProvider>().isLoading;

    return Scaffold(
      appBar: AppBar(title: const Text("Registration")),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                validator: (val) {
                  if (val == null || val.isEmpty) {
                    return "Phone number is required";
                  }
                  if (val.length < 10) {
                    return "Please enter a valid phone number";
                  }
                  return null;
                },
                decoration: const InputDecoration(
                  hintText: "+91XXXXXXXXXX",
                  labelText: "Phone Number",
                  prefixIcon: Icon(Icons.phone),
                ),
              ),
              const Spacer(),
              PrimaryButton(
                text: "Send OTP",
                isLoading: loading,
                onPressed: _sendOtp,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
