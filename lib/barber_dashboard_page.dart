// lib/barber_dashboard_page.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'barber_shop_details_page.dart';
import 'home_page.dart';
import 'owner_home_page.dart'; // <--- 1. Import OwnerHomePage

class BarberDashboardPage extends StatefulWidget {
  const BarberDashboardPage({super.key});

  @override
  State<BarberDashboardPage> createState() => _BarberDashboardPageState();
}

class _BarberDashboardPageState extends State<BarberDashboardPage> {
  Map<String, dynamic>? _shopData;
  List<Map<String, dynamic>> _services = [];
  List<Map<String, dynamic>> _staff = [];
  bool _isShopOpen = true;
  bool _isLoading = true;

  final TextEditingController _offerCtrl = TextEditingController();
  final TextEditingController _recruitmentCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadShopData();
  }

  // --- HELPER: Extract Image from DB Array ---
  String _getFirstImage(dynamic imageUrls) {
    if (imageUrls != null && imageUrls is List && imageUrls.isNotEmpty) {
      return imageUrls[0].toString();
    }
    return '';
  }

  Future<void> _loadShopData() async {
    setState(() => _isLoading = true);
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final shopResponse = await Supabase.instance.client
          .from('barber_shops')
          .select()
          .eq('owner_id', userId)
          .maybeSingle();

      if (shopResponse == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final servicesResponse = await Supabase.instance.client
          .from('services')
          .select()
          .eq('salon_id', shopResponse['id']);

      final staffResponse = await Supabase.instance.client
          .from('staff')
          .select()
          .eq('salon_id', shopResponse['id']);

      if (mounted) {
        setState(() {
          _shopData = shopResponse;
          _services = List<Map<String, dynamic>>.from(servicesResponse);
          _staff = List<Map<String, dynamic>>.from(staffResponse);
          _isShopOpen = shopResponse['is_open'] ?? true;
          _offerCtrl.text = shopResponse['today_offer'] ?? '';
          _recruitmentCtrl.text = shopResponse['recruitment_message'] ?? '';
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading shop data: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleShopStatus(bool value) async {
    if (_shopData == null) return;
    await Supabase.instance.client
        .from('barber_shops')
        .update({'is_open': value}).eq('id', _shopData!['id']);
    setState(() => _isShopOpen = value);
  }

  Future<void> _updateOffer() async {
    if (_shopData == null) return;
    await Supabase.instance.client
        .from('barber_shops')
        .update({'today_offer': _offerCtrl.text.trim()}).eq(
        'id', _shopData!['id']);
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Offer updated!")));
    }
  }

  Future<void> _updateRecruitment() async {
    if (_shopData == null) return;
    await Supabase.instance.client
        .from('barber_shops')
        .update({'recruitment_message': _recruitmentCtrl.text.trim()}).eq(
        'id', _shopData!['id']);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Recruitment updated!")));
    }
  }

  // --- UI BUILDER ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        automaticallyImplyLeading: false,
        title: Text("Dashboard",
            style: GoogleFonts.poppins(
                color: Colors.black,
                fontSize: 24,
                fontWeight: FontWeight.bold)),
        actions: [
          // 2. UPDATED BUTTON: EYE ICON TO HOME ICON
          IconButton(
            icon: const Icon(Icons.home, color: Colors.orange), // Changed to Home
            onPressed: () {
              // 3. UPDATED NAVIGATION: Redirects to OwnerHomePage
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const OwnerHomePage()),
                    (route) => false,
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.black54),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const BarberShopDetailsPage()),
              ).then((_) => _loadShopData());
            },
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.orange))
          : _shopData == null
          ? _buildNoShopView()
          : RefreshIndicator(
        color: Colors.orange,
        onRefresh: _loadShopData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildShopHeaderCard(),
              const SizedBox(height: 24),
              _buildStatusSection(),
              const SizedBox(height: 24),
              _buildInputSection(
                "Today's Offer",
                "e.g., 20% off on Haircut",
                _offerCtrl,
                Icons.local_offer,
                _updateOffer,
              ),
              const SizedBox(height: 16),
              _buildInputSection(
                "Recruitment",
                "e.g., Looking for a specialist",
                _recruitmentCtrl,
                Icons.work,
                _updateRecruitment,
              ),
              const SizedBox(height: 24),
              _buildServicesList(),
              const SizedBox(height: 24),
              _buildStaffList(),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  // --- WIDGET COMPONENTS ---

  Widget _buildNoShopView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1), shape: BoxShape.circle),
            child: const Icon(Icons.store_outlined,
                size: 60, color: Colors.orange),
          ),
          const SizedBox(height: 20),
          Text("No Shop Found",
              style: GoogleFonts.poppins(
                  fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text("Register your salon to start managing.",
              style: GoogleFonts.poppins(color: Colors.grey)),
          const SizedBox(height: 20),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
            ),
            onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const BarberShopDetailsPage()))
                .then((_) => _loadShopData()),
            child: Text("Create Shop",
                style: GoogleFonts.poppins(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildShopHeaderCard() {
    final String imageUrl = _getFirstImage(_shopData!['image_urls']);

    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        children: [
          // Image Area
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: Container(
              height: 150,
              width: double.infinity,
              color: Colors.grey[300],
              child: imageUrl.isNotEmpty
                  ? Image.network(imageUrl, fit: BoxFit.cover)
                  : const Icon(Icons.store, size: 50, color: Colors.grey),
            ),
          ),
          // Info Area
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        _shopData!['name'],
                        style: GoogleFonts.poppins(
                            fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _isShopOpen
                            ? Colors.green.withOpacity(0.1)
                            : Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: _isShopOpen ? Colors.green : Colors.red),
                      ),
                      child: Text(
                        _isShopOpen ? "OPEN" : "CLOSED",
                        style: TextStyle(
                            color: _isShopOpen ? Colors.green : Colors.red,
                            fontWeight: FontWeight.bold,
                            fontSize: 12),
                      ),
                    )
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.location_on,
                        size: 16, color: Colors.black54),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        _shopData!['address'] ?? "No address",
                        style: GoogleFonts.poppins(
                            color: Colors.black54, fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusSection() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text("Accepting Bookings?",
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600, fontSize: 16)),
          Switch(
            value: _isShopOpen,
            activeColor: Colors.orange,
            onChanged: _toggleShopStatus,
          ),
        ],
      ),
    );
  }

  Widget _buildInputSection(String title, String hint,
      TextEditingController controller, IconData icon, VoidCallback onSave) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style:
            GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  style: GoogleFonts.poppins(fontSize: 14),
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: const TextStyle(color: Colors.black38),
                    prefixIcon: Icon(icon, color: Colors.orange, size: 20),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.save, color: Colors.green),
                onPressed: onSave,
              )
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildServicesList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("Services",
                style: GoogleFonts.poppins(
                    fontSize: 18, fontWeight: FontWeight.bold)),
            GestureDetector(
              onTap: _showAddServiceDialog,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    shape: BoxShape.circle),
                child: const Icon(Icons.add, color: Colors.orange, size: 20),
              ),
            )
          ],
        ),
        const SizedBox(height: 12),
        if (_services.isEmpty)
          const Text("No services added yet.",
              style: TextStyle(color: Colors.grey)),
        ..._services.map((service) => Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: Colors.grey[100], shape: BoxShape.circle),
                child: const Icon(Icons.content_cut,
                    size: 16, color: Colors.black54),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(service['name'],
                        style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              Text("₹${service['price']}",
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold, color: Colors.orange)),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _deleteService(service['id']),
                child: const Icon(Icons.delete_outline,
                    color: Colors.red, size: 20),
              )
            ],
          ),
        ))
      ],
    );
  }

  Widget _buildStaffList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("Staff",
                style: GoogleFonts.poppins(
                    fontSize: 18, fontWeight: FontWeight.bold)),
            GestureDetector(
              onTap: _showAddStaffDialog,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    shape: BoxShape.circle),
                child: const Icon(Icons.add, color: Colors.orange, size: 20),
              ),
            )
          ],
        ),
        const SizedBox(height: 12),
        if (_staff.isEmpty)
          const Text("No staff added yet.",
              style: TextStyle(color: Colors.grey)),
        ..._staff.map((member) => Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: Colors.orange.withOpacity(0.2),
                child: Text(member['name'][0].toUpperCase(),
                    style: const TextStyle(
                        color: Colors.orange, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(member['name'],
                        style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600)),
                    if (member['specialty'] != null)
                      Text(member['specialty'],
                          style: const TextStyle(
                              fontSize: 12, color: Colors.black54)),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => _deleteStaff(member['id']),
                child: const Icon(Icons.delete_outline,
                    color: Colors.red, size: 20),
              )
            ],
          ),
        ))
      ],
    );
  }

  // --- LOGIC DIALOGS ---

  void _showAddServiceDialog() {
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Add Service",
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: "Service Name")),
            TextField(
                controller: priceCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: "Price (₹)")),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () async {
              if (nameCtrl.text.isEmpty || priceCtrl.text.isEmpty) return;
              await Supabase.instance.client.from('services').insert({
                'salon_id': _shopData!['id'],
                'name': nameCtrl.text.trim(),
                'price': double.parse(priceCtrl.text),
              });
              Navigator.pop(ctx);
              _loadShopData();
            },
            child: const Text("Add"),
          ),
        ],
      ),
    );
  }

  void _showAddStaffDialog() {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final specialtyCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Add Staff",
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: "Name")),
            TextField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration:
                const InputDecoration(labelText: "Phone (Optional)")),
            TextField(
                controller: specialtyCtrl,
                decoration:
                const InputDecoration(labelText: "Specialty (Optional)")),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () async {
              if (nameCtrl.text.isEmpty) return;
              await Supabase.instance.client.from('staff').insert({
                'salon_id': _shopData!['id'],
                'name': nameCtrl.text.trim(),
                'phone': phoneCtrl.text.trim(),
                'specialty': specialtyCtrl.text.trim(),
              });
              Navigator.pop(ctx);
              _loadShopData();
            },
            child: const Text("Add"),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteService(int id) async {
    await Supabase.instance.client.from('services').delete().eq('id', id);
    _loadShopData();
  }

  Future<void> _deleteStaff(int id) async {
    await Supabase.instance.client.from('staff').delete().eq('id', id);
    _loadShopData();
  }
}