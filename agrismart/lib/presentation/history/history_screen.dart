// lib/presentation/history/history_screen.dart
// Sprint 2 — branché sur SQLite + suivi longitudinal par zone

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/agri_widgets.dart';
import '../../data/local/scan_dao.dart';
import '../../domain/entities/scan_result.dart';

// ── Provider SQLite ───────────────────────────────────────────────
final allScansProvider = FutureProvider<List<ScanResult>>((ref) async {
  return ScanDao.instance.getAllScans();
});

final tagZonesProvider = FutureProvider<List<String>>((ref) async {
  return ScanDao.instance.getAllTagZones();
});

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Historique'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textTertiary,
          tabs: const [
            Tab(text: 'Tous les scans'),
            Tab(text: 'Suivi zones'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _AllScansTab(),
          _ZoneTrackingTab(),
        ],
      ),
    );
  }
}

// ── Onglet 1 : Tous les scans ─────────────────────────────────────
class _AllScansTab extends ConsumerStatefulWidget {
  const _AllScansTab();

  @override
  ConsumerState<_AllScansTab> createState() => _AllScansTabState();
}

class _AllScansTabState extends ConsumerState<_AllScansTab> {
  SeverityLevel? _filter;

  @override
  Widget build(BuildContext context) {
    final scansAsync = ref.watch(allScansProvider);

    return scansAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Erreur : $e')),
      data: (scans) {
        final filtered = _filter == null
            ? scans
            : scans.where((s) => s.severity == _filter).toList();

        return Column(
          children: [
            // Barre résumé + filtre
            _ScanSummaryBar(
              scans: scans,
              currentFilter: _filter,
              onFilterTap: () => _showFilter(context, scans),
            ),
            // Liste
            Expanded(
              child: filtered.isEmpty
                  ? _EmptyState()
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, i) {
                        final s = filtered[i];
                        return DiagnosticCard(
                          diseaseName: s.disease,
                          plantName: s.plantName ?? 'Plante',
                          confidence: s.confidence,
                          severity: _toWidgetSeverity(s.severity),
                          dateLabel: _formatDate(s.capturedAt),
                          onTap: () {},
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  void _showFilter(BuildContext context, List<ScanResult> scans) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _FilterSheet(
        current: _filter,
        onSelect: (f) {
          setState(() => _filter = f);
          Navigator.pop(context);
        },
      ),
    );
  }
}

// ── Onglet 2 : Suivi longitudinal par zone ────────────────────────
class _ZoneTrackingTab extends ConsumerWidget {
  const _ZoneTrackingTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final zonesAsync = ref.watch(tagZonesProvider);

    return zonesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Erreur : $e')),
      data: (zones) => zones.isEmpty
          ? _EmptyZonesState()
          : ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: zones.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) => _ZoneCard(tagZone: zones[i]),
            ),
    );
  }
}

class _ZoneCard extends ConsumerWidget {
  const _ZoneCard({required this.tagZone});
  final String tagZone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scansAsync = ref.watch(
      FutureProvider((ref) => ScanDao.instance.getScansByZone(tagZone)),
    );

    return scansAsync.when(
      loading: () => const SizedBox(height: 80,
          child: Center(child: CircularProgressIndicator())),
      error: (_, __) => const SizedBox.shrink(),
      data: (scans) {
        if (scans.isEmpty) return const SizedBox.shrink();

        final latest = scans.last;
        final earliest = scans.first;
        final latestPct = (latest.confidence * 100).toInt();
        final firstPct = (earliest.confidence * 100).toInt();
        final trend = latestPct - firstPct;

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header zone
              Row(
                children: [
                  Icon(Icons.location_on_rounded,
                      color: AppColors.primary, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(tagZone, style: AppTextStyles.titleMedium),
                  ),
                  _TrendBadge(trend: trend),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${scans.length} scan${scans.length > 1 ? 's' : ''} · '
                '${_formatDate(earliest.capturedAt)} → ${_formatDate(latest.capturedAt)}',
                style: AppTextStyles.labelSmall,
              ),
              const SizedBox(height: 14),

              // Mini courbe d'évolution
              _EvolutionChart(scans: scans),

              const SizedBox(height: 10),

              // Dernière maladie détectée
              Row(
                children: [
                  Text('Dernier diagnostic : ',
                      style: AppTextStyles.labelLarge),
                  Text(
                    latest.disease,
                    style: AppTextStyles.bodySemiBold.copyWith(
                      color: _severityColor(latest.severity),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Color _severityColor(SeverityLevel s) {
    switch (s) {
      case SeverityLevel.healthy: return AppColors.healthy;
      case SeverityLevel.warning: return AppColors.warning;
      case SeverityLevel.danger:  return AppColors.danger;
      default: return AppColors.textSecondary;
    }
  }
}

// ── Mini courbe d'évolution ───────────────────────────────────────
class _EvolutionChart extends StatelessWidget {
  const _EvolutionChart({required this.scans});
  final List<ScanResult> scans;

  @override
  Widget build(BuildContext context) {
    if (scans.length < 2) {
      return Container(
        height: 60,
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: Text('Scannez à nouveau pour voir l\'évolution',
              style: AppTextStyles.labelSmall),
        ),
      );
    }

    return SizedBox(
      height: 60,
      child: CustomPaint(
        painter: _ChartPainter(scans: scans),
        size: const Size(double.infinity, 60),
      ),
    );
  }
}

class _ChartPainter extends CustomPainter {
  const _ChartPainter({required this.scans});
  final List<ScanResult> scans;

  @override
  void paint(Canvas canvas, Size size) {
    if (scans.length < 2) return;

    final bgPaint = Paint()
      ..color = AppColors.background
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Offset.zero & size, const Radius.circular(10),
      ),
      bgPaint,
    );

    final n = scans.length;
    final points = <Offset>[];

    for (int i = 0; i < n; i++) {
      final x = (i / (n - 1)) * size.width;
      final y = size.height - (scans[i].confidence * (size.height - 12)) - 6;
      points.add(Offset(x, y));
    }

    // Zone remplie
    final fillPath = Path()..moveTo(points.first.dx, size.height);
    for (final p in points) fillPath.lineTo(p.dx, p.dy);
    fillPath.lineTo(points.last.dx, size.height);
    fillPath.close();

    canvas.drawPath(
      fillPath,
      Paint()..color = AppColors.primary.withOpacity(0.12),
    );

    // Ligne
    final linePath = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) linePath.lineTo(points[i].dx, points[i].dy);

    canvas.drawPath(
      linePath,
      Paint()
        ..color = AppColors.primary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // Points
    for (final p in points) {
      canvas.drawCircle(p, 4, Paint()..color = Colors.white);
      canvas.drawCircle(p, 3, Paint()..color = AppColors.primary);
    }
  }

  @override
  bool shouldRepaint(covariant _ChartPainter old) => old.scans != scans;
}

// ── Widgets utilitaires ───────────────────────────────────────────

class _TrendBadge extends StatelessWidget {
  const _TrendBadge({required this.trend});
  final int trend;

  @override
  Widget build(BuildContext context) {
    final isUp    = trend > 0;
    final isFlat  = trend == 0;
    final color   = isFlat ? AppColors.textTertiary
        : isUp ? AppColors.danger : AppColors.healthy;
    final icon    = isFlat ? Icons.remove_rounded
        : isUp ? Icons.trending_up_rounded : Icons.trending_down_rounded;
    final label   = isFlat ? '=' : '${isUp ? '+' : ''}$trend%';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 3),
          Text(label, style: TextStyle(
            fontSize: 12, fontWeight: FontWeight.w700, color: color,
          )),
        ],
      ),
    );
  }
}

class _ScanSummaryBar extends StatelessWidget {
  const _ScanSummaryBar({
    required this.scans,
    required this.currentFilter,
    required this.onFilterTap,
  });
  final List<ScanResult> scans;
  final SeverityLevel? currentFilter;
  final VoidCallback onFilterTap;

  @override
  Widget build(BuildContext context) {
    final healthy = scans.where((s) => s.severity == SeverityLevel.healthy).length;
    final warning = scans.where((s) => s.severity == SeverityLevel.warning).length;
    final danger  = scans.where((s) => s.severity == SeverityLevel.danger).length;

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          _SummaryChip(count: scans.length, label: 'Total', color: AppColors.textSecondary),
          _SummaryChip(count: healthy, label: 'Sains',     color: AppColors.healthy),
          _SummaryChip(count: warning, label: 'Attention', color: AppColors.warning),
          _SummaryChip(count: danger,  label: 'Danger',    color: AppColors.danger),
          const Spacer(),
          GestureDetector(
            onTap: onFilterTap,
            child: Icon(
              Icons.filter_list_rounded,
              color: currentFilter != null
                  ? AppColors.primary
                  : AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({required this.count, required this.label, required this.color});
  final int count; final String label; final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 14),
      child: Column(
        children: [
          Text('$count', style: AppTextStyles.titleMedium.copyWith(color: color)),
          Text(label, style: AppTextStyles.labelSmall),
        ],
      ),
    );
  }
}

class _FilterSheet extends StatelessWidget {
  const _FilterSheet({required this.current, required this.onSelect});
  final SeverityLevel? current;
  final ValueChanged<SeverityLevel?> onSelect;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Filtrer', style: AppTextStyles.titleMedium),
          const SizedBox(height: 16),
          _FilterTile(null,             'Tous',      Icons.list_rounded,          AppColors.textSecondary, current, onSelect),
          _FilterTile(SeverityLevel.healthy, 'Sain', Icons.check_circle_rounded, AppColors.healthy, current, onSelect),
          _FilterTile(SeverityLevel.warning, 'Attention', Icons.warning_rounded, AppColors.warning, current, onSelect),
          _FilterTile(SeverityLevel.danger,  'Danger',  Icons.dangerous_rounded,  AppColors.danger,  current, onSelect),
        ]),
      ),
    );
  }
}

Widget _FilterTile(
  SeverityLevel? level, String label, IconData icon, Color color,
  SeverityLevel? current, ValueChanged<SeverityLevel?> onSelect,
) {
  final selected = current == level;
  return GestureDetector(
    onTap: () => onSelect(level),
    child: Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: selected ? color.withOpacity(0.08) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: selected ? color.withOpacity(0.4) : AppColors.border),
      ),
      child: Row(children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(width: 12),
        Expanded(child: Text(label, style: AppTextStyles.bodySemiBold)),
        if (selected) Icon(Icons.check_rounded, color: color, size: 20),
      ]),
    ),
  );
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.search_off_rounded, size: 56, color: AppColors.textTertiary),
      const SizedBox(height: 12),
      Text('Aucun scan', style: AppTextStyles.bodyLarge),
    ]),
  );
}

class _EmptyZonesState extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.location_off_rounded, size: 56, color: AppColors.textTertiary),
        const SizedBox(height: 16),
        Text('Aucune zone étiquetée', style: AppTextStyles.titleMedium),
        const SizedBox(height: 8),
        Text(
          'Après un scan, étiquetez une zone (ex: "Tomate Rang 3") '
          'pour suivre l\'évolution de la maladie dans le temps.',
          style: AppTextStyles.bodyMedium,
          textAlign: TextAlign.center,
        ),
      ]),
    ),
  );
}

// ── Helpers ───────────────────────────────────────────────────────
SeverityLevel _toWidgetSeverity(SeverityLevel s) => s;

String _formatDate(DateTime dt) {
  final now = DateTime.now();
  final diff = now.difference(dt);
  if (diff.inDays == 0) return 'Aujourd\'hui';
  if (diff.inDays == 1) return 'Hier';
  return '${dt.day}/${dt.month}/${dt.year}';
}