import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/arete_bottom_sheet.dart';
import '../data/backup_service.dart';

class PromptGeneratorSheet extends ConsumerStatefulWidget {
  const PromptGeneratorSheet({super.key});

  static Future<void> show(BuildContext context) {
    return AreteBottomSheet.show(
      context: context,
      title: 'AI Workspace Generator',
      child: const PromptGeneratorSheet(),
    );
  }

  @override
  ConsumerState<PromptGeneratorSheet> createState() => _PromptGeneratorSheetState();
}

class _PromptGeneratorSheetState extends ConsumerState<PromptGeneratorSheet> {
  final TextEditingController _jsonInputController = TextEditingController();
  bool _isPromptCopied = false;
  bool _showTemplatePreview = false;
  bool _isImporting = false;
  String? _errorMessage;

  static const String _defaultLlmPrompt = '''
You are an expert personal productivity architect. I want you to generate a customized configuration file for my focus and habit tracking app called "Areté".

Please ask me or use the following answers to construct my personalized workspace:
1. My top 3 long-term goals or domains (e.g. Master Backend Systems, Marathon Training, Daily Mindful Craft).
2. 3 to 5 core daily habits with ideal target times (e.g. Morning Deep Work 90m, Read 20 pages, Hydration 3L).
3. 4 to 6 active priority tasks for today with estimated completion and categories.
4. Learning collections or study roadmaps (e.g. Distributed Systems, LeetCode Patterns, Stoic Philosophy).

OUTPUT FORMAT REQUIREMENTS:
- Output ONLY valid JSON inside a single ```json ``` markdown code block.
- Follow this exact schema:

```json
{
  "app": "Areté",
  "version": 4,
  "tables": {
    "goals": [
      {
        "id": "goal_1",
        "title": "Master Backend Systems",
        "description": "High-throughput microservices and distributed databases",
        "color": "#D2E8D4",
        "target_date": "2026-12-31"
      }
    ],
    "tasks": [
      {
        "id": "task_1",
        "title": "Design idempotency keys for payment webhook",
        "description": "Ensure deduplication with Redis cache layer",
        "goal_id": "goal_1",
        "is_completed": 0,
        "is_daily_target": 1
      }
    ],
    "habits": [
      {
        "id": "habit_1",
        "title": "90m Deep Focus Block",
        "frequency_type": "daily",
        "color": "#D2E8D4"
      }
    ],
    "learning_collections": [
      {
        "id": "col_1",
        "title": "Distributed Systems Mastery",
        "description": "Consensus, Raft, Paxos, and Cache Invalidation",
        "color": "#D2E8D4",
        "icon": "dns_rounded"
      }
    ]
  }
}
```
Now ask me my goals, or generate a tailored setup based on my prompt!
''';

  @override
  void dispose() {
    _jsonInputController.dispose();
    super.dispose();
  }

  void _copyPrompt() async {
    await Clipboard.setData(const ClipboardData(text: _defaultLlmPrompt));
    setState(() => _isPromptCopied = true);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✨ AI prompt copied to clipboard! Paste it into ChatGPT or Gemini.'),
          duration: Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _isPromptCopied = false);
    });
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text != null && text.trim().isNotEmpty) {
      setState(() {
        _jsonInputController.text = text.trim();
        _errorMessage = null;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('📋 Pasted JSON from clipboard!'),
            duration: Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Clipboard is empty or contains no text.'),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _importJson(String jsonString) async {
    final text = jsonString.trim();
    if (text.isEmpty) {
      setState(() => _errorMessage = 'Please paste the generated JSON first.');
      return;
    }

    setState(() {
      _isImporting = true;
      _errorMessage = null;
    });

    final backupService = ref.read(backupServiceProvider);
    final result = await backupService.importBackupFromTextDetailed(ref, text, replaceExisting: false);

    if (!mounted) return;
    setState(() => _isImporting = false);

    if (result.success) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🎉 ${result.summary}'),
          backgroundColor: const Color(0xFF2A4E35),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      setState(() {
        _errorMessage = result.error ?? 'Invalid JSON structure. Ensure you copy the complete JSON output.';
      });
    }
  }

  void _loadDemoData() {
    final demoJson = BackupService.getStarterTemplateJson();
    _jsonInputController.text = demoJson;
    _importJson(demoJson);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header Badge & Intro
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E2822) : const Color(0xFFD2E8D4).withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark ? const Color(0xFF35523E) : const Color(0xFFB0D5B4),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF2E4D38) : const Color(0xFF2A4E35),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.auto_awesome_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Generate Your Custom Setup',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: isDark ? const Color(0xFFD2E8D4) : const Color(0xFF1B3623),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Feed our pre-formatted prompt to ChatGPT or Gemini to build a custom workspace tailored to your goals and study habits.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isDark ? Colors.white70 : const Color(0xFF2C4A34),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Step 1: Copy AI Prompt
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF2E4D38) : const Color(0xFF2A4E35),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Text(
                  '1',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Copy Prompt for ChatGPT / Gemini',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1B201D) : const Color(0xFFF4F1EA),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? Colors.white12 : const Color(0xFFE2DDD3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '“You are an expert personal productivity architect. Generate a customized configuration file for my focus app Areté...”',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontStyle: FontStyle.italic,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _copyPrompt,
                    icon: Icon(
                      _isPromptCopied ? Icons.check_circle_rounded : Icons.content_copy_rounded,
                      size: 18,
                    ),
                    label: Text(
                      _isPromptCopied ? 'Copied Prompt to Clipboard!' : 'Copy AI Prompt to Clipboard',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: _isPromptCopied
                          ? (isDark ? const Color(0xFF86D99B) : const Color(0xFF2A4E35))
                          : (isDark ? const Color(0xFF2E4D38) : const Color(0xFF2A4E35)),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 22),

          // Step 2: Paste Generated JSON
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF2E4D38) : const Color(0xFF2A4E35),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Text(
                  '2',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Paste Generated JSON or Load Demo',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: _pasteFromClipboard,
                icon: const Icon(Icons.paste_rounded, size: 16),
                label: const Text('Paste', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  foregroundColor: isDark ? const Color(0xFF86D99B) : const Color(0xFF2A4E35),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Input Text Box
          TextField(
            controller: _jsonInputController,
            maxLines: 5,
            onChanged: (val) => setState(() {}),
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            decoration: InputDecoration(
              hintText: 'Paste the generated JSON code block here...\n{\n  "app": "Areté",\n  "tables": { ... }\n}',
              hintStyle: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
              ),
              suffixIcon: _jsonInputController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18),
                      onPressed: () {
                        setState(() {
                          _jsonInputController.clear();
                          _errorMessage = null;
                        });
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: isDark ? Colors.white12 : const Color(0xFFE2DDD3),
                ),
              ),
              filled: true,
              fillColor: isDark ? const Color(0xFF181C19) : const Color(0xFFFAF8F5),
            ),
          ),

          if (_errorMessage != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 14),

          // Action Buttons: Import & One-Click Demo
          Row(
            children: [
              Expanded(
                flex: 3,
                child: FilledButton.icon(
                  onPressed: _isImporting
                      ? null
                      : () => _importJson(_jsonInputController.text),
                  icon: _isImporting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.download_done_rounded, size: 18),
                  label: const Text(
                    'Import & Apply',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: isDark ? const Color(0xFF86D99B) : const Color(0xFF2A4E35),
                    foregroundColor: isDark ? const Color(0xFF101C14) : Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: OutlinedButton.icon(
                  onPressed: _isImporting ? null : _loadDemoData,
                  icon: const Icon(Icons.auto_stories_outlined, size: 16),
                  label: const Text(
                    'Load Demo',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                  ),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Pick from Device option
          Center(
            child: TextButton.icon(
              icon: const Icon(Icons.folder_open_outlined, size: 16),
              label: const Text('Or select .json backup file from device', style: TextStyle(fontSize: 12.5)),
              onPressed: () async {
                final backupService = ref.read(backupServiceProvider);
                final success = await backupService.importBackupFromFile(ref);
                if (context.mounted) {
                  if (success) {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('🎉 Backup file imported successfully!'),
                        backgroundColor: Color(0xFF2A4E35),
                      ),
                    );
                  }
                }
              },
            ),
          ),

          const SizedBox(height: 14),

          // Collapsible Sample Template Preview
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              setState(() => _showTemplatePreview = !_showTemplatePreview);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
              child: Row(
                children: [
                  Icon(
                    _showTemplatePreview ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_right,
                    size: 20,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Preview Starter Template JSON',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (_showTemplatePreview) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF131714) : const Color(0xFFEFECE5),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark ? Colors.white10 : const Color(0xFFDDD8CE),
                ),
              ),
              constraints: const BoxConstraints(maxHeight: 220),
              child: SingleChildScrollView(
                child: SelectableText(
                  BackupService.getStarterTemplateJson(),
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    height: 1.35,
                  ),
                ),
              ),
            ),
          ],

          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
