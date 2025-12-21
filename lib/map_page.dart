import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;

class MapPickerPage extends StatefulWidget {
  const MapPickerPage({super.key});

  @override
  State<MapPickerPage> createState() => _MapPickerPageState();
}

class _MapPickerPageState extends State<MapPickerPage> {
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();

  // Default Location: Pune, India
  LatLng _center = const LatLng(18.5204, 73.8567);
  String _address = "Fetching location...";
  bool _isMoving = false;
  List<dynamic> _searchResults = [];
  Timer? _debounce;

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  // 1. FREE SEARCH (Nominatim)
  Future<void> _searchPlaces(String query) async {
    if (query.isEmpty) {
      if (mounted) setState(() => _searchResults = []);
      return;
    }

    final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=$query&format=json&limit=5&addressdetails=1');

    try {
      final response = await http.get(url, headers: {'User-Agent': 'com.example.barberapp'});

      if (response.statusCode == 200 && mounted) {
        setState(() => _searchResults = json.decode(response.body));
      }
    } catch (e) {
      debugPrint("Search error: $e");
    }
  }

  // 2. MOVE MAP TO SEARCH RESULT
  void _moveToLocation(double lat, double lng) {
    _mapController.move(LatLng(lat, lng), 16.0);

    if (mounted) {
      setState(() {
        _searchResults = [];
        _searchController.clear();
        FocusScope.of(context).unfocus();
      });
    }
  }

  // 3. GET ADDRESS (Reverse Geocoding)
  Future<void> _getAddress(double lat, double lng) async {
    final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lng&zoom=18&addressdetails=1');

    try {
      final response = await http.get(url, headers: {'User-Agent': 'com.example.barberapp'});
      if (response.statusCode == 200 && mounted) {
        final data = json.decode(response.body);
        final addr = data['address'];
        String cleanAddr = data['display_name'] ?? "Unknown Location";

        if (addr != null) {
          // Create a shorter, cleaner address string
          cleanAddr = [
            addr['road'],
            addr['suburb'],
            addr['city'],
            addr['postcode']
          ].where((s) => s != null && s.isNotEmpty).toSet().join(', ');
        }

        if (mounted) {
          setState(() => _address = cleanAddr.isEmpty ? "Unknown Location" : cleanAddr);
        }
      }
    } catch (e) {
      if (mounted) setState(() => _address = "Network Error");
    }
  }

  // MAP EVENT: When drag stops
  void _onMapPositionChanged(MapPosition position, bool hasGesture) {
    if (hasGesture) {
      setState(() {
        _isMoving = true;
        _address = "Locating...";
      });

      if (_debounce?.isActive ?? false) _debounce!.cancel();
      _debounce = Timer(const Duration(milliseconds: 800), () {
        if (mounted && position.center != null) {
          setState(() => _isMoving = false);
          _center = position.center!;
          _getAddress(_center.latitude, _center.longitude);
        }
      });
    }
  }

  @override
  void initState() {
    super.initState();
    // Initial fetch
    _getAddress(_center.latitude, _center.longitude);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // --- FREE OPENSTREETMAP ---
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              center: _center,
              zoom: 15.0,
              onPositionChanged: _onMapPositionChanged,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate, // Keep map straight
              ),
            ),
            children: [
              // Stylish Dark Mode Tiles (Free)
              TileLayer(
                urlTemplate: 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png',
                subdomains: const ['a', 'b', 'c'],
                userAgentPackageName: 'com.example.barberapp',
              ),
            ],
          ),

          // --- CENTER PIN ---
          Center(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(10)),
                    child: Text(_isMoving ? "Locating..." : "Pick Here",
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 5),
                  const Icon(Icons.location_on, size: 50, color: Colors.orange),
                ],
              ),
            ),
          ),

          // --- SEARCH BAR ---
          Positioned(
            top: 60, left: 20, right: 20,
            child: Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 10)],
                  ),
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(color: Colors.white),
                    onChanged: (val) {
                      _debounce?.cancel();
                      _debounce = Timer(const Duration(milliseconds: 800), () => _searchPlaces(val));
                    },
                    decoration: InputDecoration(
                      hintText: "Search location...",
                      hintStyle: const TextStyle(color: Colors.white38),
                      prefixIcon: const Icon(Icons.search, color: Colors.orange),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () {
                        _searchController.clear();
                        if (mounted) setState(() => _searchResults = []);
                      })
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.all(15),
                    ),
                  ),
                ),
                if (_searchResults.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 5),
                    decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(15)),
                    constraints: const BoxConstraints(maxHeight: 200),
                    child: ListView.separated(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      itemCount: _searchResults.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, color: Colors.white10),
                      itemBuilder: (ctx, i) {
                        final place = _searchResults[i];
                        return ListTile(
                          title: Text(place['display_name']?.split(',')[0] ?? 'Unknown', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          subtitle: Text(place['display_name'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                          onTap: () {
                            final lat = double.tryParse(place['lat']?.toString() ?? '');
                            final lon = double.tryParse(place['lon']?.toString() ?? '');
                            if (lat != null && lon != null) {
                              _moveToLocation(lat, lon);
                            }
                          },
                        );
                      },
                    ),
                  )
              ],
            ),
          ),

          // --- BOTTOM CONFIRM SHEET ---
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              padding: const EdgeInsets.all(25),
              decoration: const BoxDecoration(
                color: Color(0xFF1A1A1A),
                borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("Selected Location", style: TextStyle(color: Colors.orange, fontSize: 12)),
                  const SizedBox(height: 10),
                  Text(_address, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold), maxLines: 2),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _isMoving ? null : () {
                      Navigator.pop(context, {
                        'address': _address,
                        'lat': _center.latitude,
                        'lng': _center.longitude,
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      minimumSize: const Size.fromHeight(50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text("Confirm Location", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                  )
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
