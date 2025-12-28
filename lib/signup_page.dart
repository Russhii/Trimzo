// lib/signup_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'fill_profile_page.dart';
import 'home_page.dart';
import 'signin_page.dart';
import 'login_page.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});
  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _rememberMe = false;

  Future<void> _signUpAndRedirect() async {
    if (_emailCtrl.text.isEmpty || _passCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill all fields")),
      );
      return;
    }

    try {
      // This will now work instantly because email confirmation is OFF in dashboard
      final response = await Supabase.instance.client.auth.signUp(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text,
      );

      if (!mounted) return;

      if (response.user != null) {
        // Profile created automatically via trigger → now go to Fill Profile
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const FillProfilePage()),
              (route) => false,
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: ${e.toString()}")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),

              IconButton(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginPage()),
                  );
                },
                icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
              ),

              const SizedBox(height: 20),

              Text(
                "Create your\nAccount",
                style: GoogleFonts.poppins(
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),

              const Spacer(flex: 2),

              _InputField(controller: _emailCtrl, hint: "Email", icon: Icons.mail_outline_rounded),
              const SizedBox(height: 20),
              _InputField(controller: _passCtrl, hint: "Password", icon: Icons.lock_outline_rounded, isPassword: true),

              const SizedBox(height: 16),
              Row(
                children: [
                  Checkbox(
                    value: _rememberMe,
                    activeColor: Colors.orange,
                    onChanged: (v) => setState(() => _rememberMe = v!),
                  ),
                  Text("Remember me", style: GoogleFonts.poppins(color: Colors.black)),
                ],
              ),

              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton(
                  onPressed: _signUpAndRedirect,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF6B00),
                    elevation: 20,
                    shadowColor: const Color(0xFFFF6B00).withOpacity(0.7),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                  child: Text(
                    "Sign up",
                    style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white),
                  ),
                ),
              ),

              const Spacer(flex: 2),
              const Center(child: Text("or continue with", style: TextStyle(color: Colors.grey))),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _SocialIcon('https://cdn.jsdelivr.net/npm/simple-icons@v13/icons/facebook.svg', color: const Color(0xFF1877F2)),
                  const SizedBox(width: 30),
                  _SocialIcon('https://cdn.jsdelivr.net/npm/simple-icons@v13/icons/google.svg'),
                ],
              ),

              const SizedBox(height: 30),
              Center(
                child: GestureDetector(
                  onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const SignInPage())),
                  child: Text.rich(
                    TextSpan(
                      text: "Already have an account? ",
                      style: const TextStyle(color: Colors.grey),
                      children: [
                        TextSpan(
                          text: "Sign in",
                          style: GoogleFonts.poppins(color: const Color(0xFFFF6B00), fontWeight: FontWeight.bold),
                        )
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

// Reusable widgets
class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool isPassword;
  const _InputField({required this.controller, required this.hint, required this.icon, this.isPassword = false});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: isPassword,
      style: const TextStyle(color: Colors.black),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: Colors.black54),
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.black38),
        filled: true,
        fillColor: Colors.black.withOpacity(0.08),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      ),
    );
  }
}

class _SocialIcon extends StatelessWidget {
  final String url;
  final Color? color;
  const _SocialIcon(this.url, {this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.black.withOpacity(0.08), borderRadius: BorderRadius.circular(16)),
      child: SvgPicture.network(url, height: 32, width: 32, colorFilter: color != null ? ColorFilter.mode(color!, BlendMode.srcIn) : null),
    );
  }
}
