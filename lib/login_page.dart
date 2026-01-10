import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'signin_page.dart';
import 'signup_page.dart';
import 'fill_profile_page.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const SizedBox(height: 40),

              // Illustration
              Image.asset(
                'assets/images/lets_you_in.png',  // Your local image file
                height: 240,
                fit: BoxFit.contain,  // Keeps aspect ratio like your screenshot
                errorBuilder: (context, error, stackTrace) => const Icon(
                  Icons.image_not_supported,
                  size: 240,
                  color: Colors.orange,
                ),
              ),

              const SizedBox(height: 50),
              Text(
                "Let's you in",
                style: GoogleFonts.poppins(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
                textAlign: TextAlign.center,
              ),

              const Spacer(flex: 2),

              // Facebook
              _SocialButton(
                icon: 'https://cdn.jsdelivr.net/npm/simple-icons@v13/icons/facebook.svg',
                color: const Color(0xFF1877F2),
                text: 'Continue with Facebook',
                onTap: () => Supabase.instance.client.auth.signInWithOAuth(OAuthProvider.facebook),
              ),

              const SizedBox(height: 16),

              // Google
              _SocialButton(
                icon: 'https://cdn.jsdelivr.net/npm/simple-icons@v13/icons/google.svg',
                text: 'Continue with Google',
                onTap: () async {
                  await Supabase.instance.client.auth.signInWithOAuth(OAuthProvider.google);
                },

              ),

              const SizedBox(height: 50),
              const Text("or", style: TextStyle(color: Colors.grey, fontSize: 16)),
              const SizedBox(height: 30),

              // Sign in with password
              SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton(
                  onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const SignInPage())),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF6B00),
                    elevation: 20,
                    shadowColor: const Color(0xFFFF6B00).withOpacity(0.7),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                  child: Text(
                    "Sign in with password",
                    style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white),
                  ),
                ),
              ),

              const SizedBox(height: 40),

              GestureDetector(
                onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const SignUpPage())),
                child: Text.rich(
                  TextSpan(
                    text: "Don't have an account? ",
                    style: const TextStyle(color: Colors.grey),
                    children: [
                      TextSpan(
                        text: "Sign up",
                        style: GoogleFonts.poppins(color: const Color(0xFFFF6B00), fontWeight: FontWeight.bold),
                      )
                    ],
                  ),
                ),
              ),

              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}

class _SocialButton extends StatelessWidget {
  final String icon;
  final Color? color;
  final String text;
  final VoidCallback onTap;

  const _SocialButton({required this.icon, this.color, required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Colors.black26, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SvgPicture.network(icon, height: 28, width: 28, colorFilter: color != null ? ColorFilter.mode(color!, BlendMode.srcIn) : null),
            const SizedBox(width: 16),
            Text(text, style: GoogleFonts.poppins(fontSize: 17, color: Colors.black)),
          ],
        ),
      ),
    );
  }
}