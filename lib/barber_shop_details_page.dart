import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'map_page.dart';
import 'barber_dashboard_page.dart';

class BarberShopDetailsPage extends StatefulWidget {
  final int? shopId; // OPTIONAL: If null, it's Create Mode. If set, it's Edit Mode.

  const BarberShopDetailsPage({super.key, this.shopId});

  @override
  State<BarberShopDetailsPage> createState() => _BarberShopDetailsPageState();
}

class _BarberShopDetailsPageState extends State<BarberShopDetailsPage> {
  final _formKey = GlobalKey<FormState>();

  // --- Controllers (Same as before) ---
  final _shopNameCtrl = TextEditingController();
  final _shopPhoneCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _facilitiesCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _buildingCtrl = TextEditingController();
  final _floorCtrl = TextEditingController();

  // --- State Variables ---
  double? _latitude;
  double? _longitude;
  bool _isSaving = false;
  bool _isLoadingData = true;

  // --- NEW: Unified Image Gallery State ---
  // This list holds both existing URLs and new Files in order.
  // Index 0 is ALWAYS the Main/Showcase Image.
  List<ShopImageWrapper> _galleryItems = [];
  final ImagePicker _picker = ImagePicker();

  // --- Other State ---
  String? _selectedGenderType;
  final List<String> _genderOptions = ['Male', 'Female', 'Unisex'];
  TimeOfDay _openingTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _closingTime = const TimeOfDay(hour: 21, minute: 0);
  List<Map<String, TextEditingController>> _services = [];
  List<Map<String, TextEditingController>> _staff = [];

  @override
  void initState() {
    super.initState();
    if (widget.shopId != null) {
      _loadExistingData();
    } else {
      _addService();
      _addStaff();
      setState(() => _isLoadingData = false);
    }
  }

  // --- 1. LOAD DATA ---
  Future<void> _loadExistingData() async {
    try {
      final shopData = await Supabase.instance.client
          .from('barber_shops')
          .select()
          .eq('id', widget.shopId!)
          .single();

      final servicesData = await Supabase.instance.client
          .from('services')
          .select()
          .eq('salon_id', widget.shopId!);

      final staffData = await Supabase.instance.client
          .from('staff')
          .select()
          .eq('salon_id', widget.shopId!);

      if (mounted) {
        setState(() {
          _shopNameCtrl.text = shopData['name'] ?? '';
          _shopPhoneCtrl.text = shopData['shop_phone'] ?? '';
          _descriptionCtrl.text = shopData['description'] ?? '';
          _facilitiesCtrl.text = shopData['facilities'] ?? '';
          _locationCtrl.text = shopData['address'] ?? '';
          _buildingCtrl.text = shopData['building_name'] ?? '';
          _floorCtrl.text = shopData['floor_no'] ?? '';
          _latitude = shopData['latitude'];
          _longitude = shopData['longitude'];
          _selectedGenderType = shopData['target_gender'];

          // LOAD IMAGES INTO UNIFIED LIST
          if (shopData['image_urls'] != null) {
            final List<dynamic> urls = shopData['image_urls'];
            _galleryItems = urls.map((url) => ShopImageWrapper(url: url.toString())).toList();
          }

          // Load Services & Staff (Same as before)
          _services = (servicesData as List).map((s) => {
            'name': TextEditingController(text: s['name']),
            'price': TextEditingController(text: s['price'].toString()),
          }).toList();

          _staff = (staffData as List).map((s) => {
            'name': TextEditingController(text: s['name']),
            'phone': TextEditingController(text: s['phone'] ?? ''),
            'specialty': TextEditingController(text: s['specialty'] ?? ''),
          }).toList();

          _isLoadingData = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading data: $e");
      if(mounted) setState(() => _isLoadingData = false);
    }
  }

  // --- 2. IMAGE LOGIC (UPDATED) ---

  Future<void> _pickImages() async {
    final List<XFile> images = await _picker.pickMultiImage();
    if (images.isNotEmpty) {
      setState(() {
        for (var xFile in images) {
          _galleryItems.add(ShopImageWrapper(file: File(xFile.path)));
        }
      });
    }
  }

  // Moves the selected image to Index 0 (Main Image)
  void _setAsMainImage(int index) {
    setState(() {
      final item = _galleryItems.removeAt(index);
      _galleryItems.insert(0, item);
    });
  }

  void _removeImage(int index) {
    setState(() {
      _galleryItems.removeAt(index);
    });
  }

  // --- 3. SAVE LOGIC (UPDATED) ---
  Future<void> _saveShopDetails() async {
    if (!_formKey.currentState!.validate()) return;
    if (_galleryItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select at least one image")));
      return;
    }

    setState(() => _isSaving = true);
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      // Step A: Process Images in Order
      // We loop through our unified list. If it's a file, we upload it. If it's a URL, we keep it.
      // Step A: Process Images in Order
      List<String> finalImageUrls = [];
      final storage = Supabase.instance.client.storage.from('avatars');

      // We use a simple counter 'i' to ensure unique names if uploaded at the exact same millisecond
      int i = 0;
      for (var item in _galleryItems) {
        if (item.isNetwork) {
          // Keep existing URL
          finalImageUrls.add(item.url!);
        } else if (item.isFile) {
          // Upload new file
          i++;
          final fileExt = item.file!.path.split('.').last;

          // FIX: Use simple timestamp + index. No special characters!
          final fileName = '$userId/${DateTime.now().millisecondsSinceEpoch}_$i.$fileExt';

          await storage.upload(fileName, item.file!);
          final imageUrl = storage.getPublicUrl(fileName);
          finalImageUrls.add(imageUrl);
        }
      }

      // Step B: Prepare Data
      final openingHours = '${_formatTimeOfDay(_openingTime)} - ${_formatTimeOfDay(_closingTime)}';

      final Map<String, dynamic> shopData = {
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
        'image_urls': finalImageUrls, // The ordered list (Index 0 is main)
        'is_open': true,
        'target_gender': _selectedGenderType,
      };

      // Step C: Insert or Update
      int salonId;
      if (widget.shopId == null) {
        shopData['rating'] = 0.0;
        final res = await Supabase.instance.client.from('barber_shops').insert(shopData).select().single();
        salonId = res['id'];
      } else {
        await Supabase.instance.client.from('barber_shops').update(shopData).eq('id', widget.shopId!);
        salonId = widget.shopId!;
        // Refresh services/staff
        await Supabase.instance.client.from('services').delete().eq('salon_id', salonId);
        await Supabase.instance.client.from('staff').delete().eq('salon_id', salonId);
      }

      // Step D: Save Sub-tables
      for (var service in _services) {
        if (service['name']!.text.isNotEmpty) {
          await Supabase.instance.client.from('services').insert({
            'salon_id': salonId,
            'name': service['name']!.text.trim(),
            'price': double.tryParse(service['price']!.text.trim()) ?? 0.0,
          });
        }
      }
      for (var member in _staff) {
        if (member['name']!.text.isNotEmpty) {
          await Supabase.instance.client.from('staff').insert({
            'salon_id': salonId,
            'name': member['name']!.text.trim(),
            'phone': member['phone']!.text.trim(),
            'specialty': member['specialty']!.text.trim(),
          });
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Shop Saved Successfully!"), backgroundColor: Colors.green));
        Navigator.pop(context); // Go back or to dashboard
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // --- Helper Methods ---
  TimeOfDay _parseTime(String t) { /* Same as before */ return const TimeOfDay(hour: 9, minute: 0); }
  String _formatTimeOfDay(TimeOfDay t) {
    final hour = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final min = t.minute.toString().padLeft(2, '0');
    final per = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$min $per';
  }
  // (Keep _addService, _removeService, _addStaff, _removeStaff, _openMap same as before)
  void _addService() { setState(() { _services.add({'name': TextEditingController(), 'price': TextEditingController()}); }); }
  void _removeService(int index) { setState(() { _services.removeAt(index); }); }
  void _addStaff() { setState(() { _staff.add({'name': TextEditingController(), 'phone': TextEditingController(), 'specialty': TextEditingController()}); }); }
  void _removeStaff(int index) { setState(() { _staff.removeAt(index); }); }
  Future<void> _openMap() async {
    final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => const MapPickerPage()));
    if (result != null && result is Map<String, dynamic>) {
      setState(() { _locationCtrl.text = result['address'] ?? ''; _latitude = result['lat']; _longitude = result['lng']; });
    }
  }


  // --- UI BUILD ---
  @override
  Widget build(BuildContext context) {
    if (_isLoadingData) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text("Shop Details"), backgroundColor: Colors.white, elevation: 0),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ... [KEEP YOUR TEXT FIELDS HERE: Name, Phone, Gender, Desc, Location, Hours, Facilities, Services, Staff] ...
              _buildTextField("Shop Name", _shopNameCtrl),
              const SizedBox(height: 16),

              // --- NEW IMAGE UI SECTION ---
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text("Shop Photos", style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
                IconButton(onPressed: _pickImages, icon: const Icon(Icons.add_a_photo, color: Colors.orange))
              ]),
              const Text("The first image will be your Main Showcase Image.", style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 12),

              // ... inside your build method, replace the existing Image ListView with this:

              if (_galleryItems.isNotEmpty)
                SizedBox(
                  height: 180,
                  child: ReorderableListView(
                    scrollDirection: Axis.horizontal,
                    onReorder: (int oldIndex, int newIndex) {
                      setState(() {
                        if (oldIndex < newIndex) {
                          newIndex -= 1;
                        }
                        final item = _galleryItems.removeAt(oldIndex);
                        _galleryItems.insert(newIndex, item);
                      });
                    },
                    proxyDecorator: (Widget child, int index, Animation<double> animation) {
                      // This creates the "Pop-out" effect when long pressing
                      return AnimatedBuilder(
                        animation: animation,
                        builder: (BuildContext context, Widget? child) {
                          return Material(
                            elevation: 10, // Shadow depth
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            child: Transform.scale(
                              scale: 1.05, // Slightly bigger when dragging
                              child: child,
                            ),
                          );
                        },
                        child: child,
                      );
                    },
                    children: [
                      for (int index = 0; index < _galleryItems.length; index++)
                        Container(
                          key: ObjectKey(_galleryItems[index]), // CRITICAL: Unique Key
                          margin: const EdgeInsets.only(right: 12), // Spacing (replaces separator)
                          child: Column(
                            children: [
                              Stack(
                                children: [
                                  Container(
                                    width: 130,
                                    height: 130,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      // Highlight the Main image (Index 0)
                                      border: index == 0
                                          ? Border.all(color: Colors.orange, width: 3)
                                          : Border.all(color: Colors.grey[300]!),
                                      image: DecorationImage(
                                        image: _galleryItems[index].isNetwork
                                            ? NetworkImage(_galleryItems[index].url!)
                                            : FileImage(_galleryItems[index].file!) as ImageProvider,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                  // "MAIN" Badge
                                  if (index == 0)
                                    Positioned(
                                      top: 8,
                                      left: 8,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.orange,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: const Text(
                                          "MAIN",
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                  // Delete Button
                                  Positioned(
                                    top: 4,
                                    right: 4,
                                    child: GestureDetector(
                                      onTap: () => _removeImage(index),
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
                              ),
                              const SizedBox(height: 8),
                              // "Set Main" Button (Hidden for index 0)
                              if (index != 0)
                                SizedBox(
                                  height: 30,
                                  child: ElevatedButton(
                                    onPressed: () => _setAsMainImage(index),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      side: const BorderSide(color: Colors.orange),
                                      padding: const EdgeInsets.symmetric(horizontal: 8),
                                      elevation: 0,
                                    ),
                                    child: const Text(
                                      "Set Main",
                                      style: TextStyle(fontSize: 10, color: Colors.orange),
                                    ),
                                  ),
                                )
                              else
                                const SizedBox(
                                  height: 30,
                                  child: Center(
                                    child: Icon(Icons.check_circle, color: Colors.orange, size: 20),
                                  ),
                                ),
                            ],
                          ),
                        ),
                    ],
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
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.image, size: 40, color: Colors.grey),
                      Text("No images added"),
                    ],
                  ),
                ),

              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: _isSaving ? null : _saveShopDetails,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, minimumSize: const Size.fromHeight(56)),
                child: _isSaving ? const CircularProgressIndicator(color: Colors.white) : const Text("Save Shop Details", style: TextStyle(color: Colors.white, fontSize: 18)),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  // (Keep _buildTextField helper methods)
  Widget _buildTextField(String label, TextEditingController controller, {bool isPhone = false, bool isNumeric = false, bool isMultiline = false}) {
    return TextFormField(
      controller: controller,
      keyboardType: isPhone ? TextInputType.phone : (isNumeric ? TextInputType.number : (isMultiline ? TextInputType.multiline : TextInputType.text)),
      maxLines: isMultiline ? null : 1, minLines: isMultiline ? 3 : 1,
      validator: (val) => val!.isEmpty ? "Required" : null,
      decoration: InputDecoration(labelText: label, filled: true, fillColor: Colors.grey[100], border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
    );
  }
}

// --- HELPER CLASS ---
class ShopImageWrapper {
  final String? url;
  final File? file;

  ShopImageWrapper({this.url, this.file});

  bool get isNetwork => url != null;
  bool get isFile => file != null;
}