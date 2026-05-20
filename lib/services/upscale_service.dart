import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Serviço de Upscale de Imagens com IA
/// 
/// Suporta múltiplos backends:
/// - Replicate API (Real-ESRGAN, Waifu2x)
/// - DeepAI (Waifu2x)
/// - Local processing (futuro)
/// 
/// Otimizado para imagens de anime/manga
class UpscaleService {
  static final UpscaleService _instance = UpscaleService._internal();
  factory UpscaleService() => _instance;
  UpscaleService._internal();

  // API Keys (usuário configura nas settings)
  String? _replicateApiKey;
  String? _deepAiApiKey;
  
  // Cache de imagens upscaladas
  final Map<String, String> _cache = {};
  
  // Configurações
  UpscaleProvider _provider = UpscaleProvider.replicate;
  UpscaleModel _model = UpscaleModel.realEsrgan;
  int _scaleFactor = 2;
  bool _enabled = false;

  // Getters
  bool get isEnabled => _enabled;
  UpscaleProvider get provider => _provider;
  UpscaleModel get model => _model;
  int get scaleFactor => _scaleFactor;
  bool get hasApiKey => _getApiKey() != null;

  /// Inicializa o serviço carregando configurações
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _replicateApiKey = prefs.getString('upscale_replicate_key');
    _deepAiApiKey = prefs.getString('upscale_deepai_key');
    _enabled = prefs.getBool('upscale_enabled') ?? false;
    _scaleFactor = prefs.getInt('upscale_scale') ?? 2;
    
    final providerIndex = prefs.getInt('upscale_provider') ?? 0;
    _provider = UpscaleProvider.values[providerIndex.clamp(0, UpscaleProvider.values.length - 1)];
    
    final modelIndex = prefs.getInt('upscale_model') ?? 0;
    _model = UpscaleModel.values[modelIndex.clamp(0, UpscaleModel.values.length - 1)];
    
    debugPrint('[UpscaleService] Initialized - Provider: $_provider, Model: $_model, Enabled: $_enabled');
  }

  /// Salva configurações
  Future<void> saveSettings({
    String? replicateKey,
    String? deepAiKey,
    UpscaleProvider? provider,
    UpscaleModel? model,
    int? scale,
    bool? enabled,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    
    if (replicateKey != null) {
      _replicateApiKey = replicateKey;
      await prefs.setString('upscale_replicate_key', replicateKey);
    }
    if (deepAiKey != null) {
      _deepAiApiKey = deepAiKey;
      await prefs.setString('upscale_deepai_key', deepAiKey);
    }
    if (provider != null) {
      _provider = provider;
      await prefs.setInt('upscale_provider', provider.index);
    }
    if (model != null) {
      _model = model;
      await prefs.setInt('upscale_model', model.index);
    }
    if (scale != null) {
      _scaleFactor = scale;
      await prefs.setInt('upscale_scale', scale);
    }
    if (enabled != null) {
      _enabled = enabled;
      await prefs.setBool('upscale_enabled', enabled);
    }
  }

  String? _getApiKey() {
    switch (_provider) {
      case UpscaleProvider.replicate:
        return _replicateApiKey;
      case UpscaleProvider.deepAi:
        return _deepAiApiKey;
      case UpscaleProvider.local:
        return 'local'; // Não precisa de API key
    }
  }

  /// Faz upscale de uma imagem a partir de URL
  /// Retorna a URL da imagem upscalada ou a original se falhar
  Future<String> upscaleImageUrl(String imageUrl, {
    int? scale,
    UpscaleModel? model,
    Function(double)? onProgress,
  }) async {
    if (!_enabled) return imageUrl;
    
    // Verifica cache
    final cacheKey = '${imageUrl}_${scale ?? _scaleFactor}_${model ?? _model}';
    if (_cache.containsKey(cacheKey)) {
      debugPrint('[UpscaleService] Cache hit for: $imageUrl');
      return _cache[cacheKey]!;
    }

    try {
      onProgress?.call(0.1);
      
      String result;
      switch (_provider) {
        case UpscaleProvider.replicate:
          result = await _upscaleWithReplicate(imageUrl, scale ?? _scaleFactor, model ?? _model, onProgress);
          break;
        case UpscaleProvider.deepAi:
          result = await _upscaleWithDeepAi(imageUrl, onProgress);
          break;
        case UpscaleProvider.local:
          result = await _upscaleLocally(imageUrl, scale ?? _scaleFactor, onProgress);
          break;
      }
      
      // Salva no cache
      _cache[cacheKey] = result;
      onProgress?.call(1.0);
      
      return result;
    } catch (e) {
      debugPrint('[UpscaleService] Error: $e');
      return imageUrl; // Retorna original em caso de erro
    }
  }

  /// Upscale usando Replicate API (Real-ESRGAN ou Waifu2x)
  Future<String> _upscaleWithReplicate(
    String imageUrl, 
    int scale, 
    UpscaleModel model,
    Function(double)? onProgress,
  ) async {
    final apiKey = _replicateApiKey;
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('Replicate API key not configured');
    }

    onProgress?.call(0.2);

    // Seleciona o modelo correto
    String modelVersion;
    Map<String, dynamic> input;
    
    switch (model) {
      case UpscaleModel.realEsrgan:
        // Real-ESRGAN x4 plus (anime optimized)
        modelVersion = 'dadc8672d39e47b8e1c4b3c6e9d7f8e9a0f1b2c3'; // Exemplo - usar versão real
        input = {
          'image': imageUrl,
          'scale': scale,
          'face_enhance': false,
        };
        break;
      case UpscaleModel.waifu2x:
        // Waifu2x (específico para anime)
        modelVersion = 'waifu2x-model-version-id'; // Exemplo
        input = {
          'image': imageUrl,
          'scale': scale,
          'noise_level': 1,
        };
        break;
      case UpscaleModel.esrganAnime:
        // ESRGAN Anime específico
        modelVersion = 'esrgan-anime-version-id';
        input = {
          'image': imageUrl,
          'upscale': scale,
        };
        break;
    }

    // Cria a predição
    final createResponse = await http.post(
      Uri.parse('https://api.replicate.com/v1/predictions'),
      headers: {
        'Authorization': 'Token $apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'version': modelVersion,
        'input': input,
      }),
    );

    if (createResponse.statusCode != 201) {
      throw Exception('Failed to create prediction: ${createResponse.body}');
    }

    final createData = jsonDecode(createResponse.body);
    final predictionId = createData['id'];
    final getUrl = createData['urls']['get'];

    onProgress?.call(0.4);

    // Poll para resultado
    String? outputUrl;
    int attempts = 0;
    const maxAttempts = 60; // 60 segundos timeout

    while (outputUrl == null && attempts < maxAttempts) {
      await Future.delayed(const Duration(seconds: 1));
      attempts++;
      
      onProgress?.call(0.4 + (0.5 * attempts / maxAttempts));

      final statusResponse = await http.get(
        Uri.parse(getUrl),
        headers: {'Authorization': 'Token $apiKey'},
      );

      final statusData = jsonDecode(statusResponse.body);
      final status = statusData['status'];

      if (status == 'succeeded') {
        outputUrl = statusData['output'];
        if (outputUrl is List) {
          outputUrl = (statusData['output'] as List).first;
        }
      } else if (status == 'failed') {
        throw Exception('Prediction failed: ${statusData['error']}');
      }
    }

    if (outputUrl == null) {
      throw Exception('Timeout waiting for upscale result');
    }

    onProgress?.call(0.95);
    return outputUrl;
  }

  /// Upscale usando DeepAI Waifu2x API
  Future<String> _upscaleWithDeepAi(
    String imageUrl,
    Function(double)? onProgress,
  ) async {
    final apiKey = _deepAiApiKey;
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('DeepAI API key not configured');
    }

    onProgress?.call(0.3);

    final response = await http.post(
      Uri.parse('https://api.deepai.org/api/waifu2x'),
      headers: {
        'api-key': apiKey,
      },
      body: {
        'image': imageUrl,
      },
    );

    onProgress?.call(0.8);

    if (response.statusCode != 200) {
      throw Exception('DeepAI request failed: ${response.body}');
    }

    final data = jsonDecode(response.body);
    final outputUrl = data['output_url'];

    if (outputUrl == null) {
      throw Exception('No output URL in response');
    }

    return outputUrl;
  }

  /// Upscale local (placeholder - requer implementação com TFLite/ONNX)
  Future<String> _upscaleLocally(
    String imageUrl,
    int scale,
    Function(double)? onProgress,
  ) async {
    // Para implementação local, precisaríamos de:
    // 1. Baixar a imagem
    // 2. Converter para tensor
    // 3. Rodar modelo TFLite/ONNX
    // 4. Salvar resultado
    
    // Por enquanto, retorna a imagem original
    debugPrint('[UpscaleService] Local upscale not yet implemented');
    
    onProgress?.call(0.5);
    
    // Simula processamento
    await Future.delayed(const Duration(milliseconds: 500));
    
    onProgress?.call(1.0);
    return imageUrl;
  }

  /// Faz upscale de bytes de imagem
  Future<Uint8List> upscaleImageBytes(Uint8List imageBytes, {
    int? scale,
    UpscaleModel? model,
    Function(double)? onProgress,
  }) async {
    if (!_enabled) return imageBytes;

    try {
      // Salva temporariamente
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/temp_upscale_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await tempFile.writeAsBytes(imageBytes);

      // Por enquanto, para APIs baseadas em URL, precisaríamos fazer upload primeiro
      // Isso é um placeholder para implementação futura
      
      onProgress?.call(1.0);
      return imageBytes;
    } catch (e) {
      debugPrint('[UpscaleService] Error upscaling bytes: $e');
      return imageBytes;
    }
  }

  /// Limpa o cache
  void clearCache() {
    _cache.clear();
    debugPrint('[UpscaleService] Cache cleared');
  }

  /// Pré-carrega upscale para uma lista de URLs (background)
  Future<void> preloadUpscale(List<String> imageUrls) async {
    if (!_enabled || !hasApiKey) return;

    for (final url in imageUrls) {
      // Não espera, processa em background
      upscaleImageUrl(url).catchError((e) {
        debugPrint('[UpscaleService] Preload error for $url: $e');
        return url;
      });
      
      // Rate limiting
      await Future.delayed(const Duration(milliseconds: 500));
    }
  }
}

/// Provedores de upscale disponíveis
enum UpscaleProvider {
  replicate,
  deepAi,
  local,
}

extension UpscaleProviderExtension on UpscaleProvider {
  String get displayName {
    switch (this) {
      case UpscaleProvider.replicate:
        return 'Replicate (Cloud)';
      case UpscaleProvider.deepAi:
        return 'DeepAI (Cloud)';
      case UpscaleProvider.local:
        return 'Local (Device)';
    }
  }

  String get description {
    switch (this) {
      case UpscaleProvider.replicate:
        return 'Alta qualidade, múltiplos modelos disponíveis';
      case UpscaleProvider.deepAi:
        return 'Waifu2x otimizado para anime';
      case UpscaleProvider.local:
        return 'Gratuito, processa no dispositivo';
    }
  }

  bool get requiresApiKey {
    switch (this) {
      case UpscaleProvider.replicate:
      case UpscaleProvider.deepAi:
        return true;
      case UpscaleProvider.local:
        return false;
    }
  }
}

/// Modelos de upscale disponíveis
enum UpscaleModel {
  realEsrgan,
  waifu2x,
  esrganAnime,
}

extension UpscaleModelExtension on UpscaleModel {
  String get displayName {
    switch (this) {
      case UpscaleModel.realEsrgan:
        return 'Real-ESRGAN';
      case UpscaleModel.waifu2x:
        return 'Waifu2x';
      case UpscaleModel.esrganAnime:
        return 'ESRGAN Anime';
    }
  }

  String get description {
    switch (this) {
      case UpscaleModel.realEsrgan:
        return 'Melhor para fotos e ilustrações gerais';
      case UpscaleModel.waifu2x:
        return 'Especializado em anime e manga';
      case UpscaleModel.esrganAnime:
        return 'ESRGAN treinado em anime';
    }
  }
}
