import 'package:flutter/material.dart';

/// GCS color tokens — Mission Planner black theme
class AppColors {
  AppColors._();

  // Core palette — true Mission Planner black
  static const Color background  = Color(0xFF0D0D0D); // near-black main bg
  static const Color panels      = Color(0xFF1A1A1A); // dark gray panels
  static const Color accent      = Color(0xFF00D4FF); // cyan accent
  static const Color success     = Color(0xFF00C853); // green
  static const Color warning     = Color(0xFFFFC107); // amber
  static const Color danger      = Color(0xFFFF5252); // red
  static const Color textPrimary = Color(0xFFFFFFFF); // white text
  static const Color textSecond  = Color(0xFF8A8A8A); // gray text

  // Derived / opacity variants
  static const Color accentDim    = Color(0x2600D4FF);   // 15% accent
  static const Color accentPanel  = Color(0x0D00D4FF);   // 5% accent
  static const Color successDim   = Color(0x3300C853);   // 20% success
  static const Color warningDim   = Color(0x33FFC107);   // 20% warning
  static const Color dangerDim    = Color(0x26FF5252);   // 15% danger
  static const Color dangerPanel  = Color(0x1AFF5252);   // 10% danger

  // Glassmorphic HUD Slate Tokens
  static const Color glassBg      = Color(0xD90F172A); // 85% opacity dark slate (#0F172A)
  static const Color glassPanel   = Color(0xCC1E293B); // 80% opacity lighter slate
  static const Color glassBorder  = Color(0x1AFFFFFF); // hairline white border (10% opacity)
  static const Color glassBorderCyan = Color(0x3300D4FF); // 20% cyan stroke

  // Tactical HUD Glow Colors
  static const Color tacticalGreen  = Color(0xFF00E676); // glowing tactical green
  static const Color tacticalCyan   = Color(0xFF00D4FF); // electric blue/cyan
  static const Color tacticalAmber  = Color(0xFFFFB300); // warning amber
  static const Color tacticalRed    = Color(0xFFFF1744); // danger red

  // Flight Dials Palette
  static const Color horizonSky     = Color(0xFF1E88E5); // artificial horizon sky blue
  static const Color horizonGround  = Color(0xFF8D6E63); // artificial horizon ground brown
  static const Color horizonReticle = Color(0xFFFFD600); // center target reticle yellow

  // Day mode aliased to dark (day mode is disabled — always dark)
  static const Color backgroundDay = Color(0xFF0D0D0D);
  static const Color panelsDay     = Color(0xFF1A1A1A);
  static const Color textDay       = Color(0xFFFFFFFF);
  static const Color textSecDay    = Color(0xFF8A8A8A);
}
