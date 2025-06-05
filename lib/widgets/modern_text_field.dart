import 'package:flutter/material.dart';

class ModernTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool obscureText;
  final Widget? suffixIcon;
  final TextInputType? keyboardType;
  final bool readOnly;
  final VoidCallback? onTap;
  final String? Function(String?)? validator;

  const ModernTextField({
    required this.controller,
    required this.label,
    required this.icon,
    this.obscureText = false,
    this.suffixIcon,
    this.keyboardType,
    this.readOnly = false,
    this.onTap,
    this.validator,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      readOnly: readOnly,
      onTap: onTap,
      validator: validator,
      style: const TextStyle(color: Colors.white, fontSize: 16),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(
          color: Colors.white70,
          fontWeight: FontWeight.w500,
        ),
        prefixIcon: Icon(icon, color: Colors.white),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: Colors.white.withOpacity(0.10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.white24),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.white24),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.white),
        ),
        contentPadding: const EdgeInsets.symmetric(
          vertical: 18,
          horizontal: 18,
        ),
      ),
    );
  }
}
