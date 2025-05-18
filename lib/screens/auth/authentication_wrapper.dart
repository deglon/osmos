import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../welcome_screen.dart';
import '../home_screen.dart';
import '../onboarding/emotion_screen.dart';
import 'email_verification_screen.dart'; // Import the email verification screen

class AuthenticationWrapper extends StatelessWidget {
  const AuthenticationWrapper({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const CircularProgressIndicator();
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
              future: FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid) // Use user.uid here
                  .get(),
              builder: (context, userSnapshot) {
                if (userSnapshot.connectionState == ConnectionState.waiting) {
                  return const CircularProgressIndicator();
                }

                if (userSnapshot.hasData && userSnapshot.data!.exists) {
                  final userData = userSnapshot.data!.data() as Map<String, dynamic>;
                  final isOnboardingComplete = userData['isComplete'] ?? false;

                  if (isOnboardingComplete) {
                    // Onboarding complete, go to Home
                    return const HomeScreen();
                  } else {
                    // Onboarding not complete, go to the first onboarding screen
                    return const EmotionScreen();
                  }
                } else {
                  // User document doesn't exist, maybe a new user who hasn't completed onboarding setup?
                  // Or an error occurred. For now, direct to onboarding start.
                  // You might want more robust error handling or initial user doc creation logic here.
                  return const EmotionScreen();
                }
              },
            );
          }
        } else {
          // User is not logged in, show welcome screen
          return const WelcomeScreen();
        }
      },
    );
  }
}