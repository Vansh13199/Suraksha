import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:suraksha_plus/providers/auth_provider.dart';
import 'package:suraksha_plus/features/auth/screens/login_screen.dart';

class HomeScreen extends StatelessWidget {
  final bool isDemoMode;
  const HomeScreen({super.key, this.isDemoMode = false});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Suraksha+ Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              if (isDemoMode) {
                Navigator.pushReplacement(
                  context, 
                  MaterialPageRoute(builder: (_) => const LoginScreen(isDemoMode: true))
                );
              } else {
                await context.read<AuthProvider>().signOut();
                if (context.mounted) {
                  Navigator.pushReplacement(
                    context, 
                    MaterialPageRoute(builder: (_) => const LoginScreen())
                  );
                }
              }
            },
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GestureDetector(
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('SOS Alert Sent! (Simulation)'),
                    backgroundColor: Colors.red,
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withValues(alpha: 0.5),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: const Center(
                  child: Text(
                    'SOS',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 40),
            const Text(
              'Press to send emergency alert',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
