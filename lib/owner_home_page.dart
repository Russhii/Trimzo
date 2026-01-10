// lib/owner_home_page.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'barber_shop_details_page.dart'; // Used for editing shop details
import 'profile_page.dart'; // Reusing your existing profile page
// REMOVED: import 'home_page.dart';

class OwnerHomePage extends StatefulWidget {
  const OwnerHomePage({super.key});

  @override
  State<OwnerHomePage> createState() => _OwnerHomePageState();
}

class _OwnerHomePageState extends State<OwnerHomePage> {
  int _selectedIndex = 0;
  final PageController _pageController = PageController();

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    _pageController.jumpToPage(index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(), // Disable swipe to avoid conflict with lists
        children: const [
          _DashboardTab(),
          _MyShopTab(),
          ProfilePage(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -4),
            )
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          backgroundColor: Colors.white,
          selectedItemColor: Colors.orange,
          unselectedItemColor: Colors.grey,
          showUnselectedLabels: true,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          selectedLabelStyle: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500),
          unselectedLabelStyle: GoogleFonts.poppins(fontSize: 12),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_outlined),
              activeIcon: Icon(Icons.dashboard),
              label: 'Dashboard',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.store_mall_directory_outlined),
              activeIcon: Icon(Icons.store_mall_directory),
              label: 'My Shop',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}

// =======================================================
// TAB 1: DASHBOARD (Status, Offers, Quick Stats)
// =======================================================

class _DashboardTab extends StatefulWidget {
  const _DashboardTab();

  @override
  State<_DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<_DashboardTab> {
  Map<String, dynamic>? _shopData;
  bool _isLoading = true;
  bool _isShopOpen = false;
  final TextEditingController _offerCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final data = await Supabase.instance.client
          .from('barber_shops')
          .select()
          .eq('owner_id', userId)
          .maybeSingle();

      if (mounted) {
        setState(() {
          _shopData = data;
          if (data != null) {
            _isShopOpen = data['is_open'] ?? false;
            _offerCtrl.text = data['today_offer'] ?? '';
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleStatus(bool value) async {
    if (_shopData == null) return;
    setState(() => _isShopOpen = value); // Optimistic update
    await Supabase.instance.client
        .from('barber_shops')
        .update({'is_open': value}).eq('id', _shopData!['id']);
  }

  Future<void> _updateOffer() async {
    if (_shopData == null) return;
    await Supabase.instance.client
        .from('barber_shops')
        .update({'today_offer': _offerCtrl.text.trim()}).eq('id', _shopData!['id']);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Today's offer updated!")));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Colors.orange));
    }

    if (_shopData == null) {
      return _NoShopWidget(onRefresh: _loadDashboardData);
    }

    // Helper to get image safely
    String imageUrl = '';
    if (_shopData!['image_urls'] != null && (_shopData!['image_urls'] as List).isNotEmpty) {
      imageUrl = _shopData!['image_urls'][0];
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          "Dashboard",
          style: GoogleFonts.poppins(
              color: Colors.black, fontWeight: FontWeight.bold, fontSize: 24),
        ),
        // REMOVED: actions: [...] (The eye icon button is gone)
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. STATUS CARD
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _isShopOpen
                      ? [Colors.green[400]!, Colors.green[700]!]
                      : [Colors.red[400]!, Colors.red[700]!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: (_isShopOpen ? Colors.green : Colors.red).withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  )
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _isShopOpen ? "ONLINE" : "OFFLINE",
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                      Switch(
                        value: _isShopOpen,
                        activeColor: Colors.white,
                        activeTrackColor: Colors.white24,
                        inactiveThumbColor: Colors.white,
                        inactiveTrackColor: Colors.white24,
                        onChanged: _toggleStatus,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isShopOpen
                        ? "Your shop is visible to customers."
                        : "Customers cannot book appointments now.",
                    style: GoogleFonts.poppins(color: Colors.white.withOpacity(0.9), fontSize: 13),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // 2. SHOP HEADER MINI
            Row(
              children: [
                Container(
                  width: 60, height: 60,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(15),
                    image: imageUrl.isNotEmpty
                        ? DecorationImage(image: NetworkImage(imageUrl), fit: BoxFit.cover)
                        : null,
                  ),
                  child: imageUrl.isEmpty ? const Icon(Icons.store, color: Colors.grey) : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_shopData!['name'],
                          style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
                      Row(
                        children: [
                          const Icon(Icons.star, size: 14, color: Colors.amber),
                          Text(" ${(_shopData!['rating'] ?? 0).toString()}",
                              style: const TextStyle(fontWeight: FontWeight.w600)),
                          const SizedBox(width: 10),
                          const Icon(Icons.location_on, size: 14, color: Colors.grey),
                          Expanded(
                            child: Text(
                              " ${_shopData!['address']}",
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ),
                        ],
                      )
                    ],
                  ),
                )
              ],
            ),

            const SizedBox(height: 24),

            // 3. MARKETING SECTION
            Text("Marketing", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey[200]!),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.local_offer, color: Colors.orange, size: 20),
                      const SizedBox(width: 8),
                      Text("Today's Special Offer", style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _offerCtrl,
                    decoration: InputDecoration(
                      hintText: "e.g., 50% off on first haircut...",
                      filled: true,
                      fillColor: Colors.grey[50],
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _updateOffer,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text("Update Offer", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
                    ),
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

// =======================================================
// TAB 2: MY SHOP (Services, Staff, Settings)
// =======================================================

class _MyShopTab extends StatefulWidget {
  const _MyShopTab();

  @override
  State<_MyShopTab> createState() => _MyShopTabState();
}

class _MyShopTabState extends State<_MyShopTab> {
  Map<String, dynamic>? _shopData;
  List<Map<String, dynamic>> _services = [];
  List<Map<String, dynamic>> _staff = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadShopDetails();
  }

  Future<void> _loadShopDetails() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final shop = await Supabase.instance.client
          .from('barber_shops')
          .select()
          .eq('owner_id', userId)
          .maybeSingle();

      if (shop == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final services = await Supabase.instance.client
          .from('services')
          .select()
          .eq('salon_id', shop['id']);

      final staff = await Supabase.instance.client
          .from('staff')
          .select()
          .eq('salon_id', shop['id']);

      if (mounted) {
        setState(() {
          _shopData = shop;
          _services = List<Map<String, dynamic>>.from(services);
          _staff = List<Map<String, dynamic>>.from(staff);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- CRUD FUNCTIONS ---
  Future<void> _addService(String name, String price) async {
    if (_shopData == null) return;
    await Supabase.instance.client.from('services').insert({
      'salon_id': _shopData!['id'],
      'name': name,
      'price': double.tryParse(price) ?? 0.0,
    });
    _loadShopDetails();
  }

  Future<void> _deleteService(int id) async {
    await Supabase.instance.client.from('services').delete().eq('id', id);
    _loadShopDetails();
  }

  Future<void> _addStaff(String name, String specialty) async {
    if (_shopData == null) return;
    await Supabase.instance.client.from('staff').insert({
      'salon_id': _shopData!['id'],
      'name': name,
      'specialty': specialty,
    });
    _loadShopDetails();
  }

  Future<void> _deleteStaff(int id) async {
    await Supabase.instance.client.from('staff').delete().eq('id', id);
    _loadShopDetails();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Colors.orange));
    }
    if (_shopData == null) {
      return _NoShopWidget(onRefresh: _loadShopDetails);
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text("My Shop", style: GoogleFonts.poppins(color: Colors.black, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: Colors.black),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const BarberShopDetailsPage()))
                  .then((_) => _loadShopDetails());
            },
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // SERVICES SECTION
            _buildSectionHeader("Services", "Manage your price list", Icons.add, () => _showAddServiceDialog(context)),
            const SizedBox(height: 16),
            if (_services.isEmpty) _buildEmptyState("No services added yet"),
            ..._services.map((s) => _buildServiceTile(s)),

            const SizedBox(height: 32),

            // STAFF SECTION
            _buildSectionHeader("Staff Members", "Manage your team", Icons.person_add, () => _showAddStaffDialog(context)),
            const SizedBox(height: 16),
            if (_staff.isEmpty) _buildEmptyState("No staff added yet"),
            ..._staff.map((s) => _buildStaffTile(s)),

            const SizedBox(height: 80), // Bottom padding
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, String subtitle, IconData icon, VoidCallback onAdd) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
            Text(subtitle, style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
          ],
        ),
        ElevatedButton(
          onPressed: onAdd,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange.withOpacity(0.1),
            elevation: 0,
            shape: const CircleBorder(),
            padding: const EdgeInsets.all(12),
          ),
          child: Icon(icon, color: Colors.orange),
        )
      ],
    );
  }

  Widget _buildEmptyState(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Center(child: Text(text, style: const TextStyle(color: Colors.grey))),
    );
  }

  Widget _buildServiceTile(Map<String, dynamic> service) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[100]!),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.content_cut, color: Colors.orange, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(service['name'], style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16)),
          ),
          Text("₹${service['price']}", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.green)),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            onPressed: () => _deleteService(service['id']),
          ),
        ],
      ),
    );
  }

  Widget _buildStaffTile(Map<String, dynamic> staff) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[100]!),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.blue.withOpacity(0.1),
            child: Text(staff['name'][0].toUpperCase(), style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(staff['name'], style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16)),
                Text(staff['specialty'] ?? 'Staff', style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            onPressed: () => _deleteStaff(staff['id']),
          ),
        ],
      ),
    );
  }

  // DIALOGS
  void _showAddServiceDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Add Service"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: "Service Name")),
            TextField(controller: priceCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Price")),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              if (nameCtrl.text.isNotEmpty && priceCtrl.text.isNotEmpty) {
                _addService(nameCtrl.text.trim(), priceCtrl.text.trim());
                Navigator.pop(context);
              }
            },
            child: const Text("Add"),
          )
        ],
      ),
    );
  }

  void _showAddStaffDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final roleCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Add Staff"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: "Name")),
            TextField(controller: roleCtrl, decoration: const InputDecoration(labelText: "Specialty (e.g. Barber)")),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              if (nameCtrl.text.isNotEmpty) {
                _addStaff(nameCtrl.text.trim(), roleCtrl.text.trim());
                Navigator.pop(context);
              }
            },
            child: const Text("Add"),
          )
        ],
      ),
    );
  }
}

// =======================================================
// HELPER: NO SHOP WIDGET
// =======================================================
class _NoShopWidget extends StatelessWidget {
  final VoidCallback onRefresh;
  const _NoShopWidget({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.store_mall_directory_outlined, size: 80, color: Colors.grey),
          const SizedBox(height: 16),
          Text("You haven't created a shop yet", style: GoogleFonts.poppins(color: Colors.grey)),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const BarberShopDetailsPage()))
                  .then((_) => onRefresh());
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text("Create My Shop", style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }
}