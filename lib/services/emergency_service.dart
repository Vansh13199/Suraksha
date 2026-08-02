import 'dart:convert';
import 'dart:async';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:location/location.dart';
import 'package:flutter_phone_direct_caller/flutter_phone_direct_caller.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/contact_model.dart';
import 'location_service.dart';
import 'auth_service.dart';

class EmergencyService {
  final LocationService _locationService = LocationService();
  final AuthService _authService = AuthService();
  bool _isSosActive = false;

  // Track session ID and subscriptions
  String? _currentSosSessionId;
  StreamSubscription<LocationData>? _locationSubscription;
  Timer? _locationTimer;

  bool get isSosActive => _isSosActive;
  String? get currentSosSessionId => _currentSosSessionId;

  /// Activate SOS: create session, start tracking, send SMS, call emergency.
  Future<void> activateSos(List<ContactModel> contacts, {double? latOverride, double? lonOverride, bool isLowBattery = false}) async {
    try {
      _isSosActive = true;

      // 1. Start Location Service
      await _locationService.startLiveTracking();

      LocationData? location;
      if (latOverride != null && lonOverride != null) {
        location = LocationData.fromMap({
          'latitude': latOverride,
          'longitude': lonOverride,
          'accuracy': 10.0,
          'altitude': 0.0,
          'speed': 0.0,
          'speed_accuracy': 0.0,
          'heading': 0.0,
          'time': DateTime.now().millisecondsSinceEpoch.toDouble(),
        });
      } else {
        location = await _locationService.getCurrentLocation();
      }

      // 2. Create Backend SOS Session
      await _createSosSession(location, contacts, isLowBattery);

      // 3. Start Live Location Updates
      _startLiveLocationUpdates();

      // 4. Build tracking link
      const String websiteBaseUrl = 'https://suraksha.dev-vansh.in';

      final String trackingLink = _currentSosSessionId != null
          ? '$websiteBaseUrl/?session=$_currentSosSessionId'
          : 'https://maps.google.com/?q=${location?.latitude},${location?.longitude}';

      final String message = 'SOS! I need help. Track me LIVE here: $trackingLink';

      safePrint('[SOS] SENDING TO: ${contacts.map((c) => c.phoneNumber).join(", ")}');
      safePrint('[SOS] MESSAGE: $message');

      // 5. Send SMS via Backend API (Skip for low battery, handled via Push)
      if (contacts.isNotEmpty && !isLowBattery) {
        await _sendSmsBackend(contacts, message);
      }

      // 6. Initiate Phone Call (Direct to emergency contact)
      if (!isLowBattery) {
        await _callEmergencyDirectly(contacts);
      }
    } catch (e) {
      safePrint('[SOS] CRITICAL ERROR: $e');
    }
  }

  /// Create SOS session in GraphQL backend.
  Future<void> _createSosSession(LocationData? location, List<ContactModel> contacts, bool isLowBattery) async {
    try {
      // Fetch phone number from the user's DynamoDB profile
      String userPhone = '';
      try {
        final userDetails = await _authService.getUserDetails();
        if (userDetails != null && userDetails.phoneNumber.isNotEmpty) {
          userPhone = userDetails.phoneNumber;
          safePrint('[SOS] Phone number fetched from user profile: $userPhone');
        } else {
          safePrint('[SOS] WARNING: No phone number found in user profile!');
        }
      } catch (e) {
        safePrint('[SOS] ERROR fetching user phone from profile: $e');
      }

      safePrint('[SOS] Creating session: phone=$userPhone, lat=${location?.latitude}, lng=${location?.longitude}');

      final String mutation = '''
        mutation CreateSOSSession(\$input: CreateSOSSessionInput!) {
          createSOSSession(input: \$input) {
            id
            isActive
          }
        }
      ''';

      final request = GraphQLRequest<String>(
        document: mutation,
        variables: {
          'input': {
            'phoneNumber': userPhone,
            'isActive': true,
            'latitude': location?.latitude ?? 0.0,
            'longitude': location?.longitude ?? 0.0,
            'triggerType': isLowBattery ? 'LOW_BATTERY' : 'MANUAL',
            'authorizedViewers': contacts.map((c) => c.phoneNumber).toList(),
          }
        },
      );

      final response = await Amplify.API.mutate(request: request).response;

      if (response.errors.isNotEmpty) {
        safePrint('[SOS] CreateSession ERRORS: ${response.errors}');
        return;
      }

      safePrint('[SOS] CreateSession response: ${response.data}');
      final data = jsonDecode(response.data!);
      _currentSosSessionId = data['createSOSSession']['id'];
      safePrint('[SOS] Session Created: $_currentSosSessionId');
    } catch (e) {
      safePrint('[SOS] Failed to create SOS session: $e');
    }
  }

  /// Listen to location stream AND poll on a timer as fallback.
  void _startLiveLocationUpdates() {
    _locationSubscription?.cancel();
    _locationTimer?.cancel();

    // Stream-based updates
    _locationSubscription = _locationService.locationStream.listen((location) async {
      if (_currentSosSessionId != null && _isSosActive) {
        await _updateSosLocation(location);
      }
    });

    // Timer-based fallback: push location every 5 seconds
    _locationTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (_currentSosSessionId != null && _isSosActive) {
        final location = await _locationService.getCurrentLocation();
        if (location != null) {
          await _updateSosLocation(location);
        }
      }
    });
  }

  /// Update SOS session location via GraphQL mutation.
  Future<void> _updateSosLocation(LocationData location) async {
    try {
      final String mutation = '''
        mutation UpdateSOSSession(\$input: UpdateSOSSessionInput!) {
          updateSOSSession(input: \$input) {
            id
            latitude
            longitude
          }
        }
      ''';

      final request = GraphQLRequest<String>(
        document: mutation,
        variables: {
          'input': {
            'id': _currentSosSessionId,
            'latitude': location.latitude,
            'longitude': location.longitude,
          }
        },
      );

      await Amplify.API.mutate(request: request).response;
      safePrint('[SOS] Updated Location: ${location.latitude}, ${location.longitude}');
    } catch (e) {
      safePrint('[SOS] Failed to update location: $e');
    }
  }

  /// Send SMS via REST API backend.
  Future<void> _sendSmsBackend(List<ContactModel> contacts, String message) async {
    try {
      final body = {
        'contacts': contacts.map((c) => c.phoneNumber).toList(),
        'message': message,
      };

      final operation = Amplify.API.post(
        '/sos',
        apiName: 'sosapi',
        body: HttpPayload.json(body),
      );

      final response = await operation.response;
      safePrint('[SOS] SMS Response: ${response.statusCode} ${response.decodeBody()}');
    } catch (e) {
      safePrint('[SOS] Failed to send SMS via backend: $e');
    }
  }

  /// Deactivate SOS: stop tracking, end session.
  Future<void> deactivateSos() async {
    _isSosActive = false;
    _locationSubscription?.cancel();
    _locationSubscription = null;
    _locationTimer?.cancel();
    _locationTimer = null;
    await _locationService.stopLiveTracking();

    if (_currentSosSessionId != null) {
      await _endSosSession();
      _currentSosSessionId = null;
    }
  }

  /// End SOS session in backend.
  Future<void> _endSosSession() async {
    try {
      final String mutation = '''
        mutation UpdateSOSSession(\$input: UpdateSOSSessionInput!) {
          updateSOSSession(input: \$input) {
            id
            isActive
          }
        }
      ''';

      final request = GraphQLRequest<String>(
        document: mutation,
        variables: {
          'input': {
            'id': _currentSosSessionId,
            'isActive': false,
          }
        },
      );
      await Amplify.API.mutate(request: request).response;
      safePrint('[SOS] Session Ended');
    } catch (e) {
      safePrint('[SOS] Failed to end session: $e');
    }
  }

  /// Call emergency number directly.
  Future<void> _callEmergencyDirectly(List<ContactModel> contacts) async {
    String emergencyNumber = '112';
    if (contacts.isNotEmpty) {
      emergencyNumber = contacts.first.phoneNumber;
    }
    
    try {
      safePrint('[SOS] Checking permissions for DIRECT call...');

      var status = await Permission.phone.status;
      if (!status.isGranted) {
        status = await Permission.phone.request();
      }

      if (status.isGranted) {
        safePrint('[SOS] Permission granted. Initiating DIRECT call to $emergencyNumber');
        bool? res = await FlutterPhoneDirectCaller.callNumber(emergencyNumber);
        if (res != true) {
          safePrint('[SOS] Direct call returned false. Falling back to dialer.');
          _launchDialer(emergencyNumber);
        }
      } else {
        safePrint('[SOS] Phone permission denied. Falling back to dialer.');
        _launchDialer(emergencyNumber);
      }
    } catch (e) {
      safePrint('[SOS] Error during direct emergency call: $e');
      _launchDialer(emergencyNumber);
    }
  }

  /// Fallback: open phone dialer.
  Future<void> _launchDialer(String number) async {
    final Uri uri = Uri(scheme: 'tel', path: number);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
