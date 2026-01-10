import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';

class MapPickerPage extends StatefulWidget {
  const MapPickerPage({super.key});

  @override
  State<MapPickerPage> createState() => _MapPickerPageState();
}

class _MapPickerPageState extends State<MapPickerPage> {
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();

  LatLng _center = const LatLng(18.5204, 73.8567); // Default: Pune
  bool _isMoving = false;
  bool _isLoadingGPS = false;
  List<dynamic> _searchResults = [];
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _addressController.dispose();
    _debounce?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  // --- IMPROVED: Get Current Location with timeout & fallback ---
  Future<void> _getCurrentLocation() async {
    if (_isLoadingGPS) return;

    setState(() => _isLoadingGPS = true);

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        setState(() => _isLoadingGPS = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enable location services in settings.')),
        );
      }
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() => _isLoadingGPS = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permission is required.')),
          );
        }
        return;
      }
    }

    try {
      // Try high-precision fix with reasonable timeout
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
        timeLimit: const Duration(seconds: 20),
      );

      if (mounted) {
        setState(() => _isLoadingGPS = false);
        _moveToLocation(position.latitude, position.longitude);
      }
    } catch (e) {
      debugPrint('High-precision location failed: $e');

      // Fallback: Use last known position (fast but may be older)
      Position? lastPosition = await Geolocator.getLastKnownPosition();
      if (lastPosition != null && mounted) {
        setState(() => _isLoadingGPS = false);
        _moveToLocation(lastPosition.latitude, lastPosition.longitude);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Using last known location. For precise GPS, go outdoors and try again.',
            ),
            duration: Duration(seconds: 4),
          ),
        );
      } else {
        if (mounted) {
          setState(() => _isLoadingGPS = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Unable to get location. Please try again outdoors.')),
          );
        }
      }
    }
  }

  // --- Move map to new coordinates & fetch address ---
  void _moveToLocation(double lat, double lng) {
    _center = LatLng(lat, lng);
    _mapController.move(_center, 17.0);
    _getAddress(lat, lng);

    if (mounted) {
      setState(() {
        _searchResults = [];
        _searchController.clear();
        FocusScope.of(context).unfocus();
      });
    }
  }

  // --- Reverse Geocoding: Get human-readable address ---
  Future<void> _getAddress(double lat, double lng) async {
    if (!mounted) return;
    setState(() => _addressController.text = "Fetching address...");

    final url = Uri.parse(
      'https://nominatim.openstreetmap.org/reverse?'
          'format=json&lat=$lat&lon=$lng&zoom=18&addressdetails=1',
    );

    try {
      final response = await http.get(
        url,
        headers: {'User-Agent': 'com.example.myapp/1.0 (your.email@example.com)'},
      );

      if (response.statusCode == 200 && mounted) {
        final data = json.decode(response.body);
        final addr = data['address'];

        String address;
        if (addr != null) {
          List<String> parts = [];
          if (addr['house_number'] != null) parts.add(addr['house_number']);
          if (addr['road'] != null) parts.add(addr['road']);
          if (addr['neighbourhood'] != null) parts.add(addr['neighbourhood']);
          if (addr['suburb'] != null) parts.add(addr['suburb']);
          if (addr['city'] ?? addr['town'] ?? addr['village'] != null) {
            parts.add(addr['city'] ?? addr['town'] ?? addr['village']);
          }
          if (addr['postcode'] != null) parts.add(addr['postcode']);

          address = parts.isNotEmpty ? parts.join(', ') : data['display_name'];
        } else {
          address = data['display_name'] ?? 'Unknown location';
        }

        if (mounted) setState(() => _addressController.text = address);
      } else {
        if (mounted) setState(() => _addressController.text = 'Failed to fetch address');
      }
    } catch (e) {
      if (mounted) setState(() => _addressController.text = 'Network error');
    }
  }

  // --- Search places using Nominatim ---
  Future<void> _searchPlaces(String query) async {
    if (query.trim().isEmpty) {
      if (mounted) setState(() => _searchResults = []);
      return;
    }

    final url = Uri.parse(
      'https://nominatim.openstreetmap.org/search?'
          'q=${Uri.encodeComponent(query)}&format=json&limit=6&addressdetails=1',
    );

    try {
      final response = await http.get(
        url,
        headers: {'User-Agent': 'com.example.myapp/1.0 (your.email@example.com)'},
      );

      if (response.statusCode == 200 && mounted) {
        final results = json.decode(response.body) as List<dynamic>;
        setState(() => _searchResults = results);
      }
    } catch (e) {
      debugPrint('Search error: $e');
    }
  }

  // --- Debounced address update when user drags the map ---
  void _onMapPositionChanged(MapCamera camera, bool hasGesture) {
    if (hasGesture) {
      setState(() {
        _isMoving = true;
        _addressController.text = "Locating...";
      });

      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 800), () {
        if (mounted) {
          setState(() => _isMoving = false);
          _center = camera.center;
          _getAddress(_center.latitude, _center.longitude);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // Map
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _center,
              initialZoom: 17.0,
              onPositionChanged: _onMapPositionChanged,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate:
                'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
                userAgentPackageName: 'com.example.myapp',
              ),
            ],
          ),

          // Center Pin
          Center(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 40.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const [
                        BoxShadow(color: Colors.black38, blurRadius: 6),
                      ],
                    ),
                    child: Text(
                      _isMoving ? "Move to pin..." : "Exact spot",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Icon(Icons.location_on, size: 48, color: Colors.redAccent),
                ],
              ),
            ),
          ),

          // My Location Button
          Positioned(
            bottom: 240,
            right: 16,
            child: FloatingActionButton(
              backgroundColor: Colors.white,
              elevation: 6,
              onPressed: _isLoadingGPS ? null : _getCurrentLocation,
              child: _isLoadingGPS
                  ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              )
                  : const Icon(Icons.my_location, color: Colors.black87),
            ),
          ),

          // Search Bar
          Positioned(
            top: 50,
            left: 16,
            right: 16,
            child: Column(
              children: [
                Card(
                  elevation: 8,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search for a location...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          if (mounted) setState(() => _searchResults = []);
                        },
                      )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                    onChanged: (value) {
                      _debounce?.cancel();
                      _debounce = Timer(const Duration(milliseconds: 600), () => _searchPlaces(value));
                    },
                  ),
                ),
                if (_searchResults.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: const [
                        BoxShadow(color: Colors.black26, blurRadius: 8),
                      ],
                    ),
                    constraints: const BoxConstraints(maxHeight: 200),
                    child: ListView.separated(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      itemCount: _searchResults.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final place = _searchResults[index];
                        final displayName = place['display_name'] ?? 'Unknown';
                        final mainText = displayName.split(',').first.trim();

                        return ListTile(
                          title: Text(mainText, style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text(
                            displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12),
                          ),
                          onTap: () {
                            final lat = double.tryParse(place['lat'] ?? '');
                            final lon = double.tryParse(place['lon'] ?? '');
                            if (lat != null && lon != null) {
                              _moveToLocation(lat, lon);
                            }
                          },
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),

          // Bottom Address & Confirm Panel
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(color: Colors.black26, blurRadius: 12, offset: Offset(0, -6)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'SELECTED LOCATION',
                    style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _addressController,
                    minLines: 1,
                    maxLines: 3,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.all(14),
                      border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                      hintText: 'Add flat/suite number or additional details',
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: (_isMoving || _isLoadingGPS)
                          ? null
                          : () {
                        Navigator.pop(context, {
                          'address': _addressController.text.trim(),
                          'lat': _center.latitude,
                          'lng': _center.longitude,
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 4,
                      ),
                      child: const Text(
                        'Confirm Location',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}