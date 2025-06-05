import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:lottie/lottie.dart';
// import 'package:osmos/screens/onboarding/onboarding_flow.dart';

class EmailVerificationScreen extends StatefulWidget {
  const EmailVerificationScreen({super.key});

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen>
    with SingleTickerProviderStateMixin {
  final auth = FirebaseAuth.instance;
  User? user;
  Timer? timer;
  bool isEmailVerified = false;
  bool canResendEmail = false;

  // Animation controller for the verification animation
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    user = auth.currentUser;

    // Initialize animation controller
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    // Check if the user's email is verified
    if (user != null && !user!.emailVerified) {
      timer = Timer.periodic(
        const Duration(seconds: 3),
        (_) => checkEmailVerified(),
      );
    }

    // Allow resending after 30 seconds
    Timer(const Duration(seconds: 30), () {
      if (mounted) {
        setState(() {
          canResendEmail = true;
        });
      }
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> checkEmailVerified() async {
    await auth.currentUser?.reload();

    if (mounted) {
      setState(() {
        isEmailVerified = auth.currentUser?.emailVerified ?? false;
      });

      if (isEmailVerified) {
        // Play the animation when email is verified
        _animationController.forward();
        timer?.cancel();

        // Delay navigation to allow animation to play
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            // Navigate to the onboarding entry point
            Navigator.pushReplacementNamed(context, '/onboarding');
          }
        });
      }
    }
  }

  Future<void> sendVerificationEmail() async {
    try {
      await user?.sendEmailVerification();

      setState(() {
        canResendEmail = false;
      });

      // Allow resending after 30 seconds
      Timer(const Duration(seconds: 30), () {
        if (mounted) {
          setState(() {
            canResendEmail = true;
          });
        }
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Verification email sent!')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error sending email: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF00B77D),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Email Verification',
          style: TextStyle(color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            // Sign out and go back to login
            auth.signOut();
            Navigator.pop(context);
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Show animation when verified, otherwise show email icon
            if (isEmailVerified)
              Stack(
                alignment: Alignment.center,
                children: [
                  // Green circle background
                  Container(
                    width: 120,
                    height: 120,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                  // Check mark animation
                  SizedBox(
                    width: 150,
                    height: 150,
                    child: AnimatedBuilder(
                      animation: _animationController,
                      builder: (context, child) {
                        return CustomPaint(
                          painter: CheckMarkPainter(
                            animation: _animationController.value,
                            color: const Color(0xFF00B77D),
                            strokeWidth: 8,
                          ),
                        );
                      },
                    ),
                  ),
                ],
              )
            else
              const Icon(Icons.email_outlined, size: 100, color: Colors.white),
            const SizedBox(height: 24),
            Text(
              isEmailVerified ? 'Email Verified!' : 'Verify your email',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isEmailVerified
                  ? 'Your email has been successfully verified. You will be redirected shortly.'
                  : 'We\'ve sent a verification email to ${user?.email}. Please check your inbox and click the verification link.',
              style: const TextStyle(fontSize: 16, color: Colors.white70),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            if (!isEmailVerified)
              ElevatedButton(
                onPressed: canResendEmail ? sendVerificationEmail : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF006B49),
                  padding: const EdgeInsets.symmetric(
                    vertical: 16,
                    horizontal: 32,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  canResendEmail ? 'Resend Email' : 'Wait to resend',
                  style: const TextStyle(fontSize: 16, color: Colors.white),
                ),
              ),
            const SizedBox(height: 16),
            if (!isEmailVerified)
              TextButton(
                onPressed: () {
                  // Sign out and go back to login
                  auth.signOut();
                  Navigator.pop(context);
                },
                child: const Text(
                  'Back to Login',
                  style: TextStyle(color: Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// Custom painter for the check mark animation
class CheckMarkPainter extends CustomPainter {
  final double animation;
  final Color color;
  final double strokeWidth;

  CheckMarkPainter({
    required this.animation,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint =
        Paint()
          ..color = color
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke;

    final double progress = animation;

    // Calculate check mark points
    final Path path = Path();

    // Starting point of the check mark
    final Offset start = Offset(size.width * 0.25, size.height * 0.5);

    // Bottom point of the check mark
    final Offset mid = Offset(size.width * 0.45, size.height * 0.7);

    // End point of the check mark
    final Offset end = Offset(size.width * 0.75, size.height * 0.3);

    // Draw the first part of the check mark (from start to mid)
    if (progress < 0.5) {
      final double firstPartProgress = progress * 2;
      path.moveTo(start.dx, start.dy);
      path.lineTo(
        start.dx + (mid.dx - start.dx) * firstPartProgress,
        start.dy + (mid.dy - start.dy) * firstPartProgress,
      );
    } else {
      // Draw the complete first part
      path.moveTo(start.dx, start.dy);
      path.lineTo(mid.dx, mid.dy);

      // Draw the second part of the check mark (from mid to end)
      final double secondPartProgress = (progress - 0.5) * 2;
      path.lineTo(
        mid.dx + (end.dx - mid.dx) * secondPartProgress,
        mid.dy + (end.dy - mid.dy) * secondPartProgress,
      );
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CheckMarkPainter oldDelegate) {
    return oldDelegate.animation != animation ||
        oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
