import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../welcome_screen.dart';
import '../home_screen.dart';
import 'email_verification_screen.dart'; // Import the email verification screen

class AuthenticationWrapper extends StatelessWidget {
  const AuthenticationWrapper({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasData) {
          final user = snapshot.data!;
          // Check if email is verified
          if (!user.emailVerified) {
            // If email is not verified, navigate to email verification screen
            return const EmailVerificationScreen();
          } else {
            // User is logged in and email is verified, check onboarding status
            return FutureBuilder<DocumentSnapshot>(
              future:
                  FirebaseFirestore.instance
                      .collection('users')
                      .doc(user.uid)
                      .get(),
              builder: (context, userSnapshot) {
                if (userSnapshot.connectionState == ConnectionState.waiting) {
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                }

                if (userSnapshot.hasData && userSnapshot.data!.exists) {
                  final userData =
                      userSnapshot.data!.data() as Map<String, dynamic>;
                  final isOnboardingComplete =
                      userData['onboardingComplete'] ?? false;

                  if (isOnboardingComplete) {
                    // Onboarding complete, go to Home
                    return const HomeScreen();
                  } else {
                    // Onboarding not complete, go to onboarding
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      Navigator.pushReplacementNamed(context, '/onboarding');
                    });
                    return const Scaffold(
                      body: Center(child: CircularProgressIndicator()),
                    );
                  }
                }
                // If user doc doesn't exist, treat as not onboarded
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  Navigator.pushReplacementNamed(context, '/onboarding');
                });
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              },
            );
          }
        }
        // Not logged in, show welcome screen
        return const WelcomeScreen();
      },
    );
  }
}
