import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import '../../providers/sos_provider.dart';
import '../../core/theme/app_theme.dart';

class SosActiveScreen extends StatefulWidget {
  const SosActiveScreen({super.key});

  @override
  State<SosActiveScreen> createState() => _SosActiveScreenState();
}

class _SosActiveScreenState extends State<SosActiveScreen> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _stopSos(BuildContext context) {
    Provider.of<SosProvider>(context, listen: false).deactivateSos();
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.alertRed, 
      body: Stack(
        children: [
          // Animated Background
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                return Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.center,
                      radius: 1.5,
                      colors: [
                        AppTheme.alertRed,
                        Color.lerp(AppTheme.alertRed, Colors.black, _pulseController.value * 0.3)!,
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          
          SafeArea(
            child: Column(
              children: [
                 Padding(
                   padding: const EdgeInsets.all(24.0),
                   child: Column(
                     children: [
                        FadeTransition(
                          opacity: _pulseController,
                          child: const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 64),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "SOS ACTIVATED",
                          style: Theme.of(context).textTheme.displayMedium?.copyWith(
                            color: Colors.white,
                            letterSpacing: 2,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 12, 
                                height: 12, 
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                "Sharing Live Location",
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                     ],
                   ),
                 ),
                 
                 Expanded(
                   child: Container(
                     margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                     decoration: BoxDecoration(
                       borderRadius: BorderRadius.circular(24),
                       boxShadow: [
                         BoxShadow(
                           color: Colors.black.withOpacity(0.3),
                           blurRadius: 20,
                           spreadRadius: 5,
                         ),
                       ],
                     ),
                     clipBehavior: Clip.antiAlias,
                     child: Stack(
                       children: [
                         StreamBuilder<Position>(
                           stream: Geolocator.getPositionStream(
                             locationSettings: const LocationSettings(
                               accuracy: LocationAccuracy.high,
                               distanceFilter: 10,
                             ),
                           ),
                           builder: (context, snapshot) {
                             if (!snapshot.hasData) {
                                return const Center(child: CircularProgressIndicator(color: AppTheme.alertRed));
                             }
                             
                             final lat = snapshot.data!.latitude;
                             final lng = snapshot.data!.longitude;
                             final currentPos = LatLng(lat, lng);

                             return FlutterMap(
                               options: MapOptions(
                                 initialCenter: currentPos,
                                 initialZoom: 16.0,
                               ),
                               children: [
                                 TileLayer(
                                   urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                   userAgentPackageName: 'com.example.suraksha_plus',
                                 ),
                                 MarkerLayer(
                                   markers: [
                                     Marker(
                                       point: currentPos,
                                       width: 80,
                                       height: 80,
                                       child: const Icon(
                                         Icons.my_location,
                                         color: AppTheme.primaryBlue,
                                         size: 40,
                                       ),
                                     ),
                                   ],
                                 ),
                               ],
                             );
                           },
                         ),
                         // Map Overlay Gradient
                         Positioned(
                           top: 0, left: 0, right: 0,
                           height: 40,
                           child: Container(
                             decoration: BoxDecoration(
                               gradient: LinearGradient(
                                 begin: Alignment.topCenter,
                                 end: Alignment.bottomCenter,
                                 colors: [Colors.black.withOpacity(0.2), Colors.transparent],
                               ),
                             ),
                           ),
                         ),
                       ],
                     ),
                   ),
                 ),
                 
                 Padding(
                   padding: const EdgeInsets.all(24.0),
                   child: SizedBox(
                     width: double.infinity,
                     height: 60,
                     child: ElevatedButton(
                       style: ElevatedButton.styleFrom(
                         backgroundColor: Colors.white,
                         foregroundColor: AppTheme.alertRed,
                         elevation: 8,
                         shape: RoundedRectangleBorder(
                           borderRadius: BorderRadius.circular(30),
                         ),
                       ),
                       onPressed: () => _stopSos(context),
                       child: Row(
                         mainAxisAlignment: MainAxisAlignment.center,
                         children: [
                           const Icon(Icons.stop_circle_outlined, size: 28),
                           const SizedBox(width: 12),
                           const Text(
                             "I AM SAFE - STOP SOS",
                             style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                           ),
                         ],
                       ),
                     ),
                   ),
                 ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
