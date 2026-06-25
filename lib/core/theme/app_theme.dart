import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTheme {
  AppTheme._();

  static ThemeData darkTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.accent,
        secondary: AppColors.success,
        error: AppColors.danger,
        surface: AppColors.panels,
        onPrimary: AppColors.background,
        onSecondary: AppColors.background,
        onSurface: AppColors.textPrimary,
      ),
      textTheme: _buildTextTheme(AppColors.textPrimary, AppColors.textSecond),
      iconTheme: const IconThemeData(color: AppColors.textSecond, size: 20),
      dividerColor: AppColors.accentDim,
      cardColor: AppColors.panels,
      cardTheme: CardThemeData(
        color: AppColors.panels,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: const BorderSide(color: AppColors.accentDim),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.background,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: AppColors.accentDim),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: AppColors.accentDim),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: AppColors.accent),
        ),
        hintStyle: const TextStyle(color: AppColors.textSecond, fontSize: 11),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: AppColors.background,
          textStyle: GoogleFonts.jetBrainsMono(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          elevation: 0,
        ),
      ),
      extensions: const [GcsThemeExtension.dark()],
    );
  }

  static ThemeData lightTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.backgroundDay,
      colorScheme: const ColorScheme.light(
        primary: AppColors.accent,
        secondary: AppColors.success,
        error: AppColors.danger,
        surface: AppColors.panelsDay,
        onPrimary: AppColors.background,
        onSecondary: AppColors.background,
        onSurface: AppColors.textDay,
      ),
      textTheme: _buildTextTheme(AppColors.textDay, AppColors.textSecDay),
      extensions: const [GcsThemeExtension.light()],
    );
  }

  static TextTheme _buildTextTheme(Color primary, Color secondary) {
    const ui = GoogleFonts.inter;
    const mono = GoogleFonts.jetBrainsMono;
    return TextTheme(
      displayLarge:
          ui(fontSize: 32, fontWeight: FontWeight.bold, color: primary),
      titleLarge: ui(fontSize: 16, fontWeight: FontWeight.w600, color: primary),
      titleMedium:
          ui(fontSize: 13, fontWeight: FontWeight.w500, color: primary),
      bodyLarge: ui(fontSize: 13, color: primary),
      bodyMedium: ui(fontSize: 11, color: secondary),
      bodySmall: mono(fontSize: 10, color: secondary, letterSpacing: 0.5),
      labelSmall: mono(fontSize: 9, color: secondary, letterSpacing: 1.0),
    );
  }
}

/// Custom theme extension to carry GCS-specific token references
@immutable
class GcsThemeExtension extends ThemeExtension<GcsThemeExtension> {
  const GcsThemeExtension({
    required this.bg,
    required this.panels,
    required this.accent,
    required this.success,
    required this.warning,
    required this.danger,
    required this.text,
    required this.secText,
  });

  const GcsThemeExtension.dark()
      : bg = AppColors.background,
        panels = AppColors.panels,
        accent = AppColors.accent,
        success = AppColors.success,
        warning = AppColors.warning,
        danger = AppColors.danger,
        text = AppColors.textPrimary,
        secText = AppColors.textSecond;

  const GcsThemeExtension.light()
      : bg = AppColors.backgroundDay,
        panels = AppColors.panelsDay,
        accent = AppColors.accent,
        success = AppColors.success,
        warning = AppColors.warning,
        danger = AppColors.danger,
        text = AppColors.textDay,
        secText = AppColors.textSecDay;

  final Color bg;
  final Color panels;
  final Color accent;
  final Color success;
  final Color warning;
  final Color danger;
  final Color text;
  final Color secText;

  @override
  GcsThemeExtension copyWith({
    Color? bg,
    Color? panels,
    Color? accent,
    Color? success,
    Color? warning,
    Color? danger,
    Color? text,
    Color? secText,
  }) {
    return GcsThemeExtension(
      bg: bg ?? this.bg,
      panels: panels ?? this.panels,
      accent: accent ?? this.accent,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
      text: text ?? this.text,
      secText: secText ?? this.secText,
    );
  }

  @override
  GcsThemeExtension lerp(GcsThemeExtension? other, double t) {
    if (other is! GcsThemeExtension) return this;
    return GcsThemeExtension(
      bg: Color.lerp(bg, other.bg, t)!,
      panels: Color.lerp(panels, other.panels, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      text: Color.lerp(text, other.text, t)!,
      secText: Color.lerp(secText, other.secText, t)!,
    );
  }
}

/// Helper extension on BuildContext
extension GcsThemeX on BuildContext {
  GcsThemeExtension get gcs => Theme.of(this).extension<GcsThemeExtension>()!;
}
