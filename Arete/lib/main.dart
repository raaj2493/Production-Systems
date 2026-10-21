import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/database/database_service.dart';
import 'core/providers/app_settings_provider.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Local Storage & Preferences
  final prefs = await SharedPreferences.getInstance();

  // Initialize SQLite Database (starts 100% fresh and private for new users)
  try {
    final dbService = DatabaseService.instance;
    await dbService.initDatabase();
  } catch (e) {
    debugPrint('Database initialization warning: $e');
  }

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const AreteApp(),
    ),
  );
}

class AreteApp extends ConsumerWidget {
  const AreteApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);

    return MaterialApp.router(
      title: 'Areté',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.getTheme(palette: settings.colorPalette, isDark: false),
      darkTheme: AppTheme.getTheme(palette: settings.colorPalette, isDark: true),
      themeMode: settings.themeMode,
      routerConfig: appRouter,
    );
  }
}
