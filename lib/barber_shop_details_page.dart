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

  // Basic Controllers
  final _shopNameCtrl = TextEditingController();
  final _shopPhoneCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _facilitiesCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _buildingCtrl = TextEditingController();
  final _floorCtrl = TextEditingController();

  // State Variables
  double? _latitude;
  double? _longitude;

  // Image Handling: We need to handle Existing URLs (from DB) and New Files (from Picker) separately
  List<String> _existingImageUrls = [];
  List<File> _newSelectedImages = [];

  bool _isSaving = false;
  bool _isLoadingData = true;

  // Salon Type
  String? _selectedGenderType;
  final List<String> _genderOptions = ['Male', 'Female', 'Unisex'];

  // Opening / Closing Times
  TimeOfDay _openingTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _closingTime = const TimeOfDay(hour: 21, minute: 0);

  // Services & Staff
  List<Map<String, TextEditingController>> _services = [];
  List<Map<String, TextEditingController>> _staff = [];

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    if (widget.shopId != null) {
      _loadExistingData(); // EDIT MODE
    } else {
      // CREATE MODE
      _addService();
      _addStaff();
      setState(() => _isLoadingData = false);
    }
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
    for (var s in _services) { s['name']!.dispose(); s['price']!.dispose(); }
    for (var s in _staff) { s['name']!.dispose(); s['phone']!.dispose(); s['specialty']!.dispose(); }
    super.dispose();
  }

  // --- 1. LOAD DATA FOR EDITING ---
  Future<void> _loadExistingData() async {
    try {
      // Fetch Shop
      final shopData = await Supabase.instance.client
          .from('barber_shops')
          .select()
          .eq('id', widget.shopId!)
          .single();

      // Fetch Services
      final servicesData = await Supabase.instance.client
          .from('services')
          .select()
          .eq('salon_id', widget.shopId!);

      // Fetch Staff
      final staffData = await Supabase.instance.client
          .from('staff')
          .select()
          .eq('salon_id', widget.shopId!);

      if (mounted) {
        setState(() {
          // Fill Controllers
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

          // Handle Images
          if (shopData['image_urls'] != null) {
            _existingImageUrls = List<String>.from(shopData['image_urls']);
          }

          // Handle Time (Format expected: "9:00 AM - 9:00 PM")
          if (shopData['opening_hours'] != null) {
            final parts = (shopData['opening_hours'] as String).split(' - ');
            if (parts.length == 2) {
              _openingTime = _parseTime(parts[0]);
              _closingTime = _parseTime(parts[1]);
            }
          }

          // Handle Services
          _services = (servicesData as List).map((s) => {
            'name': TextEditingController(text: s['name']),
            'price': TextEditingController(text: s['price'].toString()),
          }).toList();
          if (_services.isEmpty) _addService();

          // Handle Staff
          _staff = (staffData as List).map((s) => {
            'name': TextEditingController(text: s['name']),
            'phone': TextEditingController(text: s['phone'] ?? ''),
            'specialty': TextEditingController(text: s['specialty'] ?? ''),
          }).toList();
          if (_staff.isEmpty) _addStaff();

          _isLoadingData = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading data: $e");
      if(mounted) setState(() => _isLoadingData = false);
    }
  }

  // Helper to parse "9:00 AM" back to TimeOfDay
  TimeOfDay _parseTime(String timeString) {
    try {
      final timeParts = timeString.split(" "); // ["9:00", "AM"]
      final hm = timeParts[0].split(":"); // ["9", "00"]
      int hour = int.parse(hm[0]);
      int minute = int.parse(hm[1]);
      if (timeParts[1] == "PM" && hour != 12) hour += 12;
      if (timeParts[1] == "AM" && hour == 12) hour = 0;
      return TimeOfDay(hour: hour, minute: minute);
    } catch (e) {
      return const TimeOfDay(hour: 9, minute: 0);
    }
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  // --- 2. PICK & UPLOAD IMAGES ---
  Future<void> _pickImages() async {
    final List<XFile> images = await _picker.pickMultiImage();
    if (images.isNotEmpty) {
      setState(() {
        _newSelectedImages.addAll(images.map((x) => File(x.path)));
      });
    }
  }

  Future<List<String>> _uploadNewImages(String userId) async {
    List<String> uploadedUrls = [];
    final storage = Supabase.instance.client.storage.from('shop_images');

    for (var image in _newSelectedImages) {
      final fileName = '$userId/${DateTime.now().millisecondsSinceEpoch}_${image.path.split(Platform.isAndroid ? '/' : '/').last}';
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

  // --- 3. SAVE / UPDATE LOGIC ---
  Future<void> _saveShopDetails() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedGenderType == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select a Salon Type")));
      return;
    }
    if (_latitude == null || _longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please pick a location")));
      return;
    }
    if (_existingImageUrls.isEmpty && _newSelectedImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select at least one image")));
      return;
    }

    setState(() => _isSaving = true);
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      // 1. Upload new images and merge with existing
      final newImageUrls = await _uploadNewImages(userId);
      final finalImageUrls = [..._existingImageUrls, ...newImageUrls];

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
        'image_urls': finalImageUrls,
        'is_open': true,
        'target_gender': _selectedGenderType,
      };

      int salonId;

      if (widget.shopId == null) {

        shopData['rating'] = 0.0;
        shopData['today_offer'] = '';
        shopData['recruitment_message'] = '';

        final res = await Supabase.instance.client.from('barber_shops').insert(shopData).select().single();
        salonId = res['id'];
      } else {
        // --- EDIT MODE ---
        await Supabase.instance.client.from('barber_shops').update(shopData).eq('id', widget.shopId!);
        salonId = widget.shopId!;

        // Clear existing services/staff to re-insert (Simple way to handle edits/deletions)
        await Supabase.instance.client.from('services').delete().eq('salon_id', salonId);
        await Supabase.instance.client.from('staff').delete().eq('salon_id', salonId);
      }

      // Insert Services
      for (var service in _services) {
        if (service['name']!.text.isNotEmpty) {
          await Supabase.instance.client.from('services').insert({
            'salon_id': salonId,
            'name': service['name']!.text.trim(),
            'price': double.tryParse(service['price']!.text.trim()) ?? 0.0,
          });
        }
      }

      // Insert Staff
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(widget.shopId == null ? "Shop Created!" : "Shop Updated!"), backgroundColor: Colors.green));
        Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const BarberDashboardPage()), (route) => false);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // --- UI HELPERS ---

  // ... (Keep existing _addService, _removeService, _addStaff, _removeStaff) ...
  void _addService() { setState(() { _services.add({'name': TextEditingController(), 'price': TextEditingController()}); }); }
  void _removeService(int index) { setState(() { _services[index]['name']!.dispose(); _services[index]['price']!.dispose(); _services.removeAt(index); }); }
  void _addStaff() { setState(() { _staff.add({'name': TextEditingController(), 'phone': TextEditingController(), 'specialty': TextEditingController()}); }); }
  void _removeStaff(int index) { setState(() { _staff[index]['name']!.dispose(); _staff[index]['phone']!.dispose(); _staff[index]['specialty']!.dispose(); _staff.removeAt(index); }); }
  Future<void> _openMap() async {
    final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => const MapPickerPage()));
    if (result != null && result is Map<String, dynamic>) {
      setState(() { _locationCtrl.text = result['address'] ?? ''; _latitude = result['lat']; _longitude = result['lng']; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingData) return const Scaffold(body: Center(child: CircularProgressIndicator(color: Colors.orange)));

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(widget.shopId == null ? "Add Shop Details" : "Edit Shop Details", style: GoogleFonts.poppins(color: Colors.black, fontWeight: FontWeight.bold)),
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

              Text("Salon Type", style: GoogleFonts.poppins(color: Colors.orange, fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedGenderType,
                decoration: InputDecoration(
                  filled: true, fillColor: Colors.grey[100],
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
                hint: const Text("Select Type (e.g. Unisex)"),
                items: _genderOptions.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                onChanged: (val) => setState(() => _selectedGenderType = val),
                validator: (val) => val == null ? 'Required' : null,
              ),
              const SizedBox(height: 16),

              _buildTextField("Description", _descriptionCtrl, isMultiline: true),
              const SizedBox(height: 24),
              const Divider(color: Colors.black26),

              // LOCATION
              const SizedBox(height: 16),
              Text("Location Details", style: GoogleFonts.poppins(color: Colors.orange, fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: _openMap,
                child: AbsorbPointer(
                  child: TextFormField(
                    controller: _locationCtrl,
                    validator: (val) => val!.isEmpty ? "Required" : null,
                    decoration: InputDecoration(
                      labelText: "Shop Address (Tap to Pick)", filled: true, fillColor: Colors.grey[100],
                      suffixIcon: const Icon(Icons.map, color: Colors.orange),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(children: [Expanded(child: _buildTextField("Building Name", _buildingCtrl)), const SizedBox(width: 16), Expanded(child: _buildTextField("Floor No", _floorCtrl))]),

              const SizedBox(height: 24),
              const Divider(color: Colors.black26),

              // OPENING HOURS
              const SizedBox(height: 16),
              Text("Opening Hours", style: GoogleFonts.poppins(color: Colors.orange, fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: InkWell(onTap: () async { final t = await showTimePicker(context: context, initialTime: _openingTime); if(t!=null) setState(()=>_openingTime=t); }, child: _buildTimeBox("Open", _openingTime))),
                const Padding(padding: EdgeInsets.symmetric(horizontal: 20), child: Text("—", style: TextStyle(fontSize: 36, color: Colors.grey))),
                Expanded(child: InkWell(onTap: () async { final t = await showTimePicker(context: context, initialTime: _closingTime); if(t!=null) setState(()=>_closingTime=t); }, child: _buildTimeBox("Close", _closingTime))),
              ]),

              const SizedBox(height: 24),
              const Divider(color: Colors.black26),
              const SizedBox(height: 16),
              Text("Facilities", style: GoogleFonts.poppins(color: Colors.orange, fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              _buildTextField("Facilities (e.g. AC, WiFi)", _facilitiesCtrl),

              const SizedBox(height: 24),
              const Divider(color: Colors.black26),

              // SERVICES
              const SizedBox(height: 16),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text("Services", style: GoogleFonts.poppins(color: Colors.orange, fontSize: 16, fontWeight: FontWeight.w600)), IconButton(onPressed: _addService, icon: const Icon(Icons.add_circle_outline, color: Colors.orange))]),
              ..._services.asMap().entries.map((entry) => Padding(padding: const EdgeInsets.only(bottom: 16), child: Row(children: [
                Expanded(child: _buildTextField("Service Name", entry.value['name']!)), const SizedBox(width: 16),
                Expanded(child: _buildTextField("Price", entry.value['price']!, isNumeric: true)),
                if (_services.length > 1) IconButton(onPressed: () => _removeService(entry.key), icon: const Icon(Icons.remove_circle_outline, color: Colors.red)),
              ]))),

              const SizedBox(height: 24),
              const Divider(color: Colors.black26),

              // STAFF
              const SizedBox(height: 16),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text("Staff Members (Optional)", style: GoogleFonts.poppins(color: Colors.orange, fontSize: 16, fontWeight: FontWeight.w600)), IconButton(onPressed: _addStaff, icon: const Icon(Icons.add_circle_outline, color: Colors.orange))]),
              ..._staff.asMap().entries.map((entry) => Padding(padding: const EdgeInsets.only(bottom: 20), child: Column(children: [
                _buildOptionalTextField("Name", entry.value['name']!), const SizedBox(height: 8),
                _buildOptionalTextField("Phone", entry.value['phone']!, isPhone: true), const SizedBox(height: 8),
                _buildOptionalTextField("Specialty", entry.value['specialty']!),
                if (_staff.length > 1) Align(alignment: Alignment.centerRight, child: IconButton(onPressed: () => _removeStaff(entry.key), icon: const Icon(Icons.remove_circle_outline, color: Colors.red))),
              ]))),

              const SizedBox(height: 24),
              const Divider(color: Colors.black26),

              // IMAGES
              const SizedBox(height: 16),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text("Shop Photos", style: GoogleFonts.poppins(color: Colors.orange, fontSize: 16, fontWeight: FontWeight.w600)), IconButton(onPressed: _pickImages, icon: const Icon(Icons.add_a_photo, color: Colors.black))]),
              const SizedBox(height: 12),

              // Image List (Mix of Existing URLs and New Files)
              if (_existingImageUrls.isNotEmpty || _newSelectedImages.isNotEmpty)
                SizedBox(
                  height: 120,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _existingImageUrls.length + _newSelectedImages.length,
                    itemBuilder: (ctx, index) {
                      final bool isExisting = index < _existingImageUrls.length;
                      final imageProvider = isExisting
                          ? NetworkImage(_existingImageUrls[index])
                          : FileImage(_newSelectedImages[index - _existingImageUrls.length]) as ImageProvider;

                      return Stack(
                        children: [
                          Container(
                            margin: const EdgeInsets.only(right: 12),
                            width: 120, height: 120,
                            decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), image: DecorationImage(image: imageProvider, fit: BoxFit.cover)),
                          ),
                          Positioned(
                            top: 4, right: 12,
                            child: GestureDetector(
                              onTap: () => setState(() {
                                if (isExisting) _existingImageUrls.removeAt(index);
                                else _newSelectedImages.removeAt(index - _existingImageUrls.length);
                              }),
                              child: Container(padding: const EdgeInsets.all(6), decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle), child: const Icon(Icons.close, color: Colors.white, size: 18)),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                )
              else
                Container(
                  height: 120, width: double.infinity,
                  decoration: BoxDecoration(border: Border.all(color: Colors.grey[300]!), borderRadius: BorderRadius.circular(12), color: Colors.grey[50]),
                  child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.image_not_supported_outlined, size: 48, color: Colors.grey), SizedBox(height: 8), Text("No images selected", style: TextStyle(color: Colors.grey))]),
                ),

              const SizedBox(height: 50),
              ElevatedButton(
                onPressed: _isSaving ? null : _saveShopDetails,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, minimumSize: const Size.fromHeight(56), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: _isSaving ? const CircularProgressIndicator(color: Colors.white) : Text(widget.shopId == null ? "Create Shop" : "Update Shop", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  // --- WIDGET BUILDERS (SAME AS BEFORE) ---
  Widget _buildTimeBox(String label, TimeOfDay time) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey[300]!)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.w600)), const SizedBox(height: 8), Text(_formatTimeOfDay(time), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.orange))]),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, {bool isPhone = false, bool isNumeric = false, bool isMultiline = false}) {
    return TextFormField(
      controller: controller,
      keyboardType: isPhone ? TextInputType.phone : (isNumeric ? TextInputType.number : (isMultiline ? TextInputType.multiline : TextInputType.text)),
      maxLines: isMultiline ? null : 1, minLines: isMultiline ? 3 : 1,
      validator: (val) => val!.isEmpty ? "Required" : null,
      decoration: InputDecoration(labelText: label, filled: true, fillColor: Colors.grey[100], border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
    );
  }

  Widget _buildOptionalTextField(String label, TextEditingController controller, {bool isPhone = false}) {
    return TextFormField(
      controller: controller,
      keyboardType: isPhone ? TextInputType.phone : TextInputType.text,
      decoration: InputDecoration(labelText: label, filled: true, fillColor: Colors.grey[100], border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
    );
  }
}