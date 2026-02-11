import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'salon_reviews_page.dart'; // Ensure this import exists
import 'package:share_plus/share_plus.dart';

class SalonDetailsPage extends StatefulWidget {
  final Map<String, dynamic> salon;

  const SalonDetailsPage({super.key, required this.salon});

  @override
  State<SalonDetailsPage> createState() => _SalonDetailsPageState();
}

class _SalonDetailsPageState extends State<SalonDetailsPage> {
  // --- STATE FOR REVIEWS ---
  List<Map<String, dynamic>> _reviews = [];
  bool _isLoadingReviews = true;

  @override
  void initState() {
    super.initState();
    _fetchReviewsPreview();
  }

  // Fetch only the top 3 latest reviews
  Future<void> _fetchReviewsPreview() async {
    try {
      final response = await Supabase.instance.client
          .from('reviews')
          .select('*, profiles(full_name)')
          .eq('salon_id', widget.salon['id'])
          .order('created_at', ascending: false)
          .limit(3);

      final data = List<Map<String, dynamic>>.from(response);

      if (mounted) {
        setState(() {
          _reviews = data;
          _isLoadingReviews = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading reviews: $e");
      if (mounted) setState(() => _isLoadingReviews = false);
    }
  }

  // --- ACTION BUTTON LOGIC ---

  Future<void> _launchNavigation() async {
    final lat = widget.salon['latitude'];
    final lng = widget.salon['longitude'];

    if (lat == null || lng == null) {
      final address = widget.salon['address'] ?? '';
      if (address.isNotEmpty) {
        final Uri queryUrl = Uri.parse(
            "https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(address)}");
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
    final dynamic phoneRaw = widget.salon['phone_number'] ?? widget.salon['phone'];
    final String phone = (phoneRaw?.toString() ?? '').trim();

    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Phone number not available")),
      );
      return;
    }

    // Clean phone number (remove spaces, dashes, etc. if needed)
    final cleanPhone = phone.replaceAll(RegExp(r'[\s\-\(\)]'), '');

    final Uri telUri = Uri(scheme: 'tel', path: cleanPhone);

    try {
      if (await canLaunchUrl(telUri)) {
        await launchUrl(telUri, mode: LaunchMode.externalApplication);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Cannot open phone dialer on this device")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error calling: $e")),
      );
    }
  }

  // Navigate to full reviews page
  void _goToReviewsPage() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SalonReviewsPage(
          salonId: widget.salon['id'],
          salonName: widget.salon['name'] ?? 'Salon',
        ),
      ),
    ).then((_) {
      // Optional: refresh preview reviews when coming back
      _fetchReviewsPreview();
    });
  }

  // Share salon details using share_plus
  void _shareSalon() async {
    final name = widget.salon['name'] ?? 'Salon';
    final address = widget.salon['address'] ?? 'No address';
    final phone = (widget.salon['phone_number'] ?? widget.salon['phone'] ?? '').toString().trim();
    final rating = widget.salon['rating']?.toString() ?? 'N/A';

    final shareText = '''
Check out $name!
⭐ $rating
📍 $address
📞 $phone

Book now via our app!
    '''.trim();

    try {
      await Share.share(
        shareText,
        subject: 'Discover this amazing salon!',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Couldn't share: $e")),
        );
      }
    }
  }

  // --- BOOKING POPUP LOGIC ---

  void _showBookingSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _BookingBottomSheet(salon: widget.salon),
    );
  }

  // FIXED: Safe Image Getter
  String get _displayImage {
    final dynamic images = widget.salon['image_urls'];
    if (images is List && images.isNotEmpty) {
      return images.first.toString();
    }
    return ''; // Return empty string if no image exists
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
              background: _displayImage.isNotEmpty
                  ? Image.network(
                _displayImage,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                    color: Colors.grey[200],
                    child: const Icon(Icons.store, size: 60, color: Colors.grey)),
              )
                  : Container(
                  color: Colors.grey[200],
                  child: const Icon(Icons.store, size: 60, color: Colors.grey)),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title & Rating
                  Text(widget.salon['name'] ?? 'Unknown Salon',
                      style: GoogleFonts.poppins(
                          fontSize: 24, fontWeight: FontWeight.w600, color: Colors.black87)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 18),
                      const SizedBox(width: 4),
                      Text("${widget.salon['rating'] ?? '4.5'}",
                          style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text("•  ${widget.salon['address'] ?? 'No Address'}",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(color: Colors.grey[600], fontSize: 13)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Action Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildActionButton(Icons.directions, "Directions", true, _launchNavigation),
                      _buildActionButton(Icons.call, "Call", false, _callShop),
                      _buildActionButton(Icons.star_outline, "Reviews", false, _goToReviewsPage),
                      _buildActionButton(Icons.share, "Share", false, _shareSalon),
                    ],
                  ),
                  const Divider(height: 40),

                  // About Section
                  Text("About",
                      style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(
                      "Experience world-class grooming services at ${widget.salon['name']}. We offer haircuts, shaving, spa treatments and more.",
                      style: GoogleFonts.poppins(color: Colors.grey[600], height: 1.5)),
                  const Divider(height: 40),

                  // --- REVIEWS SECTION START ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Reviews",
                          style:
                          GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
                      TextButton(
                        onPressed: _goToReviewsPage,
                        child: Text("See All",
                            style: GoogleFonts.poppins(
                                color: Colors.orange, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  if (_isLoadingReviews)
                    const Center(child: CircularProgressIndicator(color: Colors.orange))
                  else if (_reviews.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.rate_review_outlined, color: Colors.grey[400], size: 40),
                          const SizedBox(height: 8),
                          Text("No reviews yet", style: GoogleFonts.poppins(color: Colors.grey)),
                        ],
                      ),
                    )
                  else
                    Column(
                      children: _reviews.map((review) {
                        final profile = review['profiles'] ?? {};
                        final name = profile['full_name'] ?? 'Anonymous';
                        final date = DateTime.parse(review['created_at']);
                        final rating = review['rating'] as int;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey[100]!),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black.withOpacity(0.02),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4))
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 16,
                                    backgroundColor: Colors.orange.withOpacity(0.1),
                                    child: Text(name[0].toUpperCase(),
                                        style: GoogleFonts.poppins(
                                            color: Colors.orange, fontWeight: FontWeight.bold)),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(name,
                                            style: GoogleFonts.poppins(
                                                fontWeight: FontWeight.w600, fontSize: 14)),
                                        Text(DateFormat('MMM d, yyyy').format(date),
                                            style: GoogleFonts.poppins(
                                                fontSize: 11, color: Colors.grey)),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                        color: Colors.green[50],
                                        borderRadius: BorderRadius.circular(6)),
                                    child: Row(
                                      children: [
                                        Text("$rating",
                                            style: GoogleFonts.poppins(
                                                fontWeight: FontWeight.bold,
                                                color: Colors.green,
                                                fontSize: 12)),
                                        const Icon(Icons.star, size: 12, color: Colors.green),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              if (review['comment'] != null && review['comment'].isNotEmpty) ...[
                                const SizedBox(height: 10),
                                Text(
                                  review['comment'],
                                  style: GoogleFonts.poppins(color: Colors.black87, fontSize: 13, height: 1.4),
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ]
                            ],
                          ),
                        );
                      }).toList(),
                    ),

                  const SizedBox(height: 100), // Space for bottom button
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
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, -4))
          ],
        ),
        child: ElevatedButton(
          onPressed: () => _showBookingSheet(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(vertical: 18),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: Text("Book Appointment",
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600, color: Colors.white, fontSize: 16)),
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
// BOOKING BOTTOM SHEET (WITH RAZORPAY)
// ==========================================

// ==========================================
// BOOKING BOTTOM SHEET (WITH RAZORPAY)
// ==========================================

class _BookingBottomSheet extends StatefulWidget {
  final Map<String, dynamic> salon;
  const _BookingBottomSheet({required this.salon});

  @override
  State<_BookingBottomSheet> createState() => _BookingBottomSheetState();
}

class _BookingBottomSheetState extends State<_BookingBottomSheet> {
  // --- RAZORPAY INSTANCE ---
  late Razorpay _razorpay;

  // --- REPLACE THIS WITH YOUR ACTUAL RAZORPAY TEST KEY ---
  static const String razorpayKey = "rzp_test_1DP5mmOlF5G5ag"; // Example format

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
  bool _isProcessingPayment = false;

  @override
  void initState() {
    super.initState();
    // 1. Initialize Razorpay
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);

    // 2. Fetch Data
    _fetchServices();
    _fetchStaff();
    _fetchTakenSlots();
  }

  @override
  void dispose() {
    _razorpay.clear(); // Important: Clear listeners
    super.dispose();
  }

  // --- RAZORPAY HANDLERS ---

  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    debugPrint("Payment Successful: ${response.paymentId}");
    // Payment verified by Razorpay SDK. Now we save to Supabase.
    _finalizeBookingInSupabase(response.paymentId);
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    debugPrint("Payment Error: ${response.code} - ${response.message}");
    setState(() => _isProcessingPayment = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text("Payment Failed: ${response.message}"),
          backgroundColor: Colors.red
      ),
    );
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    debugPrint("External Wallet selected: ${response.walletName}");
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("External Wallet Selected: ${response.walletName}")),
    );
  }

  Future<void> _initiateRazorpay() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please login to book"))
      );
      return;
    }
    if (_selectedServices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please select at least one service"))
      );
      return;
    }
    if (_selectedSlot == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please select a time slot"))
      );
      return;
    }

    setState(() => _isProcessingPayment = true);

    double totalPrice = 0;
    for (var service in _selectedServices) {
      totalPrice += (service['price'] as num).toDouble();
    }

    // Razorpay Options
    var options = {
      'key': razorpayKey, // Uses the static const defined above
      'amount': (totalPrice * 100).toInt(), // Amount in paise (e.g. 100.00 -> 10000)
      'name': widget.salon['name'] ?? 'Salon Booking',
      'description': 'Booking for ${_selectedServices.length} services',
      'retry': {'enabled': true, 'max_count': 1},
      'send_sms_hash': true,
      'prefill': {
        'contact': user.phone ?? '', // User phone if available
        'email': user.email ?? '',   // User email
      },
      'external': {
        'wallets': ['paytm'] // Optional: limit wallets
      }
    };

    try {
      _razorpay.open(options);
    } catch (e) {
      debugPrint("Error opening Razorpay: $e");
      setState(() => _isProcessingPayment = false);
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error initiating payment: $e"))
      );
    }
  }

  // --- DATABASE LOGIC ---

  Future<void> _finalizeBookingInSupabase(String? paymentId) async {
    final user = Supabase.instance.client.auth.currentUser;

    // Safety check if widget was disposed during payment
    if (!mounted) return;

    try {
      double totalPrice = 0;
      List<String> serviceNames = [];

      for (var service in _selectedServices) {
        totalPrice += (service['price'] as num).toDouble();
        serviceNames.add(service['name']);
      }

      String finalServiceName = serviceNames.join(", ");
      if (_selectedStaff != null) {
        finalServiceName += " (with ${_selectedStaff!['name']})";
      }

      // Insert Booking
      final bookingResponse = await Supabase.instance.client.from('bookings').insert({
        'user_id': user!.id,
        'salon_id': widget.salon['id'],
        'service_name': finalServiceName,
        'price': totalPrice,
        'booking_date': _selectedSlot!.toIso8601String(),
        'status': 'upcoming',
        'payment_id': paymentId,     // Save Razorpay ID
        'payment_status': 'paid'     // Mark as Paid
      }).select('id').single();

      final int bookingId = bookingResponse['id'];

      // Send Notification to Owner (Optional - ensure table exists)
      try {
        var ownerId = widget.salon['owner_id'];
        if (ownerId != null) {
          await Supabase.instance.client.from('inbox_messages').insert({
            'user_id': ownerId,
            'salon_id': widget.salon['id'],
            'booking_id': bookingId,
            'title': 'New Paid Booking',
            'message': 'Paid booking: $finalServiceName on ${DateFormat('MMM d, h:mm a').format(_selectedSlot!)}',
            'type': 'booking_new',
            'is_read': false,
          });
        }
      } catch (e) {
        debugPrint("Notification error (non-fatal): $e");
      }

      if (mounted) {
        Navigator.pop(context); // Close sheet
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Booking & Payment Successful!"),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            )
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Database Error: $e"), backgroundColor: Colors.red)
        );
        setState(() => _isProcessingPayment = false);
      }
    }
  }

  // --- DATA FETCHING METHODS ---

  Future<void> _fetchServices() async {
    try {
      final response = await Supabase.instance.client
          .from('services')
          .select()
          .eq('salon_id', widget.salon['id']);
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
          .eq('salon_id', widget.salon['id']);
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
          .eq('salon_id', widget.salon['id'])
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

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
                primary: Colors.black, onPrimary: Colors.white, onSurface: Colors.black),
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
    // Generating slots from 10 AM to 8 PM
    for (int hour = 10; hour <= 20; hour++) {
      slots.add(DateTime(base.year, base.month, base.day, hour, 0));
    }
    return slots;
  }

  bool _isSlotTaken(DateTime slot) {
    for (var taken in _bookedSlots) {
      if (taken.year == slot.year &&
          taken.month == slot.month &&
          taken.day == slot.day &&
          taken.hour == slot.hour &&
          taken.minute == slot.minute) {
        return true;
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final slots = _generateDailySlots();
    double currentTotal = 0;
    for (var s in _selectedServices) {
      currentTotal += (s['price'] as num).toDouble();
    }

    // We use a Column inside a Container.
    // We must use Expanded/Flexible carefully to avoid overflow.
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
          // Drag handle
          Center(
            child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
          ),
          const SizedBox(height: 20),

          // 1. DATE PICKER
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Select Date & Time",
                  style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
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
          // Using Flexible to allow the grid to take available space but not force infinite height
          Flexible(
            flex: 2,
            child: _isLoadingSlots
                ? const Center(child: CircularProgressIndicator(color: Colors.orange))
                : GridView.builder(
              shrinkWrap: true,
              // Allows scrolling if slots exceed space
              physics: const BouncingScrollPhysics(),
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
                  onTap: isTaken ? null : () => setState(() => _selectedSlot = slotTime),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isTaken
                          ? Colors.grey[200]
                          : isSelected
                          ? Colors.orange
                          : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: isTaken
                              ? Colors.transparent
                              : (isSelected ? Colors.orange : Colors.grey[300]!)),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      DateFormat('h:mm a').format(slotTime),
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: isTaken
                            ? Colors.grey[400]
                            : (isSelected ? Colors.white : Colors.black87),
                        fontWeight: FontWeight.w500,
                        decoration: isTaken ? TextDecoration.lineThrough : null,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 10),

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
            Text("Select Professional",
                style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
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
                          width: 55,
                          height: 55,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isSelected ? Colors.orange.withOpacity(0.1) : Colors.grey[100],
                            border: Border.all(
                                color: isSelected ? Colors.orange : Colors.grey[300]!,
                                width: isSelected ? 2 : 1),
                          ),
                          child: Center(
                            child: Text(
                              staff['name'][0].toUpperCase(),
                              style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected ? Colors.orange : Colors.grey[600]),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(staff['name'],
                            style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                      ],
                    ),
                  );
                },
              ),
            ),
            const Divider(height: 30),
          ],

          // 4. SERVICES LIST
          Text("Select Services",
              style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),

          // Flexible ensures this takes remaining space properly
          Expanded(
            flex: 3,
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
                      border: Border.all(
                          color: isSelected ? Colors.green : Colors.grey[200]!),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(service['name'],
                                style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w600, fontSize: 15)),
                            Text("₹${service['price']}",
                                style: GoogleFonts.poppins(
                                    color: Colors.grey[600], fontSize: 13)),
                          ],
                        ),
                        Container(
                          width: 32,
                          height: 32,
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

          // 5. PAYMENT BUTTON
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isProcessingPayment ? null : _initiateRazorpay,
              style: ElevatedButton.styleFrom(
                backgroundColor: _isProcessingPayment ? Colors.grey : Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: _isProcessingPayment
                  ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text(
                  _selectedServices.isEmpty
                      ? "Select Service"
                      : "Pay & Book ₹${currentTotal.toStringAsFixed(0)}",
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600, color: Colors.white)),
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
          width: 12,
          height: 12,
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