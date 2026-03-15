// lib/presentation/result/result_screen.dart
// Résultat du scan : diagnostic + confiance + conseil + TTS

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/agri_widgets.dart';
import '../../core/router/route_names.dart';

class ResultScreen extends StatefulWidget {
  const ResultScreen({super.key, required this.data});
  final Map<String, dynamic> data;

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeIn;
  late Animation<Offset> _slideIn;
  bool _isSpeaking = false;

  SeverityLevel get _severity {
    switch (widget.data['severity']) {
      case 'healthy': return SeverityLevel.healthy;
      case 'warning': return SeverityLevel.warning;
      case 'danger':  return SeverityLevel.danger;
      default:        return SeverityLevel.unknown;
    }
  }

  double get _confidence =>
      (widget.data['confidence'] as num?)?.toDouble() ?? 0.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    )..forward();

    _fadeIn = CurveTween(curve: Curves.easeOut).animate(_controller);
    _slideIn = Tween(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _speak() async {
    setState(() => _isSpeaking = !_isSpeaking);
    // flutter_tts sera configuré en Sprint 3
  }

  @override
  Widget build(BuildContext context) {
    final disease = widget.data['disease'] as String? ?? 'Inconnu';
    final plant   = widget.data['plant']   as String? ?? '';
    final advice  = widget.data['advice']  as String? ?? '';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeIn,
          child: SlideTransition(
            position: _slideIn,
            child: CustomScrollView(
              slivers: [
                // ── Header ──────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () => context.goNamed(RouteNames.scannerName),
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.border),
                            ),
                            child: const Icon(
                              Icons.arrow_back_rounded,
                              color: AppColors.textPrimary,
                              size: 22,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          'Résultat',
                          style: AppTextStyles.titleLarge,
                        ),
                        const Spacer(),
                        // Bouton TTS — lire le résultat à voix haute
                        GestureDetector(
                          onTap: _speak,
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: _isSpeaking
                                  ? AppColors.primaryLight
                                  : Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: _isSpeaking
                                    ? AppColors.primary
                                    : AppColors.border,
                              ),
                            ),
                            child: Icon(
                              _isSpeaking
                                  ? Icons.volume_up_rounded
                                  : Icons.volume_up_outlined,
                              color: _isSpeaking
                                  ? AppColors.primary
                                  : AppColors.textSecondary,
                              size: 22,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Carte principale maladie ─────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                    child: _DiseaseCard(
                      disease: disease,
                      plant: plant,
                      severity: _severity,
                    ),
                  ),
                ),

                // ── Confiance du modèle ──────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        children: [
                          Text('Niveau de confiance',
                              style: AppTextStyles.titleMedium),
                          const SizedBox(height: 16),
                          ConfidenceBadge(confidence: _confidence),
                        ],
                      ),
                    ),
                  ),
                ),

                // ── Conseils ─────────────────────────────────────
                if (advice.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                      child: _AdviceCard(advice: advice, severity: _severity),
                    ),
                  ),

                // ── Actions ──────────────────────────────────────
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      AgriButton(
                        label: 'Nouveau scan',
                        icon: Icons.camera_alt_rounded,
                        onPressed: () =>
                            context.goNamed(RouteNames.scannerName),
                      ),
                      const SizedBox(height: 12),
                      AgriButton(
                        label: 'Enregistrer sur parcelle',
                        icon: Icons.save_rounded,
                        variant: AgriButtonVariant.outline,
                        onPressed: () {},
                      ),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Carte maladie avec indicateur visuel ──────────────────────────
class _DiseaseCard extends StatelessWidget {
  const _DiseaseCard({
    required this.disease,
    required this.plant,
    required this.severity,
  });

  final String disease;
  final String plant;
  final SeverityLevel severity;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: severity.backgroundColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: severity.color.withOpacity(0.3),
          width: 2,
        ),
      ),
      child: Row(
        children: [
          SeverityIndicator(level: severity, size: 64),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  disease,
                  style: AppTextStyles.displayMedium.copyWith(
                    color: severity.color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(plant, style: AppTextStyles.bodyLarge),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: severity.color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    severity.label.toUpperCase(),
                    style: AppTextStyles.labelSmall.copyWith(
                      color: severity.color,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Carte conseil ────────────────────────────────────────────────
class _AdviceCard extends StatelessWidget {
  const _AdviceCard({required this.advice, required this.severity});
  final String advice;
  final SeverityLevel severity;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.lightbulb_rounded,
                color: AppColors.warning,
                size: 22,
              ),
              const SizedBox(width: 8),
              Text('Conseils de traitement',
                  style: AppTextStyles.titleMedium),
            ],
          ),
          const SizedBox(height: 14),
          // Chaque conseil sur sa ligne
          ...advice.split('.').where((s) => s.trim().isNotEmpty).map(
            (tip) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 6),
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      tip.trim(),
                      style: AppTextStyles.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}