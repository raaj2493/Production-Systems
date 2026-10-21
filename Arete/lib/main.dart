import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/database/database_service.dart';
import 'core/providers/app_settings_provider.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/learn/data/learning_hub_repository.dart';
import 'features/learn/data/learning_import_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Local Storage & Preferences
  final prefs = await SharedPreferences.getInstance();

  // Initialize SQLite Database & Starter Seed Data
  try {
    final dbService = DatabaseService.instance;
    await dbService.initDatabase();
    await dbService.seedStarterData();

    // Auto-seed organized learning data from asset if categories are empty
    final hubRepo = LearningHubRepository(dbService);
    final categories = await hubRepo.getAllCategories();
    if (categories.isEmpty) {
      final importService = LearningImportService(dbService);
      final jsonStr = await importService.loadDefaultAssetJsonString();
      if (jsonStr != null) {
        final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
        await importService.executeImport(decoded, preserveUserProgress: true);
      }
    }
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
