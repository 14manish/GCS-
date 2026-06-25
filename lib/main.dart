import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/router/app_router.dart';
import 'core/store/gcs_notifier.dart';
import 'core/theme/app_theme.dart';

void main() {
  runApp(
    const ProviderScope(
      child: GcsApp(),
    ),
  );
}

class GcsApp extends ConsumerWidget {
  const GcsApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(gcsProvider.select((s) => s.themeMode));

    return MaterialApp.router(
      title: 'WINGSPAN GCS',
      debugShowCheckedModeBanner: false,
      routerConfig: appRouter,
      theme: AppTheme.lightTheme(),
      darkTheme: AppTheme.darkTheme(),
      themeMode: themeMode == 'dark' ? ThemeMode.dark : ThemeMode.light,
    );
  }
}
