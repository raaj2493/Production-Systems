import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/arete_card.dart';
import '../../../core/widgets/arete_text_field.dart';
import '../data/learning_hub_repository.dart';
import '../domain/dsa_problem_model.dart';
import '../domain/learning_roadmap_model.dart';

class RoadmapDetailScreen extends ConsumerStatefulWidget {
  final String roadmapId;

  const RoadmapDetailScreen({
    super.key,
    required this.roadmapId,
  });

  @override
  ConsumerState<RoadmapDetailScreen> createState() => _RoadmapDetailScreenState();
}

class _RoadmapDetailScreenState extends ConsumerState<RoadmapDetailScreen> {
  final Set<String> _expandedPhases = {};

  @override
  void initState() {
    super.initState();
    // Expand the first phase by default
    _expandedPhases.add('0');
  }

  void _togglePhase(String phaseIndexKey) {
    setState(() {
      if (_expandedPhases.contains(phaseIndexKey)) {
        _expandedPhases.remove(phaseIndexKey);
      } else {
        _expandedPhases.add(phaseIndexKey);
      }
    });
  }

  void _showTopicNotesDialog(BuildContext context, RoadmapTopic topic) {
    final controller = TextEditingController(text: topic.notes ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: EdgeInsets.only(
            top: 16,
            left: 20,
            right: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Topic Notes',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  topic.title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.sagePrimary,
                  ),
                ),
                const SizedBox(height: 16),
                AreteTextField(
                  controller: controller,
                  label: 'Notes & Key Learnings',
                  hint: 'Record intuition, why before how, or tricky edge cases...',
                  maxLines: 4,
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: () async {
                        final repo = ref.read(learningHubRepositoryProvider);
                        await repo.updateTopicNotes(topic.id, controller.text.trim());
                        ref.invalidate(learningRoadmapsProvider);
                        ref.invalidate(learningCategoriesProvider);
                        if (ctx.mounted) Navigator.of(ctx).pop();
                      },
                      child: const Text('Save Notes'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showDsaProblemSheet(BuildContext context, DsaProblem problem) {
    final intuitionCtrl = TextEditingController(text: problem.intuition ?? '');
    final approachCtrl = TextEditingController(text: problem.approach ?? '');
    final mistakesCtrl = TextEditingController(text: problem.mistakes ?? '');
    final timeCtrl = TextEditingController(text: problem.timeComplexity ?? '');
    final spaceCtrl = TextEditingController(text: problem.spaceComplexity ?? '');
    String currentStatus = problem.status;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (sheetCtx, setSheetState) {
            final theme = Theme.of(sheetCtx);

            return Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              padding: EdgeInsets.only(
                top: 16,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 24,
              ),
              child: SafeArea(
                top: false,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 36,
                          height: 4,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.outlineVariant,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  problem.title,
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: problem.difficultyColor.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        problem.difficulty,
                                        style: TextStyle(
                                          color: problem.difficultyColor,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Pattern: ${problem.pattern}',
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // Status Selector
                      Text(
                        'Problem Solving Status',
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          ('not_started', 'Not Started', const Color(0xFF8B948C)),
                          ('attempted', 'Attempted', const Color(0xFFFF7A59)),
                          ('solved', 'Solved', const Color(0xFF5A8E65)),
                          ('mastered', 'Mastered', const Color(0xFF2A4E35)),
                        ].map((item) {
                          final isSelected = currentStatus == item.$1;
                          return ChoiceChip(
                            label: Text(item.$2),
                            selected: isSelected,
                            selectedColor: item.$3.withValues(alpha: 0.2),
                            onSelected: (val) {
                              if (val) setSheetState(() => currentStatus = item.$1);
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 18),

                      // Intuition & Mental Model
                      AreteTextField(
                        controller: intuitionCtrl,
                        label: 'Intuition & First Principles',
                        hint: 'Why does this pattern apply? Brute force observation...',
                        maxLines: 2,
                      ),
                      const SizedBox(height: 14),

                      // Approach
                      AreteTextField(
                        controller: approachCtrl,
                        label: 'Optimal Approach & Pointer Logic',
                        hint: 'Opposite-direction or same-direction? Invariant proof...',
                        maxLines: 2,
                      ),
                      const SizedBox(height: 14),

                      // Mistakes & Lessons Learned
                      AreteTextField(
                        controller: mistakesCtrl,
                        label: 'Mistakes & Lessons Learned',
                        hint: 'Off-by-one errors, duplicate skipping, edge cases...',
                        maxLines: 2,
                      ),
                      const SizedBox(height: 14),

                      // Time & Space Complexity
                      Row(
                        children: [
                          Expanded(
                            child: AreteTextField(
                              controller: timeCtrl,
                              label: 'Time Complexity',
                              hint: 'e.g. O(N)',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: AreteTextField(
                              controller: spaceCtrl,
                              label: 'Space Complexity',
                              hint: 'e.g. O(1)',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Save Button
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () async {
                            final updated = problem.copyWith(
                              status: currentStatus,
                              intuition: intuitionCtrl.text.trim(),
                              approach: approachCtrl.text.trim(),
                              mistakes: mistakesCtrl.text.trim(),
                              timeComplexity: timeCtrl.text.trim(),
                              spaceComplexity: spaceCtrl.text.trim(),
                              updatedAt: DateTime.now(),
                            );
                            final repo = ref.read(learningHubRepositoryProvider);
                            await repo.updateDsaProblem(updated);
                            ref.invalidate(dsaProblemsProvider);
                            if (sheetCtx.mounted) Navigator.of(sheetCtx).pop();
                          },
                          child: const Text('Save Problem Progress'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final repo = ref.watch(learningHubRepositoryProvider);

    return FutureBuilder<LearningRoadmap?>(
      future: repo.getRoadmapById(widget.roadmapId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        final roadmap = snapshot.data;
        if (roadmap == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('Roadmap not found')),
          );
        }

        final isDsa = roadmap.id == 'roadmap-dsa';
        final dsaProblemsAsync = ref.watch(dsaProblemsProvider);

        return Scaffold(
          appBar: AppBar(
            title: Text(roadmap.title),
            elevation: 0,
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isDark
                        ? theme.colorScheme.surfaceContainer
                        : AppColors.sagePrimaryContainer.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: AppColors.sagePrimary.withValues(alpha: isDark ? 0.3 : 0.2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              roadmap.title,
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          if (roadmap.primaryLanguage != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.sagePrimary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                roadmap.primaryLanguage!,
                                style: const TextStyle(
                                  color: AppColors.sagePrimary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                        ],
                      ),
                      if (roadmap.description != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          roadmap.description!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                      const SizedBox(height: 18),

                      // Overall Progress
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Topics Mastered',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '${roadmap.completedTopics} of ${roadmap.totalTopics} (${(roadmap.progressRatio * 100).toInt()}%)',
                            style: const TextStyle(
                              color: AppColors.sagePrimary,
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(9999),
                        child: LinearProgressIndicator(
                          value: roadmap.progressRatio,
                          minHeight: 8,
                          backgroundColor: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                          valueColor: const AlwaysStoppedAnimation<Color>(AppColors.sagePrimary),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Learning Rules / Mentoring Philosophy
                if (roadmap.learningRules.isNotEmpty)
                  _buildLearningRulesCard(context, roadmap.learningRules),

                // DSA Special Problem Practice Section
                if (isDsa) ...[
                  const SizedBox(height: 24),
                  _buildDsaProblemPracticeSection(context, dsaProblemsAsync),
                ],

                const SizedBox(height: 24),

                // Phases Accordion
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Phases & Topics (${roadmap.phases.length} Phases)',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          if (_expandedPhases.length == roadmap.phases.length) {
                            _expandedPhases.clear();
                          } else {
                            _expandedPhases.addAll(
                              List.generate(roadmap.phases.length, (i) => '$i'),
                            );
                          }
                        });
                      },
                      child: Text(
                        _expandedPhases.length == roadmap.phases.length ? 'Collapse All' : 'Expand All',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                ...roadmap.phases.asMap().entries.map((entry) {
                  final index = entry.key;
                  final phase = entry.value;
                  return _buildPhaseAccordion(context, index, phase);
                }),

                const SizedBox(height: 48),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLearningRulesCard(BuildContext context, List<String> rules) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Theme(
      data: theme.copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        collapsedBackgroundColor: isDark
            ? theme.colorScheme.surfaceContainer
            : const Color(0xFFFDE8E1).withValues(alpha: 0.5),
        backgroundColor: isDark
            ? theme.colorScheme.surfaceContainer
            : const Color(0xFFFDE8E1).withValues(alpha: 0.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        leading: const Icon(Icons.psychology_outlined, color: Color(0xFFFF7A59)),
        title: Text(
          'Learning Principles & Mentoring Rules',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Text(
          '${rules.length} core rules for true first-principles mastery',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: rules.map((r) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('• ', style: TextStyle(fontWeight: FontWeight.bold)),
                      Expanded(
                        child: Text(
                          r,
                          style: theme.textTheme.bodySmall?.copyWith(height: 1.3),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDsaProblemPracticeSection(
    BuildContext context,
    AsyncValue<List<DsaProblem>> dsaProblemsAsync,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF261D19) : const Color(0xFFFFF6F3),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFFF7A59).withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF7A59).withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.code_rounded, color: Color(0xFFFF7A59), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Two Pointers Practice Set',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Current active pattern • Track intuition & complexity',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          dsaProblemsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Text('Error loading DSA problems: $err'),
            data: (problems) {
              if (problems.isEmpty) {
                return const Text('No DSA practice problems imported yet.');
              }

              final solvedCount = problems.where((p) => p.isSolved).length;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Solved: $solvedCount of ${problems.length}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFFFF7A59),
                        ),
                      ),
                      Text(
                        '${((solvedCount / problems.length) * 100).toInt()}%',
                        style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(9999),
                    child: LinearProgressIndicator(
                      value: problems.isNotEmpty ? solvedCount / problems.length : 0.0,
                      minHeight: 6,
                      backgroundColor: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFF7A59)),
                    ),
                  ),
                  const SizedBox(height: 14),

                  ...problems.map((prob) {
                    return AreteCard(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      borderRadius: 14,
                      onTap: () => _showDsaProblemSheet(context, prob),
                      child: Row(
                        children: [
                          Icon(
                            prob.isSolved
                                ? Icons.check_circle_rounded
                                : (prob.status == 'attempted'
                                    ? Icons.timelapse_rounded
                                    : Icons.radio_button_unchecked_rounded),
                            color: prob.statusColor,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  prob.title,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (prob.intuition != null && prob.intuition!.isNotEmpty)
                                  Text(
                                    prob.intuition!,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                      fontSize: 11,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: prob.statusColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              prob.statusDisplay,
                              style: TextStyle(
                                color: prob.statusColor,
                                fontWeight: FontWeight.w700,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(Icons.chevron_right_rounded, size: 18),
                        ],
                      ),
                    );
                  }),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPhaseAccordion(BuildContext context, int index, RoadmapPhase phase) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isExpanded = _expandedPhases.contains('$index');

    final total = phase.topics.length;
    final completed = phase.completedTopics;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? theme.colorScheme.surfaceContainer : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Phase Header Tap
          InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => _togglePhase('$index'),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: completed == total && total > 0
                          ? AppColors.sagePrimary
                          : AppColors.sagePrimaryContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: completed == total && total > 0
                        ? const Icon(Icons.check, color: Colors.white, size: 18)
                        : Text(
                            '${index + 1}',
                            style: const TextStyle(
                              color: AppColors.sagePrimary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          phase.title,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$completed of $total topics completed',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    isExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),

          // Topics List when Expanded
          if (isExpanded) ...[
            const Divider(height: 1),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: phase.topics.length,
              separatorBuilder: (_, __) => const Divider(height: 1, indent: 44),
              itemBuilder: (ctx, tIndex) {
                final topic = phase.topics[tIndex];
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  leading: GestureDetector(
                    onTap: () async {
                      final repo = ref.read(learningHubRepositoryProvider);
                      await repo.toggleTopicCompletion(topic.id, !topic.isCompleted);
                      ref.invalidate(learningRoadmapsProvider);
                      ref.invalidate(learningCategoriesProvider);
                      setState(() {});
                    },
                    child: Icon(
                      topic.isCompleted
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded,
                      color: topic.isCompleted
                          ? AppColors.sagePrimary
                          : theme.colorScheme.outline,
                      size: 22,
                    ),
                  ),
                  title: Text(
                    topic.title,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: topic.isCompleted ? FontWeight.w500 : FontWeight.w600,
                      decoration: topic.isCompleted ? TextDecoration.lineThrough : null,
                      color: topic.isCompleted
                          ? theme.colorScheme.onSurface.withValues(alpha: 0.5)
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                  trailing: IconButton(
                    icon: Icon(
                      topic.notes != null && topic.notes!.isNotEmpty
                          ? Icons.sticky_note_2_rounded
                          : Icons.note_add_outlined,
                      size: 20,
                      color: topic.notes != null && topic.notes!.isNotEmpty
                          ? AppColors.sagePrimary
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                    tooltip: 'Notes & Reflections',
                    onPressed: () => _showTopicNotesDialog(context, topic),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}
