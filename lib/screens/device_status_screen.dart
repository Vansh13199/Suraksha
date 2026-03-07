import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/ble_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/modern_card.dart';

class DeviceStatusScreen extends StatelessWidget {
  const DeviceStatusScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final bleProvider = Provider.of<BleProvider>(context);
    final isConnected = bleProvider.isConnected;

    return Scaffold(
      appBar: AppBar(title: const Text("Device Status")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const SizedBox(height: 20),
            Center(
              child: Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: isConnected ? AppTheme.successGreen.withOpacity(0.1) : AppTheme.alertRed.withOpacity(0.1),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isConnected ? AppTheme.successGreen.withOpacity(0.3) : AppTheme.alertRed.withOpacity(0.3),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isConnected ? AppTheme.successGreen.withOpacity(0.2) : AppTheme.alertRed.withOpacity(0.2),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Icon(
                  isConnected ? Icons.bluetooth_connected_rounded : Icons.bluetooth_disabled_rounded,
                  size: 64,
                  color: isConnected ? AppTheme.successGreen : AppTheme.alertRed,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              isConnected ? "Securely Connected" : "Disconnected",
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: isConnected ? AppTheme.successGreen : AppTheme.alertRed,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isConnected 
                  ? "Your Suraksha device is active and monitoring." 
                  : "Please connect your device to ensure safety features work.",
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textGrey,
              ),
            ),
            const SizedBox(height: 48),

            ModernCard(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                children: [
                  _buildStatusItem(
                    context, 
                    label: "Battery Level", 
                    value: "85%", 
                    icon: Icons.battery_full_rounded,
                    valueColor: AppTheme.successGreen,
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Divider(height: 1),
                  ),
                  _buildStatusItem(
                    context, 
                    label: "Signal Strength", 
                    value: "-45 dBm", 
                    icon: Icons.wifi_rounded,
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Divider(height: 1),
                  ),
                  _buildStatusItem(
                    context, 
                    label: "Last Synced", 
                    value: "Just now", 
                    icon: Icons.sync_rounded
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusItem(BuildContext context, {
    required String label, 
    required String value, 
    required IconData icon,
    Color? valueColor,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppTheme.primaryBlue.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: AppTheme.primaryBlue, size: 24),
      ),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      trailing: Text(
        value, 
        style: TextStyle(
          fontWeight: FontWeight.bold, 
          fontSize: 16,
          color: valueColor ?? AppTheme.textDark,
        ),
      ),
    );
  }
}
