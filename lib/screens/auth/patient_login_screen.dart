import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'patient_registration_screen.dart';
import '../home_screen.dart'; // Import the new HomeScreen
import '../stats_screen.dart'; // Make sure StatsScreen is also accessible if needed elsewhere
import 'package:osmos/widgets/modern_text_field.dart';

class PatientLoginScreen extends StatefulWidget {
  const PatientLoginScreen({Key? key}) : super(key: key);

  @override
  State<PatientLoginScreen> createState() => _PatientLoginScreenState();
}

class _PatientLoginScreenState extends State<PatientLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      // Save login state to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', true);

      if (mounted) {
        // Navigate to the home screen (the main shell with bottom nav)
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const HomeScreen(),
          ), // Navigate to the main HomeScreen
        );
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMessage = e.message ?? 'An error occurred during login';
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'An unexpected error occurred';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Initialize GoogleSignIn with your web client ID
      final GoogleSignIn googleSignIn = GoogleSignIn(
        clientId:
            '1072116166304-g8u62jrsuf7sen0b50nm4msb97m6fmrv.apps.googleusercontent.com',
        scopes: ['email', 'profile'],
      );

      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        // User canceled the sign-in flow
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      await FirebaseAuth.instance.signInWithCredential(credential);

      // Save login state to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', true);

      if (mounted) {
        Navigator.pushReplacementNamed(context, '/');
      }
    } catch (e) {
      // Log the error for debugging but show a user-friendly message
      print('Google Sign-In Error: ${e.toString()}');

      setState(() {
        // User-friendly error message instead of the technical error
        _errorMessage =
            'Unable to sign in with Google. Please try again later.';
        _isLoading = false;
      });
    }
  }

  Future<void> _signInWithFacebook() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final LoginResult result = await FacebookAuth.instance.login();
      if (result.status == LoginStatus.success) {
        final AccessToken accessToken = result.accessToken!;
        final OAuthCredential credential = FacebookAuthProvider.credential(
          accessToken.toString(),
        );
        await FirebaseAuth.instance.signInWithCredential(credential);

        // Save login state to SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isLoggedIn', true);

        if (mounted) {
          Navigator.pushReplacementNamed(context, '/');
        }
      } else {
        setState(() {
          _errorMessage = 'Facebook login canceled or failed';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to sign in with Facebook: ${e.toString()}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _resetPassword() async {
    if (_emailController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your email address')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: _emailController.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password reset link sent to your email'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF00B77D),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
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
                  border: Border.all(color: Colors.white.withOpacity(0.10)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Welcome Back!',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.1,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 18),
                    Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ModernTextField(
                            controller: _emailController,
                            label: 'Email',
                            icon: Icons.email,
                            keyboardType: TextInputType.emailAddress,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your email';
                              }
                              if (!value.contains('@')) {
                                return 'Please enter a valid email';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          ModernTextField(
                            controller: _passwordController,
                            label: 'Password',
                            icon: Icons.lock,
                            obscureText: _obscurePassword,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                                color: Colors.white,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                          ),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: _resetPassword,
                              child: Text(
                                'Forgot Password?',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.85),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                          if (_errorMessage != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  _errorMessage!,
                                  style: const TextStyle(
                                    color: Colors.red,
                                    fontSize: 14,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ElevatedButton(
                            onPressed: _isLoading ? null : _login,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              backgroundColor: Colors.white,
                              foregroundColor: const Color(0xFF00B77D),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                              textStyle: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                              elevation: 2,
                            ),
                            child:
                                _isLoading
                                    ? const CircularProgressIndicator(
                                      color: Color(0xFF00B77D),
                                    )
                                    : const Text('Log In'),
                          ),
                          const SizedBox(height: 24),
                          // Divider
                          Row(
                            children: const [
                              Expanded(
                                child: Divider(
                                  color: Colors.white24,
                                  thickness: 1,
                                ),
                              ),
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 8.0),
                                child: Text(
                                  'or continue with',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Divider(
                                  color: Colors.white24,
                                  thickness: 1,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          // Social Sign-in Buttons
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _SocialIconButton(
                                icon: FontAwesomeIcons.google,
                                onPressed: _signInWithGoogle,
                              ),
                              const SizedBox(width: 24),
                              _SocialIconButton(
                                icon: FontAwesomeIcons.facebookF,
                                onPressed: _signInWithFacebook,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          "Don't have an account? ",
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (context) =>
                                        const PatientRegistrationScreen(),
                              ),
                            );
                          },
                          child: const Text(
                            'Sign Up',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SocialIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const _SocialIconButton({
    Key? key,
    required this.icon,
    required this.onPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Center(child: FaIcon(icon, color: Colors.white, size: 24)),
      ),
    );
  }
}
