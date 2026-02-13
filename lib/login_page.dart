import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart'; // REQUIRED for Native Login

import 'signin_page.dart';
import 'signup_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {

  // ---------------------------------------------------------
  // 👇 REPLACE THIS WITH YOUR ACTUAL WEB CLIENT ID FROM GOOGLE CLOUD
  // It looks like: "123456789-abcde...apps.googleusercontent.com"
  static const String _webClientId = '294768462523-ijkd535a5g4q86sfg7eg9q43i65g9sv6.apps.googleusercontent.com';
  // ---------------------------------------------------------

  bool _isLoading = false;

  Future<void> _googleSignIn() async {
    setState(() => _isLoading = true);

    try {
      // 1. Setup Google Sign In
      final GoogleSignIn googleSignIn = GoogleSignIn(
        serverClientId: _webClientId,
      );
      await googleSignIn.signOut();

      // 2. Open the Native Android Dialog
      final googleUser = await googleSignIn.signIn();
      final googleAuth = await googleUser?.authentication;

      if (googleAuth == null) {
        // User cancelled the login
        setState(() => _isLoading = false);
        return;
      }

      final accessToken = googleAuth.accessToken;
      final idToken = googleAuth.idToken;

      if (idToken == null) {
        throw 'No ID Token found.';
      }

      // 3. Send tokens to Supabase
      await Supabase.instance.client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );

      // 4. Success! The AuthWrapper in main.dart will handle the navigation.

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Login Failed: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
      setState(() => _isLoading = false);
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
            children: [
              const SizedBox(height: 40),

              // Illustration
              Image.asset(
                'assets/app_icon.png',
                height: 240,
                fit: BoxFit.contain,
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

              // Loading Indicator override
              if (_isLoading)
                const CircularProgressIndicator(color: Color(0xFFFF6B00))
              else
                Column(
                  children: [
                    // Facebook (Optional - kept standard redirect for now)
                    _SocialButton(
                      icon: 'https://cdn.jsdelivr.net/npm/simple-icons@v13/icons/facebook.svg',
                      color: const Color(0xFF1877F2),
                      text: 'Continue with Facebook',
                      onTap: () => Supabase.instance.client.auth.signInWithOAuth(OAuthProvider.facebook),
                    ),

                    const SizedBox(height: 16),

                    // Google (NATIVE IMPLEMENTATION)
                    _SocialButton(
                      icon: 'https://cdn.jsdelivr.net/npm/simple-icons@v13/icons/google.svg',
                      text: 'Continue with Google',
                      onTap: _googleSignIn, // Calls our new native function
                    ),
                  ],
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
            SvgPicture.network(
              icon,
              height: 28,
              width: 28,
              colorFilter: color != null ? ColorFilter.mode(color!, BlendMode.srcIn) : null,
              placeholderBuilder: (BuildContext context) => const Icon(Icons.error), // Handles loading
            ),
            const SizedBox(width: 16),
            Text(text, style: GoogleFonts.poppins(fontSize: 17, color: Colors.black)),
          ],
        ),
      ),
    );
  }
}