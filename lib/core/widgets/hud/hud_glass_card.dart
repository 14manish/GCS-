import 'dart:ui';
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

class HudGlassCard extends StatelessWidget {
  const HudGlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(10),
    this.borderColor,
    this.backgroundColor,
    this.borderRadius = 8.0,
    this.blur = 12.0,
    this.width,
    this.height,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? borderColor;
  final Color? backgroundColor;
  final double borderRadius;
  final double blur;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final effectiveBorder = borderColor ?? AppColors.glassBorder;
    final effectiveBg = backgroundColor ?? AppColors.glassBg;

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          width: width,
          height: height,
          padding: padding,
          decoration: BoxDecoration(
            color: effectiveBg,
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: effectiveBorder, width: 1.0),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}
