import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  GoogleMapController? mapController;
  Position? _currentPosition;
  LatLng? _homeLocation;
  String _mode = '...';
  StreamSubscription<Position>? _positionStream;

  final double distanceThresholdMeters = 200;

  @override
  void initState() {
    super.initState();
    _loadHomeLocation();
    _initLocation();
  }

  Future<void> _loadHomeLocation() async {
    final prefs = await SharedPreferences.getInstance();
    final lat = prefs.getDouble('home_lat');
    final lng = prefs.getDouble('home_lng');
    if (lat != null && lng != null) {
      setState(() {
        _homeLocation = LatLng(lat, lng);
      });
    }
  }

  Future<void> _saveHomeLocation(LatLng location) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('home_lat', location.latitude);
    await prefs.setDouble('home_lng', location.longitude);
  }

  Future<void> _initLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.deniedForever || permission == LocationPermission.denied) {
        return;
      }
    }

    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen((Position position) {
      setState(() {
        _currentPosition = position;
        _mode = _homeLocation != null ? _calculateMode(position) : '...';
      });
    });
  }

  String _calculateMode(Position pos) {
    if (_homeLocation == null) return '...';
    double distance = Geolocator.distanceBetween(
      pos.latitude,
      pos.longitude,
      _homeLocation!.latitude,
      _homeLocation!.longitude,
    );
    return distance <= distanceThresholdMeters ? "Home" : "Away";
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    LatLng? currentLatLng = _currentPosition != null
        ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
        : null;

    return Scaffold(
      appBar: AppBar(title: const Text('Localisation & Mode')),
      body: Column(
        children: [
          Expanded(
            child: currentLatLng != null
                ? GoogleMap(
                    onMapCreated: (controller) {
                      mapController = controller;
                    },
                    initialCameraPosition: CameraPosition(
                      target: currentLatLng,
                      zoom: 15,
                    ),
                    markers: {
                      Marker(
                        markerId: const MarkerId('user'),
                        position: currentLatLng,
                        infoWindow: const InfoWindow(title: 'Vous êtes ici'),
                      ),
                      if (_homeLocation != null)
                        Marker(
                          markerId: const MarkerId('home'),
                          position: _homeLocation!,
                          infoWindow: const InfoWindow(title: 'Maison'),
                          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
                        ),
                    },
                    onTap: (LatLng tappedLocation) async {
                      setState(() {
                        _homeLocation = tappedLocation;
                        if (_currentPosition != null) {
                          _mode = _calculateMode(_currentPosition!);
                        }
                      });
                      await _saveHomeLocation(tappedLocation);
                    },
                  )
                : const Center(child: CircularProgressIndicator()),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              _homeLocation != null ? "Mode : $_mode" : "Tapez sur la carte pour définir la maison",
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
