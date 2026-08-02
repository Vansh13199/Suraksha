import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../core/theme/app_theme.dart';
import 'register_email_screen.dart';
import 'home_dashboard_screen.dart';
import 'user_details_screen.dart';
import 'ekyc_verification_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );
    
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    _controller.forward();
    _checkAuth();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _checkAuth() async {
    // Wait for AuthProvider to finish checking session + fetching profile
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    await authProvider.waitForInit();

    // Small splash delay for visual effect
    await Future.delayed(const Duration(seconds: 2));
    
    if (!mounted) return;

    debugPrint('[SPLASH] isSignedIn=${authProvider.isSignedIn}, currentUser=${authProvider.currentUser?.firstName ?? "NULL"}');

    if (authProvider.isSignedIn) {
      if (authProvider.currentUser != null) {
        if (authProvider.currentUser!.isEkycVerified) {
          if (authProvider.currentUser!.firstName != null &&
              authProvider.currentUser!.firstName!.isNotEmpty) {
            // Profile exists + eKYC verified → Home
            Navigator.pushReplacement(
                context, MaterialPageRoute(builder: (_) => const HomeDashboardScreen()));
          } else {
            // eKYC verified but no profile details → User Details
            Navigator.pushReplacement(
                context, MaterialPageRoute(builder: (_) => const UserDetailsScreen()));
          }
        } else {
          // NOT eKYC verified → eKYC flow
          Navigator.pushReplacement(
              context, MaterialPageRoute(builder: (_) => const EkycVerificationScreen()));
        }
      } else {
        // Signed in but no user record at all → eKYC first
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (_) => const EkycVerificationScreen()));
      }
    } else {
      // Not signed in → Login
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => const RegisterEmailScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          color: AppTheme.primaryBlue,
        ),
        child: SizedBox.expand(
          child: Stack(
            alignment: Alignment.center,
          children: [
            // 1. The Logo - Exactly in the geometric center
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.shield_moon_outlined,
                size: 100,
                color: Colors.white,
              ),
            ),
            
            // 2. The Text - Positioned below the logo, animated in
            Positioned(
              top: MediaQuery.of(context).size.height / 2 + 80, // Offset below center
              child: SlideTransition(
                position: _slideAnimation,
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Column(
                    children: [
                      Text(
                        "Suraksha+",
                        style: Theme.of(context).textTheme.displayLarge?.copyWith(
                              color: Colors.white,
                              fontSize: 40,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        "Connecting Safety",
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.white70,
                              fontSize: 16,
                              letterSpacing: 4.0,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }
}
