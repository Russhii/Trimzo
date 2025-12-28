// lib/home_page.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path; // <--- Hides Path to fix conflict
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart'; // <--- Speed Optimization

import 'profile_page.dart';
import 'inbox_page.dart';
import 'my_bookings_page.dart';
import 'all_salons_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  late final PageController _pageController;

  // Map Controller
  final MapController _mapController = MapController();
  LatLng _currentLocation = const LatLng(18.5204, 73.8567); // Default: Pune
  List<Marker> _shopMarkers = [];
  bool _isLoadingMap = true;

  // Supabase Futures
  late final Future<List<Map<String, dynamic>>> _popularSalonsFuture;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _initMapData();

    // Initialize Future for Popular list
    _popularSalonsFuture = Supabase.instance.client
        .from('salons')
        .select()
        .order('rating', ascending: false)
        .limit(5);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  // --- 1. Initialize Map: Get Location & Fetch Shops ---
  Future<void> _initMapData() async {
    await _getCurrentLocation();
    await _fetchShopMarkers();
  }

  // --- 2. Get User's Real Location ---
  Future<void> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    if (permission == LocationPermission.deniedForever) return;

    final position = await Geolocator.getCurrentPosition();
    if (mounted) {
      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
        _isLoadingMap = false;
      });
      // Smoothly move map to user
      _mapController.move(_currentLocation, 15.0);
    }
  }

  // --- 3. Fetch Shops and create Markers ---
  Future<void> _fetchShopMarkers() async {
    try {
      final response = await Supabase.instance.client
          .from('salons')
          .select('id, name, address, latitude, longitude, image_url, rating, phone');

      final List<dynamic> data = response;
      final List<Marker> markers = [];

      for (var shop in data) {
        if (shop['latitude'] != null && shop['longitude'] != null) {
          final point = LatLng(shop['latitude'], shop['longitude']);

          markers.add(
            Marker(
              point: point,
              width: 60,
              height: 60,
              child: GestureDetector(
                onTap: () => _showShopDetailsSheet(shop), // Open Popup
                child: _buildCustomShopPin(shop['image_url']),
              ),
            ),
          );
        }
      }

      if (mounted) {
        setState(() {
          _shopMarkers = markers;
        });
      }
    } catch (e) {
      debugPrint("Error fetching map markers: $e");
    }
  }

  // --- 4. Launch Navigation ---
  Future<void> _launchNavigation(double lat, double lng) async {
    final Uri googleMapsUrl = Uri.parse("google.navigation:q=$lat,$lng&mode=d");
    final Uri appleMapsUrl = Uri.parse("https://maps.apple.com/?daddr=$lat,$lng");

    if (await canLaunchUrl(googleMapsUrl)) {
      await launchUrl(googleMapsUrl);
    } else if (await canLaunchUrl(appleMapsUrl)) {
      await launchUrl(appleMapsUrl);
    } else {
      final webUrl = Uri.parse("https://www.google.com/maps/dir/?api=1&destination=$lat,$lng");
      await launchUrl(webUrl, mode: LaunchMode.externalApplication);
    }
  }

  // --- 5. Call Shop ---
  Future<void> _callShop(String? phone) async {
    if (phone == null || phone.isEmpty) return;
    final Uri launchUri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    }
  }

  // --- WIDGETS ---

  Widget _buildCustomShopPin(String? imageUrl) {
    return Column(
      children: [
        Container(
          width: 45,
          height: 45,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.orange, width: 2),
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
            image: imageUrl != null && imageUrl.isNotEmpty
                ? DecorationImage(image: NetworkImage(imageUrl), fit: BoxFit.cover)
                : null,
          ),
          child: imageUrl == null || imageUrl.isEmpty
              ? const Icon(Icons.store, size: 24, color: Colors.orange)
              : null,
        ),
        ClipPath(
          clipper: _TriangleClipper(),
          child: Container(color: Colors.orange, width: 10, height: 8),
        )
      ],
    );
  }

  void _showShopDetailsSheet(Map<String, dynamic> shop) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
                ),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          shop['name'],
                          style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          shop['address'] ?? "No address",
                          style: GoogleFonts.poppins(color: Colors.grey[600], fontSize: 13),
                          maxLines: 2,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.star, color: Colors.amber, size: 18),
                            const SizedBox(width: 4),
                            Text("${shop['rating'] ?? 'New'}", style: const TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      shop['image_url'] ?? '',
                      width: 80, height: 80, fit: BoxFit.cover,
                      errorBuilder: (_,__,___) => Container(width: 80, height: 80, color: Colors.grey[200]),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildActionButton(
                      icon: Icons.directions,
                      label: "Direction",
                      color: Colors.blue,
                      onTap: () => _launchNavigation(shop['latitude'], shop['longitude'])
                  ),
                  _buildActionButton(
                      icon: Icons.call,
                      label: "Call",
                      color: Colors.green,
                      onTap: () => _callShop(shop['phone'])
                  ),
                  _buildActionButton(
                      icon: Icons.share,
                      label: "Share",
                      color: Colors.black54,
                      onTap: () { /* Share Logic */ }
                  ),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                  child: Text("Book Appointment", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16)),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActionButton({required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(height: 8),
          Text(label, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  // --- BUILD METHOD ---

  User? get user => Supabase.instance.client.auth.currentUser;

  AppBar _buildHomeAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      toolbarHeight: 90,
      title: Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Morning, ${user?.userMetadata?['full_name']?.split(' ').first ?? 'User'}!",
              style: GoogleFonts.poppins(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.black),
            ),
            Text("Find your nearest salon", style: GoogleFonts.poppins(fontSize: 14, color: Colors.black54)),
          ],
        ),
      ),
      actions: const [
        IconButton(icon: Icon(Icons.notifications_outlined, color: Colors.black, size: 28), onPressed: null),
        SizedBox(width: 12),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _selectedIndex == 0 ? _buildHomeAppBar() : null,
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _buildHomeContent(),
          const MyBookingsPage(),
          const InboxPage(),
          const ProfilePage(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 20)],
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: BottomNavigationBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: Colors.orange,
          unselectedItemColor: Colors.black54,
          currentIndex: _selectedIndex,
          onTap: (index) {
            setState(() => _selectedIndex = index);
            _pageController.jumpToPage(index);
          },
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
            BottomNavigationBarItem(icon: Icon(Icons.calendar_today), label: "Bookings"),
            BottomNavigationBarItem(icon: Icon(Icons.inbox), label: "Inbox"),
            BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
          ],
        ),
      ),
    );
  }

  Widget _buildHomeContent() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            decoration: InputDecoration(
              hintText: "Search salon, service...",
              hintStyle: const TextStyle(color: Colors.black38),
              prefixIcon: const Icon(Icons.search, color: Colors.black54),
              filled: true,
              fillColor: Colors.grey[100],
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 24),

          Text("Explore Nearby", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          Container(
            height: 280,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 15, offset: const Offset(0, 5))],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Stack(
                children: [
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: _currentLocation,
                      initialZoom: 14.0,
                      interactionOptions: const InteractionOptions(
                        flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                      ),
                    ),
                    children: [
                      // --- OPTIMIZED TILE LAYER ---
                      TileLayer(
                        urlTemplate: 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
                        subdomains: const ['a', 'b', 'c'],
                        userAgentPackageName: 'com.ruturaj.barberapp',
                        tileProvider: CancellableNetworkTileProvider(), // Fast Loading
                        panBuffer: 1, // Pre-loads edges
                        keepBuffer: 5, // Remembers visited tiles
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _currentLocation,
                            width: 60, height: 60,
                            child: _buildUserLocationPin(),
                          ),
                          ..._shopMarkers,
                        ],
                      ),
                    ],
                  ),
                  if (_isLoadingMap)
                    Container(
                      color: Colors.white,
                      child: const Center(child: CircularProgressIndicator(color: Colors.orange)),
                    ),
                  Positioned(
                    bottom: 16, right: 16,
                    child: FloatingActionButton.small(
                      backgroundColor: Colors.white,
                      onPressed: _getCurrentLocation,
                      child: const Icon(Icons.my_location, color: Colors.black87),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFFFF8B00), Color(0xFFFF6B00)]),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("30% OFF", style: GoogleFonts.poppins(fontSize: 16, color: Colors.white70)),
                    Text("Today's Special", style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                  ],
                ),
                Text("30%", style: GoogleFonts.poppins(fontSize: 50, fontWeight: FontWeight.bold, color: Colors.white)),
              ],
            ),
          ),
          const SizedBox(height: 32),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Most Popular", style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w600)),
              TextButton(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AllSalonsPage())),
                child: Text("See All", style: GoogleFonts.poppins(color: Colors.orange)),
              ),
            ],
          ),
          const SizedBox(height: 16),

          FutureBuilder<List<Map<String, dynamic>>>(
            future: _popularSalonsFuture,
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Colors.orange));
              final salons = snapshot.data!;
              return Column(
                children: salons.map((salon) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _salonCard(salon),
                )).toList(),
              );
            },
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildUserLocationPin() {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 60, height: 60,
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
        ),
        Container(
          width: 20, height: 20,
          decoration: BoxDecoration(
            color: Colors.blue,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 5)],
          ),
        ),
      ],
    );
  }

  Widget _salonCard(Map<String, dynamic> salon) {
    return GestureDetector(
      onTap: () {
        // Navigate to booking page
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey[200]!),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                salon['image_url'] ?? '',
                width: 90, height: 90, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(color: Colors.grey[200], child: const Icon(Icons.spa, color: Colors.grey, size: 40)),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(salon['name'], style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(salon['address'] ?? '', style: const TextStyle(color: Colors.black54, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 18),
                      Text(" ${salon['rating']}", style: const TextStyle(fontWeight: FontWeight.w600)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TriangleClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.moveTo(0, 0);
    path.lineTo(size.width / 2, size.height);
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }
  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}