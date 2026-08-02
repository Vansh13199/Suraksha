import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/primary_button.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/validators.dart';
import '../../services/ekyc_service.dart';
import 'user_details_screen.dart';
import 'home_dashboard_screen.dart';

/// eKYC Verification Screen
/// Combined screen: Email OTP + Security Question dropdown + Answer.
/// Appears right after login OTP, before User Details.
class EkycVerificationScreen extends StatefulWidget {
  const EkycVerificationScreen({super.key});

  @override
  State<EkycVerificationScreen> createState() => _EkycVerificationScreenState();
}

class _EkycVerificationScreenState extends State<EkycVerificationScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _otpController = TextEditingController();
  final TextEditingController _answerController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final EkycService _ekycService = EkycService();

  Timer? _timer;
  int _start = 20;
  bool _isResendEnabled = false;
  bool _isLoading = false;
  bool _isSendingOtp = false;
  bool _isVerified = false;
  String? _errorMessage;
  String? _selectedQuestion;

  late AnimationController _animController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );
    _animController.forward();

    // Auto-send eKYC OTP on screen load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _sendEkycOtp();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _otpController.dispose();
    _answerController.dispose();
    _animController.dispose();
    super.dispose();
  }

  void _startTimer() {
    setState(() {
      _start = 20;
      _isResendEnabled = false;
    });
    _timer = Timer.periodic(
      const Duration(seconds: 1),
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

  Future<void> _sendEkycOtp() async {
    final auth = context.read<AuthProvider>();
    final email = auth.currentUser?.email ?? auth.tempEmail;

    if (email == null || email.isEmpty) {
      setState(() {
        _errorMessage = "No email found. Please log in again.";
      });
      return;
    }

    setState(() {
      _isSendingOtp = true;
      _errorMessage = null;
    });

    final success = await _ekycService.sendEkycOtp(email);

    if (mounted) {
      setState(() {
        _isSendingOtp = false;
      });

      if (success) {
        _startTimer();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("eKYC OTP sent to your email!"),
            backgroundColor: AppTheme.successGreen,
          ),
        );
      } else {
        setState(() {
          _errorMessage = "Failed to send OTP. Please try 'Resend'.";
        });
        _startTimer();
      }
    }
  }

  Future<void> _verifyAndComplete() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthProvider>();
    final email = auth.currentUser?.email ?? auth.tempEmail;
    final otp = _otpController.text.trim();
    final question = _selectedQuestion!;
    final answer = _answerController.text.trim();

    if (email == null || email.isEmpty) {
      setState(() {
        _errorMessage = "No email found. Please log in again.";
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // Step 1: Verify OTP
    final otpValid = await _ekycService.verifyEkycOtp(email, otp);

    if (!mounted) return;

    if (!otpValid) {
      setState(() {
        _isLoading = false;
        _errorMessage = "Invalid OTP. Please check and try again.";
      });
      return;
    }

    // Step 2: Save security question + answer
    final savedAnswer = await auth.saveSecurityAnswer(question, answer);

    if (!mounted) return;

    if (!savedAnswer) {
      setState(() {
        _isLoading = false;
        _errorMessage = auth.errorMessage ?? "Failed to save security answer.";
      });
      return;
    }

    // Step 3: Mark eKYC verified
    final ekycSuccess = await auth.completeEkyc();

    if (!mounted) return;

    if (ekycSuccess) {
      setState(() {
        _isVerified = true;
        _isLoading = false;
      });
      _timer?.cancel();

      // Short delay for success animation, then navigate
      await Future.delayed(const Duration(milliseconds: 1500));

      if (mounted) {
        // After eKYC → go to User Details if no profile, or Home if profile exists
        if (auth.currentUser?.firstName != null &&
            auth.currentUser!.firstName!.isNotEmpty) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const HomeDashboardScreen()),
            (route) => false,
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const UserDetailsScreen()),
          );
        }
      }
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage = auth.errorMessage ?? "Failed to complete eKYC.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 24),

                  // Header Icon
                  Center(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 500),
                      child: _isVerified
                          ? Container(
                              key: const ValueKey('verified'),
                              height: 90,
                              width: 90,
                              decoration: BoxDecoration(
                                color: AppTheme.successGreen.withOpacity(0.15),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.verified_rounded,
                                size: 55,
                                color: AppTheme.successGreen,
                              ),
                            )
                          : Container(
                              key: const ValueKey('unverified'),
                              height: 90,
                              width: 90,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    AppTheme.primaryBlue.withOpacity(0.15),
                                    AppTheme.secondaryBlue.withOpacity(0.1),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.verified_user_outlined,
                                size: 45,
                                color: AppTheme.primaryBlue,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Title
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: _isVerified
                        ? Text(
                            "eKYC Verified! ✅",
                            key: const ValueKey('title_verified'),
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.successGreen,
                                ),
                          )
                        : Text(
                            "eKYC Verification",
                            key: const ValueKey('title_unverified'),
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                  ),
                  const SizedBox(height: 8),

                  if (_isVerified) ...[
                    Text(
                      "Your identity has been verified successfully.\nRedirecting...",
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textGrey,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Center(
                      child: CircularProgressIndicator(
                        color: AppTheme.successGreen,
                      ),
                    ),
                  ],

                  if (!_isVerified) ...[
                    Text(
                      "Verify your identity to continue using Suraksha+",
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textGrey,
                      ),
                    ),

                    const SizedBox(height: 28),

                    // ── Section 1: Email OTP ──────────────────────────
                    _buildSectionHeader(
                      context,
                      icon: Icons.email_outlined,
                      title: "Email OTP Verification",
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "A 6-digit code has been sent to your registered email",
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textGrey,
                      ),
                    ),
                    // Show email
                    Builder(builder: (context) {
                      final email =
                          context.read<AuthProvider>().currentUser?.email ??
                              context.read<AuthProvider>().tempEmail ??
                              '';
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          email,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.primaryBlue,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 12),

                    if (_isSendingOtp)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                              SizedBox(width: 12),
                              Text("Sending OTP..."),
                            ],
                          ),
                        ),
                      ),

                    if (!_isSendingOtp) ...[
                      TextFormField(
                        controller: _otpController,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        textAlign: TextAlign.center,
                        validator: Validators.validateOtp,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 8,
                        ),
                        decoration: InputDecoration(
                          hintText: "000000",
                          counterText: "",
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 16),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Didn't receive code? ",
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          TextButton(
                            onPressed: _isResendEnabled && !_isLoading
                                ? _sendEkycOtp
                                : null,
                            child: Text(
                              _isResendEnabled
                                  ? "Resend OTP"
                                  : "Resend in ${_start}s",
                              style: TextStyle(
                                color: _isResendEnabled
                                    ? AppTheme.primaryBlue
                                    : Colors.grey,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],

                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 20),

                    // ── Section 2: Security Question ──────────────────
                    _buildSectionHeader(
                      context,
                      icon: Icons.security_rounded,
                      title: "Security Question",
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Select a question and provide your answer",
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textGrey,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Dropdown for security question
                    DropdownButtonFormField<String>(
                      value: _selectedQuestion,
                      isExpanded: true,
                      validator: (val) {
                        if (val == null || val.isEmpty) {
                          return "Please select a security question";
                        }
                        return null;
                      },
                      decoration: InputDecoration(
                        labelText: "Select Question",
                        prefixIcon:
                            const Icon(Icons.help_outline_rounded),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      items: EkycService.securityQuestions
                          .map((q) => DropdownMenuItem(
                                value: q,
                                child: Text(
                                  q,
                                  style: const TextStyle(fontSize: 14),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ))
                          .toList(),
                      onChanged: (val) {
                        setState(() {
                          _selectedQuestion = val;
                        });
                      },
                    ),
                    const SizedBox(height: 16),

                    // Answer field
                    TextFormField(
                      controller: _answerController,
                      textCapitalization: TextCapitalization.words,
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return "Please enter your answer";
                        }
                        if (val.trim().length < 2) {
                          return "Answer must be at least 2 characters";
                        }
                        return null;
                      },
                      decoration: InputDecoration(
                        labelText: "Your Answer",
                        hintText: "Enter your answer",
                        prefixIcon: const Icon(Icons.edit_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),

                    // Error message
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.alertRed.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppTheme.alertRed.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline,
                                color: AppTheme.alertRed, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(
                                  color: AppTheme.alertRed,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 32),

                    // Submit button
                    PrimaryButton(
                      text: "Verify & Continue",
                      isLoading: _isLoading,
                      onPressed: _verifyAndComplete,
                    ),
                    const SizedBox(height: 24),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context, {
    required IconData icon,
    required String title,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.primaryBlue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppTheme.primaryBlue, size: 20),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
