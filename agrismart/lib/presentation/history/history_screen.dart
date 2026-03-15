// lib/presentation/history/history_screen.dart
// Historique des scans — tous les diagnostics de l'agriculteur
// (Remplace l'onglet Parcelles qui passe sur le logiciel drone)

import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/agri_widgets.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  SeverityLevel? _filterLevel; // null = tout afficher

  // Données simulées — sera remplacé par SQLite en Sprint 2
  final List<_ScanEntry> _scans = [
    _ScanEntry('Mildiou',        'Tomate',  0.92, SeverityLevel.danger,  'Aujourd\'hui, 09h14'),
    _ScanEntry('Plante saine',   'Maïs',    0.87, SeverityLevel.healthy, 'Hier, 16h30'),
    _ScanEntry('Oïdium précoce', 'Piment',  0.68, SeverityLevel.warning, '12 mars, 11h00'),
    _ScanEntry('Plante saine',   'Haricot', 0.91, SeverityLevel.healthy, '11 mars, 08h22'),
    _ScanEntry('Rouille',        'Tomate',  0.78, SeverityLevel.danger,  '10 mars, 14h05'),
    _ScanEntry('Plante saine',   'Maïs',    0.95, SeverityLevel.healthy, '09 mars, 07h50'),
  ];

  List<_ScanEntry> get _filtered => _filterLevel == null
      ? _scans
      : _scans.where((s) => s.severity == _filterLevel).toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Historique'),
        actions: [
          // Bouton filtre
          IconButton(
            onPressed: () => _showFilterSheet(context),
            icon: Stack(
              children: [
                const Icon(Icons.filter_list_rounded),
                if (_filterLevel != null)
                  Positioned(
                    right: 0, top: 0,
                    child: Container(
                      width: 8, height: 8,
                      decoration: BoxDecoration(
                        color: _filterLevel!.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Résumé compteurs ────────────────────────────────
          _ScanSummaryBar(scans: _scans),

          // ── Liste ───────────────────────────────────────────
          Expanded(
            child: _filtered.isEmpty
                ? _EmptyState()
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
                    itemCount: _filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final s = _filtered[i];
                      return DiagnosticCard(
                        diseaseName: s.disease,
                        plantName: s.plant,
                        confidence: s.confidence,
                        severity: s.severity,
                        dateLabel: s.date,
                        onTap: () {},
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _showFilterSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _FilterSheet(
        current: _filterLevel,
        onSelect: (level) {
          setState(() => _filterLevel = level);
          Navigator.pop(context);
        },
      ),
    );
  }
}

// ── Barre de résumé ───────────────────────────────────────────────
class _ScanSummaryBar extends StatelessWidget {
  const _ScanSummaryBar({required this.scans});
  final List<_ScanEntry> scans;

  @override
  Widget build(BuildContext context) {
    final total   = scans.length;
    final healthy = scans.where((s) => s.severity == SeverityLevel.healthy).length;
    final warning = scans.where((s) => s.severity == SeverityLevel.warning).length;
    final danger  = scans.where((s) => s.severity == SeverityLevel.danger).length;

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _SummaryChip(count: total,   label: 'Total',    color: AppColors.textSecondary),
          _SummaryChip(count: healthy, label: 'Sains',    color: AppColors.healthy),
          _SummaryChip(count: warning, label: 'Attention',color: AppColors.warning),
          _SummaryChip(count: danger,  label: 'Danger',   color: AppColors.danger),
        ],
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({
    required this.count,
    required this.label,
    required this.color,
  });
  final int count;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '$count',
          style: AppTextStyles.titleMedium.copyWith(color: color),
        ),
        Text(label, style: AppTextStyles.labelSmall),
      ],
    );
  }
}

// ── Sheet de filtre ───────────────────────────────────────────────
class _FilterSheet extends StatelessWidget {
  const _FilterSheet({required this.current, required this.onSelect});
  final SeverityLevel? current;
  final ValueChanged<SeverityLevel?> onSelect;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Filtrer par sévérité', style: AppTextStyles.titleMedium),
            const SizedBox(height: 16),
            _FilterTile(
              label: 'Tous les scans',
              icon: Icons.list_rounded,
              color: AppColors.textSecondary,
              selected: current == null,
              onTap: () => onSelect(null),
            ),
            _FilterTile(
              label: 'Sain',
              icon: Icons.check_circle_rounded,
              color: AppColors.healthy,
              selected: current == SeverityLevel.healthy,
              onTap: () => onSelect(SeverityLevel.healthy),
            ),
            _FilterTile(
              label: 'Attention',
              icon: Icons.warning_rounded,
              color: AppColors.warning,
              selected: current == SeverityLevel.warning,
              onTap: () => onSelect(SeverityLevel.warning),
            ),
            _FilterTile(
              label: 'Danger',
              icon: Icons.dangerous_rounded,
              color: AppColors.danger,
              selected: current == SeverityLevel.danger,
              onTap: () => onSelect(SeverityLevel.danger),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterTile extends StatelessWidget {
  const _FilterTile({
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.08) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? color.withOpacity(0.4) : AppColors.border,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label, style: AppTextStyles.bodySemiBold),
            ),
            if (selected)
              Icon(Icons.check_rounded, color: color, size: 20),
          ],
        ),
      ),
    );
  }
}

// ── État vide ─────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.search_off_rounded,
            size: 64,
            color: AppColors.textTertiary,
          ),
          const SizedBox(height: 16),
          Text(
            'Aucun scan pour ce filtre',
            style: AppTextStyles.bodyLarge,
          ),
        ],
      ),
    );
  }
}

// ── Modèle local (remplacé par entité SQLite en Sprint 2) ─────────
class _ScanEntry {
  const _ScanEntry(
    this.disease,
    this.plant,
    this.confidence,
    this.severity,
    this.date,
  );
  final String disease;
  final String plant;
  final double confidence;
  final SeverityLevel severity;
  final String date;
}