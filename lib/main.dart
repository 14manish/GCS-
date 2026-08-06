import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

class GcsHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (X509Certificate cert, String host, int port) => true;
  }
}

void main() {
  HttpOverrides.global = GcsHttpOverrides();
  _printBanner();
  runApp(
    const ProviderScope(
      child: GcsApp(),
    ),
  );
}

void _printBanner() {
  final now = DateTime.now().toUtc();
  final ts =
      '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} '
      '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')} UTC';

  // ignore: avoid_print
  print('''
==========================================================================
  __      __ I N G S P A N N   G C S
  W
==========================================================================
  WINGSPANN Ground Control Station  —  Flutter Edition
  Build Platform : Windows x64
  Dart Runtime   : Dart VM
  Start Time     : $ts
==========================================================================
[BOOT] Initializing providers...
[BOOT] Loading theme (dark)...
[BOOT] Setting up router...
[BOOT] Starting MAVLink subsystem...
[BOOT] Ready.
==========================================================================
''');
}

class GcsApp extends ConsumerWidget {
  const GcsApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Always dark — Mission Planner style, no day/night toggle.
    return MaterialApp.router(
      title: 'WINGSPANN GCS',
      debugShowCheckedModeBanner: false,
      routerConfig: appRouter,
      theme: AppTheme.darkTheme(),
      darkTheme: AppTheme.darkTheme(),
      themeMode: ThemeMode.dark,
    );
  }
}
