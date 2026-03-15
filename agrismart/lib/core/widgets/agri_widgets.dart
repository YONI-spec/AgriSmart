// lib/core/widgets/agri_widgets.dart
// Composants réutilisables AgriSmart
// Pensés pour agriculteurs : grands, contrastés, universels

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

// ════════════════════════════════════════════════════════════
// AGRI BUTTON — Bouton principal très visible
// ════════════════════════════════════════════════════════════

enum AgriButtonVariant { primary, secondary, danger, outline }

class AgriButton extends StatefulWidget {
  const AgriButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.variant = AgriButtonVariant.primary,
    this.isLoading = false,
    this.fullWidth = true,
    this.height = 60,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final AgriButtonVariant variant;
  final bool isLoading;
  final bool fullWidth;
  final double height;

  @override
  State<AgriButton> createState() => _AgriButtonState();
}

class _AgriButtonState extends State<AgriButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 120),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurveTween(curve: Curves.easeInOut).animate(_controller),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color get _backgroundColor {
    if (widget.onPressed == null) return AppColors.textTertiary.withOpacity(0.3);
    switch (widget.variant) {
      case AgriButtonVariant.primary:
        return AppColors.primary;
      case AgriButtonVariant.secondary:
        return AppColors.primaryLight;
      case AgriButtonVariant.danger:
        return AppColors.danger;
      case AgriButtonVariant.outline:
        return Colors.transparent;
    }
  }

  Color get _foregroundColor {
    switch (widget.variant) {
      case AgriButtonVariant.primary:
      case AgriButtonVariant.danger:
        return Colors.white;
      case AgriButtonVariant.secondary:
        return AppColors.primary;
      case AgriButtonVariant.outline:
        return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        if (widget.onPressed != null) {
          _controller.forward();
          HapticFeedback.lightImpact();
        }
      },
      onTapUp: (_) {
        _controller.reverse();
        widget.onPressed?.call();
      },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: widget.fullWidth ? double.infinity : null,
          height: widget.height,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(
            color: _backgroundColor,
            borderRadius: BorderRadius.circular(16),
            border: widget.variant == AgriButtonVariant.outline
                ? Border.all(color: AppColors.primary, width: 2)
                : null,
            boxShadow: widget.variant == AgriButtonVariant.primary &&
                    widget.onPressed != null
                ? [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.30),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: widget.isLoading
              ? Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: _foregroundColor,
                    ),
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize:
                      widget.fullWidth ? MainAxisSize.max : MainAxisSize.min,
                  children: [
                    if (widget.icon != null) ...[
                      Icon(widget.icon, color: _foregroundColor, size: 24),
                      const SizedBox(width: 10),
                    ],
                    Text(
                      widget.label,
                      style: AppTextStyles.buttonLarge.copyWith(
                        color: _foregroundColor,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
// SEVERITY INDICATOR — Vert / Orange / Rouge
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

class SeverityIndicator extends StatelessWidget {
  const SeverityIndicator({
    super.key,
    required this.level,
    this.showLabel = true,
    this.size = 48,
  });

  final SeverityLevel level;
  final bool showLabel;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: level.backgroundColor,
            shape: BoxShape.circle,
          ),
          child: Icon(
            level.icon,
            color: level.color,
            size: size * 0.55,
          ),
        ),
        if (showLabel) ...[
          const SizedBox(height: 6),
          Text(
            level.label,
            style: AppTextStyles.labelLarge.copyWith(
              color: level.color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════
// CONFIDENCE BADGE — Affiche le % de confiance du modèle ML
// ════════════════════════════════════════════════════════════

class ConfidenceBadge extends StatelessWidget {
  const ConfidenceBadge({
    super.key,
    required this.confidence, // 0.0 à 1.0
    this.compact = false,
  });

  final double confidence;
  final bool compact;

  Color get _color {
    if (confidence >= 0.75) return AppColors.healthy;
    if (confidence >= 0.50) return AppColors.warning;
    return AppColors.danger;
  }

  @override
  Widget build(BuildContext context) {
    final percent = (confidence * 100).toStringAsFixed(0);

    if (compact) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: _color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _color.withOpacity(0.3)),
        ),
        child: Text(
          '$percent%',
          style: AppTextStyles.labelLarge.copyWith(
            color: _color,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$percent%',
          style: AppTextStyles.confidenceLarge.copyWith(color: _color),
        ),
        Text(
          'CONFIANCE',
          style: AppTextStyles.confidenceLabel,
        ),
        const SizedBox(height: 12),
        // Barre de progression
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: confidence,
            minHeight: 8,
            backgroundColor: AppColors.border,
            valueColor: AlwaysStoppedAnimation<Color>(_color),
          ),
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════
// DIAGNOSTIC CARD — Card résumé d'un scan
// ════════════════════════════════════════════════════════════

class DiagnosticCard extends StatelessWidget {
  const DiagnosticCard({
    super.key,
    required this.diseaseName,
    required this.plantName,
    required this.confidence,
    required this.severity,
    this.dateLabel,
    this.onTap,
    this.showFullDetail = false,
  });

  final String diseaseName;
  final String plantName;
  final double confidence;
  final SeverityLevel severity;
  final String? dateLabel;
  final VoidCallback? onTap;
  final bool showFullDetail;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: severity.color.withOpacity(0.25),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Bande couleur en haut ──────────────────────────
            Container(
              height: 5,
              decoration: BoxDecoration(
                color: severity.color,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(19),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Icône sévérité
                  SeverityIndicator(
                    level: severity,
                    showLabel: false,
                    size: 52,
                  ),
                  const SizedBox(width: 14),
                  // Infos maladie
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          diseaseName,
                          style: AppTextStyles.titleMedium,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          plantName,
                          style: AppTextStyles.bodyMedium,
                        ),
                        if (dateLabel != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            dateLabel!,
                            style: AppTextStyles.labelSmall,
                          ),
                        ],
                      ],
                    ),
                  ),
                  // Badge confiance
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      ConfidenceBadge(
                        confidence: confidence,
                        compact: true,
                      ),
                      if (onTap != null) ...[
                        const SizedBox(height: 8),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: AppColors.textTertiary,
                          size: 22,
                        ),
                      ],
                    ],
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

// ════════════════════════════════════════════════════════════
// SECTION HEADER — Titre de section réutilisable
// ════════════════════════════════════════════════════════════

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(title, style: AppTextStyles.titleMedium),
        ),
        if (actionLabel != null && onAction != null)
          GestureDetector(
            onTap: onAction,
            child: Text(
              actionLabel!,
              style: AppTextStyles.labelLarge.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════
// AGRI TEXT FIELD — Champ de saisie cohérent
// ════════════════════════════════════════════════════════════

class AgriTextField extends StatelessWidget {
  const AgriTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.prefixIcon,
    this.keyboardType,
    this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final IconData? prefixIcon;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.labelLarge),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          onChanged: onChanged,
          style: AppTextStyles.bodySemiBold,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textTertiary,
            ),
            prefixIcon: prefixIcon != null
                ? Icon(prefixIcon, color: AppColors.textTertiary)
                : null,
            filled: true,
            fillColor: AppColors.background,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: AppColors.primary, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
        ),
      ],
    );
  }
}