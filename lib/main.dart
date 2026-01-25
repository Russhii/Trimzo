// lib/main.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'login_page.dart';
import 'home_page.dart'; // Customer Home
import 'owner_home_page.dart'; // Barber/Owner Home
import 'fill_profile_page.dart';
import 'reset_password_page.dart';
import 'my_bookings_page.dart';

import 'firebase_options.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Initialize Supabase
  try {
    await Supabase.initialize(
      url: 'https://otcqgozalgpmuzhocdlb.supabase.co',
      anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im90Y3Fnb3phbGdwbXV6aG9jZGxiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjM2MjczODUsImV4cCI6MjA3OTIwMzM4NX0.7VXQbHbkM790MnO6CrNiGEfvN3gZtlE3d7M-24LX4_c',
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

  // 3. Setup Notifications
  final messaging = FirebaseMessaging.instance;
  await messaging.requestPermission();

  // Save Token silently
  try {
    String? token = await messaging.getToken();
    if (token != null) {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        await Supabase.instance.client
            .from('profiles')
            .update({'fcm_token': token})
            .eq('id', user.id);
      }
    }
  } catch (_) {}

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
        scaffoldBackgroundColor: Colors.white,
        textTheme: GoogleFonts.poppinsTextTheme(ThemeData.light().textTheme),
        colorScheme: ColorScheme.fromSwatch(primarySwatch: Colors.orange)
            .copyWith(secondary: const Color(0xFFFF6B00)),
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

        // 2. Logged In -> Check Role
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

            // 3. Profile Incomplete -> Fill Profile
            if (profile == null || profile['full_name'] == null) {
              return const FillProfilePage();
            }

            // 4. Check User Type (Case Insensitive)
            final String userType = (profile['user_type'] ?? 'Customer').toString().toLowerCase();

            // ✅ REDIRECT LOGIC
            // Checks for 'barber' OR 'owner' to match your database images
            if (userType == 'barber' || userType == 'owner') {
              print("✅ User is Barber/Owner. Going to OwnerHomePage");
              return const OwnerHomePage();
            } else {
              print("👤 User is Customer. Going to HomePage");
              return const HomePage();
            }
          },
        );
      },
    );
  }
}