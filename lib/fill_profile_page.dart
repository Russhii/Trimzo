import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
// Make sure these imports exist in your project
import 'home_page.dart';
import 'login_page.dart';
import 'barber_shop_details_page.dart';

class FillProfilePage extends StatefulWidget {
  final bool isEditMode;

  const FillProfilePage({
    super.key,
    this.isEditMode = false,
  });

  @override
  State<FillProfilePage> createState() => _FillProfilePageState();
}

class _FillProfilePageState extends State<FillProfilePage> {
  final _fullNameCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();

  String? _fullPhoneNumber;
  String? _existingPhone;
  String? _existingAvatarUrl;

  DateTime? _selectedDate;
  String _gender = 'Male';
  String _userType = 'Customer';
  File? _profileImage;

  bool _isLoading = false;
  bool _phoneError = false;

  final picker = ImagePicker();

  @override
  void initState() {
    super.initState();

    final user = Supabase.instance.client.auth.currentUser;
    if (user?.email != null) {
      _emailCtrl.text = user!.email!;
    }

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

  // Validate Indian mobile number (10 digits, starts with 6-9)
  bool _isValidIndianMobile(String? phone) {
    if (phone == null || phone.isEmpty) return false;
    String cleaned = phone.replaceAll(RegExp(r'^\+?91'), '').trim();
    return RegExp(r'^[6-9]\d{9}$').hasMatch(cleaned);
  }

  Future<void> _saveProfile() async {
    setState(() => _phoneError = false);

    // 1. Mandatory Text Fields Validation
    if (_fullNameCtrl.text.trim().isEmpty || _usernameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Full Name and Username are mandatory")),
      );
      return;
    }

    // 2. Mandatory Birthday Validation
    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Birthday is mandatory")),
      );
      return;
    }

    // 3. Mandatory Phone Validation
    if (_fullPhoneNumber == null || !_isValidIndianMobile(_fullPhoneNumber)) {
      setState(() => _phoneError = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please enter a valid 10-digit Indian mobile number"),
          backgroundColor: Colors.red,
        ),
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
      // Start with existing avatar (if any), allow it to remain null
      String? avatarUrl = _existingAvatarUrl;

      // Only upload if a NEW image is selected.
      // If _profileImage is null, we skip this and avatarUrl remains as is.
      if (_profileImage != null) {
        final fileExt = _profileImage!.path.split('.').last;
        final fileName = '${user.id}/${DateTime.now().millisecondsSinceEpoch}.$fileExt';

        await Supabase.instance.client.storage.from('avatars').upload(fileName, _profileImage!);
        avatarUrl = Supabase.instance.client.storage.from('avatars').getPublicUrl(fileName);
      }

      // Upsert profile data
      await Supabase.instance.client.from('profiles').upsert({
        'id': user.id,
        'full_name': _fullNameCtrl.text.trim(),
        'username': _usernameCtrl.text.trim(),
        'birthday': _selectedDate!.toIso8601String(), // Safe to unwrap due to check above
        'phone': _fullPhoneNumber,
        'gender': _gender,
        'user_type': _userType,
        'avatar_url': avatarUrl, // Can be null, that is okay
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.isEditMode ? "Profile updated!" : "Profile saved!"),
            backgroundColor: Colors.green,
          ),
        );

        if (widget.isEditMode) {
          Navigator.pop(context);
        } else {
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
          SnackBar(content: Text("Error saving profile: $e")),
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
            : null,
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

            // Profile Picture (Optional)
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
            const SizedBox(height: 8),
            Text(
              "(Optional)",
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
            ),

            const SizedBox(height: 30),

            // Full Name *
            _buildTextField(_fullNameCtrl, "Full Name *"),
            const SizedBox(height: 16),

            // Username *
            _buildTextField(_usernameCtrl, "Username *"),
            const SizedBox(height: 16),

            // Birthday *
            _buildDateField(),
            const SizedBox(height: 16),

            // Email (disabled)
            _buildTextField(_emailCtrl, "Email", enabled: false),
            const SizedBox(height: 16),

            // Phone Number *
            IntlPhoneField(
              initialValue: _existingPhone?.replaceAll('+91', '').trim(),
              style: const TextStyle(color: Colors.black),
              decoration: InputDecoration(
                labelText: 'Phone Number *',
                labelStyle: const TextStyle(color: Colors.black54),
                filled: true,
                fillColor: Colors.grey[200],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                errorText: _phoneError ? "Enter valid 10-digit Indian mobile number" : null,
                errorStyle: const TextStyle(color: Colors.red),
              ),
              initialCountryCode: 'IN',
              onChanged: (phone) {
                _fullPhoneNumber = phone.completeNumber;
                setState(() => _phoneError = false);
              },
              dropdownTextStyle: const TextStyle(color: Colors.black),
              dropdownIcon: const Icon(Icons.arrow_drop_down, color: Colors.black),
            ),
            const SizedBox(height: 16),

            // Gender
            _buildGenderDropdown(),
            const SizedBox(height: 16),

            // User Type
            if (!widget.isEditMode) ...[
              _buildUserTypeDropdown(),
              const SizedBox(height: 16),
            ],

            // Save Button
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

  Widget _buildDateField() {
    return GestureDetector(
      onTap: _selectDate,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(16),
          border: _selectedDate == null
              ? null
              : Border.all(color: Colors.transparent), // Helper for debugging layout
        ),
        child: Row(
          children: [
            Text(
              _selectedDate == null
                  ? "Birthday *" // Added asterisk
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

  Widget _buildGenderDropdown() {
    return DropdownButtonFormField<String>(
      value: _gender,
      dropdownColor: Colors.white,
      style: const TextStyle(color: Colors.black),
      decoration: InputDecoration(
        labelText: "Gender", // Implicitly mandatory due to default value
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