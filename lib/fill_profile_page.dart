// lib/fill_profile_page.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'home_page.dart';
import 'login_page.dart';
import 'barber_shop_details_page.dart';

class FillProfilePage extends StatefulWidget {
  final bool isEditMode; // NEW: true = edit existing profile, false = first-time setup

  const FillProfilePage({
    super.key,
    this.isEditMode = false, // default: first-time signup
  });

  @override
  State<FillProfilePage> createState() => _FillProfilePageState();
}

class _FillProfilePageState extends State<FillProfilePage> {
  final _fullNameCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  String? _fullPhoneNumber;
  String? _existingPhone; // NEW
  String? _existingAvatarUrl; // NEW: for displaying current photo

  DateTime? _selectedDate;
  String _gender = 'Male';
  String _userType = 'Customer';
  File? _profileImage;

  bool _isLoading = false; // NEW: for loading existing data in edit mode

  final picker = ImagePicker();

  @override
  void initState() {
    super.initState();

    final user = Supabase.instance.client.auth.currentUser;
    if (user?.email != null) {
      _emailCtrl.text = user!.email!;
    }

    // If edit mode → load existing profile data
    if (widget.isEditMode) {
      _loadExistingProfile();
    }
  }

  Future<void> _loadExistingProfile() async {
    setState(() => _isLoading = true);

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      Navigator.pop(context);
      return;
    }

    try {
      final response = await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (response != null && mounted) {
        setState(() {
          _fullNameCtrl.text = response['full_name'] ?? '';
          _usernameCtrl.text = response['username'] ?? '';
          _existingPhone = response['phone'];
          _selectedDate = response['birthday'] != null ? DateTime.tryParse(response['birthday']) : null;
          _gender = response['gender'] ?? 'Male';
          _userType = response['user_type'] ?? 'Customer';
          _existingAvatarUrl = response['avatar_url'];
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint("Error loading profile: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImage() async {
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null && mounted) {
      setState(() => _profileImage = File(pickedFile.path));
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime(2000),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: ThemeData.light().copyWith(
          colorScheme: const ColorScheme.light(
            primary: Colors.orange,
            onPrimary: Colors.white,
            surface: Colors.white,
            onSurface: Colors.black,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null && mounted) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _saveProfile() async {
    if (_fullNameCtrl.text.trim().isEmpty || _usernameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Full Name and Username are required")),
      );
      return;
    }

    setState(() => _isLoading = true);

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      String? avatarUrl = _existingAvatarUrl;

      // Upload new profile picture if selected
      if (_profileImage != null) {
        final fileExt = _profileImage!.path.split('.').last;
        final fileName = '${user.id}/${DateTime.now().millisecondsSinceEpoch}.$fileExt';

        await Supabase.instance.client.storage.from('avatars').upload(fileName, _profileImage!);
        avatarUrl = Supabase.instance.client.storage.from('avatars').getPublicUrl(fileName);
      }

      await Supabase.instance.client.from('profiles').upsert({
        'id': user.id,
        'full_name': _fullNameCtrl.text.trim(),
        'username': _usernameCtrl.text.trim(),
        'birthday': _selectedDate?.toIso8601String(),
        'phone': _fullPhoneNumber ?? _existingPhone,
        'gender': _gender,
        'user_type': _userType,
       // 'avatar_url': avatarUrl, // NEW: save profile picture URL
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.isEditMode ? "Profile updated successfully!" : "Profile saved!"),
            backgroundColor: Colors.green,
          ),
        );

        if (widget.isEditMode) {
          // In edit mode → go back
          Navigator.pop(context);
        } else {
          // First time → go to home or barber setup
          if (_userType == 'Barber') {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const BarberShopDetailsPage()),
                  (route) => false,
            );
          } else {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const HomePage()),
                  (route) => false,
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: widget.isEditMode
            ? IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        )
            : null, // No back button in first-time mode
        title: Text(
          widget.isEditMode ? "Edit Profile" : "Fill Your Profile",
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.orange))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 20),

            // Profile Picture
            Stack(
              children: [
                CircleAvatar(
                  radius: 60,
                  backgroundImage: _profileImage != null
                      ? FileImage(_profileImage!)
                      : (_existingAvatarUrl != null
                      ? NetworkImage(_existingAvatarUrl!)
                      : const AssetImage('assets/avatar_placeholder.png') as ImageProvider),
                  backgroundColor: Colors.grey[200],
                  child: _profileImage == null && _existingAvatarUrl == null
                      ? const Icon(Icons.person, size: 70, color: Colors.grey)
                      : null,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap: _pickImage,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Colors.orange,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 40),

            // Full Name
            _buildTextField(_fullNameCtrl, "Full Name"),
            const SizedBox(height: 16),

            // Username
            _buildTextField(_usernameCtrl, "Username"),
            const SizedBox(height: 16),

            // Birthday
            _buildDateField(),
            const SizedBox(height: 16),

            // Email (always disabled)
            _buildTextField(_emailCtrl, "Email", enabled: false),
            const SizedBox(height: 16),

            // Phone Number
            _buildPhoneField(),
            const SizedBox(height: 16),

            // Gender
            _buildGenderDropdown(),
            const SizedBox(height: 16),

            // User Type (only show in first-time signup, or allow change in edit?)
            // You can decide: hide in edit mode or keep it
            if (!widget.isEditMode) ...[
              _buildUserTypeDropdown(),
              const SizedBox(height: 16),
            ],

            // Save / Update Button
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF6B00),
                  elevation: 10,
                  shadowColor: const Color(0xFFFF6B00).withOpacity(0.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: Text(
                  widget.isEditMode ? "Update Profile" : "Continue",
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // Reusable Text Field
  Widget _buildTextField(TextEditingController controller, String hint, {bool enabled = true}) {
    return TextField(
      controller: controller,
      enabled: enabled,
      style: const TextStyle(color: Colors.black),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.black38),
        filled: true,
        fillColor: Colors.grey[200],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      ),
    );
  }

  // Date Field
  Widget _buildDateField() {
    return GestureDetector(
      onTap: _selectDate,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Text(
              _selectedDate == null
                  ? "Birthday"
                  : DateFormat('dd/MM/yyyy').format(_selectedDate!),
              style: TextStyle(
                color: _selectedDate == null ? Colors.black38 : Colors.black,
                fontSize: 16,
              ),
            ),
            const Spacer(),
            Icon(Icons.calendar_today, color: Colors.black54),
          ],
        ),
      ),
    );
  }

  Widget _buildPhoneField() {
    return IntlPhoneField(
      initialValue: _existingPhone?.replaceAll('+', ''),
      style: const TextStyle(color: Colors.black),
      decoration: InputDecoration(
        labelText: 'Phone Number',
        labelStyle: const TextStyle(color: Colors.black38),
        filled: true,
        fillColor: Colors.grey[200],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
      initialCountryCode: 'IN',
      onChanged: (phone) {
        _fullPhoneNumber = phone.completeNumber;
      },
      dropdownTextStyle: const TextStyle(color: Colors.black),
      dropdownIcon: const Icon(Icons.arrow_drop_down, color: Colors.black),
    );
  }

  // Gender Dropdown
  Widget _buildGenderDropdown() {
    return DropdownButtonFormField<String>(
      value: _gender,
      dropdownColor: Colors.white,
      style: const TextStyle(color: Colors.black),
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.grey[200],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        suffixIcon: const Icon(Icons.arrow_drop_down, color: Colors.black54),
      ),
      items: ['Male', 'Female', 'Other']
          .map((g) => DropdownMenuItem(value: g, child: Text(g)))
          .toList(),
      onChanged: (val) => setState(() => _gender = val!),
    );
  }

  // User Type Dropdown (only shown in first-time signup)
  Widget _buildUserTypeDropdown() {
    return DropdownButtonFormField<String>(
      value: _userType,
      dropdownColor: Colors.white,
      style: const TextStyle(color: Colors.black),
      decoration: InputDecoration(
        labelText: "Account Type",
        labelStyle: const TextStyle(color: Colors.black54),
        filled: true,
        fillColor: Colors.grey[200],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        suffixIcon: const Icon(Icons.arrow_drop_down, color: Colors.black54),
      ),
      items: ['Customer', 'Barber']
          .map((type) => DropdownMenuItem(value: type, child: Text(type)))
          .toList(),
      onChanged: (val) => setState(() => _userType = val!),
    );
  }

  @override
  void dispose() {
    _fullNameCtrl.dispose();
    _usernameCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }
}