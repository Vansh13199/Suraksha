import 'dart:convert';
import 'dart:async'; // Added for StreamSubscription
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:url_launcher/url_launcher.dart'; // Still used elsewhere? No, removed. Wait, kept for now.
import 'package:location/location.dart'; // Added for LocationData
import 'package:flutter_phone_direct_caller/flutter_phone_direct_caller.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/contact_model.dart';
import 'location_service.dart';

class EmergencyService {
  final LocationService _locationService = LocationService();
  bool _isSosActive = false;
  
  // New: Track session ID and subscription
  String? _currentSosSessionId;
  StreamSubscription<LocationData>? _locationSubscription;
  Timer? _locationTimer;
  final String _testPhoneNumber = "+919999999999"; // Placeholder if auth missing

  bool get isSosActive => _isSosActive;

  Future<void> activateSos(List<ContactModel> contacts, {double? latOverride, double? lonOverride}) async {
    try {
      _isSosActive = true;

      // 1. Start Location Service
      await _locationService.startLiveTracking();
      // Use override if provided, else fetch current
      LocationData? location;
      if (latOverride != null && lonOverride != null) {
          // manually construct LocationData or just use the values.
          // Since LocationData constructor might be restricted or require specific map, 
          // let's create a dummy one or handle separate variables.
          // Ideally passing LocationData is cleaner but it has no public const.
          // We will use a wrapper or just handle logic below.
          // For simplicity, we just use the override values for session creation.
          // Note: LocationData is from `location` package.
           location = LocationData.fromMap({
             'latitude': latOverride,
             'longitude': lonOverride,
             'accuracy': 10.0, // Assumed
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
      await _createSosSession(location);

      // 3. Start Listening to Location Updates for Live Tracking
      _startLiveLocationUpdates();

      // Production URL
      const String websiteBaseUrl = "https://suraksha.dev-vansh.in"; 
      
      final String trackingLink = _currentSosSessionId != null 
          ? '$websiteBaseUrl/?session=$_currentSosSessionId'
          : 'https://maps.google.com/?q=${location?.latitude},${location?.longitude}';

      final String message = 'SOS! I need help. Track me LIVE here: $trackingLink';

      safePrint('SENDING SOS TO: ${contacts.map((c) => c.phoneNumber).join(", ")}');
      safePrint('MESSAGE: $message');

      // 4. Send SMS via Backend API
      if (contacts.isNotEmpty) {
        await _sendSmsBackend(contacts, message);
      }

      // 5. Initiate Phone Call (Direct to 112)
      // Call 112 immediately, regardless of contacts.
      await _callEmergencyDirectly();
    } catch (e) {
      safePrint("CRITICAL SOS ERROR: $e");
    }
  }

  // Create Session in GraphQL
  Future<void> _createSosSession(LocationData? location) async {
    try {
      String userPhone = _testPhoneNumber; 
      try {
        final attributes = await Amplify.Auth.fetchUserAttributes();
        final phonAttr = attributes.firstWhere(
          (a) => a.userAttributeKey.key == 'phone_number',
          orElse: () => AuthUserAttribute(
            userAttributeKey: const CognitoUserAttributeKey.custom('phone_number'),
            value: _testPhoneNumber,
          ),
        );
        userPhone = phonAttr.value;
      } catch(_) {}

      safePrint("[SOS] Creating session with phone=$userPhone, lat=${location?.latitude}, lng=${location?.longitude}");

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
          "input": {
            "phoneNumber": userPhone,
            "isActive": true,
            "latitude": location?.latitude ?? 0.0,
            "longitude": location?.longitude ?? 0.0,
          }
        },
      );

      final response = await Amplify.API.mutate(request: request).response;
      
      if (response.errors.isNotEmpty) {
        safePrint("[SOS] CreateSession ERRORS: ${response.errors}");
        return;
      }
      
      safePrint("[SOS] CreateSession response: ${response.data}");
      final data = jsonDecode(response.data!);
      _currentSosSessionId = data['createSOSSession']['id'];
      safePrint("[SOS] Session Created: $_currentSosSessionId");
    } catch (e) {
      safePrint("[SOS] Failed to create SOS session: $e");
    }
  }

  // Listen to location stream AND poll on a timer as fallback
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
          "input": {
            "id": _currentSosSessionId,
            "latitude": location.latitude,
            "longitude": location.longitude,
          }
        },
      );

      await Amplify.API.mutate(request: request).response;
      safePrint("[SOS] Updated Location: ${location.latitude}, ${location.longitude}");
    } catch (e) {
      safePrint("[SOS] Failed to update location: $e");
    }
  }

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
      safePrint('SOS SMS Response: ${response.statusCode} ${response.decodeBody()}');
    } catch (e) {
      safePrint('Failed to send SOS SMS via backend: $e');
    }
  }

  Future<void> deactivateSos() async {
    _isSosActive = false;
    _locationSubscription?.cancel();
    _locationSubscription = null;
    _locationTimer?.cancel();
    _locationTimer = null;
    await _locationService.stopLiveTracking();

    // End Session in Backend
    if (_currentSosSessionId != null) {
      await _endSosSession();
      _currentSosSessionId = null;
    }
  }

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
          "input": {
            "id": _currentSosSessionId,
            "isActive": false,
          }
        },
      );
      await Amplify.API.mutate(request: request).response;
      safePrint("SOS Session Ended");
    } catch (e) {
      safePrint("Failed to end SOS session: \$e");
    }
  }

  Future<void> _callEmergencyDirectly() async {
    const String emergencyNumber = '112'; // Universal Emergency Number
    try {
      safePrint("Checking permissions for DIRECT call...");
      
      // Request permission if not granted
      var status = await Permission.phone.status;
      if (!status.isGranted) {
        status = await Permission.phone.request();
      }

      if (status.isGranted) {
        safePrint("Permission granted. Initiating DIRECT call to $emergencyNumber");
        bool? res = await FlutterPhoneDirectCaller.callNumber(emergencyNumber);
        if (res != true) {
           safePrint("Direct call returned false. Falling back to dialer.");
           _launchDialer(emergencyNumber);
        }
      } else {
        safePrint("Phone permission denied. Falling back to dialer.");
        _launchDialer(emergencyNumber);
      }
    } catch (e) {
      safePrint("Error during direct emergency call: $e");
      _launchDialer(emergencyNumber);
    }
  }

  // Fallback to open dialer if direct call fails
  Future<void> _launchDialer(String number) async {
    final Uri uri = Uri(scheme: 'tel', path: number);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
