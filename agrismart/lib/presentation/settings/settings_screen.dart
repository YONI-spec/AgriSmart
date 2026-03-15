// lib/presentation/settings/settings_screen.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _selectedLang = 'fr';
  bool _ttsEnabled = true;
  bool _sttEnabled = true;
  bool _alertsEnabled = true;
  bool _highContrastMode = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Paramètres'),
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ── Langue ────────────────────────────────────────────
          _SectionTitle(icon: Icons.language_rounded, title: 'Langue'),
          _SettingsCard(
            children: [
              _LangOption(
                code: 'fr',
                label: 'Français',
                flag: '🇫🇷',
                selected: _selectedLang == 'fr',
                onTap: () => setState(() => _selectedLang = 'fr'),
              ),
              const Divider(height: 1),
              _LangOption(
                code: 'ewe',
                label: 'Éwé',
                flag: '🇹🇬',
                selected: _selectedLang == 'ewe',
                onTap: () => setState(() => _selectedLang = 'ewe'),
              ),
              const Divider(height: 1),
              _LangOption(
                code: 'en',
                label: 'English',
                flag: '🇬🇧',
                selected: _selectedLang == 'en',
                onTap: () => setState(() => _selectedLang = 'en'),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // ── Audio / Vocal ─────────────────────────────────────
          _SectionTitle(icon: Icons.volume_up_rounded, title: 'Audio & Vocal'),
          _SettingsCard(
            children: [
              _ToggleRow(
                icon: Icons.record_voice_over_rounded,
                label: 'Lecture vocale des résultats',
                subtitle: 'Lire le diagnostic à voix haute',
                value: _ttsEnabled,
                onChanged: (v) => setState(() => _ttsEnabled = v),
              ),
              const Divider(height: 1),
              _ToggleRow(
                icon: Icons.mic_rounded,
                label: 'Déclenchement vocal',
                subtitle: 'Dire "Scanner" pour photographier',
                value: _sttEnabled,
                onChanged: (v) => setState(() => _sttEnabled = v),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // ── Notifications ─────────────────────────────────────
          _SectionTitle(
              icon: Icons.notifications_rounded, title: 'Alertes'),
          _SettingsCard(
            children: [
              _ToggleRow(
                icon: Icons.location_on_rounded,
                label: 'Alertes épidémiques',
                subtitle: 'Prévention si maladie détectée proche de vous',
                value: _alertsEnabled,
                onChanged: (v) => setState(() => _alertsEnabled = v),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // ── Accessibilité ─────────────────────────────────────
          _SectionTitle(
              icon: Icons.accessibility_rounded, title: 'Accessibilité'),
          _SettingsCard(
            children: [
              _ToggleRow(
                icon: Icons.contrast_rounded,
                label: 'Contraste élevé',
                subtitle: 'Meilleure lisibilité en plein soleil',
                value: _highContrastMode,
                onChanged: (v) => setState(() => _highContrastMode = v),
              ),
            ],
          ),

          const SizedBox(height: 32),

          // Version
          Center(
            child: Text(
              'AgriSmart v1.0.0 · Sprint 1',
              style: AppTextStyles.labelSmall,
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.title});
  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 8),
          Text(title, style: AppTextStyles.labelLarge.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          )),
        ],
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(children: children),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });
  final IconData icon;
  final String label;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: AppColors.textSecondary, size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTextStyles.bodySemiBold),
                Text(subtitle, style: AppTextStyles.labelSmall),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.primary,
          ),
        ],
      ),
    );
  }
}

class _LangOption extends StatelessWidget {
  const _LangOption({
    required this.code,
    required this.label,
    required this.flag,
    required this.selected,
    required this.onTap,
  });
  final String code;
  final String label;
  final String flag;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Text(flag, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 14),
            Expanded(
              child: Text(label, style: AppTextStyles.bodySemiBold),
            ),
            if (selected)
              Icon(Icons.check_circle_rounded,
                  color: AppColors.primary, size: 22)
            else
              Icon(Icons.circle_outlined,
                  color: AppColors.border, size: 22),
          ],
        ),
      ),
    );
  }
}