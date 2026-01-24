
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';


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

class _MapScreenState extends State<MapScreen> with SingleTickerProviderStateMixin {
  Position? _position;
  String? _error;
  Stream<Position>? _positionStream;
  late final MapController _mapController;

  List<LatLng> _locations = [];

  void reportLocation() {
    if (_position == null) return;
    setState(() {
      _locations.add(LatLng(_position!.latitude, _position!.longitude));
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Location reported!')),
    );
  }

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _determinePosition();
    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.bestForNavigation),
    );
    _positionStream!.listen((Position pos) {
      setState(() {
        _position = pos;
      });
      // Optionally move the map to the new position automatically:
      _mapController.move(LatLng(pos.latitude, pos.longitude), _mapController.camera.zoom);
    });
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

  bool _menuOpen = false;
  late final AnimationController _menuController;
  late final Animation<Offset> _menuOffset;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Animation setup
    _menuController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _menuOffset = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _menuController,
      curve: Curves.easeOutCubic,
    ));
  }

  void _showMenu() {
    setState(() {
      _menuOpen = true;
    });
    _menuController.forward();
  }

  void _closeMenu() {
    _menuController.reverse().then((_) {
      if (mounted) {
        setState(() {
          _menuOpen = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _menuController.dispose();
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
    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: LatLng(_position!.latitude, _position!.longitude),
            initialZoom: 15.0,
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
                Marker(
                  width: 24.0,
                  height: 24.0,
                  point: LatLng(_position!.latitude, _position!.longitude),
                  child: Container(
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
                ),
              ],
            ),
          ],
        ),
        // Shop, Menu, and Profile buttons centered at bottom
        if (!_menuOpen)
          Positioned(
            left: 0,
            right: 0,
            bottom: 32,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Shop button (left, normal size)
                SizedBox(
                  width: 56,
                  height: 56,
                  child: FloatingActionButton(
                    heroTag: 'shop',
                    onPressed: () {
                      // TODO: Switch to shop tab
                    },
                    backgroundColor: Colors.white,
                    shape: const CircleBorder(),
                    child: const Icon(Icons.store, size: 32, color: Colors.green),
                    elevation: 6,
                  ),
                ),
                const SizedBox(width: 32),
                // Menu button (center, bigger, dual-purpose with color and icon change)
                Builder(
                  builder: (context) {
                    bool nearTrashcan = false;
                    if (_position != null && _locations.isNotEmpty) {
                      final user = LatLng(_position!.latitude, _position!.longitude);
                      for (final loc in _locations) {
                        final dist = Distance().as(LengthUnit.Meter, user, loc);
                        if (dist < 30) {
                          nearTrashcan = true;
                          break;
                        }
                      }
                    }
                    Color buttonColor = nearTrashcan ? Colors.red : Colors.yellow[700]!;
                    Icon buttonIcon = nearTrashcan
                        ? const Icon(Icons.help_outline, color: Colors.white, size: 48) // question mark
                        : const Icon(Icons.priority_high, color: Colors.white, size: 48); // exclamation mark
                    return SizedBox(
                      width: 72,
                      height: 72,
                      child: FloatingActionButton(
                        heroTag: 'menu',
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
                              if (nearestIdx != null && minDist < 30) {
                                setState(() {
                                  _locations.removeAt(nearestIdx!);
                                });
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Trashcan marker removed.')),
                                );
                              }
                            }
                          } else {
                            reportLocation();
                          }
                        },
                        backgroundColor: buttonColor,
                        shape: const CircleBorder(),
                        child: buttonIcon,
                        elevation: 8,
                      ),
                    );
                  },
                ),
                const SizedBox(width: 32),
                // Profile button (right, normal size, opens menu)
                SizedBox(
                  width: 56,
                  height: 56,
                  child: FloatingActionButton(
                    heroTag: 'profile',
                    onPressed: _showMenu,
                    backgroundColor: Colors.white,
                    shape: const CircleBorder(),
                    child: const Icon(Icons.person, size: 32, color: Colors.blue),
                    elevation: 6,
                  ),
                ),
              ],
            ),
          ),
        // Custom pull-up menu overlay
        if (_menuOpen)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            top: MediaQuery.of(context).size.height * 0.2, // 80% height
            child: SlideTransition(
              position: _menuOffset,
              child: GestureDetector(
                onVerticalDragUpdate: (details) {
                  if (details.primaryDelta != null && details.primaryDelta! > 10) {
                    _closeMenu();
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
                      const Text(
                        'Custom Menu',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      // Menu content: Large action buttons
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: double.infinity,
                                height: 80,
                                child: Builder(
                                  builder: (context) {
                                    // Check if user is near a trashcan (within 30 meters)
                                    bool nearTrashcan = false;
                                    if (_position != null && _locations.isNotEmpty) {
                                      final user = LatLng(_position!.latitude, _position!.longitude);
                                      for (final loc in _locations) {
                                        final dist = Distance().as(LengthUnit.Meter, user, loc);
                                        if (dist < 30) {
                                          nearTrashcan = true;
                                          break;
                                        }
                                      }
                                    }
                                    return ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: nearTrashcan ? Colors.red : Colors.blue,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                      ),
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
                                            if (nearestIdx != null && minDist < 30) {
                                              setState(() {
                                                _locations.removeAt(nearestIdx!);
                                              });
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(content: Text('Trashcan marker removed.')),
                                              );
                                            }
                                          }
                                        } else {
                                          reportLocation();
                                        }
                                      },
                                      child: Text(
                                        nearTrashcan ? 'Missing Trashcan' : 'Submit New Trashcan',
                                        style: const TextStyle(fontSize: 28, color: Colors.white, fontWeight: FontWeight.bold),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // X button (center, inside menu)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 32.0, top: 8.0),
                        child: GestureDetector(
                          onTap: _closeMenu,
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
