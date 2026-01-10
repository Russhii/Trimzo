// lib/barber_shop_details_page.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'map_page.dart'; // Must return Map<String, dynamic> with 'address', 'lat', 'lng'
import 'barber_dashboard_page.dart';

class BarberShopDetailsPage extends StatefulWidget {
  const BarberShopDetailsPage({super.key});

  @override
  State<BarberShopDetailsPage> createState() => _BarberShopDetailsPageState();
}

class _BarberShopDetailsPageState extends State<BarberShopDetailsPage> {
  final _formKey = GlobalKey<FormState>();

  // Basic Controllers
  final _shopNameCtrl = TextEditingController();
  final _shopPhoneCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _facilitiesCtrl = TextEditingController();
  final _locationCtrl = TextEditingController(); // Stores address string
  final _buildingCtrl = TextEditingController();
  final _floorCtrl = TextEditingController();

  // State Variables
  double? _latitude;
  double? _longitude;
  List<File> _selectedImages = [];
  bool _isSaving = false;

  // Opening / Closing Times
  TimeOfDay _openingTime = const TimeOfDay(hour: 9, minute: 0);   // Default 9:00 AM
  TimeOfDay _closingTime = const TimeOfDay(hour: 21, minute: 0); // Default 9:00 PM

  // Services
  List<Map<String, TextEditingController>> _services = [];

  // Staff
  List<Map<String, TextEditingController>> _staff = [];

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _addService(); // Start with one service field
    _addStaff();   // Start with one staff field
  }

  @override
  void dispose() {
    _shopNameCtrl.dispose();
    _shopPhoneCtrl.dispose();
    _descriptionCtrl.dispose();
    _facilitiesCtrl.dispose();
    _locationCtrl.dispose();
    _buildingCtrl.dispose();
    _floorCtrl.dispose();

    for (var service in _services) {
      service['name']!.dispose();
      service['price']!.dispose();
    }
    for (var member in _staff) {
      member['name']!.dispose();
      member['phone']!.dispose();
      member['specialty']!.dispose();
    }
    super.dispose();
  }

  // Format TimeOfDay to 12-hour string with AM/PM
  String _formatTimeOfDay(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  // 1. Pick Images
  Future<void> _pickImages() async {
    final List<XFile> images = await _picker.pickMultiImage();
    if (images.isNotEmpty) {
      setState(() {
        _selectedImages.addAll(images.map((x) => File(x.path)));
      });
    }
  }

  // 2. Open Map Picker
  Future<void> _openMap() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const MapPickerPage()),
    );

    if (result != null && result is Map<String, dynamic>) {
      setState(() {
        _locationCtrl.text = result['address'] ?? 'Unknown Location';
        _latitude = result['lat'] as double?;
        _longitude = result['lng'] as double?;
      });
    }
  }

  // 3. Upload Images to Supabase Storage
  Future<List<String>> _uploadImages(String userId) async {
    List<String> uploadedUrls = [];
    final storage = Supabase.instance.client.storage.from('shop_images');

    for (var image in _selectedImages) {
      final fileName =
          '$userId/${DateTime.now().millisecondsSinceEpoch}_${image.path.split(Platform.isAndroid ? '/' : '/').last}';
      try {
        await storage.upload(fileName, image);
        final imageUrl = storage.getPublicUrl(fileName);
        uploadedUrls.add(imageUrl);
      } catch (e) {
        debugPrint("Image upload failed: $e");
      }
    }
    return uploadedUrls;
  }

  // 4. Add Service
  void _addService() {
    setState(() {
      _services.add({
        'name': TextEditingController(),
        'price': TextEditingController(),
      });
    });
  }

  // 5. Remove Service
  void _removeService(int index) {
    setState(() {
      _services[index]['name']!.dispose();
      _services[index]['price']!.dispose();
      _services.removeAt(index);
    });
  }

  // 6. Add Staff
  void _addStaff() {
    setState(() {
      _staff.add({
        'name': TextEditingController(),
        'phone': TextEditingController(),
        'specialty': TextEditingController(),
      });
    });
  }

  // 7. Remove Staff
  void _removeStaff(int index) {
    setState(() {
      _staff[index]['name']!.dispose();
      _staff[index]['phone']!.dispose();
      _staff[index]['specialty']!.dispose();
      _staff.removeAt(index);
    });
  }

  // 8. Save Shop Details
  Future<void> _saveShopDetails() async {
    if (!_formKey.currentState!.validate()) return;

    if (_latitude == null || _longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please pick a location on the map")),
      );
      return;
    }

    if (_selectedImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select at least one shop image")),
      );
      return;
    }

    // Validate services
    for (var service in _services) {
      if (service['name']!.text.trim().isEmpty ||
          service['price']!.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  "Please fill all service details or remove empty ones")),
        );
        return;
      }
    }

    setState(() => _isSaving = true);

    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("You must be logged in to add a shop.")),
      );
      setState(() => _isSaving = false);
      return;
    }

    try {
      // Upload images
      final imageUrls = await _uploadImages(userId);

      // Format opening hours string
      final openingHours =
          '${_formatTimeOfDay(_openingTime)} - ${_formatTimeOfDay(_closingTime)}';

      // Insert shop record
      final salonResponse = await Supabase.instance.client
          .from('barber_shops')
          .insert({
        'owner_id': userId,
        'name': _shopNameCtrl.text.trim(),
        'shop_phone': _shopPhoneCtrl.text.trim(),
        'address': _locationCtrl.text.trim(),
        'building_name': _buildingCtrl.text.trim(),
        'floor_no': _floorCtrl.text.trim(),
        'latitude': _latitude,
        'longitude': _longitude,
        'description': _descriptionCtrl.text.trim(),
        'opening_hours': openingHours,
        'facilities': _facilitiesCtrl.text.trim(),
        'image_urls': imageUrls,
        'is_open': true,
        'today_offer': '',
        'recruitment_message': '',
        'rating': 0.0,
      })
          .select()
          .single();

      final salonId = salonResponse['id'] as int;

      // Insert services
      for (var service in _services) {
        await Supabase.instance.client.from('services').insert({
          'salon_id': salonId,
          'name': service['name']!.text.trim(),
          'price':
          double.tryParse(service['price']!.text.trim()) ?? 0.0,
        });
      }

      // Insert staff (only if name is provided)
      for (var member in _staff) {
        final name = member['name']!.text.trim();
        if (name.isNotEmpty) {
          await Supabase.instance.client.from('staff').insert({
            'salon_id': salonId,
            'name': name,
            'phone': member['phone']!.text.trim(),
            'specialty': member['specialty']!.text.trim(),
          });
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Shop saved successfully! Welcome to your dashboard."),
            backgroundColor: Colors.green,
          ),
        );

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const BarberDashboardPage()),
              (route) => false,
        );
      }
    } catch (e) {
      debugPrint("Save Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error saving shop: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          "Add Shop Details",
          style: GoogleFonts.poppins(
              color: Colors.black, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTextField("Shop Name", _shopNameCtrl),
              const SizedBox(height: 16),
              _buildTextField("Phone Number", _shopPhoneCtrl, isPhone: true),
              const SizedBox(height: 16),
              _buildTextField("Description", _descriptionCtrl,
                  isMultiline: true),
              const SizedBox(height: 24),
              const Divider(color: Colors.black26),
              const SizedBox(height: 16),

              Text("Location Details",
                  style: GoogleFonts.poppins(
                      color: Colors.orange,
                      fontSize: 16,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),

              GestureDetector(
                onTap: _openMap,
                child: AbsorbPointer(
                  child: TextFormField(
                    controller: _locationCtrl,
                    style: const TextStyle(color: Colors.black),
                    validator: (val) =>
                    val == null || val.isEmpty ? "Required" : null,
                    decoration: InputDecoration(
                      labelText: "Shop Address (Tap to Pick)",
                      labelStyle: const TextStyle(color: Colors.black54),
                      filled: true,
                      fillColor: Colors.grey[100],
                      suffixIcon:
                      const Icon(Icons.map, color: Colors.orange),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                      child: _buildTextField("Building Name", _buildingCtrl)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildTextField("Floor No", _floorCtrl)),
                ],
              ),

              const SizedBox(height: 24),
              const Divider(color: Colors.black26),
              const SizedBox(height: 16),

              Text("Opening Hours",
                  style: GoogleFonts.poppins(
                      color: Colors.orange,
                      fontSize: 16,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: _openingTime,
                          builder: (context, child) {
                            return MediaQuery(
                              data: MediaQuery.of(context)
                                  .copyWith(alwaysUse24HourFormat: false),
                              child: Theme(
                                data: Theme.of(context).copyWith(
                                  colorScheme: const ColorScheme.light(
                                    primary: Colors.orange,
                                    onPrimary: Colors.white,
                                  ),
                                ),
                                child: child!,
                              ),
                            );
                          },
                        );
                        if (picked != null) {
                          setState(() => _openingTime = picked);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[300]!),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 4)),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Open",
                                style: GoogleFonts.poppins(
                                    color: Colors.orangeAccent,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600)),
                            const SizedBox(height: 12),
                            Text(
                              _formatTimeOfDay(_openingTime),
                              style: GoogleFonts.poppins(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child:
                    Text("—", style: TextStyle(fontSize: 36, color: Colors.grey)),
                  ),
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: _closingTime,
                          builder: (context, child) {
                            return MediaQuery(
                              data: MediaQuery.of(context)
                                  .copyWith(alwaysUse24HourFormat: false),
                              child: Theme(
                                data: Theme.of(context).copyWith(
                                  colorScheme: const ColorScheme.light(
                                    primary: Colors.orange,
                                    onPrimary: Colors.white,
                                  ),
                                ),
                                child: child!,
                              ),
                            );
                          },
                        );
                        if (picked != null) {
                          setState(() => _closingTime = picked);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[300]!),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 4)),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Close",
                                style: GoogleFonts.poppins(
                                    color: Colors.orangeAccent,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600)),
                            const SizedBox(height: 12),
                            Text(
                              _formatTimeOfDay(_closingTime),
                              style: GoogleFonts.poppins(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  "${_formatTimeOfDay(_openingTime)} - ${_formatTimeOfDay(_closingTime)}",
                  style:
                  GoogleFonts.poppins(fontSize: 17, color: Colors.black87),
                ),
              ),

              const SizedBox(height: 24),
              const Divider(color: Colors.black26),
              const SizedBox(height: 16),

              Text(
                  "Facilities (comma-separated, e.g., AC, Parking, WiFi)",
                  style: GoogleFonts.poppins(
                      color: Colors.orange,
                      fontSize: 16,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              _buildTextField("Facilities", _facilitiesCtrl),

              const SizedBox(height: 24),
              const Divider(color: Colors.black26),
              const SizedBox(height: 16),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Services",
                      style: GoogleFonts.poppins(
                          color: Colors.orange,
                          fontSize: 16,
                          fontWeight: FontWeight.w600)),
                  IconButton(
                    onPressed: _addService,
                    icon: const Icon(Icons.add_circle_outline,
                        color: Colors.orange),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              ..._services.asMap().entries.map((entry) {
                int index = entry.key;
                var service = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    children: [
                      Expanded(
                          child: _buildTextField(
                              "Service Name", service['name']!)),
                      const SizedBox(width: 16),
                      Expanded(
                          child: _buildTextField("Price", service['price']!,
                              isNumeric: true)),
                      if (_services.length > 1)
                        IconButton(
                          onPressed: () => _removeService(index),
                          icon: const Icon(Icons.remove_circle_outline,
                              color: Colors.red),
                        ),
                    ],
                  ),
                );
              }).toList(),

              const SizedBox(height: 24),
              const Divider(color: Colors.black26),
              const SizedBox(height: 16),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Staff Members (Optional)",
                      style: GoogleFonts.poppins(
                          color: Colors.orange,
                          fontSize: 16,
                          fontWeight: FontWeight.w600)),
                  IconButton(
                    onPressed: _addStaff,
                    icon: const Icon(Icons.add_circle_outline,
                        color: Colors.orange),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              ..._staff.asMap().entries.map((entry) {
                int index = entry.key;
                var member = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildOptionalTextField(
                          "Staff Name (Optional)", member['name']!),
                      const SizedBox(height: 8),
                      _buildOptionalTextField(
                          "Phone (Optional)", member['phone']!,
                          isPhone: true),
                      const SizedBox(height: 8),
                      _buildOptionalTextField(
                          "Specialty (Optional)", member['specialty']!),
                      if (_staff.length > 1)
                        Align(
                          alignment: Alignment.centerRight,
                          child: IconButton(
                            onPressed: () => _removeStaff(index),
                            icon: const Icon(Icons.remove_circle_outline,
                                color: Colors.red),
                          ),
                        ),
                    ],
                  ),
                );
              }).toList(),

              const SizedBox(height: 24),
              const Divider(color: Colors.black26),
              const SizedBox(height: 16),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Shop Photos",
                      style: GoogleFonts.poppins(
                          color: Colors.orange,
                          fontSize: 16,
                          fontWeight: FontWeight.w600)),
                  IconButton(
                    onPressed: _pickImages,
                    icon: const Icon(Icons.add_a_photo, color: Colors.black),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              if (_selectedImages.isNotEmpty)
                SizedBox(
                  height: 120,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _selectedImages.length,
                    itemBuilder: (ctx, index) {
                      return Stack(
                        children: [
                          Container(
                            margin: const EdgeInsets.only(right: 12),
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              image: DecorationImage(
                                  image: FileImage(_selectedImages[index]),
                                  fit: BoxFit.cover),
                            ),
                          ),
                          Positioned(
                            top: 4,
                            right: 12,
                            child: GestureDetector(
                              onTap: () => setState(
                                      () => _selectedImages.removeAt(index)),
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: const BoxDecoration(
                                  color: Colors.black54,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.close,
                                    color: Colors.white, size: 18),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                )
              else
                Container(
                  height: 120,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.grey[50],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.image_not_supported_outlined,
                          size: 48, color: Colors.grey),
                      const SizedBox(height: 8),
                      Text("No images selected",
                          style: GoogleFonts.poppins(color: Colors.grey)),
                    ],
                  ),
                ),

              const SizedBox(height: 50),

              ElevatedButton(
                onPressed: _isSaving ? null : _saveShopDetails,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  disabledBackgroundColor: Colors.orange.withOpacity(0.5),
                  minimumSize: const Size.fromHeight(56),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: _isSaving
                    ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2.5),
                )
                    : Text(
                  "Save Shop Details",
                  style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller,
      {bool isPhone = false,
        bool isNumeric = false,
        bool isMultiline = false}) {
    return TextFormField(
      controller: controller,
      keyboardType: isPhone
          ? TextInputType.phone
          : (isNumeric
          ? TextInputType.number
          : (isMultiline ? TextInputType.multiline : TextInputType.text)),
      maxLines: isMultiline ? null : 1,
      minLines: isMultiline ? 3 : 1,
      style: const TextStyle(color: Colors.black),
      validator: (val) =>
      (val == null || val.isEmpty) && label.isNotEmpty ? "Required" : null,
      decoration: InputDecoration(
        labelText: label.isEmpty ? null : label,
        labelStyle: const TextStyle(color: Colors.black54),
        filled: true,
        fillColor: Colors.grey[100],
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.orange, width: 2),
        ),
      ),
    );
  }

  Widget _buildOptionalTextField(String label, TextEditingController controller,
      {bool isPhone = false}) {
    return TextFormField(
      controller: controller,
      keyboardType: isPhone ? TextInputType.phone : TextInputType.text,
      style: const TextStyle(color: Colors.black),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.black54),
        filled: true,
        fillColor: Colors.grey[100],
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.orange, width: 2),
        ),
      ),
    );
  }
}