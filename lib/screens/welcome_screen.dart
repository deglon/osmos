import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'auth/patient_login_screen.dart';
import 'auth/patient_registration_screen.dart';
import 'home_screen.dart'; // Add this import if it's missing

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return Scaffold(
      backgroundColor: const Color(0xFF00B77D),
      body: Stack(
        children: [
          // Soft gradient overlay
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF00B77D), Color(0xFF038059)],
                ),
              ),
            ),
          ),
          // Abstract background shapes
          Positioned(
            top: -80,
            left: -60,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: -60,
            right: -40,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.07),
                shape: BoxShape.circle,
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 0,
                  vertical: 24,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Logo at the top
                    Image.asset(
                      'assets/images/osmoslogo.png',
                      width: 500,
                      height: 500,
                    ),
                    const SizedBox(height: 18),
                    // Removed the 'Osmos' text title
                    // Subtitle
                    Text(
                      'Your health companion',
                      style:
                          Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Colors.white.withOpacity(0.92),
                            fontWeight: FontWeight.w500,
                          ) ??
                          const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w500,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    // Tagline
                    Text(
                      'Empowering you to live healthier, every day.',
                      style:
                          Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Colors.white70,
                            fontWeight: FontWeight.w400,
                          ) ??
                          const TextStyle(color: Colors.white70, fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    // Glassmorphic/card action area
                    Container(
                      width: 420,
                      constraints: const BoxConstraints(maxWidth: 420),
                      padding: const EdgeInsets.symmetric(
                        vertical: 32,
                        horizontal: 28,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.13),
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                        border: Border.all(
                          color: Colors.white.withOpacity(0.10),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (context) => const PatientLoginScreen(),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: const Color(0xFF00B77D),
                              minimumSize: const Size(double.infinity, 52),
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                              textStyle: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            child: const Text('Log In'),
                          ),
                          const SizedBox(height: 16),
                          OutlinedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (context) =>
                                          const PatientRegistrationScreen(),
                                ),
                              );
                            },
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(
                                color: Colors.white,
                                width: 2,
                              ),
                              foregroundColor: Colors.white,
                              minimumSize: const Size(double.infinity, 52),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                              textStyle: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            child: const Text('Sign Up'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

void main() {
  runApp(const FigmaToCodeApp());
}

class FigmaToCodeApp extends StatelessWidget {
  const FigmaToCodeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Osmos Health',
      theme: ThemeData(
        primaryColor: const Color(0xFF00B77D),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00B77D),
          primary: const Color(0xFF00B77D),
          secondary: const Color(0xFF038059),
        ),
        useMaterial3: true,
      ),
      home: const WelcomeScreen(),
    );
  }
}
