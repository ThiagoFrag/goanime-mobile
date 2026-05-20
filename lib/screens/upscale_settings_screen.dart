import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../services/upscale_service.dart';
import '../theme/app_colors.dart';

/// Tela de configurações do Upscale IA
class UpscaleSettingsScreen extends StatefulWidget {
  const UpscaleSettingsScreen({super.key});

  @override
  State<UpscaleSettingsScreen> createState() => _UpscaleSettingsScreenState();
}

class _UpscaleSettingsScreenState extends State<UpscaleSettingsScreen> {
  final UpscaleService _upscaleService = UpscaleService();
  
  final _replicateKeyController = TextEditingController();
  final _deepAiKeyController = TextEditingController();
  
  bool _isLoading = true;
  bool _enabled = false;
  UpscaleProvider _selectedProvider = UpscaleProvider.replicate;
  UpscaleModel _selectedModel = UpscaleModel.waifu2x;
  int _scaleFactor = 2;
  bool _showApiKey = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _replicateKeyController.dispose();
    _deepAiKeyController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    await _upscaleService.initialize();
    
    if (mounted) {
      setState(() {
        _enabled = _upscaleService.isEnabled;
        _selectedProvider = _upscaleService.provider;
        _selectedModel = _upscaleService.model;
        _scaleFactor = _upscaleService.scaleFactor;
        _isLoading = false;
      });
    }
  }

  Future<void> _saveSettings() async {
    await _upscaleService.saveSettings(
      enabled: _enabled,
      provider: _selectedProvider,
      model: _selectedModel,
      scale: _scaleFactor,
      replicateKey: _replicateKeyController.text.isNotEmpty 
          ? _replicateKeyController.text 
          : null,
      deepAiKey: _deepAiKeyController.text.isNotEmpty 
          ? _deepAiKeyController.text 
          : null,
    );
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Text('Configurações salvas'),
            ],
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.sparkles, color: AppColors.primary, size: 22),
            SizedBox(width: 8),
            Text(
              'Upscale IA',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _saveSettings,
            child: const Text(
              'Salvar',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header info
                  _buildInfoCard(),
                  const SizedBox(height: 24),
                  
                  // Enable toggle
                  _buildEnableToggle(),
                  const SizedBox(height: 24),
                  
                  // Provider selection
                  _buildProviderSection(),
                  const SizedBox(height: 24),
                  
                  // Model selection
                  if (_selectedProvider != UpscaleProvider.deepAi)
                    _buildModelSection(),
                  
                  // API Key input
                  if (_selectedProvider.requiresApiKey)
                    _buildApiKeySection(),
                  
                  // Scale factor
                  _buildScaleSection(),
                  const SizedBox(height: 24),
                  
                  // Clear cache button
                  _buildClearCacheButton(),
                  const SizedBox(height: 32),
                  
                  // Links de ajuda
                  _buildHelpLinks(),
                ],
              ),
            ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.2),
            AppColors.secondary.withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(LucideIcons.info, color: AppColors.primary, size: 20),
              SizedBox(width: 8),
              Text(
                'O que é Upscale IA?',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Upscale IA usa inteligência artificial para melhorar a qualidade das imagens de anime. '
            'Algoritmos como Waifu2x e Real-ESRGAN foram treinados especificamente para preservar '
            'traços e cores de ilustrações.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnableToggle() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _enabled 
                  ? AppColors.primary.withValues(alpha: 0.2)
                  : Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              LucideIcons.wand2,
              color: _enabled ? AppColors.primary : Colors.white38,
              size: 22,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Ativar Upscale IA',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  _enabled 
                      ? 'Imagens serão melhoradas automaticamente'
                      : 'Imagens serão exibidas na qualidade original',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _enabled,
            onChanged: (value) => setState(() => _enabled = value),
            activeColor: AppColors.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildProviderSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Provedor',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ...UpscaleProvider.values.map((provider) => _buildProviderTile(provider)),
      ],
    );
  }

  Widget _buildProviderTile(UpscaleProvider provider) {
    final isSelected = _selectedProvider == provider;
    
    return GestureDetector(
      onTap: () => setState(() => _selectedProvider = provider),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected 
              ? AppColors.primary.withValues(alpha: 0.15)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected 
                ? AppColors.primary 
                : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: isSelected ? AppColors.primary : Colors.white38,
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        provider.displayName,
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.white70,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (provider == UpscaleProvider.local) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.success.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'GRÁTIS',
                            style: TextStyle(
                              color: AppColors.success,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    provider.description,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModelSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Modelo de IA',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: UpscaleModel.values.map((model) {
              final isSelected = _selectedModel == model;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedModel = model),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        Text(
                          model.displayName,
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.white54,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _selectedModel.description,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildApiKeySection() {
    final controller = _selectedProvider == UpscaleProvider.replicate
        ? _replicateKeyController
        : _deepAiKeyController;
    
    final providerName = _selectedProvider == UpscaleProvider.replicate
        ? 'Replicate'
        : 'DeepAI';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'API Key ($providerName)',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: TextField(
            controller: controller,
            obscureText: !_showApiKey,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Cole sua API key aqui',
              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(16),
              prefixIcon: const Icon(LucideIcons.key, color: Colors.white38),
              suffixIcon: IconButton(
                icon: Icon(
                  _showApiKey ? LucideIcons.eyeOff : LucideIcons.eye,
                  color: Colors.white38,
                ),
                onPressed: () => setState(() => _showApiKey = !_showApiKey),
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildScaleSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Fator de Escala',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${_scaleFactor}x',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: AppColors.primary,
            inactiveTrackColor: AppColors.surface,
            thumbColor: AppColors.primary,
            overlayColor: AppColors.primary.withValues(alpha: 0.2),
          ),
          child: Slider(
            value: _scaleFactor.toDouble(),
            min: 2,
            max: 4,
            divisions: 2,
            onChanged: (value) => setState(() => _scaleFactor = value.toInt()),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '2x (Rápido)',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 11,
              ),
            ),
            Text(
              '4x (Máxima qualidade)',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildClearCacheButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () {
          _upscaleService.clearCache();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Cache limpo'),
              backgroundColor: AppColors.surface,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        },
        icon: const Icon(LucideIcons.trash2, size: 18),
        label: const Text('Limpar Cache de Imagens'),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white54,
          side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _buildHelpLinks() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Onde conseguir API Keys?',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        _buildLinkTile(
          'Replicate',
          'replicate.com',
          'Crie conta gratuita e gere sua API key',
        ),
        _buildLinkTile(
          'DeepAI',
          'deepai.org',
          'API gratuita com limite mensal',
        ),
      ],
    );
  }

  Widget _buildLinkTile(String title, String url, String description) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(LucideIcons.externalLink, color: Colors.white38, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  description,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Text(
            url,
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
