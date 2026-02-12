import 'package:flutter/material.dart';
// import 'package:google_maps_flutter/google_maps_flutter.dart'; // Disabled for demo stability
import 'package:provider/provider.dart';
import '../../providers/sos_provider.dart';
import '../../core/theme/app_theme.dart';

class SosActiveScreen extends StatefulWidget {
  const SosActiveScreen({super.key});

  @override
  State<SosActiveScreen> createState() => _SosActiveScreenState();
}

class _SosActiveScreenState extends State<SosActiveScreen> {

  void _stopSos(BuildContext context) {
    Provider.of<SosProvider>(context, listen: false).deactivateSos();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.errorRed, // Alerting background
      body: SafeArea(
        child: Column(
          children: [
             Padding(
               padding: const EdgeInsets.all(16.0),
               child: Column(
                 children: [
                    const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 60),
                    const SizedBox(height: 8),
                    Text(
                      "SOS ACIIVATED",
                      style: Theme.of(context).textTheme.displayMedium?.copyWith(color: Colors.white),
                    ),
                    const Text(
                      "Sharing Live Location...",
                      style: TextStyle(color: Colors.white70, fontSize: 18),
                    ),
                 ],
               ),
             ),
             Expanded(
               child: Container(
                 margin: const EdgeInsets.symmetric(horizontal: 16),
                 decoration: BoxDecoration(
                   borderRadius: BorderRadius.circular(16),
                   color: Colors.white,
                 ),
                 child: Container(
                   color: Colors.grey[200],
                   alignment: Alignment.center,
                   child: Column(
                     mainAxisAlignment: MainAxisAlignment.center,
                     children: [
                       Icon(Icons.map, size: 64, color: Colors.grey[400]),
                       const SizedBox(height: 16),
                       const Text(
                         "Live Map Placeholder",
                         style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black54),
                       ),
                       const SizedBox(height: 8),
                       const Text(
                         "(API Key required for live maps)",
                         style: TextStyle(color: Colors.black45),
                       ),
                     ],
                   ),
                 ),
               ),
             ),
             Padding(
               padding: const EdgeInsets.all(24.0),
               child: ElevatedButton(
                 style: ElevatedButton.styleFrom(
                   backgroundColor: Colors.white,
                   foregroundColor: AppTheme.errorRed,
                   minimumSize: const Size(double.infinity, 56),
                 ),
                 onPressed: () => _stopSos(context),
                 child: const Text("I AM SAFE - STOP SOS"),
               ),
             ),
          ],
        ),
      ),
    );
  }
}
