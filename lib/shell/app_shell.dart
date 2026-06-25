import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/store/gcs_notifier.dart';
import '../core/theme/app_colors.dart';
import 'status_bar.dart';
import 'sidebar.dart';
import 'bottom_alert_strip.dart';

class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(gcsProvider.select((s) => s.themeMode));

    return Scaffold(
      backgroundColor: themeMode == 'dark'
          ? AppColors.background
          : AppColors.backgroundDay,
      body: Column(
        children: [
          // ── Top Status Bar (40px) ──
          const GcsStatusBar(),

          // ── Middle: Sidebar + Page Content ──
          Expanded(
            child: Row(
              children: [
                // Left 80px icon sidebar
                GcsSidebar(navigationShell: navigationShell),

                // Main page content
                Expanded(
                  child: navigationShell,
                ),
              ],
            ),
          ),

          // ── Bottom Alert Console ──
          const BottomAlertStrip(),
        ],
      ),
    );
  }
}
