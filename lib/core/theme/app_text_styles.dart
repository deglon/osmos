import 'package:flutter/material.dart';

class AppTextStyles {
  static const String _fontFamily = 'SF Pro Display'; // or 'Roboto' or 'Inter'

  // Headings
  static const heading1 = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    fontFamily: _fontFamily,
    color: AppColors.textPrimary,
  );

  static const heading2 = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.bold,
    fontFamily: _fontFamily,
    color: AppColors.textPrimary,
  );

  // Body Text
  static const bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.normal,
    fontFamily: _fontFamily,
    color: AppColors.textPrimary,
  );

  static const bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    fontFamily: _fontFamily,
    color: AppColors.textPrimary,
  );

  // Input & Labels
  static const inputLabel = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.medium,
    fontFamily: _fontFamily,
    color: AppColors.textSecondary,
  );

  static const inputText = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.normal,
    fontFamily: _fontFamily,
    color: AppColors.textPrimary,
  );

  // Buttons
  static const buttonText = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.bold,
    fontFamily: _fontFamily,
    letterSpacing: 0.5,
  );
}