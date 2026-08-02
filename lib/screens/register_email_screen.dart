import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/primary_button.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/validators.dart';
import 'otp_verification_screen.dart';

class RegisterEmailScreen extends StatefulWidget {
  const RegisterEmailScreen({super.key});

  @override
  State<RegisterEmailScreen> createState() => _RegisterEmailScreenState();
}

class _RegisterEmailScreenState extends State<RegisterEmailScreen> {
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  void _sendOtp() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthProvider>();
    final email = _emailController.text.trim().toLowerCase();

    try {
      final success = await auth.sendOtp(email);

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
              backgroundColor: AppTheme.alertRed,
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
                      const SizedBox(height: 48),
                      Center(
                        child: Container(
                          height: 120,
                          width: 120,
                          decoration: BoxDecoration(
                            color: AppTheme.primaryBlue.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.lock_person_outlined, size: 64, color: AppTheme.primaryBlue),
                        ),
                      ),
                      const SizedBox(height: 32),
                      Text(
                        "Welcome Back",
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.displayMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 28,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Enter your email to continue",
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppTheme.textGrey,
                        ),
                      ),
                      const SizedBox(height: 48),
                      
                      Text(
                        "Email Address", 
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        autocorrect: false,
                        textCapitalization: TextCapitalization.none,
                        validator: Validators.validateEmail,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                        decoration: InputDecoration(
                          hintText: "you@example.com",
                          prefixIcon: const Icon(Icons.email_outlined),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                      
                      const Spacer(),
                      const SizedBox(height: 24),
                      const Text(
                        "By continuing, you agree to our Terms of Service and Privacy Policy.",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppTheme.textGrey, fontSize: 12),
                      ),
                      const SizedBox(height: 16),
                      PrimaryButton(
                        text: "Send OTP",
                        isLoading: loading,
                        onPressed: _sendOtp,
                      ),
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
