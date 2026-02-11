import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Import your pages
import 'home_page.dart';
import 'signup_page.dart';
import 'forgot_password_page.dart'; // <--- THIS is the correct import
import 'main.dart'; // To access AuthWrapper

class SignInPage extends StatefulWidget {
  const SignInPage({super.key});
  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _rememberMe = false;
  bool _isLoading = false;

  Future<void> _login() async {
    if (_emailCtrl.text.isEmpty || _passCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill all fields")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await Supabase.instance.client.auth.signInWithPassword(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text,
      );

      if (response.session != null && response.user != null) {
        // Auto-create/upsert profile just in case it's missing
        await Supabase.instance.client.from('profiles').upsert({
          'id': response.user!.id,
          'email': response.user!.email,
        }, onConflict: 'id');

        if (mounted) {
          // ✅ FIX: Send user to AuthWrapper to decide role (Barber/Customer)
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const AuthWrapper()),
                (route) => false,
          );
        }
      }
    } on AuthException catch (e) {
      String message;
      if (e.message.contains('Invalid login credentials')) {
        message = "Invalid email or password";
      } else if (e.message.contains('Email not confirmed')) {
        message = "Please confirm your email first.";
      } else {
        message = "Login failed: ${e.message}";
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Unexpected error: $e")),
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
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                IconButton(
                  onPressed: () {
                    if (Navigator.canPop(context)) {
                      Navigator.pop(context);
                    }
                  },
                  icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
                ),

                const SizedBox(height: 20),
                Text("Login to your\nAccount",
                    style: GoogleFonts.poppins(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.black)),

                const SizedBox(height: 60),

                _InputField(controller: _emailCtrl, hint: "Email", icon: Icons.mail_outline_rounded),
                const SizedBox(height: 20),
                _InputField(controller: _passCtrl, hint: "Password", icon: Icons.lock_outline_rounded, isPassword: true),

                const SizedBox(height: 16),
                Row(children: [
                  Checkbox(
                      value: _rememberMe,
                      activeColor: const Color(0xFFFF6B00),
                      onChanged: (v) => setState(() => _rememberMe = v!)
                  ),
                  Text("Remember me", style: GoogleFonts.poppins(color: Colors.black)),
                ]),

                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF6B00),
                      elevation: 10,
                      shadowColor: const Color(0xFFFF6B00).withOpacity(0.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text("Sign in", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white)),
                  ),
                ),

                const SizedBox(height: 16),
                Center(
                  child: GestureDetector(
                    // ✅ FIXED: Navigates to ForgotPasswordPage (Input Email/Phone)
                    // instead of ResetPasswordPage (New Password)
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ForgotPasswordPage()),
                      );
                    },
                    child: Text(
                      "Forgot the password?",
                      style: GoogleFonts.poppins(
                        color: const Color(0xFFFF6B00),
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        decoration: TextDecoration.underline,
                        decorationColor: const Color(0xFFFF6B00),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 40),
                const Center(child: Text("or continue with", style: TextStyle(color: Colors.grey))),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _SocialIcon(
                      'https://cdn.jsdelivr.net/npm/simple-icons@v13/icons/facebook.svg',
                      color: const Color(0xFF1877F2),
                      onTap: () => Supabase.instance.client.auth.signInWithOAuth(OAuthProvider.facebook),
                    ),
                    const SizedBox(width: 30),
                    _SocialIcon(
                      'https://cdn.jsdelivr.net/npm/simple-icons@v13/icons/google.svg',
                      onTap: () => Supabase.instance.client.auth.signInWithOAuth(OAuthProvider.google),
                    ),
                  ],
                ),

                const SizedBox(height: 30),
                Center(
                  child: GestureDetector(
                    onTap: () => Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => const SignUpPage())
                    ),
                    child: Text.rich(TextSpan(
                      text: "Don't have an account? ",
                      style: const TextStyle(color: Colors.grey),
                      children: [
                        TextSpan(
                            text: "Sign up",
                            style: GoogleFonts.poppins(color: const Color(0xFFFF6B00), fontWeight: FontWeight.bold)
                        )
                      ],
                    )),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InputField extends StatefulWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool isPassword;
  const _InputField({required this.controller, required this.hint, required this.icon, this.isPassword = false});

  @override
  State<_InputField> createState() => _InputFieldState();
}

class _InputFieldState extends State<_InputField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      obscureText: widget.isPassword ? _obscure : false,
      style: const TextStyle(color: Colors.black),
      decoration: InputDecoration(
        prefixIcon: Icon(widget.icon, color: Colors.black54),
        suffixIcon: widget.isPassword
            ? IconButton(
          icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
          onPressed: () => setState(() => _obscure = !_obscure),
        )
            : null,
        hintText: widget.hint,
        hintStyle: const TextStyle(color: Colors.black38),
        filled: true,
        fillColor: Colors.grey[200],
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      ),
    );
  }
}

class _SocialIcon extends StatelessWidget {
  final String url;
  final Color? color;
  final VoidCallback onTap;

  const _SocialIcon(this.url, {this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(16)),
        child: SvgPicture.network(
            url,
            height: 32,
            width: 32,
            colorFilter: color != null ? ColorFilter.mode(color!, BlendMode.srcIn) : null
        ),
      ),
    );
  }
}