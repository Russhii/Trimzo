// lib/home_page.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';

import 'profile_page.dart';
import 'inbox_page.dart';
import 'my_bookings_page.dart';
import 'all_salons_page.dart';
import 'salon_details_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  late final PageController _pageController;

  // --- FILTERS STATE ---
  String _selectedCategory = "All";
  final List<String> _categories = [
    "All",
    "Haircut",
    "Shaving",
    "Face Care",
    "Massage",
    "Coloring"
  ];

  // --- MAP STATE ---
  final MapController _mapController = MapController();
  LatLng _currentLocation = const LatLng(18.5204, 73.8567);
  List<Marker> _shopMarkers = [];

  // --- SHEET STATE ---
  final DraggableScrollableController _sheetController =
  DraggableScrollableController();
  double _sheetPosition = 0.15;
  final double _minSheetSize = 0.15;
  final double _maxSheetSize = 0.88;

  // --- SUPABASE FUTURES ---
  late Future<List<Map<String, dynamic>>> _salonsFuture;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _initMapData();
    _fetchSalons("All");

    _sheetController.addListener(() {
      setState(() {
        _sheetPosition = _sheetController.size;
      });
    });
  }

  // --- HELPER: Extract Image from DB Array ---
  String _getFirstImage(dynamic imageUrls) {
    if (imageUrls != null && imageUrls is List && imageUrls.isNotEmpty) {
      return imageUrls[0].toString();
    }
    return ''; // Return empty string if no image found
  }

  void _fetchSalons(String category) {
    // FIX 1: Table name changed to 'barber_shops'
    var query = Supabase.instance.client
        .from('barber_shops')
        .select()
        .order('rating', ascending: false)
        .limit(5);

    setState(() {
      _salonsFuture = query;
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _mapController.dispose();
    _sheetController.dispose();
    super.dispose();
  }

  // --- 1. Initialize Map ---
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

    try {
      final position = await Geolocator.getCurrentPosition();
      if (mounted) {
        setState(() {
          _currentLocation = LatLng(position.latitude, position.longitude);
        });
        _mapController.move(_currentLocation, 15.0);
      }
    } catch (e) {
      debugPrint("Error: $e");
    }
  }

  // --- 3. Fetch Shops for Map ---
  Future<void> _fetchShopMarkers() async {
    try {
      // FIX 2: Table 'barber_shops' and column 'image_urls'
      final response = await Supabase.instance.client.from('barber_shops').select(
          'id, name, address, latitude, longitude, image_urls, rating, phone');

      final List<dynamic> data = response;
      final List<Marker> markers = [];

      for (var shop in data) {
        if (shop['latitude'] != null && shop['longitude'] != null) {
          final point = LatLng(shop['latitude'], shop['longitude']);

          // Use helper to get image
          final String img = _getFirstImage(shop['image_urls']);

          markers.add(
            Marker(
              point: point,
              width: 60,
              height: 60,
              child: GestureDetector(
                onTap: () => _navigateToDetails(shop),
                child: _buildCustomShopPin(img),
              ),
            ),
          );
        }
      }

      if (mounted) setState(() => _shopMarkers = markers);
    } catch (e) {
      debugPrint("Error fetching map markers: $e");
    }
  }

  // Navigation Helper
  void _navigateToDetails(Map<String, dynamic> shop) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => SalonDetailsPage(salon: shop)),
    );
  }

  // --- WIDGETS ---

  Widget _buildCategoryFilters() {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final category = _categories[index];
          final isSelected = category == _selectedCategory;
          return GestureDetector(
            onTap: () {
              setState(() => _selectedCategory = category);
              _fetchSalons(category);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected ? Colors.orange : Colors.grey[100],
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: isSelected ? Colors.orange : Colors.transparent),
              ),
              child: Center(
                child: Text(
                  category,
                  style: GoogleFonts.poppins(
                    color: isSelected ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCustomShopPin(String imageUrl) {
    return Column(
      children: [
        Container(
          width: 45,
          height: 45,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.orange, width: 2),
            image: imageUrl.isNotEmpty
                ? DecorationImage(
                image: NetworkImage(imageUrl), fit: BoxFit.cover)
                : null,
          ),
          child: imageUrl.isEmpty
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

  User? get user => Supabase.instance.client.auth.currentUser;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: false,
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _buildHomeStack(),
          const MyBookingsPage(),
          const InboxPage(),
          const ProfilePage(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 20)
            ],
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30))),
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
            BottomNavigationBarItem(
                icon: Icon(Icons.calendar_today), label: "Bookings"),
            BottomNavigationBarItem(icon: Icon(Icons.inbox), label: "Inbox"),
            BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
          ],
        ),
      ),
    );
  }

  Widget _buildHomeStack() {
    final double sheetHeightPixels =
        MediaQuery.of(context).size.height * _sheetPosition;
    final double buttonOpacity = _sheetPosition > 0.8 ? 0.0 : 1.0;

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _currentLocation,
            initialZoom: 14.0,
            interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
          ),
          children: [
            TileLayer(
              urlTemplate:
              'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
              subdomains: const ['a', 'b', 'c'],
              userAgentPackageName: 'com.ruturaj.barberapp',
              tileProvider: CancellableNetworkTileProvider(),
            ),
            MarkerLayer(markers: [
              Marker(
                  point: _currentLocation,
                  width: 60,
                  height: 60,
                  child: _buildUserLocationPin()),
              ..._shopMarkers,
            ]),
          ],
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: 150,
          child: IgnorePointer(
              child: Container(
                  decoration: BoxDecoration(
                      gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.white.withOpacity(0.9),
                            Colors.white.withOpacity(0.0)
                          ])))),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Container(
                height: 50,
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: const [
                      BoxShadow(
                          color: Colors.black12,
                          blurRadius: 10,
                          offset: Offset(0, 4))
                    ]),
                child: TextField(
                    decoration: InputDecoration(
                        hintText: "Search salon, service...",
                        hintStyle: const TextStyle(color: Colors.black38),
                        prefixIcon:
                        const Icon(Icons.search, color: Colors.orange),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 14))),
              ),
            ),
          ),
        ),
        DraggableScrollableSheet(
          controller: _sheetController,
          initialChildSize: _minSheetSize,
          minChildSize: _minSheetSize,
          maxChildSize: _maxSheetSize,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black26,
                      blurRadius: 20,
                      spreadRadius: 2,
                      offset: Offset(0, -5))
                ],
              ),
              child: SingleChildScrollView(
                controller: scrollController,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(0, 20, 0, 80),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                        child: Container(
                            width: 40,
                            height: 4,
                            margin: const EdgeInsets.only(bottom: 20),
                            decoration: BoxDecoration(
                                color: Colors.grey[300],
                                borderRadius: BorderRadius.circular(2)))),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                  "Morning, ${user?.userMetadata?['full_name']?.split(' ').first ?? 'User'}!",
                                  style: GoogleFonts.poppins(
                                      fontSize: 26,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87)),
                              Text("Find your nearest salon",
                                  style: GoogleFonts.poppins(
                                      fontSize: 14, color: Colors.black54)),
                            ],
                          ),
                          Container(
                              padding: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                        color: Colors.black12, blurRadius: 4)
                                  ]),
                              child: const Icon(Icons.notifications_outlined,
                                  color: Colors.black))
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Filter Chips
                    _buildCategoryFilters(),

                    const SizedBox(height: 24),

                    // --- TOP RATED SECTION ---
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          Text("Top Rated",
                              style: GoogleFonts.poppins(
                                  fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                                color: Colors.orange.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8)),
                            child: Text(_selectedCategory,
                                style: const TextStyle(
                                    fontSize: 10,
                                    color: Colors.orange,
                                    fontWeight: FontWeight.bold)),
                          ),
                          const Spacer(),
                          const Icon(Icons.arrow_forward,
                              size: 16, color: Colors.grey),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 200,
                      child: FutureBuilder<List<Map<String, dynamic>>>(
                        future: _salonsFuture,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                                child: CircularProgressIndicator(
                                    color: Colors.orange));
                          }
                          if (!snapshot.hasData || snapshot.data!.isEmpty) {
                            return const Center(
                                child: Text("No top rated salons found"));
                          }

                          final salons = snapshot.data!;
                          return ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            scrollDirection: Axis.horizontal,
                            itemCount: salons.length,
                            separatorBuilder: (_, __) =>
                            const SizedBox(width: 16),
                            itemBuilder: (context, index) {
                              return _buildTopRatedCard(salons[index]);
                            },
                          );
                        },
                      ),
                    ),
                    // -----------------------------------------------

                    const SizedBox(height: 24),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("Most Popular",
                              style: GoogleFonts.poppins(
                                  fontSize: 20, fontWeight: FontWeight.w600)),
                          TextButton(
                              onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => const AllSalonsPage())),
                              child: Text("See All",
                                  style:
                                  GoogleFonts.poppins(color: Colors.orange))),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: FutureBuilder<List<Map<String, dynamic>>>(
                        future: _salonsFuture,
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) return const SizedBox();
                          final salons = snapshot.data!;
                          return Column(
                              children: salons
                                  .map((salon) => Padding(
                                  padding:
                                  const EdgeInsets.only(bottom: 16),
                                  child: _salonCard(salon)))
                                  .toList());
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        Positioned(
          bottom: sheetHeightPixels + 20,
          right: 20,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: buttonOpacity,
            child: FloatingActionButton(
                heroTag: "btn_loc",
                backgroundColor: Colors.white,
                onPressed: _getCurrentLocation,
                child: const Icon(Icons.my_location, color: Colors.black87)),
          ),
        ),
      ],
    );
  }

  // --- TOP RATED CARD ---
  Widget _buildTopRatedCard(Map<String, dynamic> salon) {
    // FIX 3: Get first image safely
    final String img = _getFirstImage(salon['image_urls']);

    return GestureDetector(
      onTap: () => _navigateToDetails(salon),
      child: Container(
        width: 160,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4))
          ],
          border: Border.all(color: Colors.grey[100]!),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            Expanded(
              child: ClipRRect(
                borderRadius:
                const BorderRadius.vertical(top: Radius.circular(16)),
                child: Image.network(
                  img,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                      color: Colors.grey[200],
                      child: const Icon(Icons.spa, color: Colors.grey)),
                ),
              ),
            ),
            // Details
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(salon['name'],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                          fontSize: 14, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 14),
                      Text(
                          " ${(salon['rating'] as num?)?.toDouble() ?? 0.0}",
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.bold)),
                      Text(" (25)",
                          style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                    ],
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserLocationPin() {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.2), shape: BoxShape.circle)),
        Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
                color: Colors.blue,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: const [
                  BoxShadow(color: Colors.black26, blurRadius: 5)
                ])),
      ],
    );
  }

  Widget _salonCard(Map<String, dynamic> salon) {
    // FIX 4: Get first image safely
    final String img = _getFirstImage(salon['image_urls']);

    return GestureDetector(
      onTap: () => _navigateToDetails(salon),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey[200]!),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4))
            ]),
        child: Row(
          children: [
            ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(img,
                    width: 90,
                    height: 90,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                        color: Colors.grey[200],
                        child: const Icon(Icons.spa,
                            color: Colors.grey, size: 40)))),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(salon['name'],
                      style: GoogleFonts.poppins(
                          fontSize: 18, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(salon['address'] ?? '',
                      style: const TextStyle(color: Colors.black54, fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 8),
                  Row(children: [
                    const Icon(Icons.star, color: Colors.amber, size: 18),
                    Text(
                        " ${(salon['rating'] as num?)?.toDouble() ?? 0.0}",
                        style: const TextStyle(fontWeight: FontWeight.w600))
                  ]),
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