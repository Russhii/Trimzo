// lib/main.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'login_page.dart';
import 'home_page.dart';
import 'profile_page.dart';
import 'fill_profile_page.dart';
import 'reset_password_page.dart';
import 'owner_home_page.dart'; // <--- NEW OWNER HOME PAGE

// 🔑 Global navigator key (REQUIRED for recovery & deep links)
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ Initialize Supabase
  await Supabase.initialize(
    url: 'https://otcqgozalgpmuzhocdlb.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im90Y3Fnb3phbGdwbXV6aG9jZGxiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjM2MjczODUsImV4cCI6MjA3OTIwMzM4NX0.7VXQbHbkM790MnO6CrNiGEfvN3gZtlE3d7M-24LX4_c',
  );

  // ✅ Listen for auth changes (PASSWORD RECOVERY)
  Supabase.instance.client.auth.onAuthStateChange.listen((data) {
    final event = data.event;
    final session = data.session;

    if (event == AuthChangeEvent.passwordRecovery && session != null) {
      navigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const ResetPasswordPage()),
            (route) => false,
      );
    }
  });

  runApp(const MyApp());
}

// ======================= APP ROOT =======================

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey, // 🔑 REQUIRED
      debugShowCheckedModeBanner: false,
      title: 'Salon App',
      theme: ThemeData(
        brightness: Brightness.light,
        primaryColor: const Color(0xFFFF6B00),
        scaffoldBackgroundColor: Colors.white,
        textTheme: GoogleFonts.poppinsTextTheme(
          ThemeData.light().textTheme,
        ),
        colorScheme: ColorScheme.fromSwatch(
          primarySwatch: Colors.orange,
        ).copyWith(
          secondary: const Color(0xFFFF6B00),
          brightness: Brightness.light,
        ),
      ),
      home: const AuthWrapper(),
    );
  }
}

// ======================= AUTH WRAPPER =======================

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        // 1. Loading Auth State
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: Colors.orange),
            ),
          );
        }

        final user = snapshot.data?.session?.user;

        // 2. Not Logged In -> Login Page
        if (user == null || user.email == null || user.email!.isEmpty) {
          return const LoginPage();
        }

        // 3. Logged In -> Check Profile & Role
        return FutureBuilder(
          future: Supabase.instance.client
              .from('profiles')
              .select('full_name, role') // <--- FETCH ROLE
              .eq('id', user.id)
              .maybeSingle(),
          builder: (context, snap) {
            // Loading Profile
            if (snap.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(
                  child: CircularProgressIndicator(color: Colors.orange),
                ),
              );
            }

            final profile = snap.data as Map<String, dynamic>?;
            final hasFullName = profile != null && profile['full_name'] != null;

            // 4. Profile not filled -> Fill Profile Page
            if (!hasFullName) {
              return const FillProfilePage();
            }

            // 5. Check Role -> Redirect accordingly
            // Default to 'customer' if role is null
            final String role = profile['role'] ?? 'customer';

            if (role == 'owner') {
              return const OwnerHomePage(); // <--- Redirect Owner
            } else {
              return const HomePage(); // <--- Redirect Customer
            }
          },
        );
      },
    );
  }
}