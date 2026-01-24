
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

class _MapScreenState extends State<MapScreen> {
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

  void _showMenu() {
    setState(() {
      _menuOpen = true;
    });
  }

  void _closeMenu() {
    setState(() {
      _menuOpen = false;
    });
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
            MarkerLayer(
              markers: [
                // User's current location (smaller marker)
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
                // Locally reported markers (trashcans, larger)
                ..._locations.map((loc) => Marker(
                  width: 36.0,
                  height: 36.0,
                  point: loc,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red.withOpacity(0.5),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                )),
              ],
            ),
          ],
        ),
        // Menu button
        if (!_menuOpen)
          Positioned(
            left: 0,
            right: 0,
            bottom: 32,
            child: Center(
              child: SizedBox(
                width: 64,
                height: 64,
                child: FloatingActionButton(
                  onPressed: _showMenu,
                  backgroundColor: Colors.white,
                  shape: const CircleBorder(),
                  child: const Icon(Icons.menu, color: Colors.black, size: 40),
                  elevation: 6,
                ),
              ),
            ),
          ),
        // Custom pull-up menu overlay
        if (_menuOpen)
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
            left: 0,
            right: 0,
            bottom: 0,
            top: MediaQuery.of(context).size.height * 0.2, // 80% height
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
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                ),
                                onPressed: () {
                                  reportLocation();
                                },
                                child: const Text(
                                  'Report missing trashcan',
                                  style: TextStyle(fontSize: 28, color: Colors.white, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                            const SizedBox(height: 32),
                            SizedBox(
                              width: double.infinity,
                              height: 80,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                ),
                                onPressed: () async {
                                  // Optionally, you could implement a delete or flag endpoint
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Feature not implemented.')),
                                  );
                                },
                                child: const Text(
                                  'Trashcan not here',
                                  style: TextStyle(fontSize: 28, color: Colors.white, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Shop, X, and Profile buttons row
                    Padding(
                      padding: const EdgeInsets.only(bottom: 32.0, top: 8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Shop button (left)
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(height: 8), // Add top padding to lower the button
                              GestureDetector(
                                onTap: () {
                                  // TODO: Switch to shop tab
                                },
                                child: Container(
                                  width: 56,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    color: Colors.green[100],
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.store, size: 32, color: Colors.green),
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text('Shop', style: TextStyle(fontSize: 14)),
                            ],
                          ),
                          const SizedBox(width: 32),
                          // X button (center)
                          GestureDetector(
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
                          const SizedBox(width: 32),
                          // Profile button (right)
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(height: 8), // Add top padding to lower the button
                              GestureDetector(
                                onTap: () {
                                  // TODO: Switch to profile tab
                                },
                                child: Container(
                                  width: 56,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    color: Colors.blue[100],
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.person, size: 32, color: Colors.blue),
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text('Profile', style: TextStyle(fontSize: 14)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
