// lib/presentation/splash/splash_screen.dart
// Splash — continue vers l'accueil même si le modèle est absent

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/services/tflite_loader.dart';
import '../../core/router/route_names.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _textController;
  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;
  late Animation<double> _textOpacity;
  late Animation<Offset> _textSlide;

  @override
  void initState() {
    super.initState();

    _logoController = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    );
    _textController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _logoScale = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.elasticOut),
    );
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );
    _textOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurveTween(curve: Curves.easeOut).animate(_textController),
    );
    _textSlide = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeOutCubic),
    );

    _startSequence();
  }

  Future<void> _startSequence() async {
    await Future.delayed(const Duration(milliseconds: 200));
    _logoController.forward();

    await Future.delayed(const Duration(milliseconds: 500));
    _textController.forward();

    // Tentative chargement modèle — NON-BLOQUANT
    await ref.read(tfliteLoaderProvider.notifier).loadModel();

    // Délai minimum pour que l'animation soit visible
    await Future.delayed(const Duration(milliseconds: 800));

    if (mounted) context.goNamed(RouteNames.homeName);
  }

  @override
  void dispose() {
    _logoController.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final modelState = ref.watch(tfliteLoaderProvider);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.splashGradient),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Logo animé
                      AnimatedBuilder(
                        animation: _logoController,
                        builder: (context, child) => Opacity(
                          opacity: _logoOpacity.value,
                          child: Transform.scale(
                            scale: _logoScale.value,
                            child: child,
                          ),
                        ),
                        child: Container(
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(36),
                          ),
                          padding: const EdgeInsets.all(20),
                          child: Image.asset(
                            'assets/images/logo.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      // Nom + slogan
                      SlideTransition(
                        position: _textSlide,
                        child: FadeTransition(
                          opacity: _textOpacity,
                          child: Column(
                            children: [
                              Text(
                                'AgriSmart',
                                style: AppTextStyles.displayLarge.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Diagnostic intelligent des plantes',
                                style: AppTextStyles.bodyMedium.copyWith(
                                  color: Colors.white.withOpacity(0.8),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Statut chargement en bas
              Padding(
                padding: const EdgeInsets.only(bottom: 48),
                child: _LoadingStatus(state: modelState),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadingStatus extends StatelessWidget {
  const _LoadingStatus({required this.state});
  final ModelLoadState state;

  @override
  Widget build(BuildContext context) {
    switch (state) {
      case ModelLoadState.loading:
        return Column(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(
            width: 24, height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: Colors.white.withOpacity(0.8),
            ),
          ),
          const SizedBox(height: 12),
          Text('Chargement du modèle IA…',
              style: TextStyle(color: Colors.white.withOpacity(0.75),
                  fontSize: 15)),
        ]);

      case ModelLoadState.ready:
        return Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.check_circle_rounded,
              color: Colors.white.withOpacity(0.9), size: 26),
          const SizedBox(height: 8),
          Text('Modèle prêt',
              style: TextStyle(color: Colors.white.withOpacity(0.8),
                  fontSize: 15)),
        ]);

      // ✅ NON-BLOQUANT — affiche un avertissement mais continue
      case ModelLoadState.unavailable:
        return Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.warning_amber_rounded,
              color: Colors.amber[300], size: 26),
          const SizedBox(height: 8),
          Text('Modèle non disponible',
              style: TextStyle(color: Colors.amber[200], fontSize: 15)),
          const SizedBox(height: 4),
          Text('Le scanner sera activé à la livraison',
              style: TextStyle(
                  color: Colors.white.withOpacity(0.5), fontSize: 12)),
        ]);

      case ModelLoadState.error:
        return Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.info_outline_rounded,
              color: Colors.white.withOpacity(0.7), size: 24),
          const SizedBox(height: 8),
          Text('Démarrage sans modèle',
              style: TextStyle(color: Colors.white.withOpacity(0.65),
                  fontSize: 14)),
        ]);

      default:
        return const SizedBox(height: 48);
    }
  }
}