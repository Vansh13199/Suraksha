import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../core/theme/app_theme.dart';
import 'register_phone_screen.dart';
import 'home_dashboard_screen.dart';
import 'user_details_screen.dart'; // Add this import

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  void _checkAuth() async {
    // Wait for AuthProvider to finish checking session + fetching profile
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    await authProvider.waitForInit();

    // Small splash delay for visual effect
    await Future.delayed(const Duration(seconds: 1));
    
    if (!mounted) return;

    debugPrint('[SPLASH] isSignedIn=${authProvider.isSignedIn}, currentUser=${authProvider.currentUser?.firstName ?? "NULL"}');

    if (authProvider.isSignedIn) {
      if (authProvider.currentUser != null) {
        // Profile exists → Home
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (_) => const HomeDashboardScreen()));
      } else {
        // Signed in but no profile → Enter Details
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (_) => const UserDetailsScreen()));
      }
    } else {
      // Not signed in → Login
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => const RegisterPhoneScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryBlue,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.shield_moon_outlined, size: 80, color: Colors.white),
            const SizedBox(height: 16),
            Text(
              "Suraksha+",
              style: Theme.of(context).textTheme.displayLarge?.copyWith(
                    color: Colors.white,
                    fontSize: 32,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              "Connecting Safety",
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white70,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
