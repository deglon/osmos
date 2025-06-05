import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:country_picker/country_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:flutter/gestures.dart';
import '../legal/terms_of_use_screen.dart';
import '../legal/privacy_policy_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:osmos/widgets/modern_text_field.dart';

class PatientRegistrationScreen extends StatefulWidget {
  const PatientRegistrationScreen({super.key});

  @override
  State<PatientRegistrationScreen> createState() =>
      _PatientRegistrationScreenState();
}

class _PatientRegistrationScreenState extends State<PatientRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _dobController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  String _selectedCountryCode = '+41'; // Default to Switzerland
  String _selectedCountryFlag = '🇨🇭';
  DateTime? _selectedDate;
  bool _termsAccepted = false;
  String? _errorMessage;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _passwordController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _dobController.dispose();
    super.dispose();
  }

  void _showCountryPicker() {
    showCountryPicker(
      context: context,
      showPhoneCode: true,
      countryListTheme: CountryListThemeData(
        backgroundColor: const Color(0xFF00B77D),
        textStyle: const TextStyle(color: Colors.white),
        searchTextStyle: const TextStyle(color: Colors.white),
        bottomSheetHeight: 500,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20.0),
          topRight: Radius.circular(20.0),
        ),
        inputDecoration: InputDecoration(
          labelStyle: const TextStyle(color: Colors.white),
          prefixIcon: const Icon(Icons.search, color: Colors.white),
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
          filled: true,
          fillColor: Colors.white.withOpacity(0.1),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Colors.white70),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Colors.white70),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Colors.white),
          ),
        ),
      ),
      onSelect: (country) {
        setState(() {
          _selectedCountryCode = '+${country.phoneCode}';
          _selectedCountryFlag = country.flagEmoji;
        });
      },
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate:
          _selectedDate ??
          DateTime.now().subtract(const Duration(days: 365 * 18)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF00B77D),
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _dobController.text = "${picked.day}/${picked.month}/${picked.year}";
      });
    }
  }

  Future<void> _registerWithEmailAndPassword() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      UserCredential userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );

      // Send email verification
      await userCredential.user?.sendEmailVerification();

      // Save additional user data to Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userCredential.user!.uid)
          .set({
            'firstName': _firstNameController.text.trim(),
            'lastName': _lastNameController.text.trim(),
            'email': _emailController.text.trim(),
            'phone': _phoneController.text.trim(),
            'dateOfBirth': _dobController.text.trim(),
            'countryCode': _selectedCountryCode,
            'countryFlag': _selectedCountryFlag,
            'createdAt': Timestamp.now(),
            'isComplete': false, // Set onboarding as incomplete for new users
          });

      // Do NOT set login state yet; wait until after email verification
      // final prefs = await SharedPreferences.getInstance();
      // await prefs.setBool('isLoggedIn', true);

      if (context.mounted) {
        // Navigate to the EmailVerificationScreen
        Navigator.pushReplacementNamed(
          context,
          '/emailVerification', // Make sure this route is registered in your app
        );
      }
    } on FirebaseAuthException catch (e) {
      String message;
      if (e.code == 'weak-password') {
        message = 'The password provided is too weak.';
      } else if (e.code == 'email-already-in-use') {
        message = 'An account already exists for that email.';
      } else {
        message = 'Registration failed. Please try again.';
      }
      setState(() {
        _errorMessage = message;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'An unexpected error occurred: ${e.toString()}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleGoogleSignIn() async {
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return;

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await FirebaseAuth.instance
          .signInWithCredential(credential);

      if (userCredential.user != null && mounted) {
        // Check if user document exists, if not, create it with isComplete: false
        final userDoc = FirebaseFirestore.instance
            .collection('users')
            .doc(userCredential.user!.uid);
        final docSnapshot = await userDoc.get();

        if (!docSnapshot.exists) {
          await userDoc.set(
            {
              'email': userCredential.user!.email, // Save email from Google
              'firstName':
                  googleUser.displayName?.split(' ').first ??
                  '', // Attempt to get first name
              'lastName':
                  googleUser.displayName?.split(' ').last ??
                  '', // Attempt to get last name
              'createdAt': Timestamp.now(),
              'isComplete': false, // Set onboarding as incomplete
            },
            SetOptions(merge: true),
          ); // Use merge to avoid overwriting if doc exists partially
        }

        // TODO: Consider onboarding for social sign-in users as well
        // Navigate to the AuthenticationWrapper which will handle redirection
        Navigator.pushReplacementNamed(context, '/');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to sign in with Google: $e')),
        );
      }
    }
  }

  Future<void> _handleFacebookSignIn() async {
    try {
      final LoginResult result = await FacebookAuth.instance.login();
      if (result.status != LoginStatus.success) return;

      final OAuthCredential credential = FacebookAuthProvider.credential(
        result.accessToken!.tokenString,
      );

      final UserCredential userCredential = await FirebaseAuth.instance
          .signInWithCredential(credential);

      if (userCredential.user != null && mounted) {
        // Check if user document exists, if not, create it with isComplete: false
        final userDoc = FirebaseFirestore.instance
            .collection('users')
            .doc(userCredential.user!.uid);
        final docSnapshot = await userDoc.get();

        if (!docSnapshot.exists) {
          await userDoc.set(
            {
              'email': userCredential.user!.email, // Save email from Facebook
              'firstName':
                  userCredential.user!.displayName?.split(' ').first ??
                  '', // Attempt to get first name
              'lastName':
                  userCredential.user!.displayName?.split(' ').last ??
                  '', // Attempt to get last name
              'createdAt': Timestamp.now(),
              'isComplete': false, // Set onboarding as incomplete
            },
            SetOptions(merge: true),
          ); // Use merge to avoid overwriting if doc exists partially
        }

        // Navigate to the AuthenticationWrapper which will handle redirection
        Navigator.pushReplacementNamed(context, '/');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to sign in with Facebook: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF00B77D),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Create Account',
          style: TextStyle(color: Colors.white),
        ),
      ),
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
                      'Sign Up',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.1,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 18),
                    _buildRegistrationForm(),
                  ],
                ),
              ),
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRegistrationForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // First Name field
          ModernTextField(
            controller: _firstNameController,
            label: 'First Name',
            icon: Icons.person,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your first name';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          // Last Name field
          ModernTextField(
            controller: _lastNameController,
            label: 'Last Name',
            icon: Icons.person,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your last name';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          // Email field
          ModernTextField(
            controller: _emailController,
            label: 'Email',
            icon: Icons.email,
            keyboardType: TextInputType.emailAddress,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your email';
              }
              final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,}$');
              if (!emailRegex.hasMatch(value)) {
                return 'Please enter a valid email address';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          // Password field
          ModernTextField(
            controller: _passwordController,
            label: 'Password',
            icon: Icons.lock,
            obscureText: _obscurePassword,
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword ? Icons.visibility : Icons.visibility_off,
                color: Colors.white,
              ),
              onPressed: () {
                setState(() {
                  _obscurePassword = !_obscurePassword;
                });
              },
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter a password';
              }
              if (value.length < 8) {
                return 'Password must be at least 8 characters';
              }
              if (!RegExp(
                r'^(?=.*?[A-Z])(?=.*?[a-z])(?=.*?[0-9])',
              ).hasMatch(value)) {
                return 'Password must contain uppercase, lowercase, and number';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          // Phone field with country code
          Row(
            children: [
              InkWell(
                onTap: _showCountryPicker,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white70),
                  ),
                  child: Row(
                    children: [
                      Text(
                        _selectedCountryFlag,
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _selectedCountryCode,
                        style: const TextStyle(color: Colors.white),
                      ),
                      const Icon(Icons.arrow_drop_down, color: Colors.white),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ModernTextField(
                  controller: _phoneController,
                  label: 'Phone Number',
                  icon: Icons.phone,
                  keyboardType: TextInputType.phone,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your phone number';
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Date of Birth field with date picker
          ModernTextField(
            controller: _dobController,
            label: 'Date of Birth',
            icon: Icons.calendar_today,
            readOnly: true,
            onTap: () => _selectDate(context),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please select your date of birth';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          // Terms and Conditions checkbox
          Row(
            children: [
              Checkbox(
                value: _termsAccepted,
                onChanged: (value) {
                  setState(() {
                    _termsAccepted = value ?? false;
                  });
                },
                fillColor: MaterialStateProperty.resolveWith<Color>((
                  Set<MaterialState> states,
                ) {
                  if (states.contains(MaterialState.selected)) {
                    return Colors.white;
                  }
                  return Colors.white.withOpacity(0.5);
                }),
                checkColor: const Color(0xFF00B77D),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _termsAccepted = !_termsAccepted;
                    });
                  },
                  child: RichText(
                    text: TextSpan(
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 14,
                      ),
                      children: [
                        const TextSpan(text: 'I agree to the '),
                        TextSpan(
                          text: 'Terms of Use',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            decoration: TextDecoration.underline,
                          ),
                          recognizer:
                              TapGestureRecognizer()
                                ..onTap = () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder:
                                          (context) => const TermsOfUseScreen(),
                                    ),
                                  );
                                },
                        ),
                        const TextSpan(text: ' and '),
                        TextSpan(
                          text: 'Privacy Policy',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            decoration: TextDecoration.underline,
                          ),
                          recognizer:
                              TapGestureRecognizer()
                                ..onTap = () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder:
                                          (context) =>
                                              const PrivacyPolicyScreen(),
                                    ),
                                  );
                                },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Sign Up Button
          ElevatedButton(
            onPressed:
                _isLoading || !_termsAccepted
                    ? null
                    : _registerWithEmailAndPassword,
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
                    ? const CircularProgressIndicator(color: Color(0xFF00B77D))
                    : const Text('Sign Up'),
          ),
          const SizedBox(height: 24),
          // Divider
          Row(
            children: const [
              Expanded(child: Divider(color: Colors.white24, thickness: 1)),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 8.0),
                child: Text(
                  'or continue with',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ),
              Expanded(child: Divider(color: Colors.white24, thickness: 1)),
            ],
          ),
          const SizedBox(height: 16),
          // Social Sign-in Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _SocialIconButton(
                icon: FontAwesomeIcons.google,
                onPressed: _handleGoogleSignIn,
              ),
              const SizedBox(width: 24),
              _SocialIconButton(
                icon: FontAwesomeIcons.facebookF,
                onPressed: _handleFacebookSignIn,
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Already have an account?
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Already have an account?',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pushReplacementNamed(context, '/login');
                },
                child: const Text(
                  'Sign In',
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
    );
  }
}

// Move the _SocialIconButton class definition outside the State class
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
