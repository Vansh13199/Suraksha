import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../providers/esp32_debug_provider.dart';
import '../core/theme/app_theme.dart';
import '../widgets/modern_card.dart';
import 'package:intl/intl.dart';

class Esp32GpsDebugScreen extends StatefulWidget {
  const Esp32GpsDebugScreen({super.key});

  @override
  State<Esp32GpsDebugScreen> createState() => _Esp32GpsDebugScreenState();
}

class _Esp32GpsDebugScreenState extends State<Esp32GpsDebugScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Fetch initial location when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<Esp32DebugProvider>(context, listen: false).fetchLocation();
    });
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<Esp32DebugProvider>(context);

    // Auto-scroll logic
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

    return Scaffold(
      appBar: AppBar(title: const Text("ESP32 GPS Debug")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- GPS Info Card ---
            ModernCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("GPS Status: ${provider.gpsStatus}", 
                        style: TextStyle(fontWeight: FontWeight.bold, 
                          color: provider.gpsStatus == "Active" ? AppTheme.successGreen : AppTheme.alertRed)),
                      if (provider.isFetchingGps)
                        const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                    ],
                  ),
                  const Divider(),
                  _buildInfoRow("Latitude", provider.currentPosition?.latitude.toString() ?? "--"),
                  _buildInfoRow("Longitude", provider.currentPosition?.longitude.toString() ?? "--"),
                  _buildInfoRow("Accuracy", "${provider.currentPosition?.accuracy.toStringAsFixed(1) ?? "--"} m"),
                  _buildInfoRow("Timestamp", provider.currentPosition != null 
                    ? DateFormat('HH:mm:ss').format(provider.currentPosition!.timestamp) 
                    : "--"),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: provider.fetchLocation,
                    icon: const Icon(Icons.refresh),
                    label: const Text("Refresh GPS"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryBlue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // --- Bluetooth Connection Card ---
            ModernCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Bluetooth Devices", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      if (provider.isScanning)
                        const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: provider.isScanning ? provider.stopScan : provider.startScan,
                          child: Text(provider.isScanning ? "Stop Scan" : "Start Scan"),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (provider.isConnected)
                        Expanded(
                          child: OutlinedButton(
                            onPressed: provider.disconnect,
                            style: OutlinedButton.styleFrom(foregroundColor: AppTheme.alertRed),
                            child: const Text("Disconnect"),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (provider.scanResults.isNotEmpty)
                    Container(
                      height: 150,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ListView.builder(
                        itemCount: provider.scanResults.length,
                        itemBuilder: (ctx, index) {
                          final result = provider.scanResults[index];
                          final deviceName = result.device.platformName.isNotEmpty 
                              ? result.device.platformName 
                              : "Unknown Device (${result.device.remoteId.str})";
                          
                          bool isGpsDevice = deviceName == "Suraksha_GPS";
                          bool isSosDevice = deviceName == "Suraksha_SOS";

                          return ListTile(
                            title: Row(
                              children: [
                                Text(deviceName, style: TextStyle(
                                  fontSize: 14, 
                                  fontWeight: isGpsDevice ? FontWeight.bold : FontWeight.normal
                                )),
                                if (isGpsDevice)
                                  Container(
                                    margin: const EdgeInsets.only(left: 8),
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(4)),
                                    child: const Text("GPS ESP", style: TextStyle(color: Colors.white, fontSize: 10)),
                                  ),
                                if (isSosDevice)
                                  Container(
                                    margin: const EdgeInsets.only(left: 8),
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(4)),
                                    child: const Text("SOS ESP", style: TextStyle(color: Colors.white, fontSize: 10)),
                                  ),
                              ],
                            ),
                            subtitle: Text(result.device.remoteId.str, style: const TextStyle(fontSize: 10)),
                            trailing: ElevatedButton(
                              onPressed: isSosDevice 
                                ? null // Disable connecting to SOS ESP from Debug Screen (optional, but requested separation)
                                : () => provider.connect(result.device),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                backgroundColor: isSosDevice ? Colors.grey : AppTheme.primaryBlue,
                                foregroundColor: Colors.white,
                              ),
                              child: Text(isSosDevice ? "Wrong Device" : "Connect", style: const TextStyle(fontSize: 12)),
                            ),
                          );
                        },
                      ),
                    )
                  else if (!provider.isScanning && !provider.isConnected)
                    const Text("No devices found yet.", style: TextStyle(color: Colors.grey)),
                    
                  if (provider.isConnected)
                     Padding(
                       padding: const EdgeInsets.only(top: 8.0),
                       child: Container(
                         padding: const EdgeInsets.all(8),
                         decoration: BoxDecoration(
                           color: AppTheme.successGreen.withOpacity(0.1),
                           borderRadius: BorderRadius.circular(8),
                           border: Border.all(color: AppTheme.successGreen),
                         ),
                         child: const Row(
                           children: [
                             Icon(Icons.bluetooth_connected, color: AppTheme.successGreen),
                             SizedBox(width: 8),
                             Text("Connected", style: TextStyle(color: AppTheme.successGreen, fontWeight: FontWeight.bold)),
                           ],
                         ),
                       ),
                     )
                ],
              ),
            ),
            
            const SizedBox(height: 16),

            // --- Controls ---
            ModernCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: provider.isConnected ? provider.sendGpsData : null,
                          icon: const Icon(Icons.send),
                          label: const Text("Send GPS Now"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryBlue,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    title: const Text("Auto Send (Every 10s)"),
                    subtitle: const Text("Sends coordinates automatically"),
                    value: provider.isAutoSendEnabled,
                    onChanged: provider.isConnected ? (val) => provider.toggleAutoSend(val) : null,
                    activeColor: AppTheme.primaryBlue,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // --- Debug Console ---
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(8),
              ),
              height: 200,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Debug Console", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.white70, size: 20),
                        onPressed: provider.clearLogs,
                        tooltip: "Clear Logs",
                      )
                    ],
                  ),
                  const Divider(color: Colors.white24, height: 1),
                  Expanded(
                    child: ListView.builder(
                      controller: _scrollController,
                      itemCount: provider.logs.length,
                      itemBuilder: (ctx, index) {
                        final log = provider.logs[index];
                        Color color = Colors.white;
                        if (log.type == LogType.success) color = Colors.greenAccent;
                        if (log.type == LogType.error) color = Colors.redAccent;
                        
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2.0),
                          child: Text(
                            "[${DateFormat('HH:mm:ss').format(log.timestamp)}] ${log.message}",
                            style: TextStyle(color: color, fontSize: 12, fontFamily: 'monospace'),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          Text(value, style: const TextStyle(color: Colors.black54)),
        ],
      ),
    );
  }
}
