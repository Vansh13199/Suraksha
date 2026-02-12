import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../../providers/ble_provider.dart';
import '../../core/theme/app_theme.dart';
import 'home_dashboard_screen.dart';

class DevicePairingScreen extends StatelessWidget {
  const DevicePairingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Pair Device")),
      body: Consumer<BleProvider>(
        builder: (context, bleProvider, child) {
          return Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                color: AppTheme.lightBlue,
                child: Row(
                  children: [
                    const Icon(Icons.bluetooth_searching, color: AppTheme.primaryBlue),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        "Turn on your ESP32 device. Make sure it's close by.",
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: bleProvider.isScanning
                    ? const Center(child: CircularProgressIndicator())
                    : ListView.builder(
                        itemCount: bleProvider.scanResults.length,
                        itemBuilder: (context, index) {
                          ScanResult result = bleProvider.scanResults[index];
                          String name = result.device.platformName;
                          if (name.isEmpty) name = "Unknown Device";
                          
                          return ListTile(
                            leading: const Icon(Icons.bluetooth),
                            title: Text(name),
                            subtitle: Text(result.device.remoteId.str),
                            trailing: ElevatedButton(
                              onPressed: () async {
                                await bleProvider.connect(result.device);
                                if (bleProvider.isConnected && context.mounted) {
                                  Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(builder: (_) => const HomeDashboardScreen()),
                                  );
                                }
                              },
                              child: const Text("Connect"),
                            ),
                          );
                        },
                      ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: bleProvider.isScanning 
                      ? () => bleProvider.stopScan() 
                      : () => bleProvider.startScan(),
                    child: Text(bleProvider.isScanning ? "Stop Scanning" : "Scan for Devices"),
                  ),
                ),
              ),
               TextButton(
                 onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const HomeDashboardScreen()),
                    );
                 },
                 child: const Text("Skip Pairing"),
               ),
               const SizedBox(height: 16),
            ],
          );
        },
      ),
    );
  }
}
