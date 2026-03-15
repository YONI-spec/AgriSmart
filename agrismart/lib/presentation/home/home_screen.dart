// lib/presentation/home/home_screen.dart
// Écran d'accueil — CTA Scanner géant + historique récent

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/agri_widgets.dart';
import '../../core/router/route_names.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // ── App Bar custom ──────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Row(
                  children: [
                    // Salutation
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Bonjour 👋',
                            style: AppTextStyles.bodyMedium,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Kofi Mensah',
                            style: AppTextStyles.titleLarge,
                          ),
                        ],
                      ),
                    ),
                    // Boutons header
                    IconButton(
                      onPressed: () =>
                          context.goNamed(RouteNames.settingsName),
                      icon: const Icon(Icons.tune_rounded),
                      iconSize: 28,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: () => context.goNamed(RouteNames.profilName),
                      child: CircleAvatar(
                        radius: 22,
                        backgroundColor: AppColors.primaryLight,
                        child: Text(
                          'KM',
                          style: AppTextStyles.labelLarge.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Alerte active (si épidémie détectée) ────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: _AlertBanner(),
              ),
            ),

            // ── CTA SCANNER principal ───────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                child: _ScannerCTA(
                  onTap: () => context.goNamed(RouteNames.scannerName),
                ),
              ),
            ),

            // ── Stats rapides ───────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                child: _QuickStats(),
              ),
            ),

            // ── Historique récent ───────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
                child: SectionHeader(
                  title: 'Scans récents',
                  actionLabel: 'Tout voir',
                  onAction: () {},
                ),
              ),
            ),

            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  DiagnosticCard(
                    diseaseName: 'Mildiou',
                    plantName: 'Tomate · Parcelle A',
                    confidence: 0.92,
                    severity: SeverityLevel.danger,
                    dateLabel: 'Aujourd\'hui, 09h14',
                    onTap: () {},
                  ),
                  const SizedBox(height: 10),
                  DiagnosticCard(
                    diseaseName: 'Plante saine',
                    plantName: 'Maïs · Parcelle B',
                    confidence: 0.87,
                    severity: SeverityLevel.healthy,
                    dateLabel: 'Hier, 16h30',
                    onTap: () {},
                  ),
                  const SizedBox(height: 10),
                  DiagnosticCard(
                    diseaseName: 'Oïdium précoce',
                    plantName: 'Piment · Parcelle C',
                    confidence: 0.68,
                    severity: SeverityLevel.warning,
                    dateLabel: '12 mars, 11h00',
                    onTap: () {},
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Bannière d'alerte épidémique ──────────────────────────────────
class _AlertBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.dangerBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.danger.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.danger.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.warning_amber_rounded,
              color: AppColors.danger,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Alerte zone — Mildiou',
                  style: AppTextStyles.bodySemiBold.copyWith(
                    color: AppColors.danger,
                  ),
                ),
                Text(
                  'Signalé à 3,2 km de vous',
                  style: AppTextStyles.bodyMedium,
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            color: AppColors.danger,
          ),
        ],
      ),
    );
  }
}

// ── CTA Scanner — bouton géant central ───────────────────────────
class _ScannerCTA extends StatelessWidget {
  const _ScannerCTA({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 180,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1D9E75), Color(0xFF0F6E52)],
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.40),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Cercle décoratif
            Positioned(
              right: -20,
              top: -20,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.06),
                ),
              ),
            ),
            Positioned(
              right: 20,
              bottom: -30,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.04),
                ),
              ),
            ),
            // Contenu
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.20),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.qr_code_scanner_rounded,
                      color: Colors.white,
                      size: 36,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'SCANNER',
                    style: TextStyle(
                      fontFamily: 'AgriDisplay',
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Photographiez votre plante',
                    style: TextStyle(
                      fontFamily: 'AgriBody',
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Statistiques rapides ──────────────────────────────────────────
class _QuickStats extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            value: '24',
            label: 'Scans\nce mois',
            icon: Icons.camera_alt_rounded,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            value: '3',
            label: 'Maladies\ndétectées',
            icon: Icons.bug_report_rounded,
            color: AppColors.warning,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            value: '4',
            label: 'Parcelles\nsuivies',
            icon: Icons.grid_view_rounded,
            color: AppColors.info,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
  });

  final String value;
  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 8),
          Text(
            value,
            style: AppTextStyles.displayMedium.copyWith(fontSize: 24),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTextStyles.labelSmall,
          ),
        ],
      ),
    );
  }
}