import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/primary_button.dart';
import 'user_details_screen.dart';
import 'home_dashboard_screen.dart';
import '../../core/utils/validators.dart';

class OtpVerificationScreen extends StatefulWidget {
  const OtpVerificationScreen({super.key});

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final TextEditingController _otpController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  
  Timer? _timer;
  int _start = 20;
  bool _isResendEnabled = false;

  @override
  void initState() {
    super.initState();
    _otpController.clear();
    startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _otpController.dispose();
    super.dispose();
  }

  void startTimer() {
    setState(() {
      _start = 20;
      _isResendEnabled = false;
    });
    const oneSec = Duration(seconds: 1);
    _timer = Timer.periodic(
      oneSec,
      (Timer timer) {
        if (_start == 0) {
          setState(() {
            timer.cancel();
            _isResendEnabled = true;
          });
        } else {
          setState(() {
            _start--;
          });
        }
      },
    );
  }

  Future<void> _resendOtp() async {
    final auth = context.read<AuthProvider>();
    if (auth.tempPhoneNumber == null) return;

    // Reset timer immediately to prevent double clicks
    startTimer();

    try {
      final success = await auth.sendOtp(auth.tempPhoneNumber!);
      
      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("OTP Resent Successfully!"),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(auth.errorMessage ?? "Failed to resend OTP."),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
        );
      }
    }
  }

  Future<void> _verifyOtp() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthProvider>();
    final otp = _otpController.text.trim();

    try {
      final success = await auth.verifyOtp(otp);

      if (!mounted) return;

      if (success) {
        _timer?.cancel(); // Stop timer on success
        
        // Check if user profile already exists in database
        if (auth.currentUser != null) {
          // Profile exists → skip details, go to Home
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const HomeDashboardScreen()),
          );
        } else {
          // No profile → go to Enter Details
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const UserDetailsScreen()),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(auth.errorMessage ?? "Invalid OTP. Please try again."),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final loading = context.watch<AuthProvider>().isLoading;

    return Scaffold(
      appBar: AppBar(title: const Text("Verify OTP")),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              const Text(
                "Enter OTP",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 32),

              TextFormField(
                controller: _otpController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                textAlign: TextAlign.center,
                validator: Validators.validateOtp,
                decoration: const InputDecoration(
                  hintText: "Enter 6 digit OTP",
                  counterText: "",
                ),
              ),

              const SizedBox(height: 20),

              // Resend Button with Timer
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Didn't receive code? "),
                  TextButton(
                    onPressed: _isResendEnabled && !loading ? _resendOtp : null,
                    child: Text(
                      _isResendEnabled ? "Resend OTP" : "Resend in ${_start}s",
                      style: TextStyle(
                        color: _isResendEnabled ? Theme.of(context).primaryColor : Colors.grey,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),

              const Spacer(),

              PrimaryButton(
                text: "Verify",
                isLoading: loading,
                onPressed: _verifyOtp,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
