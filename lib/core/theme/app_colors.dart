import 'package:flutter/material.dart';

/// GCS color tokens — exactly matched from theme.ts
class AppColors {
  AppColors._();

  // Core palette
  static const Color background  = Color(0xFF0B1220);
  static const Color panels      = Color(0xFF141E30);
  static const Color accent      = Color(0xFF00D4FF);
  static const Color success     = Color(0xFF00C853);
  static const Color warning     = Color(0xFFFFC107);
  static const Color danger      = Color(0xFFFF5252);
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecond  = Color(0xFF94A3B8);

  // Derived / opacity variants
  static const Color accentDim    = Color(0x2600D4FF);   // 15% accent
  static const Color accentPanel  = Color(0x0D00D4FF);   // 5% accent
  static const Color successDim   = Color(0x3300C853);   // 20% success
  static const Color warningDim   = Color(0x33FFC107);   // 20% warning
  static const Color dangerDim    = Color(0x26FF5252);   // 15% danger
  static const Color dangerPanel  = Color(0x1AFF5252);   // 10% danger

  // Day (light) mode overrides
  static const Color backgroundDay = Color(0xFFE8EEF7);
  static const Color panelsDay     = Color(0xFFD0DBF0);
  static const Color textDay       = Color(0xFF0B1220);
  static const Color textSecDay    = Color(0xFF4A5568);
}
