import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:osmos/screens/mode_screen.dart';

class ModeCardWidget extends StatefulWidget {
  const ModeCardWidget({Key? key}) : super(key: key);

  @override
  State<ModeCardWidget> createState() => _ModeCardWidgetState();
}

class _ModeCardWidgetState extends State<ModeCardWidget> {
  Position? _currentPosition;
  double? _distance;
  String _mode = '...';
  String _awaySubMode = 'Traveling';
  LatLng? _homeLocation;
  final double distanceThresholdMeters = 200;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
    _initLocation();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final lat = prefs.getDouble('home_lat');
    final lng = prefs.getDouble('home_lng');
    final subMode = prefs.getString('away_sub_mode');
    if (lat != null && lng != null) {
      setState(() {
        _homeLocation = LatLng(lat, lng);
      });
    }
    if (subMode != null) {
      setState(() {
        _awaySubMode = subMode;
      });
    }
  }

  Future<void> _initLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) {
        return;
      }
    }
    final pos = await Geolocator.getCurrentPosition();
    setState(() {
      _currentPosition = pos;
    });
    _updateModeAndDistance(pos);
  }

  void _updateModeAndDistance(Position pos) async {
    if (_homeLocation == null) {
      setState(() {
        _mode = '...';
        _distance = null;
      });
      return;
    }
    double distance = Geolocator.distanceBetween(
      pos.latitude,
      pos.longitude,
      _homeLocation!.latitude,
      _homeLocation!.longitude,
    );
    setState(() {
      _distance = distance;
      _mode = distance <= distanceThresholdMeters ? 'Home' : 'Away';
    });
    // Save the latest location for chatbot use
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('last_lat', pos.latitude);
    await prefs.setDouble('last_lng', pos.longitude);
  }

  Color _getModeColor() {
    switch (_mode) {
      case "Home":
        return const Color(0xFF68B86C);
      case "Away":
        return const Color(0xFFFA8B26);
      default:
        return const Color(0xFF757575);
    }
  }

  IconData _getModeIcon() {
    if (_mode == "Home") {
      return Icons.home;
    } else if (_mode == "Away") {
      switch (_awaySubMode) {
        case 'Traveling':
          return Icons.directions_car;
        case 'Working':
          return Icons.work;
        case 'Shopping':
          return Icons.shopping_bag;
        case 'Dining':
          return Icons.restaurant;
        case 'Sports':
          return Icons.fitness_center;
        case 'Vacation':
          return Icons.beach_access;
        case 'Event':
          return Icons.event;
        default:
          return Icons.explore;
      }
    } else {
      return Icons.help_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ModeScreen()),
        );
      },
      child: Card(
        color: Colors.white,
        margin: const EdgeInsets.only(bottom: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          child: Row(
            children: [
              Icon(_getModeIcon(), color: _getModeColor(), size: 32),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _mode == '...'
                          ? "Set your home location"
                          : "Current Mode: $_mode",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _getModeColor(),
                        fontSize: 16,
                      ),
                    ),
                    if (_mode == 'Away')
                      Text(
                        _awaySubMode,
                        style: const TextStyle(
                          color: Color(0xFF757575),
                          fontSize: 14,
                        ),
                      ),
                    if (_distance != null && _homeLocation != null)
                      Text(
                        "Distance: ${_distance!.toInt()} m",
                        style: const TextStyle(
                          color: Color(0xFF757575),
                          fontSize: 13,
                        ),
                      ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey[600]),
            ],
          ),
        ),
      ),
    );
  }
}

// Helper LatLng class for prefs (since google_maps_flutter's LatLng is not available here)
class LatLng {
  final double latitude;
  final double longitude;
  LatLng(this.latitude, this.longitude);
}
