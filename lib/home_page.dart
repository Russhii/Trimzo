// lib/home_page.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'profile_page.dart';
import 'inbox_page.dart';
import 'my_bookings_page.dart';
import 'all_salons_page.dart'; // Import the new page

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  User? get user => Supabase.instance.client.auth.currentUser;

  // Fetch only 5 salons for the home page
  final Future<List<Map<String, dynamic>>> _nearbySalonsFuture =
  Supabase.instance.client.from('salons').select().limit(5);

  final Future<List<Map<String, dynamic>>> _popularSalonsFuture =
  Supabase.instance.client.from('salons').select().order('rating', ascending: false).limit(5);

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
    if (index == 3) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfilePage()));
    } else if (index == 2) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const InboxPage()));
    } else if (index == 1) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const MyBookingsPage()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        // ... (Keep existing AppBar code exactly as is)
        backgroundColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 100,
        title: Padding(
          padding: const EdgeInsets.only(top: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Morning, ${user?.userMetadata?['full_name']?.split(' ').first ?? user?.email?.split('@').first ?? 'Guest'}!",
                style: GoogleFonts.poppins(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              Text("Book your favorite salon today!", style: GoogleFonts.poppins(fontSize: 15, color: Colors.white70)),
            ],
          ),
        ),
        actions: const [
          IconButton(icon: Icon(Icons.notifications_outlined, color: Colors.white, size: 28), onPressed: null),
          IconButton(icon: Icon(Icons.bookmark_border, color: Colors.white, size: 28), onPressed: null),
          SizedBox(width: 12),
        ],
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ... (Keep Search Bar and Banner code exactly as is)
            TextField(
              decoration: InputDecoration(
                hintText: "Search salon, service...",
                hintStyle: const TextStyle(color: Colors.white38),
                prefixIcon: const Icon(Icons.search, color: Colors.white54),
                filled: true,
                fillColor: Colors.white.withOpacity(0.08),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 32),

            // Banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFFFF8B00), Color(0xFFFF6B00)]),
                borderRadius: BorderRadius.circular(20),
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

            // NEARBY YOUR LOCATION SECTION (Dynamic)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Nearby Your Location", style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white)),
                TextButton(
                  onPressed: () {
                    // Navigate to All Salons Page
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const AllSalonsPage()));
                  },
                  child: Text("See All", style: GoogleFonts.poppins(color: Colors.orange)),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Categories
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _categoryChip("All", isSelected: true),
                  _categoryChip("Haircuts"),
                  _categoryChip("Make up"),
                  _categoryChip("Manicure"),
                  _categoryChip("Massage"),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // DYNAMIC LIST: Nearby Salons
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _nearbySalonsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Colors.orange));
                }
                if (snapshot.hasError) {
                  return Text("Error loading salons", style: TextStyle(color: Colors.white));
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Text("No salons found", style: TextStyle(color: Colors.white));
                }

                final salons = snapshot.data!;
                return Column(
                  children: salons.map((salon) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _salonCard(
                        name: salon['name'] ?? 'Unknown',
                        address: salon['address'] ?? '',
                        distance: salon['distance'] ?? '',
                        rating: (salon['rating'] as num).toDouble(),
                        imageUrl: salon['image_url'] ?? '',
                      ),
                    );
                  }).toList(),
                );
              },
            ),

            const SizedBox(height: 40),

            // MOST POPULAR SECTION (Dynamic)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Most Popular", style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white)),
                TextButton(
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const AllSalonsPage()));
                    },
                    child: Text("See All", style: GoogleFonts.poppins(color: Colors.orange))
                ),
              ],
            ),
            const SizedBox(height: 24),

            // DYNAMIC LIST: Popular Salons
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _popularSalonsFuture,
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const SizedBox.shrink(); // Hide if loading/empty to avoid duplicate spinner

                final salons = snapshot.data!;
                return Column(
                  children: salons.map((salon) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _salonCard(
                        name: salon['name'],
                        address: salon['address'],
                        distance: salon['distance'],
                        rating: (salon['rating'] as num).toDouble(),
                        imageUrl: salon['image_url'],
                      ),
                    );
                  }).toList(),
                );
              },
            ),

            const SizedBox(height: 100),
          ],
        ),
      ),
      // ... (Keep BottomNavigationBar code exactly as is)
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 20)],
        ),
        child: BottomNavigationBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: Colors.orange,
          unselectedItemColor: Colors.white54,
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          selectedLabelStyle: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600),
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
            BottomNavigationBarItem(icon: Icon(Icons.calendar_today), label: "My Booking"),
            BottomNavigationBarItem(icon: Icon(Icons.inbox), label: "Inbox"),
            BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
          ],
        ),
      ),
    );
  }

  // Keep helper widgets
  Widget _categoryChip(String label, {bool isSelected = false}) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: ChoiceChip(
        label: Text(label, style: GoogleFonts.poppins(color: isSelected ? Colors.white : Colors.orange)),
        selected: isSelected,
        selectedColor: Colors.orange,
        backgroundColor: Colors.white.withOpacity(0.1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        onSelected: (_) {},
      ),
    );
  }

  Widget _salonCard({
    required String name,
    required String address,
    required String distance,
    required double rating,
    required String imageUrl,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.network(
              imageUrl,
              width: 90,
              height: 90,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(color: Colors.grey, child: const Icon(Icons.spa, color: Colors.white54, size: 40)),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white)),
                const SizedBox(height: 4),
                Text(address, style: const TextStyle(color: Colors.white60, fontSize: 13)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.location_on, size: 16, color: Colors.orange),
                    Text(" $distance", style: const TextStyle(color: Colors.orange, fontSize: 13)),
                    const Spacer(),
                    const Icon(Icons.star, color: Colors.amber, size: 18),
                    const SizedBox(width: 4),
                    Text("$rating", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  ],
                ),
              ],
            ),
          ),
          IconButton(icon: const Icon(Icons.bookmark_border, color: Colors.white60), onPressed: () {}),
        ],
      ),
    );
  }
}