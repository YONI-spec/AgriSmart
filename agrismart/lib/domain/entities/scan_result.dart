// lib/domain/entities/scan_result.dart
// Entité centrale + SeverityLevel — SOURCE DE VÉRITÉ UNIQUE
// Utilisé par domain, data ET presentation (via export dans agri_widgets.dart)

import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

// ════════════════════════════════════════════════════════════
// SEVERITY LEVEL — enum + extension visuelle
// Défini ICI une seule fois, exporté partout via agri_widgets.dart
// ════════════════════════════════════════════════════════════

enum SeverityLevel { healthy, warning, danger, unknown }

extension SeverityLevelX on SeverityLevel {
  Color get color {
    switch (this) {
      case SeverityLevel.healthy: return AppColors.healthy;
      case SeverityLevel.warning: return AppColors.warning;
      case SeverityLevel.danger:  return AppColors.danger;
      case SeverityLevel.unknown: return AppColors.textTertiary;
    }
  }

  Color get backgroundColor {
    switch (this) {
      case SeverityLevel.healthy: return AppColors.healthyBg;
      case SeverityLevel.warning: return AppColors.warningBg;
      case SeverityLevel.danger:  return AppColors.dangerBg;
      case SeverityLevel.unknown: return AppColors.border;
    }
  }

  IconData get icon {
    switch (this) {
      case SeverityLevel.healthy: return Icons.check_circle_rounded;
      case SeverityLevel.warning: return Icons.warning_rounded;
      case SeverityLevel.danger:  return Icons.dangerous_rounded;
      case SeverityLevel.unknown: return Icons.help_rounded;
    }
  }

  String get label {
    switch (this) {
      case SeverityLevel.healthy: return 'Sain';
      case SeverityLevel.warning: return 'Attention';
      case SeverityLevel.danger:  return 'Danger';
      case SeverityLevel.unknown: return 'Inconnu';
    }
  }
}

// ════════════════════════════════════════════════════════════
// SCAN RESULT — entité domaine
// ════════════════════════════════════════════════════════════

enum SyncStatus { pending, synced, failed }

class ScanResult {
  const ScanResult({
    required this.id,
    required this.disease,
    required this.confidence,
    required this.allProbabilities,
    required this.capturedAt,
    this.plantName,
    this.tagZone,
    this.latitude,
    this.longitude,
    this.syncStatus = SyncStatus.pending,
  });

  final String id;
  final String disease;
  final double confidence;
  final Map<String, double> allProbabilities;
  final DateTime capturedAt;
  final String? plantName;
  final String? tagZone;         // suivi longitudinal mobile
  final double? latitude;
  final double? longitude;
  final SyncStatus syncStatus;

  // Sévérité calculée depuis le label + confiance
  SeverityLevel get severity {
    final lc = disease.toLowerCase();
    if (lc == 'saine' || lc == 'sain' || lc.contains('healthy')) {
      return SeverityLevel.healthy;
    }
    if (confidence >= 0.80) return SeverityLevel.danger;
    if (confidence >= 0.60) return SeverityLevel.warning;
    return SeverityLevel.unknown;
  }

  // ── Sérialisation SQLite ──────────────────────────────────
  Map<String, dynamic> toMap() => {
    'id':          id,
    'disease':     disease,
    'confidence':  confidence,
    'plant_name':  plantName,
    'tag_zone':    tagZone,
    'latitude':    latitude,
    'longitude':   longitude,
    'captured_at': capturedAt.toIso8601String(),
    'sync_status': syncStatus.name,
  };

  factory ScanResult.fromMap(Map<String, dynamic> map) => ScanResult(
    id:               map['id'] as String,
    disease:          map['disease'] as String,
    confidence:       (map['confidence'] as num).toDouble(),
    allProbabilities: const {},
    capturedAt:       DateTime.parse(map['captured_at'] as String),
    plantName:        map['plant_name'] as String?,
    tagZone:          map['tag_zone'] as String?,
    latitude:         (map['latitude'] as num?)?.toDouble(),
    longitude:        (map['longitude'] as num?)?.toDouble(),
    syncStatus:       SyncStatus.values.byName(
                        map['sync_status'] as String? ?? 'pending',
                      ),
  );

  ScanResult copyWith({
    String? disease,
    double? confidence,
    String? plantName,
    String? tagZone,
    SyncStatus? syncStatus,
  }) => ScanResult(
    id:               id,
    disease:          disease ?? this.disease,
    confidence:       confidence ?? this.confidence,
    allProbabilities: allProbabilities,
    capturedAt:       capturedAt,
    plantName:        plantName ?? this.plantName,
    tagZone:          tagZone ?? this.tagZone,
    latitude:         latitude,
    longitude:        longitude,
    syncStatus:       syncStatus ?? this.syncStatus,
  );
}