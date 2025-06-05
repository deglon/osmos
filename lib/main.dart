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
import 'screens/onboarding/onboarding_flow_screen.dart';
import 'controllers/onboarding_controller.dart';
import 'screens/auth/authentication_wrapper.dart';
import 'providers/user_profile_provider.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // Initialize local notifications
  await NotificationService().initialize();
  runApp(
    ChangeNotifierProvider(
      create: (_) => UserProfileProvider(),
      child: const OsmosApp(),
    ),
  );
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
        // Only keep the new dynamic onboarding flow
        '/onboarding':
            (context) => ChangeNotifierProvider(
              create: (_) => OnboardingController(),
              child: const OnboardingFlowScreen(),
            ),
        '/verify-email': (context) => const EmailVerificationScreen(),
        '/emailVerification': (context) => const EmailVerificationScreen(),
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
      // Fetch user profile before navigating to home screen
      await Provider.of<UserProfileProvider>(
        context,
        listen: false,
      ).fetchUserProfile();
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
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return _nextScreen!;
  }
}
