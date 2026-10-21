import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/app_settings_provider.dart';

class InteractiveTourSheet extends ConsumerStatefulWidget {
  const InteractiveTourSheet({super.key});

  static Future<void> show(BuildContext context, {bool force = false}) async {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      enableDrag: true,
      builder: (ctx) => const InteractiveTourSheet(),
    );
  }

  @override
  ConsumerState<InteractiveTourSheet> createState() => _InteractiveTourSheetState();
}

class _InteractiveTourSheetState extends ConsumerState<InteractiveTourSheet> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  static const int _totalSteps = 5;

  final List<_TourStepData> _steps = const [
    _TourStepData(
      badge: 'WELCOME TO ARETÉ',
      title: 'Excellence Through\nConsistency',
      tagline: 'High-energy focus & habit planning inspired by Greek virtue.',
      description:
          'Areté is your intentional daily command center. Designed to eliminate distractions, build ironclad habits, and transform your deep work into consistent daily momentum.',
      icon: Icons.bolt_rounded,
      accentColor: Color(0xFFFF7A59),
      containerColor: Color(0xFFFDE8E1),
      featureHighlights: [
        'Pure velocity brand aesthetic',
        'Zero AI-slop gradients or noise',
        'Material You expressive containers',
      ],
    ),
    _TourStepData(
      badge: 'TODAY DASHBOARD',
      title: 'Dynamic Hero Carousel\n& Live Actions',
      tagline: 'All your daily targets unified in a single clean canvas.',
      description:
          'Slide through your continuous thick circular focus ring, check off habit rituals with celebratory confetti fireworks, and manage your two-way synced priority tasks.',
      icon: Icons.view_carousel_rounded,
      accentColor: Color(0xFF2A4E35),
      containerColor: Color(0xFFD2E8D4),
      featureHighlights: [
        'Single continuous focus progress ring',
        'Particle confetti habit completions',
        'Two-way synced action item checklist',
      ],
    ),
    _TourStepData(
      badge: 'CONSISTENCY MATRIX',
      title: '28-Day Visual\nMomentum Heatmap',
      tagline: 'Track your streaks with GitHub-style visual clarity.',
      description:
          'Anchored right at the base of your Today dashboard, the consistency matrix charts every hour of deep work and every habit completed over the last 28 days.',
      icon: Icons.grid_view_rounded,
      accentColor: Color(0xFF4D7C5D),
      containerColor: Color(0xFFE2F1E4),
      featureHighlights: [
        'Micro-stats: streak and weekly hours',
        'Color density scales with focus time',
        'Reflective daily inquiry logging',
      ],
    ),
    _TourStepData(
      badge: 'ZEN FOCUS & OVERLAYS',
      title: 'Full-Screen Zen Mode\n& 2-Stage Overlay',
      tagline: 'Deep work without friction, in-app or in the background.',
      description:
          'Engage immersive full-screen Zen Mode with synthetic soundscapes (Rain 🌧️, Forest 🌲, Café ☕, White Noise 🎧). When you minimize Areté, a micro 40dp floating bubble with ⚡ keeps your time visible.',
      icon: Icons.headphones_rounded,
      accentColor: Color(0xFFE67E22),
      containerColor: Color(0xFFFFDDB3),
      featureHighlights: [
        'Pomodoro cycle logic with tonal phases',
        'Offline synthetic ambient soundscapes',
        'Micro 40dp bubble & drag-to-dismiss "✕"',
      ],
    ),
    _TourStepData(
      badge: 'AI SETUP & PRIVACY',
      title: '100% Offline-First\n& AI JSON Workspace',
      tagline: 'Your data stays with you. Setup in 60 seconds with AI.',
      description:
          'Areté works completely offline with local SQLite storage. Use the 1-click AI prompt generator to have ChatGPT or Gemini construct your tailored goals, or import a friend\'s configuration instantly.',
      icon: Icons.auto_awesome_rounded,
      accentColor: Color(0xFF6750A4),
      containerColor: Color(0xFFE8DEF8),
      featureHighlights: [
        'Zero cloud tracking or account requirements',
        '1-click ChatGPT/Gemini prompt setup',
        'Instant JSON workspace import/export',
      ],
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _finishTour() {
    ref.read(appSettingsProvider.notifier).setHasCompletedTour(true);
    Navigator.of(context).pop();
  }

  void _nextPage() {
    if (_currentPage < _totalSteps - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _finishTour();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final currentStep = _steps[_currentPage];

    final sheetBg = isDark ? const Color(0xFF181C19) : const Color(0xFFFAF9F4);

    return Container(
      decoration: BoxDecoration(
        color: sheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.15),
            blurRadius: 32,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top Drag Handle
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Header: Step Counter & Skip Button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: currentStep.containerColor.withValues(alpha: isDark ? 0.2 : 0.8),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'STEP ${_currentPage + 1} OF $_totalSteps',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                        color: currentStep.accentColor,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _finishTour,
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      foregroundColor: isDark ? Colors.white60 : Colors.black54,
                    ),
                    child: const Text('Skip Tour', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // PageView Content
              SizedBox(
                height: 380,
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: _steps.length,
                  onPageChanged: (idx) => setState(() => _currentPage = idx),
                  itemBuilder: (context, index) {
                    final step = _steps[index];
                    return _buildStepCard(context, step, isDark);
                  },
                ),
              ),

              const SizedBox(height: 16),

              // Bottom Navigation & Progress Dots
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Progress Dots
                  Row(
                    children: List.generate(_totalSteps, (index) {
                      final isActive = index == _currentPage;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.only(right: 6),
                        width: isActive ? 24 : 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: isActive
                              ? currentStep.accentColor
                              : (isDark ? Colors.white24 : Colors.black12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),

                  // Actions: Back (if > 0) + Next / Get Started
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_currentPage > 0) ...[
                        IconButton.filledTonal(
                          icon: const Icon(Icons.arrow_back_rounded, size: 20),
                          onPressed: () {
                            _pageController.previousPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOutCubic,
                            );
                          },
                        ),
                        const SizedBox(width: 8),
                      ],
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: currentStep.accentColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        icon: Icon(
                          _currentPage == _totalSteps - 1
                              ? Icons.check_circle_rounded
                              : Icons.arrow_forward_rounded,
                          size: 18,
                        ),
                        label: Text(
                          _currentPage == _totalSteps - 1 ? 'Get Started ⚡' : 'Next',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                        ),
                        onPressed: _nextPage,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepCard(BuildContext context, _TourStepData step, bool isDark) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero Icon Container with Brand Badge
            Row(
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: step.containerColor.withValues(alpha: isDark ? 0.25 : 0.9),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: step.accentColor.withValues(alpha: 0.3),
                      width: 1.5,
                    ),
                  ),
                  child: Center(
                    child: Icon(step.icon, size: 30, color: step.accentColor),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        step.badge,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                          color: step.accentColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        step.tagline,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Step Headline
            Text(
              step.title,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                height: 1.2,
                letterSpacing: -0.5,
                color: isDark ? const Color(0xFFF1F8F3) : const Color(0xFF1B3623),
              ),
            ),
            const SizedBox(height: 10),

            // Description Body
            Text(
              step.description,
              style: TextStyle(
                fontSize: 13.5,
                height: 1.45,
                color: isDark ? Colors.white70 : const Color(0xFF4A554E),
              ),
            ),
            const SizedBox(height: 16),

            // Feature Bullet Highlights
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.04)
                    : Colors.black.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.06),
                ),
              ),
              child: Column(
                children: step.featureHighlights.map((feat) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle_rounded, size: 16, color: step.accentColor),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            feat,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.88)
                                  : Colors.black.withValues(alpha: 0.88),
                            ),
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
      ),
    );
  }
}

class _TourStepData {
  final String badge;
  final String title;
  final String tagline;
  final String description;
  final IconData icon;
  final Color accentColor;
  final Color containerColor;
  final List<String> featureHighlights;

  const _TourStepData({
    required this.badge,
    required this.title,
    required this.tagline,
    required this.description,
    required this.icon,
    required this.accentColor,
    required this.containerColor,
    required this.featureHighlights,
  });
}
