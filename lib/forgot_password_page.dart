import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'reset_password_page.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});
  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  // Controllers
  final _emailCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();

  // State
  bool _loading = false;
  bool _otpSent = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _otpCtrl.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------------------
  // 1. DATABASE CHECK (Email Only)
  // ------------------------------------------------------------------------
  Future<bool> _checkUserExists(String email) async {
    try {
      final result = await Supabase.instance.client
          .from('profiles')
          .select('id')
          .eq('email', email);

      if (result.isEmpty) {
        if (!mounted) return false;
        _showSnack("User not found. Please register first.", isError: true);
        return false;
      }
      return true;
    } catch (e) {
      debugPrint("DB Check skipped/failed: $e");
      return true; // Fallback
    }
  }

  // ------------------------------------------------------------------------
  // 2. SEND OTP (Email Only)
  // ------------------------------------------------------------------------
  Future<void> _sendOtp() async {
    final email = _emailCtrl.text.trim();

    if (email.isEmpty) {
      _showSnack("Please enter your email", isError: true);
      return;
    }

    setState(() => _loading = true);

    // Step A: Check Database
    bool exists = await _checkUserExists(email);
    if (!exists) {
      setState(() => _loading = false);
      return;
    }

    // Step B: Send Email Code
    try {
      await Supabase.instance.client.auth.signInWithOtp(
        email: email,
        shouldCreateUser: false,
      );

      if (!mounted) return;
      setState(() {
        _otpSent = true;
        _otpCtrl.clear();
      });
      _showSnack("Code sent! Check your inbox.", isError: false);
    } catch (e) {
      _showSnack("Error: $e", isError: true);
    } finally {
      setState(() => _loading = false);
    }
  }

  // ------------------------------------------------------------------------
  // 3. VERIFY OTP (Email Only)
  // ------------------------------------------------------------------------
  Future<void> _verifyOtp() async {
    final otp = _otpCtrl.text.trim();
    if (otp.length < 6) {
      _showSnack("Please enter the full 6-digit code", isError: true);
      return;
    }

    setState(() => _loading = true);
    try {
      await Supabase.instance.client.auth.verifyOTP(
        type: OtpType.email,
        email: _emailCtrl.text.trim(),
        token: otp,
      );

      if (!mounted) return;
      // Navigate to Reset Page
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const ResetPasswordPage()),
      );
    } catch (e) {
      _showSnack("Invalid code. Please try again.", isError: true);
    } finally {
      setState(() => _loading = false);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.poppins()),
      backgroundColor: isError ? Colors.redAccent : Colors.green,
      behavior: SnackBarBehavior.floating,
    ));
  }

  // ------------------------------------------------------------------------
  // UI BUILD
  // ------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: BackButton(
          color: Colors.black,
          onPressed: () {
            if (_otpSent) {
              setState(() => _otpSent = false);
            } else {
              Navigator.pop(context);
            }
          },
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6B00).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.lock_reset_rounded, size: 40, color: Color(0xFFFF6B00)),
              ),
              const SizedBox(height: 20),
              Text(
                _otpSent ? "Enter 6-Digit Code" : "Forgot Password?",
                style: GoogleFonts.poppins(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              const SizedBox(height: 8),
              Text(
                _otpSent
                    ? "We sent a code to ${_emailCtrl.text}"
                    : "Don't worry! It happens. Please enter your email below.",
                style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 30),

              // Inputs
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _otpSent ? _buildOtpSection() : _buildInputSection(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- SECTION 1: Email Input ---
  Widget _buildInputSection() {
    return Column(
      key: const ValueKey('input_section'),
      children: [
        _styledTextField(_emailCtrl, "Email Address", Icons.email_outlined, TextInputType.emailAddress),
        const SizedBox(height: 40),
        _actionButton("Send Code", _sendOtp),
      ],
    );
  }

  // --- SECTION 2: OTP Cube Input ---
  Widget _buildOtpSection() {
    return Column(
      key: const ValueKey('otp_section'),
      children: [
        // The Cube Widget
        _CubeOtpField(controller: _otpCtrl),

        const SizedBox(height: 40),
        _actionButton("Verify Code", _verifyOtp),

        const SizedBox(height: 20),
        TextButton(
          onPressed: _loading ? null : _sendOtp,
          child: Text(
            "Resend Code",
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.grey),
          ),
        ),
      ],
    );
  }

  // --- WIDGETS ---

  Widget _styledTextField(TextEditingController ctrl, String hint, IconData icon, TextInputType type) {
    return TextField(
      controller: ctrl,
      keyboardType: type,
      style: GoogleFonts.poppins(fontSize: 16),
      decoration: InputDecoration(
        labelText: hint,
        labelStyle: const TextStyle(color: Colors.grey),
        prefixIcon: Icon(icon, color: const Color(0xFFFF6B00)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey[300]!)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFFF6B00), width: 2)),
        filled: true,
        fillColor: Colors.white,
      ),
    );
  }

  Widget _actionButton(String text, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        onPressed: _loading ? null : onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFF6B00),
          elevation: 4,
          shadowColor: const Color(0xFFFF6B00).withOpacity(0.4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: _loading
            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : Text(text, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
      ),
    );
  }
}

// ------------------------------------------------------------------------
// 📦 CUSTOM CUBE OTP WIDGET
// ------------------------------------------------------------------------
class _CubeOtpField extends StatefulWidget {
  final TextEditingController controller;
  const _CubeOtpField({required this.controller});

  @override
  State<_CubeOtpField> createState() => _CubeOtpFieldState();
}

class _CubeOtpFieldState extends State<_CubeOtpField> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(() => setState(() {}));
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // 1. The Visible Cubes
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(6, (index) {
            final text = widget.controller.text;
            final char = index < text.length ? text[index] : "";
            final isActive = index == text.length;
            final isFilled = index < text.length;

            return Container(
              width: 45,
              height: 55,
              decoration: BoxDecoration(
                color: isFilled ? const Color(0xFFFF6B00).withOpacity(0.1) : Colors.white,
                border: Border.all(
                  color: isActive ? const Color(0xFFFF6B00) : Colors.grey[300]!,
                  width: isActive ? 2 : 1.5,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  char,
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
            );
          }),
        ),

        // 2. The Invisible Input Field (Captures taps & typing)
        Opacity(
          opacity: 0.0,
          child: TextField(
            controller: widget.controller,
            maxLength: 6,
            keyboardType: TextInputType.number,
            autofocus: true,
            showCursor: false,
            enableInteractiveSelection: false,
            decoration: const InputDecoration(counterText: ""),
          ),
        ),
      ],
    );
  }
}