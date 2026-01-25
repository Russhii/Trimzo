import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'barber_shop_details_page.dart';
import 'profile_page.dart';

// =======================================================
// PARENT: OWNER HOME PAGE (Holds the "Selected Shop" State)
// =======================================================

class OwnerHomePage extends StatefulWidget {
  const OwnerHomePage({super.key});

  @override
  State<OwnerHomePage> createState() => _OwnerHomePageState();
}

class _OwnerHomePageState extends State<OwnerHomePage> {
  int _selectedIndex = 0;
  final PageController _pageController = PageController();

  // --- GLOBAL STATE FOR ALL TABS ---
  List<Map<String, dynamic>> _allShops = [];
  Map<String, dynamic>? _selectedShop;
  bool _isLoadingShops = true;

  @override
  void initState() {
    super.initState();
    _loadAllShops();
  }

  // 1. Fetch All Shops Once (at the top level)
  Future<void> _loadAllShops() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final response = await Supabase.instance.client
          .from('barber_shops')
          .select()
          .eq('owner_id', userId)
          .order('created_at');

      final List<Map<String, dynamic>> shops = List<Map<String, dynamic>>.from(response);

      if (mounted) {
        setState(() {
          _allShops = shops;
          if (shops.isNotEmpty) {
            _selectedShop = shops.first; // Default to first shop
          }
          _isLoadingShops = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading shops: $e");
      if (mounted) setState(() => _isLoadingShops = false);
    }
  }

  // 2. Callback to Change Shop (Called from Dashboard)
  void _changeShop(Map<String, dynamic> newShop) {
    setState(() {
      _selectedShop = newShop;
    });
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    _pageController.jumpToPage(index);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingShops) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: Colors.orange)));
    }

    // If user has no shops, show empty state or create page
    if (_allShops.isEmpty) {
      return Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BarberShopDetailsPage())).then((_) => _loadAllShops()),
            child: const Text("Create Your First Shop"),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          // TAB 0: DASHBOARD (Passes selected shop & callback)
          _DashboardTab(
            selectedShop: _selectedShop!,
            allShops: _allShops,
            onShopChanged: _changeShop,
          ),

          // TAB 1: SCHEDULE (Passes selected shop to filter schedule)
          _AcceptedBookingsTab(selectedShop: _selectedShop!),

          // TAB 2: MY SHOP (Passes selected shop to show correct stats)
          _MyShopTab(selectedShop: _selectedShop!),

          // TAB 3: PROFILE
          const ProfilePage(),
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
          selectedLabelStyle: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w500),
          unselectedLabelStyle: GoogleFonts.poppins(fontSize: 10),
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.dashboard_outlined), activeIcon: Icon(Icons.dashboard), label: 'Requests'),
            BottomNavigationBarItem(icon: Icon(Icons.calendar_month_outlined), activeIcon: Icon(Icons.calendar_month), label: 'Schedule'),
            BottomNavigationBarItem(icon: Icon(Icons.store_mall_directory_outlined), activeIcon: Icon(Icons.store_mall_directory), label: 'My Shop'),
            BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'Profile'),
          ],
        ),
      ),
    );
  }
}

// =======================================================
// TAB 1: DASHBOARD (Receives Data from Parent)
// =======================================================

class _DashboardTab extends StatefulWidget {
  final Map<String, dynamic> selectedShop;
  final List<Map<String, dynamic>> allShops;
  final Function(Map<String, dynamic>) onShopChanged;

  const _DashboardTab({
    required this.selectedShop,
    required this.allShops,
    required this.onShopChanged,
  });

  @override
  State<_DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<_DashboardTab> {
  List<Map<String, dynamic>> _bookings = [];
  bool _isBookingsLoading = false;
  bool _isShopOpen = false;
  final TextEditingController _offerCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initShopData();
  }

  // Detect when Parent changes the shop and reload data
  @override
  void didUpdateWidget(covariant _DashboardTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedShop['id'] != widget.selectedShop['id']) {
      _initShopData();
    }
  }

  void _initShopData() {
    setState(() {
      _isShopOpen = widget.selectedShop['is_open'] ?? false;
      _offerCtrl.text = widget.selectedShop['today_offer'] ?? '';
    });
    _loadBookingsForShop(widget.selectedShop['id']);
  }

  Future<void> _loadBookingsForShop(int shopId) async {
    setState(() => _isBookingsLoading = true);

    try {
      final bookingsResponse = await Supabase.instance.client
          .from('bookings')
          .select()
          .eq('salon_id', shopId)
          .eq('status', 'upcoming')
          .order('booking_date', ascending: true);

      final List<Map<String, dynamic>> rawBookings = List<Map<String, dynamic>>.from(bookingsResponse);
      List<Map<String, dynamic>> mergedBookings = [];

      if (rawBookings.isNotEmpty) {
        final userIds = rawBookings.map((b) => b['user_id']).toSet().toList();
        final profilesResponse = await Supabase.instance.client
            .from('profiles')
            .select()
            .filter('id', 'in', userIds);
        final List<Map<String, dynamic>> profiles = List<Map<String, dynamic>>.from(profilesResponse);

        mergedBookings = rawBookings.map((booking) {
          final profile = profiles.firstWhere((p) => p['id'] == booking['user_id'], orElse: () => <String, dynamic>{});
          return {...booking, 'customer': profile};
        }).toList();
      }

      if (mounted) {
        setState(() {
          _bookings = mergedBookings;
          _isBookingsLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isBookingsLoading = false);
    }
  }

  Future<void> _updateBookingStatus(int bookingId, String status) async {
    try {
      await Supabase.instance.client.from('bookings').update({'status': status}).eq('id', bookingId);

      // ... (Notification Logic Same as before) ...
      // Simplified for brevity, you can keep your full notification logic here

      setState(() {
        _bookings.removeWhere((b) => b['id'] == bookingId);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(status == 'cancelled' ? 'Rejected' : 'Accepted!'), backgroundColor: status == 'cancelled' ? Colors.red : Colors.green));
      }
    } catch (e) {
      // Error handling
    }
  }

  Future<void> _toggleStatus(bool value) async {
    setState(() => _isShopOpen = value);
    await Supabase.instance.client
        .from('barber_shops')
        .update({'is_open': value}).eq('id', widget.selectedShop['id']);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: GestureDetector(
          onTap: _showShopSelector,
          child: Row(
            children: [
              Text("Requests for: ", style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
              Text(widget.selectedShop['name'], style: GoogleFonts.poppins(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
              const Icon(Icons.keyboard_arrow_down, color: Colors.orange),
            ],
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => _loadBookingsForShop(widget.selectedShop['id']),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _isShopOpen ? Colors.green : Colors.red,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_isShopOpen ? "SHOP ONLINE" : "SHOP OFFLINE", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
                    Switch(value: _isShopOpen, onChanged: _toggleStatus, activeColor: Colors.white),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("New Requests", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.refresh, color: Colors.orange),
                    onPressed: () => _loadBookingsForShop(widget.selectedShop['id']),
                  )
                ],
              ),
              if (_isBookingsLoading)
                const Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: Colors.orange))
              else if (_bookings.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(40),
                  child: Column(
                    children: [
                      const Icon(Icons.check_circle_outline, size: 50, color: Colors.grey),
                      const SizedBox(height: 10),
                      Text("No pending requests", style: GoogleFonts.poppins(color: Colors.grey)),
                    ],
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _bookings.length,
                  separatorBuilder: (c, i) => const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    final booking = _bookings[index];
                    return _BookingCard(
                      booking: booking,
                      onAccept: () => _updateBookingStatus(booking['id'], 'accepted'),
                      onReject: () => _updateBookingStatus(booking['id'], 'cancelled'),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showShopSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("Select Shop", style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                ListView.separated(
                  shrinkWrap: true,
                  itemCount: widget.allShops.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final shop = widget.allShops[index];
                    return ListTile(
                      title: Text(shop['name']),
                      selected: shop['id'] == widget.selectedShop['id'],
                      selectedColor: Colors.orange,
                      onTap: () {
                        // CALL PARENT FUNCTION
                        widget.onShopChanged(shop);
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// =======================================================
// TAB 2: SCHEDULE (Filtered by Selected Shop)
// =======================================================

class _AcceptedBookingsTab extends StatefulWidget {
  final Map<String, dynamic> selectedShop;
  const _AcceptedBookingsTab({required this.selectedShop});

  @override
  State<_AcceptedBookingsTab> createState() => _AcceptedBookingsTabState();
}

class _AcceptedBookingsTabState extends State<_AcceptedBookingsTab> {
  List<Map<String, dynamic>> _acceptedBookings = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchAcceptedBookings();
  }

  @override
  void didUpdateWidget(covariant _AcceptedBookingsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedShop['id'] != widget.selectedShop['id']) {
      _fetchAcceptedBookings();
    }
  }

  Future<void> _fetchAcceptedBookings() async {
    setState(() => _isLoading = true);
    try {
      // Filter by the SELECTED shop ID
      final response = await Supabase.instance.client
          .from('bookings')
          .select('*, barber_shops(name)')
          .eq('salon_id', widget.selectedShop['id'])
          .eq('status', 'accepted')
          .order('booking_date', ascending: true);

      final raw = List<Map<String, dynamic>>.from(response);

      List<Map<String, dynamic>> merged = [];
      if (raw.isNotEmpty) {
        final userIds = raw.map((b) => b['user_id']).toSet().toList();
        final profilesRes = await Supabase.instance.client.from('profiles').select().filter('id', 'in', userIds);
        final profiles = List<Map<String, dynamic>>.from(profilesRes);
        merged = raw.map((b) {
          final profile = profiles.firstWhere((p) => p['id'] == b['user_id'], orElse: () => {});
          return {...b, 'customer': profile};
        }).toList();
      }

      if (mounted) {
        setState(() {
          _acceptedBookings = merged;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ... (Keep existing helpers: _updateAddonStatus, _markCompleted, _cancelBooking, _requestReschedule, etc.) ...
  // For brevity, I am assuming you keep the helper methods you wrote in your original code here.
  // Just ensure they refresh using _fetchAcceptedBookings();

  @override
  Widget build(BuildContext context) {
    // ... (Your existing UI for _AcceptedBookingsTab, simply use _acceptedBookings) ...
    // Copy the entire build method from your original code here.
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Schedule", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            Text(widget.selectedShop['name'], style: const TextStyle(color: Colors.grey, fontSize: 12)), // Show Shop Name
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [IconButton(icon: const Icon(Icons.refresh, color: Colors.orange), onPressed: _fetchAcceptedBookings)],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.orange))
          : _acceptedBookings.isEmpty
          ? const Center(child: Text("No upcoming appointments"))
          : ListView.separated(
        padding: const EdgeInsets.all(20),
        itemCount: _acceptedBookings.length,
        separatorBuilder: (c, i) => const SizedBox(height: 20),
        itemBuilder: (context, index) {
          // ... Your existing card UI ...
          final booking = _acceptedBookings[index];
          final customer = booking['customer'] ?? {};
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
            child: Text("${customer['full_name'] ?? 'Client'} - ${booking['service_name']}"),
          );
        },
      ),
    );
  }
}

// =======================================================
// TAB 2: MY SHOP (Receives Data from Parent)
// =======================================================

class _MyShopTab extends StatefulWidget {
  final Map<String, dynamic> selectedShop;
  const _MyShopTab({required this.selectedShop});

  @override
  State<_MyShopTab> createState() => _MyShopTabState();
}

class _MyShopTabState extends State<_MyShopTab> {
  bool _isLoading = true;
  int _totalBookings = 0;
  double _totalRevenue = 0.0;

  @override
  void initState() {
    super.initState();
    _fetchShopStats();
  }

  @override
  void didUpdateWidget(covariant _MyShopTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reload stats if the shop ID changed
    if (oldWidget.selectedShop['id'] != widget.selectedShop['id']) {
      _fetchShopStats();
    }
  }

  Future<void> _fetchShopStats() async {
    setState(() => _isLoading = true);
    try {
      final shopId = widget.selectedShop['id'];

      final bookingsResponse = await Supabase.instance.client
          .from('bookings')
          .select('price, status, addons')
          .eq('salon_id', shopId)
          .neq('status', 'cancelled');

      final List<dynamic> bookingsList = bookingsResponse;
      int count = bookingsList.length;
      double revenue = 0.0;

      for (var b in bookingsList) {
        if (b['status'] == 'completed') {
          revenue += (b['price'] as num).toDouble();
          if (b['addons'] != null) {
            final List<dynamic> addons = b['addons'];
            for (var addon in addons) {
              if (addon['status'] == 'accepted') {
                revenue += (addon['price'] as num).toDouble();
              }
            }
          }
        }
      }

      if (mounted) {
        setState(() {
          _totalBookings = count;
          _totalRevenue = revenue;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _openServiceManager(BuildContext context, int shopId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => _ManageServicesSheet(shopId: shopId),
    );
  }

  void _openStaffManager(BuildContext context, int shopId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => _ManageStaffSheet(shopId: shopId),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator(color: Colors.orange));

    final shop = widget.selectedShop;
    String imageUrl = '';
    if (shop['image_urls'] != null && (shop['image_urls'] as List).isNotEmpty) {
      imageUrl = shop['image_urls'][0];
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text("My Shop (${shop['name']})", style: GoogleFonts.poppins(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
        actions: [IconButton(icon: const Icon(Icons.refresh, color: Colors.orange), onPressed: _fetchShopStats)],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: Row(
                children: [
                  Container(
                    width: 70, height: 70,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(15),
                      image: imageUrl.isNotEmpty ? DecorationImage(image: NetworkImage(imageUrl), fit: BoxFit.cover) : null,
                    ),
                    child: imageUrl.isEmpty ? const Icon(Icons.store, size: 30, color: Colors.grey) : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(shop['name'], style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(shop['address'] ?? 'No Address', maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.star, size: 14, color: Colors.amber),
                            Text(" ${shop['rating'] ?? 0.0}", style: const TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        )
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(child: _buildStatCard("Total Bookings", "$_totalBookings", Icons.calendar_today)),
                const SizedBox(width: 12),
                Expanded(child: _buildStatCard("Revenue", "₹${_totalRevenue.toStringAsFixed(0)}", Icons.currency_rupee)),
              ],
            ),
            const SizedBox(height: 24),
            Text("Manage", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.5,
              children: [
                _buildMenuCard(icon: Icons.content_cut, title: "Services", color: Colors.blue, onTap: () => _openServiceManager(context, shop['id'])),
                _buildMenuCard(icon: Icons.people_outline, title: "Staff", color: Colors.purple, onTap: () => _openStaffManager(context, shop['id'])),
                _buildMenuCard(icon: Icons.access_time, title: "Opening Hours", color: Colors.orange, onTap: () {}),
                _buildMenuCard(icon: Icons.edit, title: "Edit Details", color: Colors.green, onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const BarberShopDetailsPage())).then((_) => _fetchShopStats());
                }),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ... (Keep _buildStatCard and _buildMenuCard helpers from original code) ...
  Widget _buildStatCard(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey[200]!)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.grey),
          const SizedBox(height: 12),
          Text(value, style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold)),
          Text(title, style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildMenuCard({required IconData icon, required String title, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey[200]!)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle), child: Icon(icon, color: color, size: 24)),
            const SizedBox(height: 12),
            Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14)),
          ],
        ),
      ),
    );
  }
}

// =======================================================
// KEEP THESE CLASSES (ServicesSheet, StaffSheet, BookingCard)
// =======================================================
// Paste your existing _ManageServicesSheet class here...
// Paste your existing _ManageStaffSheet class here...
// Paste your existing _BookingCard class here...
// (I omitted them to save space, but you must include them for the code to run)
class _ManageServicesSheet extends StatefulWidget {
  final int shopId;
  const _ManageServicesSheet({required this.shopId});

  @override
  State<_ManageServicesSheet> createState() => _ManageServicesSheetState();
}

class _ManageServicesSheetState extends State<_ManageServicesSheet> {
  List<Map<String, dynamic>> _services = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    final res = await Supabase.instance.client.from('services').select().eq('salon_id', widget.shopId);
    if(mounted) setState(() { _services = List<Map<String, dynamic>>.from(res); _isLoading = false; });
  }

  Future<void> _addService(String name, String price) async {
    await Supabase.instance.client.from('services').insert({
      'salon_id': widget.shopId,
      'name': name,
      'price': double.tryParse(price) ?? 0.0,
    });
    _fetch();
    if(mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text("Manage Services", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
            IconButton(icon: const Icon(Icons.add, color: Colors.orange), onPressed: _showAddDialog)
          ]),
          const Divider(),
          Expanded(
            child: _isLoading ? const Center(child: CircularProgressIndicator()) : ListView.builder(
              itemCount: _services.length,
              itemBuilder: (c, i) {
                final s = _services[i];
                return ListTile(
                  title: Text(s['name']),
                  trailing: Text("₹${s['price']}", style: const TextStyle(fontWeight: FontWeight.bold)),
                  leading: const Icon(Icons.content_cut, size: 18, color: Colors.grey),
                );
              },
            ),
          )
        ],
      ),
    );
  }

  void _showAddDialog() {
    final nCtrl = TextEditingController();
    final pCtrl = TextEditingController();
    showDialog(context: context, builder: (_) => AlertDialog(
      title: const Text("Add Service"),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: nCtrl, decoration: const InputDecoration(labelText: "Service Name")),
        TextField(controller: pCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Price")),
      ]),
      actions: [
        TextButton(onPressed: ()=>Navigator.pop(context), child: const Text("Cancel")),
        ElevatedButton(onPressed: () => _addService(nCtrl.text, pCtrl.text), child: const Text("Add")),
      ],
    ));
  }
}

class _ManageStaffSheet extends StatefulWidget {
  final int shopId;
  const _ManageStaffSheet({required this.shopId});

  @override
  State<_ManageStaffSheet> createState() => _ManageStaffSheetState();
}

class _ManageStaffSheetState extends State<_ManageStaffSheet> {
  List<Map<String, dynamic>> _staff = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    final res = await Supabase.instance.client.from('staff').select().eq('salon_id', widget.shopId);
    if(mounted) setState(() { _staff = List<Map<String, dynamic>>.from(res); _isLoading = false; });
  }

  Future<void> _addStaff(String name, String role) async {
    await Supabase.instance.client.from('staff').insert({
      'salon_id': widget.shopId,
      'name': name,
      'specialty': role,
    });
    _fetch();
    if(mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text("Manage Staff", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
            IconButton(icon: const Icon(Icons.add, color: Colors.purple), onPressed: _showAddDialog)
          ]),
          const Divider(),
          Expanded(
            child: _isLoading ? const Center(child: CircularProgressIndicator()) : ListView.builder(
              itemCount: _staff.length,
              itemBuilder: (c, i) {
                final s = _staff[i];
                return ListTile(
                  title: Text(s['name']),
                  subtitle: Text(s['specialty'] ?? 'Staff'),
                  leading: CircleAvatar(child: Text(s['name'][0])),
                );
              },
            ),
          )
        ],
      ),
    );
  }

  void _showAddDialog() {
    final nCtrl = TextEditingController();
    final rCtrl = TextEditingController();
    showDialog(context: context, builder: (_) => AlertDialog(
      title: const Text("Add Staff"),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: nCtrl, decoration: const InputDecoration(labelText: "Staff Name")),
        TextField(controller: rCtrl, decoration: const InputDecoration(labelText: "Specialty (e.g. Barber)")),
      ]),
      actions: [
        TextButton(onPressed: ()=>Navigator.pop(context), child: const Text("Cancel")),
        ElevatedButton(onPressed: () => _addStaff(nCtrl.text, rCtrl.text), child: const Text("Add")),
      ],
    ));
  }
}

class _BookingCard extends StatelessWidget {
  final Map<String, dynamic> booking;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const _BookingCard({
    required this.booking,
    required this.onAccept,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final customer = booking['customer'] ?? {};
    final String fullName = customer['full_name'] ?? 'Guest';
    final String phone = customer['phone'] ?? 'N/A';
    final String initials = fullName.isNotEmpty ? fullName[0].toUpperCase() : 'C';

    final String serviceName = booking['service_name'];
    final double price = (booking['price'] as num).toDouble();
    final DateTime dt = DateTime.parse(booking['booking_date']).toLocal();
    final String dateStr = DateFormat('MMM d, h:mm a').format(dt);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 5))
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.08),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(serviceName, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)),
                    Row(
                      children: [
                        const Icon(Icons.access_time, size: 14, color: Colors.orange),
                        const SizedBox(width: 4),
                        Text(dateStr, style: GoogleFonts.poppins(color: Colors.orange[800], fontWeight: FontWeight.w600, fontSize: 13)),
                      ],
                    )
                  ],
                ),
                Text("₹${price.toStringAsFixed(0)}", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    CircleAvatar(backgroundColor: Colors.grey[800], child: Text(initials, style: const TextStyle(color: Colors.white))),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(fullName, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 15)),
                        Text(phone, style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onReject,
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Colors.red[200]!),
                          backgroundColor: Colors.red[50],
                        ),
                        child: Text("Reject", style: GoogleFonts.poppins(color: Colors.red)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: onAccept,
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
                        child: Text("Accept", style: GoogleFonts.poppins(color: Colors.white)),
                      ),
                    ),
                  ],
                )
              ],
            ),
          ),
        ],
      ),
    );
  }
}