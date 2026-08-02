import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:local_auth/local_auth.dart';
import 'package:lottie/lottie.dart';

import '../core/theme/app_theme.dart';
import '../providers/auth_provider.dart';
import 'home_dashboard_screen.dart';
import 'splash_screen.dart';

class AccountDeactivatedScreen extends StatefulWidget {
  const AccountDeactivatedScreen({super.key});

  @override
  State<AccountDeactivatedScreen> createState() => _AccountDeactivatedScreenState();
}

class _AccountDeactivatedScreenState extends State<AccountDeactivatedScreen> {
  final LocalAuthentication _localAuth = LocalAuthentication();
  bool _isAuthenticating = false;

  Future<void> _activateAccount() async {
    setState(() {
      _isAuthenticating = true;
    });

    try {
      final bool canAuthenticateWithBiometrics = await _localAuth.canCheckBiometrics;
      final bool canAuthenticate = canAuthenticateWithBiometrics || await _localAuth.isDeviceSupported();

      if (!canAuthenticate) {
        _showError('Biometric authentication is not supported on this device.');
        setState(() {
          _isAuthenticating = false;
        });
        return;
      }

      final bool didAuthenticate = await _localAuth.authenticate(
        localizedReason: 'Please authenticate to reactivate your account',
        biometricOnly: false,
        persistAcrossBackgrounding: true,
      );

      if (didAuthenticate) {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        final user = authProvider.currentUser;
        
        if (user != null) {
          await authProvider.updateUserDetails(user.copyWith(isDeactivated: false));
          
          if (!mounted) return;
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const HomeDashboardScreen()),
            (route) => false,
          );
        } else {
           _showError('Session expired. Please log in again.');
           if (!mounted) return;
           Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const SplashScreen()),
            (route) => false,
          );
        }
      } else {
        _showError('Authentication failed. Please try again.');
      }
    } on PlatformException catch (e) {
      _showError('Error during authentication: ${e.message}');
    } finally {
      if (mounted) {
        setState(() {
          _isAuthenticating = false;
        });
      }
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.alertRed,
      ),
    );
  }

  void _logout() {
    Provider.of<AuthProvider>(context, listen: false).signOut();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const SplashScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Account Deactivated'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'Logout',
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.person_off_rounded,
                size: 100,
                color: AppTheme.alertRed,
              ),
              const SizedBox(height: 32),
              const Text(
                'Your account is currently deactivated.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textDark,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'You will not be able to use Suraksha+ services while your account is deactivated. Click the button below to reactivate your account.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: AppTheme.textGrey,
                ),
              ),
              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isAuthenticating ? null : _activateAccount,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isAuthenticating
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Activate Account',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: _logout,
                child: const Text(
                  'Logout',
                  style: TextStyle(
                    color: AppTheme.textGrey,
                    fontSize: 16,
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
