import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'screens/auth/email_verification_screen.dart';
import 'screens/auth/patient_login_screen.dart';
import 'screens/auth/patient_registration_screen.dart';
import 'screens/welcome_screen.dart';
import 'screens/home_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/ask_osmos/vocal_chatbot_screen.dart';
// Import the new onboarding screens
import 'screens/onboarding/emotion_screen.dart';
import 'screens/onboarding/role_screen.dart';
import 'screens/onboarding/patient_screen.dart';
import 'screens/onboarding/wellness_screen.dart';
import 'screens/onboarding/caregiver_screen.dart';
// Import the OnboardingController
import 'controllers/onboarding_controller.dart';
// Import the AuthenticationWrapper
import 'screens/auth/authentication_wrapper.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const OsmosApp());
}

class OsmosApp extends StatelessWidget {
  const OsmosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Osmos',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00B77D),
          primary: const Color(0xFF00B77D),
          background: Colors.white,
        ),
        useMaterial3: true,
      ),
      home: const AuthenticationWrapper(),
      routes: {
        '/login': (context) => const PatientLoginScreen(),
        '/register': (context) => const PatientRegistrationScreen(),
        '/home': (context) => const HomeScreen(),
        // Onboarding routes wrapped with Provider for the controller
        '/onboarding/emotion': (context) => ChangeNotifierProvider(
          create: (_) => OnboardingController(),
          child: const EmotionScreen(),
        ),
        '/onboarding/role': (context) => ChangeNotifierProvider(
          create: (_) => OnboardingController(),
          child: const RoleScreen(),
        ),
        '/onboarding/patient': (context) => ChangeNotifierProvider(
          create: (_) => OnboardingController(),
          child: const PatientScreen(),
        ),
        '/onboarding/wellness': (context) => ChangeNotifierProvider(
          create: (_) => OnboardingController(),
          child: const WellnessScreen(),
        ),
        '/onboarding/caregiver': (context) => ChangeNotifierProvider(
          create: (_) => OnboardingController(),
          child: const CaregiverScreen(),
        ),
        '/verify-email': (context) => const EmailVerificationScreen(),
        '/profile': (context) => const ProfileScreen(),
      },
    );
  }
}



class AuthenticationWrapper extends StatefulWidget {
  const AuthenticationWrapper({super.key});

  @override
  State<AuthenticationWrapper> createState() => _AuthenticationWrapperState();
}

class _AuthenticationWrapperState extends State<AuthenticationWrapper> {
  bool _initialized = false;
  Widget? _nextScreen;

  @override
  void initState() {
    super.initState();
    _checkAuthAndOnboarding();
  }

  Future<void> _checkAuthAndOnboarding() async {
    final user = FirebaseAuth.instance.currentUser;
    final prefs = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
    
    if (user != null && isLoggedIn) {
      // User is logged in, navigate to home screen
      setState(() {
        _initialized = true;
        _nextScreen = const HomeScreen();
      });
    } else {
      // User is not logged in, show welcome screen
      setState(() {
        _initialized = true;
        _nextScreen = const WelcomeScreen();
      });
      
      // Clear any stale login state if user is null but isLoggedIn is true
      if (user == null && isLoggedIn) {
        await prefs.setBool('isLoggedIn', false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    return _nextScreen!;
  }
}