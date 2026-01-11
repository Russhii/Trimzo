import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'barber_shop_details_page.dart';
import 'profile_page.dart';

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
        physics: const NeverScrollableScrollPhysics(),
        children: const [
          _DashboardTab(),        // 0: Requests
          _AcceptedBookingsTab(), // 1: Schedule (WITH ADD-ON LOGIC)
          _MyShopTab(),           // 2: Manage Shop
          ProfilePage(),          // 3: Profile
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
          selectedLabelStyle:
          GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w500),
          unselectedLabelStyle: GoogleFonts.poppins(fontSize: 10),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_outlined),
              activeIcon: Icon(Icons.dashboard),
              label: 'Requests',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.calendar_month_outlined),
              activeIcon: Icon(Icons.calendar_month),
              label: 'Schedule',
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
// TAB 1: DASHBOARD (Incoming Requests)
// =======================================================

class _DashboardTab extends StatefulWidget {
  const _DashboardTab();

  @override
  State<_DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<_DashboardTab> {
  List<Map<String, dynamic>> _shops = [];
  Map<String, dynamic>? _selectedShop;
  List<Map<String, dynamic>> _bookings = [];
  bool _isLoading = true;
  bool _isBookingsLoading = false;
  bool _isShopOpen = false;
  final TextEditingController _offerCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadAllShops();
  }

  Future<void> _loadAllShops() async {
    setState(() => _isLoading = true);
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final response = await Supabase.instance.client
          .from('barber_shops')
          .select()
          .eq('owner_id', userId)
          .order('created_at');

      final List<Map<String, dynamic>> shops =
      List<Map<String, dynamic>>.from(response);

      if (mounted) {
        setState(() {
          _shops = shops;
          if (_selectedShop == null && shops.isNotEmpty) {
            _selectShop(shops.first);
          } else if (_selectedShop != null) {
            final updated = shops.firstWhere(
                  (s) => s['id'] == _selectedShop!['id'],
              orElse: () => shops.first,
            );
            _selectShop(updated);
          } else {
            _isLoading = false;
          }
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _selectShop(Map<String, dynamic> shop) {
    setState(() {
      _selectedShop = shop;
      _isLoading = false;
      _isShopOpen = shop['is_open'] ?? false;
      _offerCtrl.text = shop['today_offer'] ?? '';
    });
    _loadBookingsForShop(shop['id']);
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

      final List<Map<String, dynamic>> rawBookings =
      List<Map<String, dynamic>>.from(bookingsResponse);

      List<Map<String, dynamic>> mergedBookings = [];

      if (rawBookings.isNotEmpty) {
        final userIds = rawBookings.map((b) => b['user_id']).toSet().toList();

        final profilesResponse = await Supabase.instance.client
            .from('profiles')
            .select()
            .filter('id', 'in', userIds);

        final List<Map<String, dynamic>> profiles = List<Map<String, dynamic>>.from(profilesResponse);

        mergedBookings = rawBookings.map((booking) {
          final profile = profiles.firstWhere(
                (p) => p['id'] == booking['user_id'],
            orElse: () => <String, dynamic>{},
          );
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
      debugPrint('Error loading bookings: $e');
      if (mounted) setState(() => _isBookingsLoading = false);
    }
  }

  Future<void> _updateBookingStatus(int bookingId, String status) async {
    try {
      await Supabase.instance.client
          .from('bookings')
          .update({'status': status}).eq('id', bookingId);

      setState(() {
        _bookings.removeWhere((b) => b['id'] == bookingId);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(status == 'cancelled' ? 'Request Rejected' : 'Booking Accepted!'),
          backgroundColor: status == 'cancelled' ? Colors.red : Colors.green,
          duration: const Duration(seconds: 1),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Error updating booking")));
      }
    }
  }

  Future<void> _toggleStatus(bool value) async {
    if (_selectedShop == null) return;
    setState(() => _isShopOpen = value);
    await Supabase.instance.client
        .from('barber_shops')
        .update({'is_open': value}).eq('id', _selectedShop!['id']);
  }

  Future<void> _updateOffer() async {
    if (_selectedShop == null) return;
    await Supabase.instance.client
        .from('barber_shops')
        .update({'today_offer': _offerCtrl.text.trim()}).eq(
        'id', _selectedShop!['id']);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Offer updated!")));
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator(color: Colors.orange));
    if (_shops.isEmpty) return _NoShopWidget(onRefresh: _loadAllShops);

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
              Text(_selectedShop!['name'], style: GoogleFonts.poppins(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
              const Icon(Icons.keyboard_arrow_down, color: Colors.orange),
            ],
          ),
        ),
      ),
      body: SingleChildScrollView(
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
                  Text(_isShopOpen ? "SHOP ONLINE" : "SHOP OFFLINE",
                      style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
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
                  onPressed: () => _loadBookingsForShop(_selectedShop!['id']),
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
                  itemCount: _shops.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final shop = _shops[index];
                    return ListTile(
                      title: Text(shop['name']),
                      selected: shop['id'] == _selectedShop?['id'],
                      selectedColor: Colors.orange,
                      onTap: () {
                        _selectShop(shop);
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

class _AcceptedBookingsTab extends StatefulWidget {
  const _AcceptedBookingsTab();

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

  Future<void> _fetchAcceptedBookings() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final shopsRes = await Supabase.instance.client
          .from('barber_shops')
          .select('id')
          .eq('owner_id', userId);

      final shopIds = (shopsRes as List).map((s) => s['id']).toList();

      if (shopIds.isEmpty) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final response = await Supabase.instance.client
          .from('bookings')
          .select('*, barber_shops(name)')
          .filter('salon_id', 'in', shopIds)
          .eq('status', 'accepted')
          .order('booking_date', ascending: true);

      final raw = List<Map<String, dynamic>>.from(response);

      List<Map<String, dynamic>> merged = [];
      if (raw.isNotEmpty) {
        final userIds = raw.map((b) => b['user_id']).toSet().toList();
        final profilesRes = await Supabase.instance.client
            .from('profiles')
            .select()
            .filter('id', 'in', userIds);

        final profiles = List<Map<String, dynamic>>.from(profilesRes);

        merged = raw.map((b) {
          final profile = profiles
              .firstWhere((p) => p['id'] == b['user_id'], orElse: () => {});
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

  Future<void> _updateAddonStatus(int bookingId, List<dynamic> currentAddons,
      int addonIndex, bool isAccepted) async {
    currentAddons[addonIndex]['status'] = isAccepted ? 'accepted' : 'rejected';

    await Supabase.instance.client
        .from('bookings')
        .update({'addons': currentAddons}).eq('id', bookingId);

    _fetchAcceptedBookings();

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(isAccepted ? "Add-on Confirmed" : "Add-on Rejected"),
      backgroundColor: isAccepted ? Colors.green : Colors.red,
      behavior: SnackBarBehavior.floating,
    ));
  }

  Future<void> _markCompleted(int id) async {
    await Supabase.instance.client
        .from('bookings')
        .update({'status': 'completed'}).eq('id', id);
    _fetchAcceptedBookings();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB), // Very light grey background
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Schedule",
                style: GoogleFonts.poppins(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 22)),
            Text("Upcoming appointments",
                style: GoogleFonts.poppins(color: Colors.grey, fontSize: 12)),
          ],
        ),
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  shape: BoxShape.circle),
              child: const Icon(Icons.refresh, color: Colors.orange, size: 20),
            ),
            onPressed: _fetchAcceptedBookings,
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.orange))
          : _acceptedBookings.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.calendar_today_outlined,
                size: 60, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text("No appointments yet",
                style: GoogleFonts.poppins(color: Colors.grey)),
          ],
        ),
      )
          : ListView.separated(
        padding: const EdgeInsets.all(20),
        itemCount: _acceptedBookings.length,
        separatorBuilder: (c, i) => const SizedBox(height: 20),
        itemBuilder: (context, index) {
          final booking = _acceptedBookings[index];
          final customer = booking['customer'] ?? {};
          final dt =
          DateTime.parse(booking['booking_date']).toLocal();
          final dateStr = DateFormat('MMM d').format(dt);
          final timeStr = DateFormat('h:mm a').format(dt);
          final String fullName = customer['full_name'] ?? 'Guest';
          final String initials = fullName.isNotEmpty
              ? fullName.substring(0, 1).toUpperCase()
              : 'C';

          final List<dynamic> addons = booking['addons'] != null
              ? List.from(booking['addons'])
              : [];

          // Check if any addon is pending
          final bool hasPendingAddon =
          addons.any((a) => a['status'] == 'pending');

          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                )
              ],
            ),
            child: Column(
              children: [
                // --- 1. HEADER: Time & Status ---
                if (hasPendingAddon)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        vertical: 8, horizontal: 16),
                    decoration: const BoxDecoration(
                      color: Color(0xFFFFEBD4), // Soft Orange
                      borderRadius: BorderRadius.vertical(
                          top: Radius.circular(24)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.notifications_active,
                            color: Colors.orange, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          "New Add-on Requested",
                          style: GoogleFonts.poppins(
                            color: Colors.orange[900],
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),

                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // --- 2. CUSTOMER INFO ROW ---
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Avatar
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: Colors.grey[900],
                              borderRadius: BorderRadius.circular(16),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              initials,
                              style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 20),
                            ),
                          ),
                          const SizedBox(width: 16),
                          // Name & Service
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                              CrossAxisAlignment.start,
                              children: [
                                Text(
                                  fullName,
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  booking['service_name'],
                                  style: GoogleFonts.poppins(
                                    color: Colors.grey[600],
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Time Pill
                          Column(
                            crossAxisAlignment:
                            CrossAxisAlignment.end,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.blue[50],
                                  borderRadius:
                                  BorderRadius.circular(10),
                                ),
                                child: Text(
                                  timeStr,
                                  style: GoogleFonts.poppins(
                                    color: Colors.blue[700],
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(dateStr,
                                  style: GoogleFonts.poppins(
                                      color: Colors.grey,
                                      fontSize: 11)),
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // --- 3. ADD-ONS SECTION (Modernized) ---
                      if (addons.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(bottom: 20),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: Colors.grey[200]!),
                          ),
                          child: Column(
                            children: addons
                                .asMap()
                                .entries
                                .map((entry) {
                              int idx = entry.key;
                              Map addon = entry.value;
                              bool isPending =
                                  addon['status'] == 'pending';
                              bool isLast =
                                  idx == addons.length - 1;

                              return Column(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Row(
                                      children: [
                                        // Icon representing "extra"
                                        Container(
                                          padding:
                                          const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                              color: Colors.white,
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                  color: Colors.grey[
                                                  200]!)),
                                          child: const Icon(
                                              Icons.add_link,
                                              size: 16,
                                              color: Colors.black),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                            CrossAxisAlignment
                                                .start,
                                            children: [
                                              Text(addon['name'],
                                                  style: GoogleFonts.poppins(
                                                      fontWeight:
                                                      FontWeight
                                                          .w600,
                                                      fontSize: 13)),
                                              Text(
                                                  "+₹${addon['price']}",
                                                  style: GoogleFonts.poppins(
                                                      fontSize: 11,
                                                      color: Colors
                                                          .grey)),
                                            ],
                                          ),
                                        ),
                                        // Actions
                                        if (isPending) ...[
                                          _buildModernActionButton(
                                            icon: Icons.close,
                                            color: Colors.red,
                                            onTap: () =>
                                                _updateAddonStatus(
                                                    booking['id'],
                                                    addons,
                                                    idx,
                                                    false),
                                          ),
                                          const SizedBox(width: 10),
                                          _buildModernActionButton(
                                            icon: Icons.check,
                                            color: Colors.green,
                                            onTap: () =>
                                                _updateAddonStatus(
                                                    booking['id'],
                                                    addons,
                                                    idx,
                                                    true),
                                          ),
                                        ] else
                                          _buildStatusBadge(
                                              addon['status']),
                                      ],
                                    ),
                                  ),
                                  if (!isLast)
                                    Divider(
                                        height: 1,
                                        color: Colors.grey[200]),
                                ],
                              );
                            }).toList(),
                          ),
                        ),

                      // --- 4. FOOTER: Total & Complete ---
                      Row(
                        mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment:
                            CrossAxisAlignment.start,
                            children: [
                              Text("Total Payment",
                                  style: GoogleFonts.poppins(
                                      color: Colors.grey,
                                      fontSize: 11)),
                              Text(
                                  "₹${(booking['price'] as num).toDouble().toStringAsFixed(0)}",
                                  style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 20)),
                            ],
                          ),
                          ElevatedButton.icon(
                            onPressed: () =>
                                _markCompleted(booking['id']),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                BorderRadius.circular(12),
                              ),
                            ),
                            icon: const Icon(Icons.check_circle,
                                size: 18, color: Colors.white),
                            label: Text("Complete",
                                style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white)),
                          ),
                        ],
                      )
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // --- Helper Widget: Modern Action Button (Square with Soft Background) ---
  Widget _buildModernActionButton(
      {required IconData icon,
        required Color color,
        required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }

  // --- Helper Widget: Status Badge for Processed Addons ---
  Widget _buildStatusBadge(String status) {
    bool accepted = status == 'accepted';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: accepted
            ? Colors.green.withOpacity(0.1)
            : Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: accepted
                ? Colors.green.withOpacity(0.2)
                : Colors.red.withOpacity(0.2)),
      ),
      child: Text(
        accepted ? "ADDED" : "REJECTED",
        style: GoogleFonts.poppins(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: accepted ? Colors.green[700] : Colors.red[700],
        ),
      ),
    );
  }
}

// =======================================================
// WIDGET: BOOKING CARD (Dashboard Requests)
// =======================================================

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

// =======================================================
// TAB 3: MY SHOP (Connected to Supabase)
// =======================================================

// =======================================================
// TAB 3: MY SHOP (Updated Revenue Logic)
// =======================================================

class _MyShopTab extends StatefulWidget {
  const _MyShopTab();

  @override
  State<_MyShopTab> createState() => _MyShopTabState();
}

class _MyShopTabState extends State<_MyShopTab> {
  Map<String, dynamic>? _shopData;
  bool _isLoading = true;
  int _totalBookings = 0;
  double _totalRevenue = 0.0;

  @override
  void initState() {
    super.initState();
    _fetchShopData();
  }

  Future<void> _fetchShopData() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      // 1. Fetch Shop Details
      final shopResponse = await Supabase.instance.client
          .from('barber_shops')
          .select()
          .eq('owner_id', userId)
          .order('created_at')
          .limit(1)
          .single();

      final shopId = shopResponse['id'];

      // 2. Fetch Bookings (Get price, status, AND addons)
      final bookingsResponse = await Supabase.instance.client
          .from('bookings')
          .select('price, status, addons') // Requesting addons column
          .eq('salon_id', shopId)
          .neq('status', 'cancelled');

      final List<dynamic> bookingsList = bookingsResponse;

      // Count: All valid bookings (Upcoming + Accepted + Completed)
      int count = bookingsList.length;

      double revenue = 0.0;

      for (var b in bookingsList) {
        // --- NEW REVENUE LOGIC ---
        // Only count revenue if the service is fully COMPLETED
        if (b['status'] == 'completed') {

          // 1. Add Base Service Price
          revenue += (b['price'] as num).toDouble();

          // 2. Add Price of Accepted Add-ons
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
          _shopData = shopResponse;
          _totalBookings = count;
          _totalRevenue = revenue;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading shop data: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ... (Rest of the UI code remains the same, included below for completeness) ...

  void _openServiceManager(BuildContext context, int shopId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => _ManageServicesSheet(shopId: shopId),
    );
  }

  void _openStaffManager(BuildContext context, int shopId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => _ManageStaffSheet(shopId: shopId),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Colors.orange));
    }

    if (_shopData == null) {
      return _NoShopWidget(onRefresh: _fetchShopData);
    }

    String imageUrl = '';
    if (_shopData!['image_urls'] != null &&
        (_shopData!['image_urls'] as List).isNotEmpty) {
      imageUrl = _shopData!['image_urls'][0];
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text("My Shop",
            style: GoogleFonts.poppins(
                color: Colors.black, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.orange),
            onPressed: _fetchShopData, // Allows manual refresh to see updated revenue
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Shop Header Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4))
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(15),
                      image: imageUrl.isNotEmpty
                          ? DecorationImage(
                          image: NetworkImage(imageUrl), fit: BoxFit.cover)
                          : null,
                    ),
                    child: imageUrl.isEmpty
                        ? const Icon(Icons.store, size: 30, color: Colors.grey)
                        : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_shopData!['name'],
                            style: GoogleFonts.poppins(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(_shopData!['address'] ?? 'No Address',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                                fontSize: 12, color: Colors.grey)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.star, size: 14, color: Colors.amber),
                            Text(" ${_shopData!['rating'] ?? 0.0}",
                                style: const TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        )
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Stats Row
            Row(
              children: [
                Expanded(
                    child: _buildStatCard("Total Bookings", "$_totalBookings",
                        Icons.calendar_today)),
                const SizedBox(width: 12),
                Expanded(
                    child: _buildStatCard("Revenue",
                        "₹${_totalRevenue.toStringAsFixed(0)}", Icons.currency_rupee)),
              ],
            ),

            const SizedBox(height: 24),
            Text("Manage",
                style: GoogleFonts.poppins(
                    fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),

            // Grid Menu
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.5,
              children: [
                _buildMenuCard(
                  icon: Icons.content_cut,
                  title: "Services",
                  color: Colors.blue,
                  onTap: () => _openServiceManager(context, _shopData!['id']),
                ),
                _buildMenuCard(
                  icon: Icons.people_outline,
                  title: "Staff",
                  color: Colors.purple,
                  onTap: () => _openStaffManager(context, _shopData!['id']),
                ),
                _buildMenuCard(
                  icon: Icons.access_time,
                  title: "Opening Hours",
                  color: Colors.orange,
                  onTap: () {},
                ),
                _buildMenuCard(
                  icon: Icons.edit,
                  title: "Edit Details",
                  color: Colors.green,
                  onTap: () {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const BarberShopDetailsPage()))
                        .then((_) => _fetchShopData());
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.grey),
          const SizedBox(height: 12),
          Text(value,
              style: GoogleFonts.poppins(
                  fontSize: 20, fontWeight: FontWeight.bold)),
          Text(title,
              style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildMenuCard(
      {required IconData icon,
        required String title,
        required Color color,
        required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: color.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 12),
            Text(title,
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600, fontSize: 14)),
          ],
        ),
      ),
    );
  }
}

// --- HELPER SHEET 1: MANAGE SERVICES ---
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

// --- HELPER SHEET 2: MANAGE STAFF ---
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
              Navigator.push(context, MaterialPageRoute(builder: (_) => const BarberShopDetailsPage())).then((_) => onRefresh());
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text("Create My First Shop", style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }
}