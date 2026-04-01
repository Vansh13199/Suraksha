import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'dart:convert';
import 'dart:async';
import 'package:provider/provider.dart';
import '../providers/sos_provider.dart';
import '../core/theme/app_theme.dart';

class InAppLiveLocationScreen extends StatefulWidget {
  final String sessionId;
  const InAppLiveLocationScreen({Key? key, required this.sessionId}) : super(key: key);

  @override
  _InAppLiveLocationScreenState createState() => _InAppLiveLocationScreenState();
}

class _InAppLiveLocationScreenState extends State<InAppLiveLocationScreen> {
  GoogleMapController? _mapController;
  Map<MarkerId, Marker> _markers = <MarkerId, Marker>{};
  StreamSubscription<GraphQLResponse<String>>? _subscription;
  
  bool _isLoading = true;
  double _lat = 0.0;
  double _lng = 0.0;
  bool _isActive = true;

  @override
  void initState() {
    super.initState();
    _fetchInitialSessionAndSubscribe();
  }

  Future<void> _fetchInitialSessionAndSubscribe() async {
    try {
      // 1. Fetch
      final query = '''
        query GetSOS(\$id: ID!) {
          getSOSSession(id: \$id) {
            id latitude longitude isActive
          }
        }
      ''';
      final res = await Amplify.API.query(
        request: GraphQLRequest<String>(document: query, variables: {'id': widget.sessionId})
      ).response;

      if (res.data != null) {
        final data = jsonDecode(res.data!)['getSOSSession'];
        if (data != null) {
          setState(() {
            _lat = (data['latitude'] as num).toDouble();
            _lng = (data['longitude'] as num).toDouble();
            _isActive = data['isActive'] as bool;
            _isLoading = false;
            _updateMarker();
          });
        }
      }

      // 2. Subscribe
      final sub = '''
        subscription OnUpdate(\$id: ID!) {
          onSOSSessionUpdated(id: \$id) {
            id latitude longitude isActive
          }
        }
      ''';
      
      final subRequest = GraphQLRequest<String>(
        document: sub,
        variables: {'id': widget.sessionId}
      );

      _subscription = Amplify.API.subscribe<String>(
        subRequest,
        onEstablished: () => print('[Map] Subscription established'),
      ).listen((event) {
        if (event.data != null) {
          final data = jsonDecode(event.data!)['onSOSSessionUpdated'];
          if (data != null) {
            setState(() {
              _lat = (data['latitude'] as num).toDouble();
              _lng = (data['longitude'] as num).toDouble();
              _isActive = data['isActive'] as bool;
              _updateMarker();
            });
          }
        }
      }, onError: (e) => print('[Map] Sub Error: \$e'));

    } catch (e) {
      print("Failed to load map data: \$e");
      setState(() => _isLoading = false);
    }
  }

  void _updateMarker() {
    final position = LatLng(_lat, _lng);
    final markerId = const MarkerId('sos_target');
    
    final marker = Marker(
      markerId: markerId,
      position: position,
      icon: _isActive ? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed) 
                      : BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      infoWindow: InfoWindow(
        title: _isActive ? 'Emergency Location' : 'Resolved',
        snippet: 'Updated tracking active',
      ),
    );

    setState(() {
      _markers[markerId] = marker;
    });

    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: position, zoom: 17.0),
      ),
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sosProvider = Provider.of<SosProvider>(context);

    // 🛡️ ROLE GUARD: Prevent sender from seeing responder's live tracking view
    if (sosProvider.isSosActive && sosProvider.currentSessionId == widget.sessionId) {
      return Scaffold(
        appBar: AppBar(
          title: const Text("SOS Dashboard Active"),
          backgroundColor: AppTheme.alertRed,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.map_outlined, size: 80, color: AppTheme.alertRed),
              const SizedBox(height: 24),
              const Text(
                "Restricted Access",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                child: Text(
                  "This live tracking map is reserved for your emergency responders to locate you. Please use your SOS active screen for help controls.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontSize: 14),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.alertRed,
                  foregroundColor: Colors.white,
                ),
                child: const Text("Return to Control Center"),
              )
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Tracking'),
        backgroundColor: _isActive ? Colors.red : Colors.green,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : Stack(
            children: [
              GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: LatLng(_lat, _lng),
                  zoom: 15.0,
                ),
                markers: Set<Marker>.of(_markers.values),
                onMapCreated: (ctl) => _mapController = ctl,
                myLocationEnabled: true,
              ),
              if (!_isActive)
                 Positioned(
                   top: 20, left: 20, right: 20,
                   child: Container(
                     padding: const EdgeInsets.all(12),
                     decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(8)),
                     child: const Center(child: Text("Emergency Resolved", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                   )
                 )
            ],
          ),
    );
  }
}
