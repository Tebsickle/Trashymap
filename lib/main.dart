
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'package:geolocator/geolocator.dart';
import 'dart:math' as math;
import 'package:trashymap/cone_painter.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';


void main() {
  runApp(const MapApp());
}

class MapApp extends StatelessWidget {
  const MapApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.transparent,
      ),
      home: const MapScreen(),
    );
  }
}

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with TickerProviderStateMixin {
      // Shop overlay state and animation
      bool _shopOpen = false;
      late final AnimationController _shopController;
      late final Animation<Offset> _shopOffset;

      void _showShop() {
        setState(() {
          _shopOpen = true;
        });
        _shopController.forward();
      }

      void _closeShop() {
        _shopController.reverse().then((_) {
          if (mounted) {
            setState(() {
              _shopOpen = false;
            });
          }
        });
      }
    double? _heading;
  Position? _position;
  String? _error;
  StreamSubscription<Position>? _positionSubscription;
  late final MapController _mapController;

  final List<LatLng> _locations = [];

  Future<void> _saveLocations() async {
    final prefs = await SharedPreferences.getInstance();
    final locStrings = _locations.map((loc) => '${loc.latitude},${loc.longitude}').toList();
    await prefs.setStringList('locations', locStrings);
  }

  Future<void> _loadLocations() async {
    final prefs = await SharedPreferences.getInstance();
    final locStrings = prefs.getStringList('locations') ?? [];
    setState(() {
      _locations.clear();
      _locations.addAll(locStrings.map((str) {
        final parts = str.split(',');
        return LatLng(double.parse(parts[0]), double.parse(parts[1]));
      }));
    });
  }

  void reportLocation() {
    if (_position == null) return;
    setState(() {
      _locations.add(LatLng(_position!.latitude, _position!.longitude));
    });
    _saveLocations();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Location reported!')),
    );
  }


  Future<void> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() {
        _error = 'Location services are disabled.';
      });
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() {
          _error = 'Location permissions are denied.';
        });
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      setState(() {
        _error = 'Location permissions are permanently denied.';
      });
      return;
    }

    try {
      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.bestForNavigation);
      setState(() {
        _position = pos;
        _error = null;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to get location: $e';
      });
    }
  }

  bool _profileOpen = false;
  late final AnimationController _profileController;
  late final Animation<Offset> _profileOffset;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _loadLocations();
    _determinePosition();
    // Remove position stream, use polling instead
    Position? lastPosition;
    Timer.periodic(const Duration(seconds: 1), (timer) async {
      try {
        final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.bestForNavigation);
        if (lastPosition == null ||
          (pos.latitude != lastPosition?.latitude ||
           pos.longitude != lastPosition?.longitude)) {
          print('Polled new position: ${pos.latitude}, ${pos.longitude}');
          setState(() {
            _position = pos;
          });
          _mapController.move(LatLng(pos.latitude, pos.longitude), _mapController.camera.zoom);
          lastPosition = pos;
        }
      } catch (e) {
        print('Polling position error: $e');
      }
    });

    // Debug: print current _position every second
    Timer.periodic(const Duration(seconds: 1), (timer) {
      print('_position is: ${_position?.latitude}, ${_position?.longitude}');
    });

    // Animation setup
    _profileController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _profileOffset = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _profileController,
      curve: Curves.easeOutCubic,
    ));

    _shopController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _shopOffset = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _shopController,
      curve: Curves.easeOutCubic,
    ));

    // Listen to compass heading
    FlutterCompass.events?.listen((event) {
      setState(() {
        _heading = event.heading;
      });
    });
  }

  void _showProfile() {
    setState(() {
      _profileOpen = true;
    });
    _profileController.forward();
  }

  void _closeProfile() {
    _profileController.reverse().then((_) {
      if (mounted) {
        setState(() {
          _profileOpen = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _profileController.dispose();
    _shopController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(child: Text(_error!));
    }
    if (_position == null) {
      return const Center(child: CircularProgressIndicator());
    }
    // Get map rotation angle in radians
    double mapRotation = 0.0;
    try {
      mapRotation = -1 * _mapController.camera.rotation * (math.pi / 180);
    } catch (_) {
      mapRotation = 0.0;
    }
    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: LatLng(_position!.latitude, _position!.longitude),
            initialZoom: 18.0,
            maxZoom: 20,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all,
            ),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
              subdomains: const ['a', 'b', 'c'],
            ),
            // Trashcan markers (layered below user marker)
            MarkerLayer(
              markers: [
                ..._locations.map((loc) => Marker(
                  width: 36.0,
                  height: 36.0,
                  point: loc,
                  child: Icon(
                    Icons.location_on,
                    color: Colors.red,
                    size: 36.0,
                  ),
                )),
              ],
            ),
            // User's current location (always on top)
            MarkerLayer(
              markers: [
                if (_position != null)
                  Marker(
                    width: 48.0,
                    height: 48.0,
                    point: LatLng(_position!.latitude, _position!.longitude),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Cone of visibility (larger, more visible)
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: Transform.rotate(
                            angle: ((_heading ?? 0) * (math.pi / 180) + (1.4 * math.pi)),
                            child: CustomPaint(
                              size: const Size(48, 80),
                              painter: ConePainter(
                                startColor: const Color(0xCC1976D2),
                                endColor: const Color(0x001976D2),
                              ),
                            ),
                          ),
                        ),
                        // User pin
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: Colors.blue,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.blue.withOpacity(0.5),
                                blurRadius: 6,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: Center(
                            child: Container(
                              width: 10,
                              height: 10,
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
        // Compass in top right (rotates with map, not device)
        Positioned(
          top: 32,
          right: 24,
          child: IgnorePointer(
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.10),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Transform.rotate(
                angle: -mapRotation,
                child: Image.asset(
                  'compass_needle.png',
                  width: 40,
                  height: 40,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
        ),
        // Pill-shaped segmented control at bottom
        if (!_profileOpen && !_shopOpen)
          Positioned(
            left: 0,
            right: 0,
            bottom: 24,
            child: Builder(
              builder: (context) {
                bool nearTrashcan = false;
                if (_position != null && _locations.isNotEmpty) {
                  final user = LatLng(_position!.latitude, _position!.longitude);
                  for (final loc in _locations) {
                    final dist = Distance().as(LengthUnit.Meter, user, loc);
                    if (dist < 3) { // even smaller threshold
                      nearTrashcan = true;
                      break;
                    }
                  }
                }
                Color centerColor = nearTrashcan ? Colors.red : Colors.yellow[700]!;
                Icon centerIcon = nearTrashcan
                    ? const Icon(Icons.help_outline, color: Colors.white, size: 48)
                    : const Icon(Icons.priority_high, color: Colors.white, size: 48);
                return Center(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(56),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.10),
                          blurRadius: 18,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Shop segment
                        IconButton(
                          icon: const Icon(Icons.store, color: Colors.green, size: 36),
                          splashRadius: 36,
                          iconSize: 36,
                          onPressed: _showShop,
                        ),
                        // Center segment (dual-purpose)
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            color: centerColor,
                            borderRadius: BorderRadius.circular(40),
                          ),
                          child: IconButton(
                            icon: centerIcon,
                            splashRadius: 44,
                            iconSize: 48,
                            onPressed: () {
                              if (nearTrashcan) {
                                // Remove the nearest trashcan marker
                                if (_position != null && _locations.isNotEmpty) {
                                  final user = LatLng(_position!.latitude, _position!.longitude);
                                  int? nearestIdx;
                                  double minDist = double.infinity;
                                  for (int i = 0; i < _locations.length; i++) {
                                    final dist = Distance().as(LengthUnit.Meter, user, _locations[i]);
                                    if (dist < minDist) {
                                      minDist = dist;
                                      nearestIdx = i;
                                    }
                                  }
                                  if (nearestIdx != null && minDist < 3) { // even smaller threshold
                                    setState(() {
                                      _locations.removeAt(nearestIdx!);
                                    });
                                    _saveLocations();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Trashcan marker removed.')),
                                    );
                                  }
                                }
                              } else {
                                reportLocation();
                              }
                            },
                          ),
                        ),
                        // Profile segment
                        IconButton(
                          icon: const Icon(Icons.person, color: Colors.blue, size: 36),
                          splashRadius: 36,
                          iconSize: 36,
                          onPressed: _showProfile,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

        // Shop pull-up menu overlay (always at top level in Stack)
        if (_shopOpen)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            top: MediaQuery.of(context).size.height * 0.2, // 80% height
            child: SlideTransition(
              position: _shopOffset,
              child: GestureDetector(
                onVerticalDragUpdate: (details) {
                  if (details.primaryDelta != null && details.primaryDelta! > 10) {
                    _closeShop();
                  }
                },
                child: Material(
                  color: Colors.white,
                  elevation: 12,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  child: Column(
                    children: [
                      const SizedBox(height: 24),
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Shop menu content (placeholder)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Column(
                                children: [
                                  const SizedBox(height: 8),
                                  Center(
                                    child: Icon(Icons.store, size: 48, color: Colors.green),
                                  ),
                                  const SizedBox(height: 12),
                                  const Center(
                                    child: Text(
                                      'Shop',
                                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  const Divider(thickness: 1.5),
                                  const SizedBox(height: 24),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
                                    child: Center(
                                      child: Text(
                                        'Shop content goes here!',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey,
                                          fontWeight: FontWeight.w400,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      // X button (center, inside menu)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 32.0, top: 8.0),
                        child: GestureDetector(
                          onTap: _closeShop,
                          child: Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                            child: const Center(
                              child: Icon(Icons.close, size: 40, color: Colors.black),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        // Custom pull-up menu overlay
        if (_profileOpen)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            top: MediaQuery.of(context).size.height * 0.2, // 80% height
            child: SlideTransition(
              position: _profileOffset,
              child: GestureDetector(
                onVerticalDragUpdate: (details) {
                  if (details.primaryDelta != null && details.primaryDelta! > 10) {
                    _closeProfile();
                  }
                },
                child: Material(
                  color: Colors.white,
                  elevation: 12,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  child: Column(
                    children: [
                      const SizedBox(height: 24),
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 24),
                      // ...existing code...
                      // Profile menu content
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Column(
                                children: [
                                  const SizedBox(height: 8),
                                  Center(
                                    child: CircleAvatar(
                                      radius: 40,
                                      backgroundColor: Colors.blueAccent,
                                      child: const Icon(Icons.person, size: 48, color: Colors.white),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  const Center(
                                    child: Text(
                                      '@UserName',
                                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  const Divider(thickness: 1.5),
                                  const SizedBox(height: 24),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
                                    child: Center(
                                      child: Text(
                                        'You have nothing in your wardrobe yet!',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey[500],
                                          fontWeight: FontWeight.w400,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      // X button (center, inside menu)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 32.0, top: 8.0),
                        child: GestureDetector(
                          onTap: _closeProfile,
                          child: Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                            child: const Center(
                              child: Icon(Icons.close, size: 40, color: Colors.black),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
