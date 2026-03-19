// lib/data/remote/api_client.dart
// Client API FastAPI — Offline-First
// TFLite toujours en premier, API enrichit si connecté

import 'dart:io';
import 'package:dio/dio.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ── Modèle réponse API ────────────────────────────────────────────
class ApiDiagnosticResult {
  const ApiDiagnosticResult({
    required this.classe,
    required this.confiance,
    required this.conseil,
    this.prixFcfa,
    this.produitLocal,
    this.description,
  });

  final String classe;
  final double confiance;
  final String conseil;
  final String? prixFcfa;       // ex: "2 500 – 4 000 FCFA"
  final String? produitLocal;   // ex: "Fungitop disponible à Lomé"
  final String? description;    // description courte de la maladie

  factory ApiDiagnosticResult.fromJson(Map<String, dynamic> json) {
    return ApiDiagnosticResult(
      classe:       json['classe']       as String,
      confiance:    (json['confiance']   as num).toDouble(),
      conseil:      json['conseil']      as String,
      prixFcfa:     json['prix_fcfa']    as String?,
      produitLocal: json['produit_local'] as String?,
      description:  json['description'] as String?,
    );
  }
}

// ── Client Dio ────────────────────────────────────────────────────
class AgriSmartApiClient {
  AgriSmartApiClient({required this.baseUrl});

  final String baseUrl;

  late final Dio _dio = Dio(BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 15),
    headers: {'Accept': 'application/json'},
  ));

  /// Envoyer une image au endpoint /predict
  /// Retourne null si offline ou timeout → l'app utilise TFLite local
  Future<ApiDiagnosticResult?> predict(File imageFile) async {
    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          imageFile.path,
          filename: 'scan.jpg',
        ),
      });

      final response = await _dio.post<Map<String, dynamic>>(
        '/predict',
        data: formData,
      );

      if (response.statusCode == 200 && response.data != null) {
        return ApiDiagnosticResult.fromJson(response.data!);
      }
      return null;
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.connectionError) {
        // Offline ou serveur injoignable → silent fail
        return null;
      }
      rethrow;
    } catch (e) {
      return null;
    }
  }
}

// ── Provider ──────────────────────────────────────────────────────
final apiClientProvider = Provider<AgriSmartApiClient>((ref) {
  return AgriSmartApiClient(
    // 🔧 Changer cette IP pour pointer vers ton serveur FastAPI
    // Dev local Android : 10.0.2.2 (émulateur) ou IP WiFi du PC
    baseUrl: 'http://192.168.1.100:8000',
  );
});

// ── Service Offline-First ─────────────────────────────────────────
class DiagnosticService {
  DiagnosticService(this._apiClient);
  final AgriSmartApiClient _apiClient;

  /// Stratégie :
  /// 1. TFLite local → résultat immédiat (offline garanti)
  /// 2. API en arrière-plan si connecté → enrichit le résultat
  Future<bool> isConnected() async {
    final result = await Connectivity().checkConnectivity();
    return result != ConnectivityResult.none;
  }

  Future<ApiDiagnosticResult?> enrichWithApi(File imageFile) async {
    if (!await isConnected()) return null;
    return _apiClient.predict(imageFile);
  }
}

final diagnosticServiceProvider = Provider<DiagnosticService>((ref) {
  return DiagnosticService(ref.read(apiClientProvider));
});