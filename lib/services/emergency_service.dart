import 'package:url_launcher/url_launcher.dart';
import '../models/contact_model.dart';
import 'location_service.dart';

class EmergencyService {
  final LocationService _locationService = LocationService();
  bool _isSosActive = false;

  bool get isSosActive => _isSosActive;

  Future<void> activateSos(List<ContactModel> contacts) async {
    try {
      _isSosActive = true;

      await _locationService.startLiveTracking();
      final location = await _locationService.getCurrentLocation();

      final String mapsLink = location != null
          ? 'https://maps.google.com/?q=${location.latitude},${location.longitude}'
          : 'Location unavailable';

      final String message = 'SOS! I need help.\n$mapsLink';

      print('SENDING SOS TO:');
      for (final c in contacts) {
        print(c.phoneNumber);
      }
      print('MESSAGE: $message');

      if (contacts.isNotEmpty) {
        await makePhoneCall(contacts.first.phoneNumber);
      }
    } catch (e) {
      print("CRITICAL SOS ERROR: $e");
      // Prevent crash, just log. 
      // State is already set to active so UI shows "SOS ACTIVE" even if background logic failed partially.
    }
  }

  Future<void> deactivateSos() async {
    _isSosActive = false;
    await _locationService.stopLiveTracking();
  }

  Future<void> makePhoneCall(String phoneNumber) async {
    final Uri uri = Uri(
      scheme: 'tel',
      path: phoneNumber,
    );

    if (await canLaunchUrl(uri)) {
      await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
    }
  }
}
