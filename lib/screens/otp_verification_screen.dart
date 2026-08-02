import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/primary_button.dart';
import 'user_details_screen.dart';
import 'home_dashboard_screen.dart';
import 'ekyc_verification_screen.dart';
import '../../core/theme/app_theme.dart';
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
    if (auth.tempEmail == null) return;

    // Reset timer immediately to prevent double clicks
    startTimer();

    try {
      final success = await auth.sendOtp(auth.tempEmail!);
      
      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("OTP Resent Successfully!"),
              backgroundColor: AppTheme.successGreen,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(auth.errorMessage ?? "Failed to resend OTP."),
              backgroundColor: AppTheme.alertRed,
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
        
        // Check eKYC + profile status
        if (auth.currentUser != null && auth.currentUser!.isEkycVerified) {
          if (auth.currentUser!.firstName != null &&
              auth.currentUser!.firstName!.isNotEmpty) {
            // eKYC verified + profile exists → Home
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const HomeDashboardScreen()),
            );
          } else {
            // eKYC verified but no profile details → User Details
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const UserDetailsScreen()),
            );
          }
        } else {
          // Not eKYC verified → eKYC Verification
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const EkycVerificationScreen()),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(auth.errorMessage ?? "Invalid OTP. Please try again."),
            backgroundColor: AppTheme.alertRed,
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
      appBar: AppBar(title: const Text("Verification")),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                       const SizedBox(height: 32),
                       Container(
                        height: 100,
                        width: 100,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryBlue.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.mark_email_unread_outlined, size: 50, color: AppTheme.primaryBlue),
                      ),
                      const SizedBox(height: 32),
                      Text(
                        "Enter Verification Code",
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "We have sent a 6-digit code to your email",
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.textGrey,
                        ),
                      ),
                      
                      const SizedBox(height: 48),

                      TextFormField(
                        controller: _otpController,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        textAlign: TextAlign.center,
                        validator: Validators.validateOtp,
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 8),
                        decoration: InputDecoration(
                          hintText: "000000",
                          counterText: "",
                          contentPadding: const EdgeInsets.symmetric(vertical: 16),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      ),

                      const SizedBox(height: 32),

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
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
