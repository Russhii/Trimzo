// lib/barber_shop_details_page.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'map_page.dart'; // Ensure this exists
import 'home_page.dart'; // Ensure this exists

class BarberShopDetailsPage extends StatefulWidget {
  const BarberShopDetailsPage({super.key});

  @override
  State<BarberShopDetailsPage> createState() => _BarberShopDetailsPageState();
}

class _BarberShopDetailsPageState extends State<BarberShopDetailsPage> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _shopNameCtrl = TextEditingController();
  final _shopPhoneCtrl = TextEditingController();
  final _locationCtrl = TextEditingController(); // Stores address string
  final _buildingCtrl = TextEditingController();
  final _floorCtrl = TextEditingController();

  // State Variables
  double? _latitude;
  double? _longitude;
  List<File> _selectedImages = [];
  bool _isSaving = false;

  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    _shopNameCtrl.dispose();
    _shopPhoneCtrl.dispose();
    _locationCtrl.dispose();
    _buildingCtrl.dispose();
    _floorCtrl.dispose();
    super.dispose();
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

    if (result != null && result is Map) {
      setState(() {
        _locationCtrl.text = result['address'] ?? 'Unknown Location';
        _latitude = result['lat'];
        _longitude = result['lng'];
      });
    }
  }

  // 3. Upload Images to Storage Bucket
  Future<List<String>> _uploadImages(String userId) async {
    List<String> uploadedUrls = [];
    // Ensure you created a bucket named 'shop_images' in Supabase Storage
    final storage = Supabase.instance.client.storage.from('shop_images');

    for (var image in _selectedImages) {
      final fileName = '$userId/${DateTime.now().millisecondsSinceEpoch}_${image.path.split('/').last}';
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

  // 4. Save to Database
  Future<void> _saveShopDetails() async {
    if (!_formKey.currentState!.validate()) return;

    // Check Map Location
    if (_latitude == null || _longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please pick a location on map"))
      );
      return;
    }

    // Check Images
    if (_selectedImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please select at least one shop image"))
      );
      return;
    }

    setState(() => _isSaving = true);

    // Get Current User
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("You must be logged in to add a shop."))
      );
      setState(() => _isSaving = false);
      return;
    }

    try {
      // Step A: Upload Images
      final imageUrls = await _uploadImages(userId);
      // We take the first image as the main thumbnail for the table
      final String mainImage = imageUrls.isNotEmpty ? imageUrls.first : '';

      // Step B: Insert into 'salons' table
      // Ensure you ran the SQL ALTER command to add phone, lat, long, etc.
      await Supabase.instance.client.from('salons').insert({
        'owner_id': userId,
        'name': _shopNameCtrl.text.trim(),
        'phone': _shopPhoneCtrl.text.trim(),
        'address': _locationCtrl.text.trim(),
        'building_name': _buildingCtrl.text.trim(),
        'floor_no': _floorCtrl.text.trim(),
        'latitude': _latitude,
        'longitude': _longitude,
        'image_url': mainImage, // Single column text
        'rating': 0.0,          // Default
        'distance': '0 km',     // Placeholder
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Shop saved successfully!"))
        );

        // Navigate Home
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const HomePage()),
              (route) => false,
        );
      }
    } catch (e) {
      debugPrint("Save Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text("Error saving shop: ${e.toString()}"),
              backgroundColor: Colors.red
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
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
            "Add Shop Details",
            style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)
        ),
        iconTheme: const IconThemeData(color: Colors.white),
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

              const SizedBox(height: 24),
              const Divider(color: Colors.white24),
              const SizedBox(height: 16),

              Text("Location Details", style: GoogleFonts.poppins(color: Colors.orange, fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),

              // Address (Read-only, tap to open Map)
              GestureDetector(
                onTap: _openMap,
                child: AbsorbPointer(
                  child: TextFormField(
                    controller: _locationCtrl,
                    style: const TextStyle(color: Colors.white),
                    validator: (val) => val == null || val.isEmpty ? "Required" : null,
                    decoration: InputDecoration(
                      labelText: "Shop Address (Tap to Pick)",
                      labelStyle: const TextStyle(color: Colors.white70),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.05),
                      suffixIcon: const Icon(Icons.map, color: Colors.orange),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Building & Floor
              Row(
                children: [
                  Expanded(child: _buildTextField("Building Name", _buildingCtrl)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildTextField("Floor No", _floorCtrl)),
                ],
              ),

              const SizedBox(height: 24),
              const Divider(color: Colors.white24),
              const SizedBox(height: 16),

              // Images Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Shop Photos", style: GoogleFonts.poppins(color: Colors.orange, fontSize: 16, fontWeight: FontWeight.w600)),
                  IconButton(
                    onPressed: _pickImages,
                    icon: const Icon(Icons.add_a_photo, color: Colors.white),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Image Preview List
              if (_selectedImages.isNotEmpty)
                SizedBox(
                  height: 100,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _selectedImages.length,
                    itemBuilder: (ctx, index) {
                      return Stack(
                        children: [
                          Container(
                            margin: const EdgeInsets.only(right: 12),
                            width: 100,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              image: DecorationImage(image: FileImage(_selectedImages[index]), fit: BoxFit.cover),
                            ),
                          ),
                          Positioned(
                            top: 0, right: 12,
                            child: GestureDetector(
                              onTap: () => setState(() => _selectedImages.removeAt(index)),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Colors.black54,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.close, color: Colors.white, size: 16),
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
                  height: 100,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white24),
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.white.withOpacity(0.02),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.image_not_supported_outlined, color: Colors.white38),
                      const SizedBox(height: 8),
                      Text("No images selected", style: GoogleFonts.poppins(color: Colors.white38)),
                    ],
                  ),
                ),

              const SizedBox(height: 40),

              // Save Button
              ElevatedButton(
                onPressed: _isSaving ? null : _saveShopDetails,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  disabledBackgroundColor: Colors.orange.withOpacity(0.5),
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isSaving
                    ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                )
                    : Text(
                    "Save Shop Details",
                    style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, {bool isPhone = false}) {
    return TextFormField(
      controller: controller,
      keyboardType: isPhone ? TextInputType.phone : TextInputType.text,
      style: const TextStyle(color: Colors.white),
      validator: (val) => val == null || val.isEmpty ? "Required" : null,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.orange)
        ),
      ),
    );
  }
}