// lib/pages/forgot_password_page.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});
  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();

  bool _loading = false;
  bool _isPhoneMode = false;
  bool _otpSent = false;

  Future<void> _sendResetLink() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please enter your email")));
      return;
    }

    setState(() => _loading = true);
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(
        email,
        redirectTo: 'io.supabase.flutter://reset-password', // Direct parameter
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Check $email for reset link"), backgroundColor: Colors.green),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _sendPhoneOtp() async {
    final phone = _phoneCtrl.text.trim();
    if (phone.isEmpty || phone.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Enter valid phone number")));
      return;
    }

    setState(() => _loading = true);
    try {
      await Supabase.instance.client.auth.signInWithOtp(
        phone: phone,
        emailRedirectTo: 'io.supabase.flutter://reset-password', // Direct parameter for redirect (works for phone too)
        channel: OtpChannel.sms, // Explicitly use SMS
      );
      if (!mounted) return;
      setState(() => _otpSent = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("OTP sent to $phone"), backgroundColor: Colors.green),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _verifyOtpAndRecover() async {
    final phone = _phoneCtrl.text.trim();
    final otp = _otpCtrl.text.trim();

    if (otp.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Enter 6-digit OTP")));
      return;
    }

    setState(() => _loading = true);
    try {
      await Supabase.instance.client.auth.verifyOTP(
        type: OtpType.recovery,
        phone: phone,
        token: otp,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Verified! Set your new password"), backgroundColor: Colors.green),
      );
      // main.dart listener will automatically show ResetPasswordPage
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Invalid OTP: $e")));
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(backgroundColor: Colors.transparent, leading: const BackButton(color: Colors.white70)),
      body: Padding(
        padding: const EdgeInsets.all(32),
        child: SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 40),
              Image.asset('assets/images/forgot_password.png', height: 180),
              const SizedBox(height: 40),
              Text("Forgot Password", style: GoogleFonts.poppins(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 16),
              Text("Choose how you want to reset your password", textAlign: TextAlign.center, style: GoogleFonts.poppins(color: Colors.white60)),
              const SizedBox(height: 40),

              // Toggle Email / Phone
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => setState(() => _isPhoneMode = false),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: !_isPhoneMode ? const Color(0xFFFF6B00) : Colors.white.withOpacity(0.1),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      ),
                      child: Text("Email", style: GoogleFonts.poppins(color: Colors.white)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => setState(() => _isPhoneMode = true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isPhoneMode ? const Color(0xFFFF6B00) : Colors.white.withOpacity(0.1),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      ),
                      child: Text("Phone OTP", style: GoogleFonts.poppins(color: Colors.white)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),

              // Email Input
              if (!_isPhoneMode) ...[
                TextField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDecoration("your@email.com", Icons.email_outlined),
                ),
                const SizedBox(height: 40),
                _bigButton(_loading ? null : _sendResetLink, "Send Reset Link"),
              ],

              // Phone Input + OTP
              if (_isPhoneMode) ...[
                TextField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDecoration("+1234567890", Icons.phone_outlined),
                ),
                const SizedBox(height: 20),
                if (_otpSent)
                  TextField(
                    controller: _otpCtrl,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDecoration("6-digit OTP", Icons.sms_outlined),
                  ),
                const SizedBox(height: 40),
                _bigButton(
                  _loading ? null : (_otpSent ? _verifyOtpAndRecover : _sendPhoneOtp),
                  _otpSent ? "Verify OTP & Continue" : "Send OTP",
                ),
              ],

              const SizedBox(height: 60),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white38),
      prefixIcon: Icon(icon, color: Colors.white70),
      filled: true,
      fillColor: Colors.white.withOpacity(0.08),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
    );
  }

  Widget _bigButton(VoidCallback? onPressed, String text) {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF6B00), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))),
        child: _loading
            ? const CircularProgressIndicator(color: Colors.white)
            : Text(text, style: GoogleFonts.poppins(fontSize: 18, color: Colors.white)),
      ),
    );
  }
}