import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../../providers/ble_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/modern_card.dart';
import '../../widgets/primary_button.dart';
import 'home_dashboard_screen.dart';

class DevicePairingScreen extends StatefulWidget {
  const DevicePairingScreen({super.key});

  @override
  State<DevicePairingScreen> createState() => _DevicePairingScreenState();
}

class _DevicePairingScreenState extends State<DevicePairingScreen> with SingleTickerProviderStateMixin {
  late AnimationController _scanAnimationController;

  @override
  void initState() {
    super.initState();
    _scanAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
  }

  @override
  void dispose() {
    _scanAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Pair Device")),
      body: Consumer<BleProvider>(
        builder: (context, bleProvider, child) {
          if (bleProvider.isScanning && !_scanAnimationController.isAnimating) {
            _scanAnimationController.repeat();
          } else if (!bleProvider.isScanning && _scanAnimationController.isAnimating) {
            _scanAnimationController.stop();
            _scanAnimationController.reset();
          }

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  // Tip Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryBlue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.primaryBlue.withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, color: AppTheme.primaryBlue),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            "Turn on your suraksha device. Make sure it's close by.",
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppTheme.textDark,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Scanning/List Area
                  Expanded(
                    child: bleProvider.scanResults.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                RotationTransition(
                                  turns: _scanAnimationController,
                                  child: Icon(
                                    Icons.bluetooth_searching,
                                    size: 80,
                                    color: bleProvider.isScanning ? AppTheme.primaryBlue : AppTheme.textGrey,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                Text(
                                  bleProvider.isScanning 
                                      ? "Searching for devices..." 
                                      : "No devices found",
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppTheme.textGrey),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            itemCount: bleProvider.scanResults.length,
                            itemBuilder: (context, index) {
                              ScanResult result = bleProvider.scanResults[index];
                              String name = result.device.platformName;
                              if (name.isEmpty) name = "Unknown Device";
                              
                              return ModernCard(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                margin: const EdgeInsets.symmetric(vertical: 8),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: AppTheme.primaryBlue.withOpacity(0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.bluetooth, color: AppTheme.primaryBlue),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            name,
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                          ),
                                          Text(
                                            result.device.remoteId.str,
                                            style: const TextStyle(color: AppTheme.textGrey, fontSize: 12),
                                          ),
                                        ],
                                      ),
                                    ),
                                    ElevatedButton(
                                      onPressed: () async {
                                        await bleProvider.connect(result.device);
                                        if (bleProvider.isConnected && context.mounted) {
                                          Navigator.pushReplacement(
                                            context,
                                            MaterialPageRoute(builder: (_) => const HomeDashboardScreen()),
                                          );
                                        }
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppTheme.primaryBlue,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                      ),
                                      child: const Text("Connect"),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),

                  const SizedBox(height: 24),

                  // Actions
                  PrimaryButton(
                    text: bleProvider.isScanning ? "Stop Scanning" : "Scan for Devices",
                    isLoading: false, // Could map to a specific loading state if needed
                    onPressed: bleProvider.isScanning 
                      ? () => bleProvider.stopScan() 
                      : () => bleProvider.startScan(),
                    backgroundColor: bleProvider.isScanning ? AppTheme.alertRed : AppTheme.primaryBlue,
                  ),
                  const SizedBox(height: 16),
                   TextButton(
                     onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (_) => const HomeDashboardScreen()),
                        );
                     },
                     child: const Text("Skip Pairing", style: TextStyle(color: AppTheme.textGrey)),
                   ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
