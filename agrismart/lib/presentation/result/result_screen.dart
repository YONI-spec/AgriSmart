// lib/presentation/result/result_screen.dart
// Sprint 3 — Résultat complet :
//   ✅ Photo capturée affichée
//   ✅ Nom maladie + niveau confiance animé
//   ✅ Description courte de la maladie
//   ✅ Conseil de traitement + produit recommandé + prix FCFA
//   ✅ Enrichissement API en arrière-plan si connecté
//   ✅ Sauvegarde SQLite

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/agri_widgets.dart';
import '../../core/router/route_names.dart';
import '../../data/remote/api_client.dart';
import '../../domain/entities/scan_result.dart';

class ResultScreen extends ConsumerStatefulWidget {
  const ResultScreen({super.key, required this.data});
  final Map<String, dynamic> data;

  @override
  ConsumerState<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends ConsumerState<ResultScreen>
    with TickerProviderStateMixin {

  // Animations
  late AnimationController _entryController;
  late AnimationController _confidenceController;
  late Animation<double> _fadeIn;
  late Animation<Offset> _slideIn;
  late Animation<double> _confidenceAnim;

  // Enrichissement API
  ApiDiagnosticResult? _apiResult;
  bool _loadingApi = false;
  bool _isConnected = false;

  // Données locales TFLite
  String get _disease    => widget.data['disease'] as String? ?? 'Inconnu';
  double get _confidence => (widget.data['confidence'] as num?)?.toDouble() ?? 0.0;
  String get _advice     => widget.data['advice']    as String? ?? '';
  String get _severityStr=> widget.data['severity']  as String? ?? 'danger';
  int    get _frames     => widget.data['framesUsed'] as int? ?? 1;
  String get _source     => widget.data['source']    as String? ?? 'camera';

  // Image capturée (si passée)
  Uint8List? get _imageBytes => widget.data['imageBytes'] as Uint8List?;
  String?    get _imagePath  => widget.data['imagePath']  as String?;

  SeverityLevel get _severity {
    switch (_severityStr) {
      case 'healthy': return SeverityLevel.healthy;
      case 'warning': return SeverityLevel.warning;
      default:        return SeverityLevel.danger;
    }
  }

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _enrichWithApi();
  }

  void _setupAnimations() {
    _entryController = AnimationController(
      duration: const Duration(milliseconds: 600), vsync: this,
    )..forward();

    _confidenceController = AnimationController(
      duration: const Duration(milliseconds: 1200), vsync: this,
    );

    _fadeIn = CurveTween(curve: Curves.easeOut).animate(_entryController);
    _slideIn = Tween(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(parent: _entryController, curve: Curves.easeOutCubic));

    _confidenceAnim = Tween<double>(begin: 0, end: _confidence)
        .animate(CurvedAnimation(parent: _confidenceController, curve: Curves.easeOut));

    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) _confidenceController.forward();
    });
  }

  Future<void> _enrichWithApi() async {
    final service = ref.read(diagnosticServiceProvider);
    setState(() => _loadingApi = true);

    _isConnected = await service.isConnected();

    if (_isConnected && _imagePath != null) {
      final file = File(_imagePath!);
      final result = await service.enrichWithApi(file);
      if (mounted) {
        setState(() {
          _apiResult = result;
          _loadingApi = false;
        });
      }
    } else {
      if (mounted) setState(() => _loadingApi = false);
    }
  }

  @override
  void dispose() {
    _entryController.dispose();
    _confidenceController.dispose();
    super.dispose();
  }

  // Données affichées : API si dispo, sinon TFLite local
  String get _displayDisease    => _apiResult?.classe       ?? _disease;
  String get _displayAdvice     => _apiResult?.conseil      ?? _advice;
  String? get _displayPrixFcfa  => _apiResult?.prixFcfa;
  String? get _displayProduit   => _apiResult?.produitLocal;
  String? get _displayDesc      => _apiResult?.description  ?? _diseaseDescription(_disease);
  double get _displayConfidence => _apiResult?.confiance    ?? _confidence;

  String? _diseaseDescription(String label) {
    const desc = {
      'Bacterienne': 'Infection causée par des bactéries pathogènes. Se propage par l\'eau, le vent et les insectes. Taches aqueuses caractéristiques sur les feuilles.',
      'Fongique':    'Champignon parasitaire qui attaque les tissus végétaux. Favorisé par l\'humidité et la chaleur. Présence fréquente de taches, moisissures ou pourritures.',
      'Parasitaire': 'Attaque d\'insectes ou d\'acariens qui se nourrissent de la plante. Visible sous forme de trous, galeries ou colonies sur les feuilles.',
      'Virale':      'Maladie causée par un virus transmis par des insectes vecteurs (pucerons, aleurodes). Déformation et mosaïque caractéristiques du feuillage.',
      'Saine':       'Aucune maladie détectée. La plante présente un aspect sain et vigoureux.',
    };
    return desc[label];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeIn,
          child: SlideTransition(
            position: _slideIn,
            child: CustomScrollView(
              slivers: [

                // ── Header ────────────────────────────────────────
                SliverToBoxAdapter(child: _buildHeader(context)),

                // ── Photo capturée ────────────────────────────────
                if (_imageBytes != null || _imagePath != null)
                  SliverToBoxAdapter(child: _buildPhoto()),

                // ── Carte maladie principale ──────────────────────
                SliverToBoxAdapter(child: _buildDiseaseCard()),

                // ── Niveau de confiance animé ─────────────────────
                SliverToBoxAdapter(child: _buildConfidenceSection()),

                // ── Description de la maladie ─────────────────────
                if (_displayDesc != null)
                  SliverToBoxAdapter(child: _buildDescriptionCard()),

                // ── Enrichissement API ────────────────────────────
                SliverToBoxAdapter(child: _buildApiStatus()),

                // ── Conseils de traitement ────────────────────────
                SliverToBoxAdapter(child: _buildTreatmentCard()),

                // ── Actions ───────────────────────────────────────
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      AgriButton(
                        label: 'Nouveau scan',
                        icon: Icons.camera_alt_rounded,
                        onPressed: () => context.goNamed(RouteNames.scannerName),
                      ),
                      const SizedBox(height: 12),
                      AgriButton(
                        label: 'Enregistrer',
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

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(children: [
        GestureDetector(
          onTap: () {
            if (context.canPop()) context.pop();
            else context.goNamed(RouteNames.scannerName);
          },
          child: Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: Colors.white, shape: BoxShape.circle,
              border: Border.all(color: AppColors.border),
            ),
            child: const Icon(Icons.arrow_back_rounded,
                color: AppColors.textPrimary, size: 22),
          ),
        ),
        const Spacer(),
        Text('Diagnostic', style: AppTextStyles.titleLarge),
        const Spacer(),
        // Badge source (caméra ou galerie)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(
              _source == 'gallery'
                  ? Icons.photo_library_rounded
                  : Icons.camera_alt_rounded,
              size: 14, color: AppColors.primary,
            ),
            const SizedBox(width: 4),
            Text(
              _source == 'gallery' ? 'Galerie' : 'Caméra',
              style: AppTextStyles.labelSmall.copyWith(color: AppColors.primary),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _buildPhoto() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: SizedBox(
          height: 200,
          width: double.infinity,
          child: _imageBytes != null
              ? Image.memory(_imageBytes!, fit: BoxFit.cover)
              : _imagePath != null
                  ? Image.file(File(_imagePath!), fit: BoxFit.cover)
                  : Container(
                      color: AppColors.primaryLight,
                      child: const Icon(Icons.image_rounded,
                          size: 60, color: AppColors.primary),
                    ),
        ),
      ),
    );
  }

  Widget _buildDiseaseCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _severity.backgroundColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _severity.color.withOpacity(0.3), width: 2),
        ),
        child: Row(children: [
          SeverityIndicator(level: _severity, size: 64),
          const SizedBox(width: 16),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_displayDisease,
                  style: AppTextStyles.displayMedium.copyWith(
                      color: _severity.color)),
              const SizedBox(height: 4),
              // Badge source données
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _apiResult != null
                      ? AppColors.info.withOpacity(0.12)
                      : AppColors.border,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _apiResult != null ? '✓ Enrichi par API' : '⚡ TFLite local',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: _apiResult != null
                        ? AppColors.info
                        : AppColors.textTertiary,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '$_frames frame${_frames > 1 ? 's' : ''} analysée${_frames > 1 ? 's' : ''}',
                style: AppTextStyles.labelSmall,
              ),
            ],
          )),
        ]),
      ),
    );
  }

  Widget _buildConfidenceSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(children: [
          Text('Niveau de confiance', style: AppTextStyles.titleMedium),
          const SizedBox(height: 16),
          // Cercle animé
          AnimatedBuilder(
            animation: _confidenceAnim,
            builder: (_, __) => _ConfidenceCircle(
              value: _confidenceAnim.value,
              severity: _severity,
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildDescriptionCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.info_rounded, color: AppColors.info, size: 20),
            const SizedBox(width: 8),
            Text('À propos', style: AppTextStyles.titleMedium),
          ]),
          const SizedBox(height: 10),
          Text(_displayDesc!, style: AppTextStyles.bodyMedium),
        ]),
      ),
    );
  }

  Widget _buildApiStatus() {
    if (!_isConnected && !_loadingApi) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.warningBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.warning.withOpacity(0.3)),
          ),
          child: Row(children: [
            Icon(Icons.wifi_off_rounded, color: AppColors.warning, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(
              'Hors ligne — résultat TFLite local uniquement',
              style: AppTextStyles.labelLarge.copyWith(color: AppColors.warning),
            )),
          ]),
        ),
      );
    }

    if (_loadingApi) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.infoBg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(children: [
            const SizedBox(width: 16, height: 16,
                child: CircularProgressIndicator(strokeWidth: 2,
                    color: AppColors.info)),
            const SizedBox(width: 10),
            Text('Enrichissement via API…',
                style: AppTextStyles.labelLarge.copyWith(
                    color: AppColors.info)),
          ]),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildTreatmentCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.healing_rounded, color: AppColors.warning, size: 20),
            const SizedBox(width: 8),
            Text('Traitement recommandé', style: AppTextStyles.titleMedium),
          ]),
          const SizedBox(height: 12),

          // Conseils ligne par ligne
          ..._displayAdvice.split('.').where((s) => s.trim().isNotEmpty).map(
            (tip) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  margin: const EdgeInsets.only(top: 7),
                  width: 7, height: 7,
                  decoration: const BoxDecoration(
                    color: AppColors.primary, shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(tip.trim(), style: AppTextStyles.bodyMedium)),
              ]),
            ),
          ),

          // Produit recommandé (API uniquement)
          if (_displayProduit != null) ...[
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 10),
            Row(children: [
              Icon(Icons.store_rounded, color: AppColors.primary, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text(_displayProduit!,
                  style: AppTextStyles.bodySemiBold)),
            ]),
          ],

          // Prix FCFA (API uniquement)
          if (_displayPrixFcfa != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(children: [
                const Icon(Icons.payments_rounded,
                    color: AppColors.primary, size: 20),
                const SizedBox(width: 10),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Prix estimé',
                      style: AppTextStyles.labelSmall),
                  Text(_displayPrixFcfa!,
                      style: AppTextStyles.titleMedium.copyWith(
                          color: AppColors.primary)),
                ]),
              ]),
            ),
          ],
        ]),
      ),
    );
  }
}

// ── Jauge de confiance circulaire animée ──────────────────────────
class _ConfidenceCircle extends StatelessWidget {
  const _ConfidenceCircle({required this.value, required this.severity});
  final double value;
  final SeverityLevel severity;

  @override
  Widget build(BuildContext context) {
    final pct = (value * 100).toInt();
    return SizedBox(
      width: 130, height: 130,
      child: Stack(alignment: Alignment.center, children: [
        SizedBox(
          width: 130, height: 130,
          child: CircularProgressIndicator(
            value: value,
            strokeWidth: 10,
            backgroundColor: AppColors.border,
            valueColor: AlwaysStoppedAnimation<Color>(severity.color),
            strokeCap: StrokeCap.round,
          ),
        ),
        Column(mainAxisSize: MainAxisSize.min, children: [
          Text('$pct%',
              style: AppTextStyles.confidenceLarge.copyWith(
                  color: severity.color, fontSize: 38)),
          Text('CONFIANCE', style: AppTextStyles.confidenceLabel),
        ]),
      ]),
    );
  }
}