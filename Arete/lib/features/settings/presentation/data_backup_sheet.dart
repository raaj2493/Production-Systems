import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/arete_bottom_sheet.dart';
import '../../../core/widgets/arete_card.dart';
import '../data/backup_service.dart';
import 'prompt_generator_sheet.dart';

class DataBackupSheet extends ConsumerWidget {
  const DataBackupSheet({super.key});

  static Future<void> show(BuildContext context) {
    return AreteBottomSheet.show(
      context: context,
      title: 'Data Management & Sync',
      child: const DataBackupSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final backupService = ref.watch(backupServiceProvider);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Intro banner
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E2822) : const Color(0xFFD2E8D4).withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isDark ? const Color(0xFF35523E) : const Color(0xFFB0D5B4),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF2E4D38) : const Color(0xFF2A4E35),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.shield_outlined, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '100% Offline & Private. Your data is stored locally in SQLite and can be exported or synced anywhere.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isDark ? Colors.white70 : const Color(0xFF2C4A34),
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // AI Prompt Generator for Friends
        AreteCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          onTap: () {
            Navigator.of(context).pop();
            PromptGeneratorSheet.show(context);
          },
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFDDB3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.auto_awesome_rounded, color: Color(0xFF5A2D00), size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'AI Workspace Generator',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF7A59).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'PROMPT',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFFFF7A59),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Generate custom JSON with ChatGPT/Gemini for friends',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: theme.colorScheme.onSurface.withValues(alpha: 0.4), size: 20),
            ],
          ),
        ),

        const SizedBox(height: 10),

        // Export JSON Backup
        AreteCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          onTap: () async {
            try {
              final path = await backupService.exportBackup();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Backup exported: $path')),
                );
              }
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Export failed: $e')),
                );
              }
            }
          },
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.file_upload_outlined, color: theme.colorScheme.primary, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Export JSON Backup',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Download or share full SQLite database backup',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: theme.colorScheme.onSurface.withValues(alpha: 0.4), size: 20),
            ],
          ),
        ),

        const SizedBox(height: 10),

        // Import JSON File
        AreteCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          onTap: () {
            Navigator.of(context).pop();
            PromptGeneratorSheet.show(context);
          },
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8DEF8),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.file_download_outlined, color: Color(0xFF382A4C), size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Import JSON Backup & AI Setup',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Paste generated JSON, load starter demo, or pick file',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: theme.colorScheme.onSurface.withValues(alpha: 0.4), size: 20),
            ],
          ),
        ),

        const SizedBox(height: 10),

        // Load Starter Template
        AreteCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          onTap: () async {
            await backupService.seedStarterData(ref);
            if (context.mounted) {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('✨ Demo starter workspace loaded!'),
                  backgroundColor: Color(0xFF2A4E35),
                ),
              );
            }
          },
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFD2E8D4),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.auto_stories_outlined, color: Color(0xFF1B3623), size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Load Starter Demo Workspace',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Seed system design goals, habits, and tasks',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: theme.colorScheme.onSurface.withValues(alpha: 0.4), size: 20),
            ],
          ),
        ),

        const SizedBox(height: 20),
      ],
    );
  }
}
