import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/ble_provider.dart';
import '../../core/theme/app_theme.dart';

class DeviceStatusScreen extends StatelessWidget {
  const DeviceStatusScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final bleProvider = Provider.of<BleProvider>(context);

    return Scaffold(
      appBar: AppBar(title: const Text("Device Status")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: bleProvider.isConnected ? AppTheme.successGreen.withOpacity(0.1) : AppTheme.errorRed.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                bleProvider.isConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
                size: 64,
                color: bleProvider.isConnected ? AppTheme.successGreen : AppTheme.errorRed,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              bleProvider.isConnected ? "Securely Connected" : "Disconnected",
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 48),
            _buildStatusItem("Battery Level", "85%", Icons.battery_full),
             const Divider(),
            _buildStatusItem("Signal Strength", "-45 dBm", Icons.wifi),
             const Divider(),
            _buildStatusItem("Last Synced", "Just now", Icons.sync),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusItem(String label, String value, IconData icon) {
    return ListTile(
      leading: Icon(icon, color: AppTheme.primaryBlue),
      title: Text(label),
      trailing: Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
    );
  }
}
