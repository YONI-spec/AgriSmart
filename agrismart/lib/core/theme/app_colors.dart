// lib/core/theme/app_colors.dart

import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // ── Couleurs primaires AgriSmart ──────────────────────────────
  static const Color primary     = Color(0xFF1D9E75); // Vert AgriSmart
  static const Color primaryDark = Color(0xFF0F6E52); // Vert foncé (hover, pressed)
  static const Color primaryLight= Color(0xFFE1F5EE); // Vert très clair (backgrounds)

  static const Color secondary   = Color(0xFF2D6A4F); // Vert forêt (titres)
  static const Color accent      = Color(0xFFF4A261); // Orange terre (CTA secondaire)

  // ── Sémantique sévérité (universel : vert/orange/rouge) ──────
  static const Color healthy     = Color(0xFF1D9E75); // Sain
  static const Color warning     = Color(0xFFFF8C00); // Attention (orange vif)
  static const Color danger      = Color(0xFFE53935); // Danger / maladie grave
  static const Color info        = Color(0xFF1976D2); // Information

  // Backgrounds sévérité (très clairs pour les cards)
  static const Color healthyBg   = Color(0xFFE8F5E9);
  static const Color warningBg   = Color(0xFFFFF3E0);
  static const Color dangerBg    = Color(0xFFFFEBEE);
  static const Color infoBg      = Color(0xFFE3F2FD);

  // ── Neutres ──────────────────────────────────────────────────
  static const Color background  = Color(0xFFF8FAF8); // Fond général légèrement verdâtre
  static const Color surface     = Color(0xFFFFFFFF); // Surfaces cards
  static const Color border      = Color(0xFFE0EDE8); // Bordures légères

  static const Color textPrimary   = Color(0xFF0D1F1A); // Noir verdâtre — très lisible soleil
  static const Color textSecondary = Color(0xFF4A6360); // Gris vert
  static const Color textTertiary  = Color(0xFF8FA8A2); // Gris clair

  // ── Overlay caméra ───────────────────────────────────────────
  static const Color scannerOverlay   = Color(0xB3000000); // 70% noir
  static const Color scannerReticle   = Color(0xFF1D9E75); // Cadre vert
  static const Color scannerReticleOk = Color(0xFF00E676); // Flash validation

  // ── Gradient splash ─────────────────────────────────────────
  static const LinearGradient splashGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF0F6E52), Color(0xFF1D9E75), Color(0xFF52B788)],
  );
}