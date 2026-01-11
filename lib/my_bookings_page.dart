import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MyBookingsPage extends StatefulWidget {
  const MyBookingsPage({super.key});

  @override
  State<MyBookingsPage> createState() => _MyBookingsPageState();
}

class _MyBookingsPageState extends State<MyBookingsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          "My Bookings",
          style: GoogleFonts.poppins(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.orange,
          labelColor: Colors.orange,
          unselectedLabelColor: Colors.black54,
          labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          tabs: const [
            Tab(text: "Upcoming"),
            Tab(text: "History"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          BookingList(statusFilter: "upcoming"),
          BookingList(statusFilter: "history"),
        ],
      ),
    );
  }
}

class BookingList extends StatefulWidget {
  final String statusFilter; // "upcoming" or "history"

  const BookingList({super.key, required this.statusFilter});

  @override
  State<BookingList> createState() => _BookingListState();
}

class _BookingListState extends State<BookingList> {
  late Future<List<Map<String, dynamic>>> _bookingsFuture;

  @override
  void initState() {
    super.initState();
    _bookingsFuture = _fetchBookings();
  }

  void _refreshList() {
    if (mounted) {
      setState(() {
        _bookingsFuture = _fetchBookings();
      });
    }
  }

  Future<List<Map<String, dynamic>>> _fetchBookings() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;

    if (userId == null) {
      return [];
    }

    try {
      List<String> statuses;
      if (widget.statusFilter == "upcoming") {
        statuses = ['upcoming', 'accepted'];
      } else {
        statuses = ['completed', 'cancelled'];
      }

      final response = await Supabase.instance.client
          .from('bookings')
          .select('*, barber_shops(name, image_urls)')
          .eq('user_id', userId)
          .filter('status', 'in', statuses)
          .order('booking_date', ascending: widget.statusFilter == 'upcoming');

      return (response as List).cast<Map<String, dynamic>>();
    } catch (e) {
      if (mounted) {
        debugPrint('Error fetching bookings: $e');
      }
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _bookingsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Colors.orange));
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final bookings = snapshot.data ?? [];

        if (bookings.isEmpty) {
          return _buildEmptyState();
        }

        return RefreshIndicator(
          color: Colors.orange,
          onRefresh: () async => _refreshList(),
          child: ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: bookings.length,
            itemBuilder: (context, index) {
              final booking = bookings[index];
              return BookingCard(
                booking: booking,
                onUpdate: _refreshList,
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            widget.statusFilter == "upcoming"
                ? Icons.event_busy_outlined
                : Icons.history,
            size: 80,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 20),
          Text(
            widget.statusFilter == "upcoming"
                ? "No upcoming bookings"
                : "No past bookings yet",
            style: GoogleFonts.poppins(
              fontSize: 18,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}

class BookingCard extends StatelessWidget {
  final Map<String, dynamic> booking;
  final VoidCallback onUpdate;

  const BookingCard({
    super.key,
    required this.booking,
    required this.onUpdate,
  });

  void _showAddServiceSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AddServiceBottomSheet(
        salonId: booking['salon_id'],
        bookingId: booking['id'],
        onSuccess: onUpdate,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final status = booking['status'] as String;
    final isCancelled = status == "cancelled";
    final isCompleted = status == "completed";
    final isAccepted = status == "accepted";
    final isUpcoming = status == "upcoming";

    // Colors
    Color statusColor;
    Color statusBgColor;
    String statusText = status.toUpperCase();

    if (isCancelled) {
      statusColor = Colors.red;
      statusBgColor = Colors.red.withOpacity(0.1);
    } else if (isCompleted) {
      statusColor = Colors.grey;
      statusBgColor = Colors.grey.withOpacity(0.2);
    } else if (isAccepted) {
      statusColor = Colors.green;
      statusBgColor = Colors.green.withOpacity(0.1);
      statusText = "CONFIRMED";
    } else {
      statusColor = Colors.orange;
      statusBgColor = Colors.orange.withOpacity(0.1);
      statusText = "PENDING";
    }

    final DateTime dateTime = DateTime.parse(booking["booking_date"]).toLocal();
    final String formattedDate = DateFormat('EEE, MMM d').format(dateTime);
    final String formattedTime = DateFormat('h:mm a').format(dateTime);

    final shopData = booking['barber_shops'] as Map<String, dynamic>? ?? {};
    final shopName = shopData['name'] ?? 'Unknown Shop';

    String shopImage = '';
    if (shopData['image_urls'] != null) {
      final List images = shopData['image_urls'] as List;
      if (images.isNotEmpty) {
        shopImage = images[0].toString();
      }
    }

    // Parse Add-ons safely
    final List<dynamic> addons = booking['addons'] != null
        ? List.from(booking['addons'])
        : [];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(
                  shopImage,
                  width: 70, height: 70, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(width: 70, height: 70, color: Colors.grey[100], child: const Icon(Icons.store, color: Colors.grey)),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      shopName,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      booking["service_name"] ?? "Service",
                      style: const TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 14, color: Colors.orange),
                        const SizedBox(width: 4),
                        Text(
                          formattedDate,
                          style: const TextStyle(color: Colors.black87, fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(width: 12),
                        const Icon(Icons.access_time, size: 14, color: Colors.orange),
                        const SizedBox(width: 4),
                        Text(
                          formattedTime,
                          style: const TextStyle(color: Colors.black87, fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          // --- ADD-ONS SECTION ---
          if (addons.isNotEmpty) ...[
            const Divider(height: 24),
            Text("Requested Add-ons:", style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 8),
            ...addons.map((addon) {
              final status = addon['status'];
              Color color = Colors.orange;
              IconData icon = Icons.access_time;
              TextDecoration decoration = TextDecoration.none;

              if (status == 'accepted') {
                color = Colors.green;
                icon = Icons.check_circle;
              } else if (status == 'rejected') {
                color = Colors.red;
                icon = Icons.cancel;
                decoration = TextDecoration.lineThrough;
              }

              return Padding(
                padding: const EdgeInsets.only(bottom: 4.0),
                child: Row(
                  children: [
                    Icon(icon, size: 14, color: color),
                    const SizedBox(width: 6),
                    Text(
                      "${addon['name']} (+₹${addon['price']})",
                      style: GoogleFonts.poppins(fontSize: 13, decoration: decoration, color: Colors.black87),
                    ),
                    const Spacer(),
                    Text(
                      status.toString().toUpperCase(),
                      style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: color),
                    )
                  ],
                ),
              );
            }),
          ],

          const SizedBox(height: 16),

          Row(
            children: [
              Text(
                "₹${(booking["price"] as num).toStringAsFixed(0)}",
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const Spacer(),

              // --- ADD SERVICE BUTTON (Only for Upcoming/Accepted) ---
              if (isUpcoming || isAccepted)
                Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: InkWell(
                    onTap: () => _showAddServiceSheet(context),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.blue[100]!),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.add, size: 16, color: Colors.blue),
                          const SizedBox(width: 4),
                          Text("Add Service", style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.blue)),
                        ],
                      ),
                    ),
                  ),
                ),

              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusBgColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  statusText,
                  style: GoogleFonts.poppins(
                    color: statusColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ========================================================
// SHEET: ADD SERVICE TO EXISTING BOOKING
// ========================================================

class _AddServiceBottomSheet extends StatefulWidget {
  final int salonId;
  final int bookingId;
  final VoidCallback onSuccess;

  const _AddServiceBottomSheet({
    required this.salonId,
    required this.bookingId,
    required this.onSuccess,
  });

  @override
  State<_AddServiceBottomSheet> createState() => _AddServiceBottomSheetState();
}

class _AddServiceBottomSheetState extends State<_AddServiceBottomSheet> {
  List<Map<String, dynamic>> _services = [];
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _fetchServices();
  }

  Future<void> _fetchServices() async {
    try {
      final response = await Supabase.instance.client
          .from('services')
          .select()
          .eq('salon_id', widget.salonId);

      if (mounted) {
        setState(() {
          _services = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Update this function in your Customer App's Add-on sheet
  Future<void> _addServiceToBooking(Map<String, dynamic> service) async {
    setState(() => _isSaving = true);

    try {
      // 1. Get the current addons array
      final res = await Supabase.instance.client
          .from('bookings')
          .select('addons')
          .eq('id', widget.bookingId)
          .single();

      // Ensure we are working with a List
      List<dynamic> currentAddons = [];
      if (res['addons'] != null && res['addons'] is List) {
        currentAddons = List.from(res['addons']);
      }

      // 2. Create a simple map for the addon
      final Map<String, dynamic> addonData = {
        "name": service['name'],
        "price": service['price'],
        "status": "pending"
      };

      currentAddons.add(addonData);

      // 3. Update Supabase
      await Supabase.instance.client
          .from('bookings')
          .update({'addons': currentAddons})
          .eq('id', widget.bookingId);

      if (mounted) {
        Navigator.pop(context);
        widget.onSuccess();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Add-on Requested!"), backgroundColor: Colors.orange),
        );
      }
    } catch (e) {
      debugPrint("Update Error: $e");
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
          ),
          const SizedBox(height: 20),

          Text("Add Service", style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text("Select a service to add to this booking", style: GoogleFonts.poppins(color: Colors.grey)),
          const SizedBox(height: 16),

          if (_isSaving)
            const Expanded(child: Center(child: CircularProgressIndicator(color: Colors.orange)))
          else if (_isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator(color: Colors.orange)))
          else if (_services.isEmpty)
              const Expanded(child: Center(child: Text("No extra services available")))
            else
              Expanded(
                child: ListView.separated(
                  itemCount: _services.length,
                  separatorBuilder: (c, i) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final service = _services[index];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.grey[200]!)
                      ),
                      title: Text(service['name'], style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text("₹${service['price']}", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                          const SizedBox(width: 10),
                          const Icon(Icons.add_circle_outline, color: Colors.orange),
                        ],
                      ),
                      onTap: () => _addServiceToBooking(service),
                    );
                  },
                ),
              ),
        ],
      ),
    );
  }
}