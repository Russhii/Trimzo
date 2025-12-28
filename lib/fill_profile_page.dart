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
  const FillProfilePage({super.key});

  @override
  State<FillProfilePage> createState() => _FillProfilePageState();
}

class _FillProfilePageState extends State<FillProfilePage> {
  final _fullNameCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  String? _fullPhoneNumber;

  DateTime? _selectedDate;
  String _gender = 'Male';
  String _userType = 'Customer'; // New field for user type
  File? _profileImage;

  final picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    final user = Supabase.instance.client.auth.currentUser;
    if (user?.email != null) {
      _emailCtrl.text = user!.email!;
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
      initialDate: DateTime(2000),
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
    if (picked != null) {
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

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      await Supabase.instance.client.from('profiles').upsert({
        'id': user.id,
        'full_name': _fullNameCtrl.text.trim(),
        'username': _usernameCtrl.text.trim(),
        'birthday': _selectedDate?.toIso8601String(),
        'phone': _fullPhoneNumber,
        'gender': _gender,
        'user_type': _userType,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Profile saved!")),
      );

      if (!mounted) return;

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
    } catch (e) {
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
        );
      }
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const LoginPage()),
                  (route) => false,
            );
          },

        ),
        title: Text(
          "Fill Your Profile",
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
      ),
      body: SingleChildScrollView(
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
                      : const AssetImage('assets/avatar_placeholder.png')
                  as ImageProvider,
                  backgroundColor: Colors.grey[200],
                  child: _profileImage == null
                      ? Icon(Icons.person, size: 70, color: Colors.grey[400])
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

            // Email (disabled)
            _buildTextField(_emailCtrl, "Email", enabled: false),
            const SizedBox(height: 16),

            // Phone Number
            _buildPhoneField(),
            const SizedBox(height: 16),

            // Gender
            _buildGenderDropdown(),
            const SizedBox(height: 16),

            // User Type (Customer or Barber)
            _buildUserTypeDropdown(),
            const SizedBox(height: 60),

            // Save Button
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                onPressed: _saveProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF6B00),
                  elevation: 10,
                  shadowColor: const Color(0xFFFF6B00).withOpacity(0.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: Text(
                  "Continue",
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
  Widget _buildTextField(TextEditingController controller, String hint,
      {bool enabled = true}) {
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
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
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
                  : DateFormat('MM/dd/yyyy').format(_selectedDate!),
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

  // User Type Dropdown (Customer or Barber)
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
