// lib/profile_page.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login_page.dart';
import 'barber_dashboard_page.dart';
import 'fill_profile_page.dart'; // NEW: Import EditProfilePage
import 'change_password_page.dart'; // NEW: Import ChangePasswordPage

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _isBarber = false;
  bool _isCheckingRole = true;

  @override
  void initState() {
    super.initState();
    _checkIfUserIsBarber();
  }

  Future<void> _checkIfUserIsBarber() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      setState(() => _isCheckingRole = false);
      return;
    }

    try {
      final response = await Supabase.instance.client
          .from('barber_shops')
          .select('id')
          .eq('owner_id', userId)
          .limit(1);

      if (mounted) {
        setState(() {
          _isBarber = response.isNotEmpty;
          _isCheckingRole = false;
        });
      }
    } catch (e) {
      debugPrint("Error checking barber role: $e");
      if (mounted) setState(() => _isCheckingRole = false);
    }
  }

  Future<void> _logout(BuildContext context) async {
    await Supabase.instance.client.auth.signOut();
    if (context.mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
            (route) => false,
      );
    }
  }

  // Navigate to Edit Profile
  void _goToEditProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const FillProfilePage(isEditMode: true)),
    );
  }

  // Navigate to Change Password
  void _goToChangePassword() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ChangePasswordPage()),
    );
  }

  // Show Help & Support Dialog (Placeholder)
  void _showHelpSupport() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Help & Support", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Text("Contact support at support@barberapp.com or visit our FAQ page.", style: GoogleFonts.poppins()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("OK")),
        ],
      ),
    );
  }

  // Show About App Dialog
  void _showAboutApp() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("About App", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Text(
          "Barber App v1.0\n\nA simple app for booking salon services.\nBuilt with Flutter and Supabase.\n\n© 2026 xAI",
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("OK")),
        ],
      ),
    );
  }

  // Navigate to Barber Dashboard
  void _goToBarberDashboard() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const BarberDashboardPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser!;
    final name = user.userMetadata?['full_name'] ?? 'User';
    final email = user.email ?? 'No email';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          "Profile",
          style: GoogleFonts.poppins(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 20),
            CircleAvatar(
              radius: 50,
              backgroundColor: Colors.orange,
              child: Text(
                name[0].toUpperCase(),
                style: const TextStyle(fontSize: 40, color: Colors.white),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              name,
              style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            Text(
              email,
              style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 32),
            _menuItem(Icons.edit, "Edit Details", _goToEditProfile),
            _menuItem(Icons.lock_outline, "Change Password", _goToChangePassword),
            _menuItem(Icons.help_outline, "Help & Support", _showHelpSupport),
            _menuItem(Icons.info_outline, "About App", _showAboutApp),

            // Only show Barber Dashboard if user is a barber
            if (_isCheckingRole)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: CircularProgressIndicator(color: Colors.orange),
              )
            else if (_isBarber)
              _menuItem(
                Icons.dashboard,
                "My Barber Dashboard",
                _goToBarberDashboard,
                color: Colors.orange,
                bold: true,
              ),

            const Spacer(),

            // Logout Button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.red, width: 2),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
                onPressed: () => _logout(context),
                child: Text(
                  "Logout",
                  style: GoogleFonts.poppins(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _menuItem(IconData icon, String title, VoidCallback onTap,
      {Color? color, bool bold = false}) {
    return ListTile(
      leading: Icon(icon, color: color ?? Colors.orange),
      title: Text(
        title,
        style: GoogleFonts.poppins(
          color: Colors.black,
          fontWeight: bold ? FontWeight.bold : FontWeight.w500,
          fontSize: bold ? 16 : 15,
        ),
      ),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.black54),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}