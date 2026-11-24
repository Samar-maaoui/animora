import 'package:flutter/material.dart';

/// Warm orange theme (welcome screen mock-up): orange accents on a cream base.
abstract final class AppColors {
  static const primary = Color(0xFFF7941D),
      primaryDark = Color(0xFFE07B00),
      primaryLight = Color(0xFFFFE9D2);
  static const adoption = Color(0xFF22C55E), greenLight = Color(0xFFE8F7EC);
  // Reports move to blue so they stay distinct from the orange brand colour.
  static const reports = Color(0xFF3B82F6), reportsLight = Color(0xFFDCEBFF);
  static const veterinary = Color(0xFF06B6D4),
      turquoiseLight = Color(0xFFE0F7FB);
  static const donations = Color(0xFF8B5CF6), purpleLight = Color(0xFFF3E8FF);
  static const events = Color(0xFFFF6B6B), pinkLight = Color(0xFFFFE8EB);
  static const ink = Color(0xFF1F1A17),
      muted = Color(0xFF7A6E66),
      background = Color(0xFFFFF7EE),
      border = Color(0xFFF1E4D6),
      shadow = Color(0x0F7A4A1A),
      surface = Colors.white,
      fieldFill = Color(0xFFFFF1E2);
}
