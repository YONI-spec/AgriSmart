// lib/core/theme/app_text_styles.dart
// Typographie pensée terrain : tailles généreuses, lisibilité soleil

import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTextStyles {
  AppTextStyles._();

  // ── Titres display (nom maladie, diagnostics) ─────────────────
  static const TextStyle displayLarge = TextStyle(
    fontFamily: 'AgriDisplay',
    fontSize: 40,
    fontWeight: FontWeight.w800,
    color: AppColors.textPrimary,
    height: 1.1,
    letterSpacing: -0.5,
  );

  static const TextStyle displayMedium = TextStyle(
    fontFamily: 'AgriDisplay',
    fontSize: 28,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    height: 1.2,
  );

  // ── Titres section ────────────────────────────────────────────
  static const TextStyle titleLarge = TextStyle(
    fontFamily: 'AgriDisplay',
    fontSize: 22,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    letterSpacing: -0.3,
  );

  static const TextStyle titleMedium = TextStyle(
    fontFamily: 'AgriDisplay',
    fontSize: 18,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );

  // ── Corps de texte — liserez en plein soleil ──────────────────
  static const TextStyle bodyLarge = TextStyle(
    fontFamily: 'AgriBody',
    fontSize: 18,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
    height: 1.6,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontFamily: 'AgriBody',
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
    height: 1.5,
  );

  static const TextStyle bodySemiBold = TextStyle(
    fontFamily: 'AgriBody',
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    height: 1.5,
  );

  // ── Labels / badges ───────────────────────────────────────────
  static const TextStyle labelLarge = TextStyle(
    fontFamily: 'AgriBody',
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.textSecondary,
    letterSpacing: 0.2,
  );

  static const TextStyle labelSmall = TextStyle(
    fontFamily: 'AgriBody',
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: AppColors.textTertiary,
    letterSpacing: 0.3,
  );

  // ── Boutons ───────────────────────────────────────────────────
  static const TextStyle buttonLarge = TextStyle(
    fontFamily: 'AgriDisplay',
    fontSize: 20,
    fontWeight: FontWeight.w700,
    color: Colors.white,
    letterSpacing: 0.5,
  );

  static const TextStyle buttonMedium = TextStyle(
    fontFamily: 'AgriBody',
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.3,
  );

  // ── Pourcentage confiance (grand affichage) ───────────────────
  static const TextStyle confidenceLarge = TextStyle(
    fontFamily: 'AgriDisplay',
    fontSize: 52,
    fontWeight: FontWeight.w800,
    height: 1.0,
  );

  static const TextStyle confidenceLabel = TextStyle(
    fontFamily: 'AgriBody',
    fontSize: 13,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.8,
    color: AppColors.textTertiary,
  );
}