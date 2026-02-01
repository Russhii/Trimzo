// lib/main.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'login_page.dart';
import 'home_page.dart';
import 'owner_home_page.dart';
import 'fill_profile_page.dart';
import 'admin_page.dart';
import 'firebase_options.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// 🔒 SECURITY: Hardcoded Admin Email
const String _kSecureAdminEmail = 'admin@gmail.com';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Initialize Supabase
  try {
    await Supabase.initialize(
      url: 'https://otcqgozalgpmuzhocdlb.supabase.co',
      anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im90Y3Fnb3phbGdwbXV6aG9jZGxiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjM2MjczODUsImV4cCI6MjA3OTIwMzM4NX0.7VXQbHbkM790MnO6CrNiGEfvN3gZtlE3d7M-24LX4_c', // Keep your actual key
    );
  } catch (e) {
    debugPrint("❌ Supabase initialization failed: $e");
  }

  // 2. Initialize Firebase
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint("❌ Firebase initialization failed: $e");
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'Salon App',
      theme: ThemeData(
        brightness: Brightness.light,
        primaryColor: const Color(0xFFFF6B00),
        scaffoldBackgroundColor: Colors.grey[50],
        textTheme: GoogleFonts.poppinsTextTheme(ThemeData.light().textTheme),
        colorScheme: ColorScheme.fromSwatch(primarySwatch: Colors.orange)
            .copyWith(secondary: const Color(0xFFFF6B00)),
        useMaterial3: true,
      ),
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator(color: Colors.orange)),
          );
        }

        final user = snapshot.data?.session?.user;

        // 1. Not Logged In -> Login Page
        if (user == null || user.email == null) {
          return const LoginPage();
        }

        // 🔒 2. SECURITY CHECK: Is this the Super Admin?
        if (user.email == _kSecureAdminEmail) {
          return const AdminPage();
        }

        // 3. Regular User -> Fetch Role from 'profiles' table
        return FutureBuilder(
          future: Supabase.instance.client
              .from('profiles')
              .select('full_name, user_type')
              .eq('id', user.id)
              .maybeSingle(),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator(color: Colors.orange)),
              );
            }

            final profile = snap.data as Map<String, dynamic>?;

            // 4. Profile Incomplete -> Fill Profile
            if (profile == null || profile['full_name'] == null) {
              return const FillProfilePage();
            }

            // 5. Check User Type from 'profiles' table
            final String userType = (profile['user_type'] ?? 'Customer').toString().toLowerCase();

            if (userType == 'barber' || userType == 'owner') {
              return const OwnerHomePage();
            } else {
              return const HomePage();
            }
          },
        );
      },
    );
  }
}