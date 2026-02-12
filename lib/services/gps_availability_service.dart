import 'package:location/location.dart';
import 'esp32_ble_service.dart';

class GpsAvailabilityService {
  final Location _location = Location();
  final Esp32BleService _espService = Esp32BleService();

  Future<bool> isPhoneGpsAvailable() async {
    bool serviceEnabled = await _location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await _location.requestService();
      if (!serviceEnabled) {
        return false;
      }
    }
    // We assume permission is granted or handled by LocationService init
    return true;
  }

  bool isEspGpsAvailable() {
    // This relies on the Esp32BleService exposing isGpsFixed
    // which we will add in the next step.
    return _espService.isGpsFixed;
  }
}
