// lib/profile_page.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login_page.dart';
import 'barber_dashboard_page.dart'; // Import your barber dashboard

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

  // Navigate to Edit Profile (for customers)
  void _goToEditProfile() {
    // TODO: Create this page later (CustomerProfileEditPage)
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Edit Profile page coming soon!")),
    );
    // Example navigation:
    // Navigator.push(context, MaterialPageRoute(builder: (_) => const CustomerProfileEditPage()));
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
    final fullName = user.userMetadata?['full_name'] ??
        user.email?.split('@').first ??
        'User';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        title: Text(
          "Profile",
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.black),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.red),
            tooltip: "Logout",
            onPressed: () => _logout(context),
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            CircleAvatar(
              radius: 60,
              backgroundImage: NetworkImage(user.userMetadata?['avatar_url'] ?? ''),
              onBackgroundImageError: (_, __) => null,
              child: user.userMetadata?['avatar_url'] == null
                  ? const Icon(Icons.person, size: 80, color: Colors.grey)
                  : null,
            ),
            const SizedBox(height: 20),
            Text(
              fullName,
              style: GoogleFonts.poppins(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              user.email ?? '',
              style: GoogleFonts.poppins(color: Colors.black54, fontSize: 16),
            ),
            const SizedBox(height: 40),

            // Menu Items
            _menuItem(Icons.person_outline, "Edit Profile", _goToEditProfile),

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

            _menuItem(Icons.lock_outline, "Change Password", () {}),
            _menuItem(Icons.help_outline, "Help & Support", () {}),
            _menuItem(Icons.info_outline, "About App", () {}),

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