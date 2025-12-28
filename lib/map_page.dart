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

  // Default Location
  LatLng _center = const LatLng(18.5204, 73.8567);
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

  // --- 1. GET ACCURATE GPS LOCATION ---
  Future<void> _getCurrentLocation() async {
    setState(() => _isLoadingGPS = true);

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) setState(() => _isLoadingGPS = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location services are disabled.')));
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) setState(() => _isLoadingGPS = false);
        return;
      }
    }

    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (mounted) {
        setState(() => _isLoadingGPS = false);
        _moveToLocation(position.latitude, position.longitude);
      }
    } catch (e) {
      debugPrint("GPS Error: $e");
      if (mounted) setState(() => _isLoadingGPS = false);
    }
  }

  // --- 2. MOVE MAP & UPDATE ADDRESS ---
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

  // --- 3. REVERSE GEOCODING (Get Address) ---
  Future<void> _getAddress(double lat, double lng) async {
    if(mounted) setState(() => _addressController.text = "Fetching precise address...");

    final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lng&zoom=18&addressdetails=1');

    try {
      final response = await http.get(url, headers: {'User-Agent': 'com.example.app'});

      if (response.statusCode == 200 && mounted) {
        final data = json.decode(response.body);
        final addr = data['address'];
        String preciseAddress;

        if (addr != null) {
          List<String> parts = [];
          if (addr['house_number'] != null) parts.add(addr['house_number']);
          if (addr['road'] != null) parts.add(addr['road']);
          if (addr['suburb'] != null) parts.add(addr['suburb']);
          if (addr['city'] != null) parts.add(addr['city']);
          if (addr['postcode'] != null) parts.add(addr['postcode']);

          preciseAddress = parts.isNotEmpty
              ? parts.toSet().join(', ')
              : data['display_name'] ?? "Unknown Location";
        } else {
          preciseAddress = data['display_name'] ?? "Unknown Location";
        }
        if(mounted) setState(() => _addressController.text = preciseAddress);
      } else {
        if(mounted) setState(() => _addressController.text = "Could not fetch address");
      }
    } catch (e) {
      if (mounted) setState(() => _addressController.text = "Network Error");
    }
  }

  // --- 4. SEARCH FUNCTION ---
  Future<void> _searchPlaces(String query) async {
    if (query.isEmpty) {
      if (mounted) setState(() => _searchResults = []);
      return;
    }
    final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=$query&format=json&limit=5&addressdetails=1');
    try {
      final response = await http.get(url, headers: {'User-Agent': 'com.example.app'});
      if (response.statusCode == 200 && mounted) {
        setState(() => _searchResults = json.decode(response.body));
      }
    } catch (e) { debugPrint(e.toString()); }
  }

  // --- FIXED: Updated to use MapCamera for flutter_map v6+ ---
  void _onMapPositionChanged(MapCamera camera, bool hasGesture) {
    if (hasGesture) {
      setState(() {
        _isMoving = true;
        _addressController.text = "Locating...";
      });
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 1000), () {
        if (mounted) {
          setState(() => _isMoving = false);
          _center = camera.center; // 'center' is now a property of 'camera'
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
          // MAP LAYER
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _center, // FIXED: Changed 'center' to 'initialCenter'
              initialZoom: 17.0,      // FIXED: Changed 'zoom' to 'initialZoom'
              onPositionChanged: _onMapPositionChanged,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
                subdomains: const ['a', 'b', 'c'],
                userAgentPackageName: 'com.example.app',
              ),
            ],
          ),

          // CENTER PIN (Fixed)
          Center(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)]
                    ),
                    child: Text(_isMoving ? "..." : "Exact Spot",
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 5),
                  const Icon(Icons.location_on, size: 50, color: Colors.redAccent),
                ],
              ),
            ),
          ),

          // MY LOCATION BUTTON (Bottom Right)
          Positioned(
            bottom: 240, right: 20,
            child: FloatingActionButton(
              backgroundColor: Colors.white,
              onPressed: _isLoadingGPS ? null : _getCurrentLocation,
              child: _isLoadingGPS
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.my_location, color: Colors.black),
            ),
          ),

          // SEARCH BAR (Top)
          Positioned(
            top: 50, left: 20, right: 20,
            child: Column(
              children: [
                Card(
                  elevation: 5,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: "Search precise location...",
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(icon: const Icon(Icons.close), onPressed: () {
                        _searchController.clear();
                        setState(() => _searchResults = []);
                      }) : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.all(15),
                    ),
                    onChanged: (val) {
                      _debounce?.cancel();
                      _debounce = Timer(const Duration(milliseconds: 500), () => _searchPlaces(val));
                    },
                  ),
                ),
                if (_searchResults.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 5),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 5)]),
                    constraints: const BoxConstraints(maxHeight: 180),
                    child: ListView.separated(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      itemCount: _searchResults.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (ctx, i) {
                        final place = _searchResults[i];
                        return ListTile(
                          title: Text(place['display_name'].split(',')[0], style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(place['display_name'], maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                          onTap: () {
                            final lat = double.tryParse(place['lat']);
                            final lon = double.tryParse(place['lon']);
                            if (lat != null && lon != null) _moveToLocation(lat, lon);
                          },
                        );
                      },
                    ),
                  )
              ],
            ),
          ),

          // BOTTOM SHEET (Address Display)
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
              decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, -5))]
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("SELECTED LOCATION", style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _addressController,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.all(12),
                      border: OutlineInputBorder(),
                      hintText: 'Add address details or suite number',
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _isMoving || _isLoadingGPS ? null : () {
                      Navigator.pop(context, {
                        'address': _addressController.text,
                        'lat': _center.latitude,
                        'lng': _center.longitude,
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text("Confirm Location", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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