import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geocoding/geocoding.dart';

// AppColors for consistent theming
class AppColors {
  static const Color primary = Color(0xFF68B86C);
  static const Color secondary = Color(0xFFFA8B26);
  static const Color background = Color(0xFFF5F5F5);
  static const Color cardBackground = Colors.white;
  static const Color textPrimary = Color(0xFF2D2D2D);
  static const Color textSecondary = Color(0xFF757575);
}

class CustomMapWidget extends StatefulWidget {
  const CustomMapWidget({Key? key}) : super(key: key);

  @override
  State<CustomMapWidget> createState() => _CustomMapWidgetState();
}

class _CustomMapWidgetState extends State<CustomMapWidget>
    with SingleTickerProviderStateMixin {
  GoogleMapController? mapController;
  Position? _currentPosition;
  LatLng? _homeLocation;
  String _mode = '...';
  String _awaySubMode = 'Traveling';
  String? _previousMode;
  StreamSubscription<Position>? _positionStream;
  late AnimationController _animationController;
  late Animation<double> _animation;

  BitmapDescriptor? _userIcon;
  bool _locationError = false;

  final double distanceThresholdMeters = 200;

  final List<String> _awaySubModes = [
    'Traveling',
    'Working',
    'Shopping',
    'Dining',
    'Sports',
    'Vacation',
    'Event',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _loadUserIcon();
    _loadHomeLocation();
    _loadAwaySubMode();
    _initLocation();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _animationController.forward();
  }

  Future<void> _loadUserIcon() async {
    // Use a blue dot as the user marker
    _userIcon = await BitmapDescriptor.fromAssetImage(
      const ImageConfiguration(size: Size(48, 48)),
      'assets/images/blue_dot.png',
    );
    setState(() {});
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

  Future<void> _loadAwaySubMode() async {
    final prefs = await SharedPreferences.getInstance();
    final subMode = prefs.getString('away_sub_mode');
    if (subMode != null) {
      setState(() {
        _awaySubMode = subMode;
      });
    }
  }

  Future<void> _saveAwaySubMode(String subMode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('away_sub_mode', subMode);
    setState(() {
      _awaySubMode = subMode;
    });
  }

  Future<void> _saveHomeLocation(LatLng location) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('home_lat', location.latitude);
    await prefs.setDouble('home_lng', location.longitude);
  }

  Future<void> _initLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() {
        _locationError = true;
      });
      debugPrint('[Modes] Location services are disabled.');
      return;
    }
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) {
        setState(() {
          _locationError = true;
        });
        debugPrint('[Modes] Location permission denied.');
        return;
      }
    }
    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen((Position position) {
      debugPrint(
        '[Modes] Location update: ${position.latitude}, ${position.longitude}',
      );
      final oldMode = _mode;
      setState(() {
        _currentPosition = position;
        _previousMode = _mode;
        _mode = _homeLocation != null ? _calculateMode(position) : '...';
        _locationError = false;
      });
      // Animate camera to user location
      if (mapController != null) {
        mapController!.animateCamera(
          CameraUpdate.newLatLng(LatLng(position.latitude, position.longitude)),
        );
      }
      if (oldMode != _mode) {
        _animationController.reset();
        _animationController.forward();
        if (_mode == "Away" && _previousMode != "Away") {
          Future.delayed(const Duration(milliseconds: 100), () {
            _showAwaySubModeSelector();
          });
        }
      }
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

  Color _getModeColor() {
    switch (_mode) {
      case "Home":
        return AppColors.primary;
      case "Away":
        return AppColors.secondary;
      default:
        return AppColors.textSecondary;
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

  Future<LatLng?> _getCoordinatesFromAddress(String address) async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        debugPrint("Permission refusée pour la géolocalisation.");
        return null;
      }
      debugPrint("Recherche de l'adresse : $address");
      List<Location> locations = await locationFromAddress(address);
      if (locations.isNotEmpty) {
        return LatLng(locations.first.latitude, locations.first.longitude);
      } else {
        debugPrint("Aucune localisation trouvée pour : $address");
      }
    } catch (e, stack) {
      debugPrint('Erreur de géocodage : $e');
      debugPrint('Stack: $stack');
    }
    return null;
  }

  void _showSearchDialog() {
    final TextEditingController _searchController = TextEditingController();
    bool _isSearching = false;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> _performSearch() async {
              final address = _searchController.text.trim();
              if (address.isEmpty) return;
              setDialogState(() {
                _isSearching = true;
              });
              final coordinates = await _getCoordinatesFromAddress(address);
              setDialogState(() {
                _isSearching = false;
              });
              if (coordinates != null) {
                Navigator.pop(context);
                setState(() {
                  _homeLocation = coordinates;
                  if (_currentPosition != null) {
                    _mode = _calculateMode(_currentPosition!);
                    _animationController.reset();
                    _animationController.forward();
                  }
                });
                await _saveHomeLocation(coordinates);
                mapController?.animateCamera(
                  CameraUpdate.newLatLngZoom(coordinates, 15),
                );
                if (_mode == "Away" && _previousMode != "Away") {
                  Future.delayed(const Duration(milliseconds: 100), () {
                    _showAwaySubModeSelector();
                  });
                }
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Adresse définie comme domicile'),
                    backgroundColor: AppColors.primary,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Adresse non trouvée. Veuillez réessayer.'),
                    backgroundColor: Colors.red,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            }

            return AlertDialog(
              title: const Text('Rechercher votre adresse'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      hintText: 'Entrez votre adresse',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _performSearch(),
                  ),
                  if (_isSearching)
                    const Padding(
                      padding: EdgeInsets.only(top: 16.0),
                      child: CircularProgressIndicator(),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Annuler'),
                ),
                TextButton(
                  onPressed: _isSearching ? null : _performSearch,
                  child: const Text('Rechercher'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showAwaySubModeSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  "You are...",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _awaySubModes.length,
                  itemBuilder: (context, index) {
                    final subMode = _awaySubModes[index];
                    final isSelected = _awaySubMode == subMode;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color:
                            isSelected
                                ? AppColors.secondary.withOpacity(0.1)
                                : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color:
                              isSelected
                                  ? AppColors.secondary
                                  : Colors.grey.withOpacity(0.2),
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color:
                                isSelected
                                    ? AppColors.secondary.withOpacity(0.2)
                                    : Colors.grey.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _getSubModeIcon(subMode),
                            color:
                                isSelected
                                    ? AppColors.secondary
                                    : Colors.grey[600],
                          ),
                        ),
                        title: Text(
                          subMode,
                          style: TextStyle(
                            fontWeight:
                                isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                            color:
                                isSelected
                                    ? AppColors.secondary
                                    : AppColors.textPrimary,
                          ),
                        ),
                        trailing:
                            isSelected
                                ? Icon(
                                  Icons.check_circle,
                                  color: AppColors.secondary,
                                )
                                : null,
                        onTap: () {
                          _saveAwaySubMode(subMode);
                          Navigator.pop(context);
                        },
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  IconData _getSubModeIcon(String subMode) {
    switch (subMode) {
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
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    LatLng? currentLatLng =
        _currentPosition != null
            ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
            : null;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        centerTitle: true,
        title: const Text(
          'Mode',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 20),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: _showSearchDialog,
            tooltip: 'Rechercher une adresse',
          ),
        ],
      ),
      body:
          _locationError
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.location_off, size: 48, color: Colors.red),
                    const SizedBox(height: 16),
                    const Text(
                      'Location unavailable. Please enable location services and permissions.',
                      style: TextStyle(color: Colors.red, fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () {
                        debugPrint(
                          '[Modes] Retry button pressed. Attempting to re-initialize location.',
                        );
                        setState(() {
                          _locationError = false;
                        });
                        _initLocation();
                      },
                    ),
                  ],
                ),
              )
              : Column(
                children: [
                  FadeTransition(
                    opacity: _animation,
                    child:
                        _homeLocation == null
                            ? _buildNoHomeCard()
                            : _buildModeStatusCard(),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 16.0, bottom: 8.0),
                    child: Align(
                      alignment: Alignment.topRight,
                      child: FloatingActionButton.small(
                        heroTag: "searchBtn",
                        onPressed: _showSearchDialog,
                        backgroundColor: Colors.white,
                        child: const Icon(
                          Icons.search,
                          color: AppColors.primary,
                        ),
                        tooltip: 'Rechercher une adresse',
                      ),
                    ),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(24),
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 8,
                              offset: const Offset(0, -2),
                            ),
                          ],
                        ),
                        child:
                            currentLatLng != null
                                ? GoogleMap(
                                  onMapCreated: (controller) {
                                    mapController = controller;
                                    mapController?.setMapStyle('''
                                [
                                  {
                                    "featureType": "all",
                                    "elementType": "labels.text.fill",
                                    "stylers": [
                                      {
                                        "saturation": 36
                                      },
                                      {
                                        "color": "#333333"
                                      },
                                      {
                                        "lightness": 40
                                      }
                                    ]
                                  }
                                ]
                                ''');
                                  },
                                  initialCameraPosition: CameraPosition(
                                    target: currentLatLng,
                                    zoom: 15,
                                  ),
                                  markers: {
                                    if (currentLatLng != null)
                                      Marker(
                                        markerId: const MarkerId('user'),
                                        position: currentLatLng,
                                        infoWindow: const InfoWindow(
                                          title: 'You are here',
                                        ),
                                        icon:
                                            _userIcon ??
                                            BitmapDescriptor.defaultMarkerWithHue(
                                              BitmapDescriptor.hueAzure,
                                            ),
                                      ),
                                    if (_homeLocation != null)
                                      Marker(
                                        markerId: const MarkerId('home'),
                                        position: _homeLocation!,
                                        infoWindow: const InfoWindow(
                                          title: 'Home',
                                        ),
                                        icon:
                                            BitmapDescriptor.defaultMarkerWithHue(
                                              BitmapDescriptor.hueGreen,
                                            ),
                                      ),
                                  },
                                  myLocationEnabled: true,
                                  myLocationButtonEnabled: true,
                                  onTap: (LatLng tappedLocation) async {
                                    final oldMode = _mode;
                                    setState(() {
                                      _homeLocation = tappedLocation;
                                      _previousMode = _mode;
                                      if (_currentPosition != null) {
                                        _mode = _calculateMode(
                                          _currentPosition!,
                                        );
                                        _animationController.reset();
                                        _animationController.forward();
                                      }
                                    });
                                    await _saveHomeLocation(tappedLocation);
                                    if (_mode == "Away" && oldMode != "Away") {
                                      Future.delayed(
                                        const Duration(milliseconds: 100),
                                        () {
                                          _showAwaySubModeSelector();
                                        },
                                      );
                                    }
                                  },
                                )
                                : Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const CircularProgressIndicator(
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              AppColors.primary,
                                            ),
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        "Loading map...",
                                        style: TextStyle(
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                      ),
                    ),
                  ),
                ],
              ),
      floatingActionButton:
          _homeLocation != null
              ? FloatingActionButton(
                heroTag: "homeBtn",
                onPressed: () {
                  mapController?.animateCamera(
                    CameraUpdate.newLatLng(_homeLocation!),
                  );
                },
                backgroundColor: AppColors.primary,
                child: const Icon(Icons.home),
              )
              : null,
    );
  }

  Widget _buildNoHomeCard() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Icon(Icons.home_outlined, size: 48, color: AppColors.primary),
          const SizedBox(height: 16),
          Text(
            "No home location set",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Tap on the map or use the search button to set your home location",
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildModeStatusCard() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _getModeColor().withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(_getModeIcon(), color: _getModeColor(), size: 36),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Current Status",
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      _mode,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: _getModeColor(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: _getModeColor(),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
                if (_mode == "Away")
                  GestureDetector(
                    onTap: _showAwaySubModeSelector,
                    child: Row(
                      children: [
                        Text(
                          _awaySubMode,
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.edit,
                          size: 14,
                          color: AppColors.textSecondary,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          if (_currentPosition != null && _homeLocation != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  "Distance",
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "${Geolocator.distanceBetween(_currentPosition!.latitude, _currentPosition!.longitude, _homeLocation!.latitude, _homeLocation!.longitude).toInt()} m",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (_mode == "Away")
                  TextButton(
                    onPressed: _showAwaySubModeSelector,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      backgroundColor: AppColors.secondary.withOpacity(0.1),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: Text(
                      "Change",
                      style: TextStyle(
                        color: AppColors.secondary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
