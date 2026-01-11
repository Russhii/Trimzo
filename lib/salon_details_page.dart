import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

class SalonDetailsPage extends StatefulWidget {
  final Map<String, dynamic> salon;

  const SalonDetailsPage({super.key, required this.salon});

  @override
  State<SalonDetailsPage> createState() => _SalonDetailsPageState();
}

class _SalonDetailsPageState extends State<SalonDetailsPage> {

  // --- ACTION BUTTON LOGIC ---

  Future<void> _launchNavigation() async {
    final lat = widget.salon['latitude'];
    final lng = widget.salon['longitude'];

    if (lat == null || lng == null) {
      final address = widget.salon['address'] ?? '';
      if(address.isNotEmpty) {
        final Uri queryUrl = Uri.parse("https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(address)}");
        await launchUrl(queryUrl, mode: LaunchMode.externalApplication);
      }
      return;
    }

    final Uri googleMapsUrl = Uri.parse("google.navigation:q=$lat,$lng&mode=d");
    if (await canLaunchUrl(googleMapsUrl)) {
      await launchUrl(googleMapsUrl);
    } else {
      final webUrl = Uri.parse("https://www.google.com/maps/dir/?api=1&destination=$lat,$lng");
      await launchUrl(webUrl, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _callShop() async {
    final phone = widget.salon['phone_number'] ?? widget.salon['phone'];
    if (phone == null || phone.toString().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Phone number not available")));
      return;
    }

    final Uri launchUri = Uri(scheme: 'tel', path: phone.toString());
    if (await canLaunchUrl(launchUri)) await launchUrl(launchUri);
  }

  void _shareSalon() {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Share feature requires share_plus package")));
  }

  // --- BOOKING POPUP LOGIC ---

  void _showBookingSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _BookingBottomSheet(salonId: widget.salon['id']),
    );
  }

  String get _displayImage {
    if (widget.salon['image_urls'] != null) {
      final List images = widget.salon['image_urls'] as List;
      if (images.isNotEmpty) {
        return images[0].toString();
      }
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 250.0,
            pinned: true,
            backgroundColor: Colors.white,
            elevation: 0,
            leading: Container(
              margin: const EdgeInsets.all(8),
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.black),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            actions: [
              Container(
                margin: const EdgeInsets.all(8),
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                child: IconButton(
                  icon: const Icon(Icons.share, color: Colors.black),
                  onPressed: _shareSalon,
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Image.network(
                _displayImage,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(color: Colors.grey[200], child: const Icon(Icons.store, size: 60, color: Colors.grey)),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.salon['name'] ?? 'Unknown Salon',
                      style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.w600, color: Colors.black87)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 18),
                      const SizedBox(width: 4),
                      Text("${widget.salon['rating'] ?? '4.5'}", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text("•  ${widget.salon['address'] ?? 'No Address'}",
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(color: Colors.grey[600], fontSize: 13)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildActionButton(Icons.directions, "Directions", true, _launchNavigation),
                      _buildActionButton(Icons.call, "Call", false, _callShop),
                      _buildActionButton(Icons.star_outline, "Reviews", false, () {}),
                      _buildActionButton(Icons.share, "Share", false, _shareSalon),
                    ],
                  ),
                  const Divider(height: 40),
                  Text("About", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text("Experience world-class grooming services at ${widget.salon['name']}. We offer haircuts, shaving, spa treatments and more.",
                      style: GoogleFonts.poppins(color: Colors.grey[600], height: 1.5)),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -4))],
        ),
        child: ElevatedButton(
          onPressed: () => _showBookingSheet(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(vertical: 18),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: Text("Book Appointment",
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.white, fontSize: 16)),
        ),
      ),
    );
  }

  Widget _buildActionButton(IconData icon, String label, bool isPrimary, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isPrimary ? Colors.blue[50] : Colors.grey[50],
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: isPrimary ? Colors.blue : Colors.black87, size: 24),
          ),
          const SizedBox(height: 8),
          Text(label, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

// ==========================================
// BOOKING BOTTOM SHEET (MULTI-SELECT ENABLED)
// ==========================================

// ==========================================
// BOOKING BOTTOM SHEET (WITH PLUS BUTTON)
// ==========================================

class _BookingBottomSheet extends StatefulWidget {
  final int salonId;
  const _BookingBottomSheet({required this.salonId});

  @override
  State<_BookingBottomSheet> createState() => _BookingBottomSheetState();
}

class _BookingBottomSheetState extends State<_BookingBottomSheet> {
  // Data
  List<Map<String, dynamic>> _services = [];
  List<Map<String, dynamic>> _staff = [];

  // Selections
  final Set<Map<String, dynamic>> _selectedServices = {};
  Map<String, dynamic>? _selectedStaff;

  // Slot Management
  DateTime _selectedDate = DateTime.now();
  DateTime? _selectedSlot;
  List<DateTime> _bookedSlots = [];

  bool _isLoadingServices = true;
  bool _isLoadingStaff = true;
  bool _isLoadingSlots = false;
  bool _isBookingProcess = false;

  @override
  void initState() {
    super.initState();
    _fetchServices();
    _fetchStaff();
    _fetchTakenSlots();
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
          _isLoadingServices = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingServices = false);
    }
  }

  Future<void> _fetchStaff() async {
    try {
      final response = await Supabase.instance.client
          .from('staff')
          .select()
          .eq('salon_id', widget.salonId);
      if (mounted) {
        setState(() {
          _staff = List<Map<String, dynamic>>.from(response);
          _isLoadingStaff = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingStaff = false);
    }
  }

  Future<void> _fetchTakenSlots() async {
    setState(() => _isLoadingSlots = true);
    final startOfDay = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    final endOfDay = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, 23, 59, 59);

    try {
      final response = await Supabase.instance.client
          .from('bookings')
          .select('booking_date')
          .eq('salon_id', widget.salonId)
          .neq('status', 'cancelled')
          .gte('booking_date', startOfDay.toIso8601String())
          .lte('booking_date', endOfDay.toIso8601String());

      final List<dynamic> data = response as List<dynamic>;
      List<DateTime> taken = [];
      for (var item in data) {
        final dt = DateTime.parse(item['booking_date']).toLocal();
        taken.add(dt);
      }

      if (mounted) {
        setState(() {
          _bookedSlots = taken;
          _isLoadingSlots = false;
          _selectedSlot = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingSlots = false);
    }
  }

  Future<void> _confirmBooking() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please login to book")));
      return;
    }
    if (_selectedServices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select at least one service")));
      return;
    }
    if (_selectedSlot == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select a time slot")));
      return;
    }

    setState(() => _isBookingProcess = true);

    try {
      double totalPrice = 0;
      List<String> serviceNames = [];

      for(var service in _selectedServices) {
        totalPrice += (service['price'] as num).toDouble();
        serviceNames.add(service['name']);
      }

      String finalServiceName = serviceNames.join(", ");
      if (_selectedStaff != null) {
        finalServiceName += " (with ${_selectedStaff!['name']})";
      }

      await Supabase.instance.client.from('bookings').insert({
        'user_id': user.id,
        'salon_id': widget.salonId,
        'service_name': finalServiceName,
        'price': totalPrice,
        'booking_date': _selectedSlot!.toIso8601String(),
        'status': 'upcoming'
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Booking Confirmed!"), backgroundColor: Colors.green)
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
        setState(() => _isBookingProcess = false);
      }
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: Colors.black, onPrimary: Colors.white, onSurface: Colors.black),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
      _fetchTakenSlots();
    }
  }

  List<DateTime> _generateDailySlots() {
    List<DateTime> slots = [];
    final base = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    for (int hour = 10; hour <= 20; hour++) {
      slots.add(DateTime(base.year, base.month, base.day, hour, 0));
    }
    return slots;
  }

  bool _isSlotTaken(DateTime slot) {
    for (var taken in _bookedSlots) {
      if (taken.year == slot.year && taken.month == slot.month &&
          taken.day == slot.day && taken.hour == slot.hour && taken.minute == slot.minute) {
        return true;
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final slots = _generateDailySlots();

    // Calculate total
    double currentTotal = 0;
    for(var s in _selectedServices) {
      currentTotal += (s['price'] as num).toDouble();
    }

    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))
            ),
          ),
          const SizedBox(height: 20),

          // 1. DATE PICKER
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Select Date & Time", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
              TextButton.icon(
                onPressed: _pickDate,
                icon: const Icon(Icons.calendar_today, size: 16, color: Colors.orange),
                label: Text(DateFormat('EEE, MMM d').format(_selectedDate),
                    style: GoogleFonts.poppins(color: Colors.black, fontWeight: FontWeight.w600)),
              )
            ],
          ),
          const SizedBox(height: 10),

          // 2. SLOT GRID
          _isLoadingSlots
              ? const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: Colors.orange)))
              : Expanded(
            flex: 0,
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                childAspectRatio: 2.2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: slots.length,
              itemBuilder: (context, index) {
                final slotTime = slots[index];
                final isTaken = _isSlotTaken(slotTime);
                final isSelected = _selectedSlot == slotTime;

                return GestureDetector(
                  onTap: isTaken
                      ? null
                      : () => setState(() => _selectedSlot = slotTime),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isTaken ? Colors.grey[200] : isSelected ? Colors.orange : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: isTaken ? Colors.transparent : (isSelected ? Colors.orange : Colors.grey[300]!)
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      DateFormat('h:mm a').format(slotTime),
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: isTaken ? Colors.grey[400] : (isSelected ? Colors.white : Colors.black87),
                        fontWeight: FontWeight.w500,
                        decoration: isTaken ? TextDecoration.lineThrough : null,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 20),

          // Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendDot(Colors.white, "Available", true),
              const SizedBox(width: 16),
              _buildLegendDot(Colors.orange, "Selected", false),
              const SizedBox(width: 16),
              _buildLegendDot(Colors.grey[200]!, "Booked", false),
            ],
          ),

          const Divider(height: 30),

          // 3. STAFF SELECTION
          if (!_isLoadingStaff && _staff.isNotEmpty) ...[
            Text("Select Professional", style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            SizedBox(
              height: 90,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _staff.length,
                separatorBuilder: (c, i) => const SizedBox(width: 16),
                itemBuilder: (context, index) {
                  final staff = _staff[index];
                  final isSelected = _selectedStaff == staff;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedStaff = staff),
                    child: Column(
                      children: [
                        Container(
                          width: 55, height: 55,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isSelected ? Colors.orange.withOpacity(0.1) : Colors.grey[100],
                            border: Border.all(
                                color: isSelected ? Colors.orange : Colors.grey[300]!,
                                width: isSelected ? 2 : 1
                            ),
                          ),
                          child: Center(
                            child: Text(
                              staff['name'][0].toUpperCase(),
                              style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected ? Colors.orange : Colors.grey[600]
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                            staff['name'],
                            style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal
                            )
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const Divider(height: 30),
          ],

          // 4. SERVICES LIST (With Plus Button)
          Text("Select Services", style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),

          Expanded(
            child: _isLoadingServices
                ? const Center(child: CircularProgressIndicator(color: Colors.orange))
                : _services.isEmpty
                ? const Center(child: Text("No services found"))
                : ListView.separated(
              itemCount: _services.length,
              separatorBuilder: (c, i) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final service = _services[index];
                final isSelected = _selectedServices.contains(service);

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      if (isSelected) {
                        _selectedServices.remove(service);
                      } else {
                        _selectedServices.add(service);
                      }
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.green.withOpacity(0.05) : Colors.white,
                      border: Border.all(color: isSelected ? Colors.green : Colors.grey[200]!),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(service['name'], style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15)),
                            Text("₹${service['price']}", style: GoogleFonts.poppins(color: Colors.grey[600], fontSize: 13)),
                          ],
                        ),

                        // --- THE PLUS BUTTON ---
                        Container(
                          width: 32, height: 32,
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.green : Colors.black,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isSelected ? Icons.check : Icons.add,
                            color: Colors.white,
                            size: 18,
                          ),
                        )
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // 5. CONFIRM BUTTON
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isBookingProcess ? null : _confirmBooking,
              style: ElevatedButton.styleFrom(
                backgroundColor: _isBookingProcess ? Colors.grey : Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: _isBookingProcess
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text(
                  _selectedServices.isEmpty
                      ? "Select Service"
                      : "Book for ₹${currentTotal.toStringAsFixed(0)}",
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.white)
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _buildLegendDot(Color color, String label, bool border) {
    return Row(
      children: [
        Container(
          width: 12, height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: border ? Border.all(color: Colors.grey[400]!) : null,
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600])),
      ],
    );
  }
}