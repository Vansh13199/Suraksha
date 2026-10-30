import 'dart:convert';
import 'dart:async';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:location/location.dart';
import 'package:flutter_phone_direct_caller/flutter_phone_direct_caller.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import '../models/contact_model.dart';
import 'location_service.dart';
import 'auth_service.dart';
import 'esp32_sos_service.dart';
import '../main.dart';

class EmergencyService {
  // Singleton pattern
  static final EmergencyService _instance = EmergencyService._internal();
  factory EmergencyService() => _instance;
  EmergencyService._internal() {
    _clearStaleLocks();
  }

  Future<void> _clearStaleLocks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('is_sos_active_global');
      await prefs.remove('active_sos_session_id');
      await prefs.remove('sos_cross_isolate_lock');
    } catch (_) {}
  }

  final LocationService _locationService = LocationService();
  final AuthService _authService = AuthService();
  bool _isSosActive = false;
  bool _isActivating = false;
  bool _isDeactivating = false;

  // Track session ID and subscriptions
  String? _currentSosSessionId;
  StreamSubscription<LocationData>? _locationSubscription;
  Timer? _locationTimer;

  bool get isSosActive => _isSosActive;
  String? get currentSosSessionId => _currentSosSessionId;

  /// External sync method for isolates to keep in-memory state aligned
  void setSosActiveState(bool active, {String? sessionId}) {
    _isSosActive = active;
    if (active) {
      if (sessionId != null && sessionId.isNotEmpty) {
        _currentSosSessionId = sessionId;
      }
    } else {
      _currentSosSessionId = null;
      _locationSubscription?.cancel();
      _locationSubscription = null;
      _locationTimer?.cancel();
      _locationTimer = null;
    }
  }

  /// Activate SOS: create session, start tracking, send SMS, call emergency.
  Future<void> activateSos(List<ContactModel> contacts, {double? latOverride, double? lonOverride, bool isLowBattery = false}) async {
    if (_isSosActive || _isActivating) {
      safePrint('[SOS] ⚠️ SOS is already active (Session: $_currentSosSessionId) or activating. Ignoring duplicate trigger.');
      return;
    }

    // Cross-isolate debounce: only debounce if another activation happened within 3s while active
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      final bool isGlobalActive = prefs.getBool('is_sos_active_global') ?? false;
      final int now = DateTime.now().millisecondsSinceEpoch;
      final int? lastActivation = prefs.getInt('sos_cross_isolate_lock');
      if (isGlobalActive && lastActivation != null && (now - lastActivation) < 3000) {
        safePrint('[SOS] ⚠️ SOS already activating in another isolate ($lastActivation). Skipping duplicate.');
        return;
      }
      await prefs.setInt('sos_cross_isolate_lock', now);
    } catch (_) {}

    _isActivating = true;
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

      // Verify session was actually created; if not, roll back
      if (_currentSosSessionId == null) {
        safePrint('[SOS] ❌ Backend session creation failed. Rolling back activation state.');
        _isSosActive = false;
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove('sos_cross_isolate_lock');
          await prefs.remove('active_sos_session_id');
          await prefs.setBool('is_sos_active_global', false);
        } catch (_) {}
        await _locationService.stopLiveTracking();
        return;
      }

      // Notify running UI isolate via background service IPC
      try {
        final bgService = FlutterBackgroundService();
        if (await bgService.isRunning()) {
          bgService.invoke('sos_status_changed', {
            'isActive': true,
            'sessionId': _currentSosSessionId,
          });
        }
      } catch (_) {}

      // 3. Start Live Location Updates
      _startLiveLocationUpdates();

      // Show high-priority ongoing heads-up alert on the phone
      await _showSosNotification();

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
      _isSosActive = false;
      safePrint('[SOS] CRITICAL ERROR: $e');
    } finally {
      _isActivating = false;
    }
  }

  /// Create SOS session in GraphQL backend.
  Future<void> _createSosSession(LocationData? location, List<ContactModel> contacts, bool isLowBattery) async {
    _currentSosSessionId = null;
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
            'phoneNumber': userPhone.isNotEmpty ? userPhone : '+910000000000',
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
        _currentSosSessionId = null;
        return;
      }

      if (response.data == null) {
        safePrint('[SOS] CreateSession response data is NULL');
        _currentSosSessionId = null;
        return;
      }

      safePrint('[SOS] CreateSession response: ${response.data}');
      final data = jsonDecode(response.data!);
      _currentSosSessionId = data['createSOSSession']?['id'];
      safePrint('[SOS] Session Created: $_currentSosSessionId');

      if (_currentSosSessionId != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('active_sos_session_id', _currentSosSessionId!);
        await prefs.setBool('is_sos_active_global', true);
      }
    } catch (e) {
      _currentSosSessionId = null;
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
  Future<void> deactivateSos({bool fromIpc = false}) async {
    if (_isDeactivating) {
      safePrint('[SOS] Deactivation already in progress, skipping duplicate.');
      return;
    }
    _isDeactivating = true;
    safePrint('[SOS] Deactivating SOS session(s) (fromIpc=$fromIpc)...');

    _isSosActive = false;
    _isActivating = false;

    // Check SharedPreferences for active session if in-memory ID was null (e.g., cross-isolate)
    String? sessionToEnd = _currentSosSessionId;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      if (sessionToEnd == null || sessionToEnd.isEmpty) {
        sessionToEnd = prefs.getString('active_sos_session_id');
      }
      await prefs.remove('sos_cross_isolate_lock');
      await prefs.remove('active_sos_session_id');
      await prefs.setBool('is_sos_active_global', false);
    } catch (_) {}

    _currentSosSessionId = null;

    // Notify other isolate via IPC if this deactivation was triggered locally
    if (!fromIpc) {
      try {
        final bgService = FlutterBackgroundService();
        if (await bgService.isRunning()) {
          bgService.invoke('sos_status_changed', {
            'isActive': false,
          });
        }
      } catch (_) {}
    }

    // Stop tracking & location updates immediately
    _locationSubscription?.cancel();
    _locationSubscription = null;
    _locationTimer?.cancel();
    _locationTimer = null;
    await _locationService.stopLiveTracking();

    // Send SOS:STOP command to ESP32 device if connected via BLE
    try {
      final esp = Esp32SosService();
      if (esp.isConnected) {
        safePrint('[SOS] 📱 Sending SOS:STOP to ESP32 wearable device...');
        await esp.sendData("SOS:STOP");
      }
    } catch (e) {
      safePrint('[SOS] Could not send SOS:STOP to ESP32: $e');
    }

    // Hide ongoing alert notification
    await _hideSosNotification();

    try {
      // 1. Explicitly end current session in backend
      if (sessionToEnd != null && sessionToEnd.isNotEmpty) {
        await _endSosSession(sessionToEnd);
      }

      // 2. Safety net: clean up any other lingering active sessions for this user on AWS
      await _endAllActiveUserSessions(excludeSessionId: sessionToEnd);
    } finally {
      _isDeactivating = false;
    }
  }

  /// End SOS session in backend by session ID.
  Future<void> _endSosSession(String sessionId) async {
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
            'id': sessionId,
            'isActive': false,
          }
        },
      );
      final response = await Amplify.API.mutate(request: request).response;
      if (response.errors.isNotEmpty) {
        safePrint('[SOS] Failed to end session $sessionId: ${response.errors}');
      } else {
        safePrint('[SOS] Session Ended: $sessionId');
      }
    } catch (e) {
      safePrint('[SOS] Failed to end session $sessionId: $e');
    }
  }

  /// Clean up any lingering active sessions for this user on AWS.
  Future<void> _endAllActiveUserSessions({String? excludeSessionId}) async {
    try {
      final userPhone = await _authService.getUserPhone();
      if (userPhone == null || userPhone.isEmpty) return;

      final query = '''
        query ListActiveSOS {
          listSOSSessions(filter: { phoneNumber: { eq: "$userPhone" }, isActive: { eq: true } }) {
            items {
              id
            }
          }
        }
      ''';

      final res = await Amplify.API.query(
        request: GraphQLRequest<String>(document: query),
      ).response;

      if (res.data != null) {
        final data = jsonDecode(res.data!);
        final items = List<Map<String, dynamic>>.from(data['listSOSSessions']['items'] ?? []);
        final dangling = items
            .where((item) =>
                item['id'] != null &&
                item['id'].toString().isNotEmpty &&
                item['id'].toString() != excludeSessionId)
            .toList();

        if (dangling.isNotEmpty) {
          safePrint('[SOS] Found ${dangling.length} dangling active session(s). Cleaning up in parallel...');
          await Future.wait(dangling.map((item) {
            final id = item['id'].toString();
            safePrint('[SOS] Cleaning up dangling active session: $id');
            return _endSosSession(id);
          }));
        }
      }
    } catch (e) {
      safePrint('[SOS] Error cleaning up active sessions: $e');
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

  /// Show high-priority heads-up notification with sound, vibration, and full-screen intent.
  Future<void> _showSosNotification() async {
    try {
      final androidImplementation = flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

      const AndroidNotificationChannel alertChannel = AndroidNotificationChannel(
        'suraksha_emergency_alert',
        'Emergency Alert',
        description: 'Active Emergency Alert Notifications',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      );
      await androidImplementation?.createNotificationChannel(alertChannel);

      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'suraksha_emergency_alert',
        'Emergency Alert',
        channelDescription: 'Active Emergency Alert Notifications',
        importance: Importance.max,
        priority: Priority.high,
        fullScreenIntent: true,
        ongoing: true,
        autoCancel: false,
        enableVibration: true,
        playSound: true,
        color: Colors.red,
        category: AndroidNotificationCategory.alarm,
        visibility: NotificationVisibility.public,
      );

      const NotificationDetails details = NotificationDetails(
        android: androidDetails,
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentSound: true,
          presentBadge: true,
        ),
      );

      await flutterLocalNotificationsPlugin.show(
        id: 911,
        title: '🚨 EMERGENCY SOS ACTIVE',
        body: 'SOS triggered from Watch. Streaming live location and alerting contacts.',
        notificationDetails: details,
        payload: 'sos_active',
      );
      safePrint('[SOS] Heads-up SOS notification displayed');
    } catch (e) {
      safePrint('[SOS] Error showing heads-up notification: $e');
    }
  }

  /// Cancel high-priority alert notification.
  Future<void> _hideSosNotification() async {
    try {
      await flutterLocalNotificationsPlugin.cancel(id: 911);
      safePrint('[SOS] Heads-up SOS notification canceled');
    } catch (_) {}
  }
}
