import 'package:flutter/material.dart';
import '../services/animedrive_service.dart';

/// Bottom sheet para seleção de qualidade de vídeo
/// Exibe todas as opções disponíveis (Mobile, HD, FullHD, FHD)
class QualitySelectorSheet extends StatefulWidget {
  final List<VideoOption> options;
  final VideoOption? selectedOption;
  final Function(VideoOption) onSelect;
  final bool isLoading;

  const QualitySelectorSheet({
    super.key,
    required this.options,
    required this.onSelect,
    this.selectedOption,
    this.isLoading = false,
  });

  /// Mostra o bottom sheet de seleção
  static Future<VideoOption?> show({
    required BuildContext context,
    required List<VideoOption> options,
    VideoOption? selectedOption,
  }) async {
    return showModalBottomSheet<VideoOption>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => QualitySelectorSheet(
        options: options,
        selectedOption: selectedOption,
        onSelect: (option) => Navigator.of(context).pop(option),
      ),
    );
  }

  @override
  State<QualitySelectorSheet> createState() => _QualitySelectorSheetState();
}

class _QualitySelectorSheetState extends State<QualitySelectorSheet> {
  int? _loadingIndex;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[700],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Title
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(
                  Icons.high_quality,
                  color: Colors.pinkAccent,
                  size: 28,
                ),
                const SizedBox(width: 12),
                const Text(
                  'Qualidade do Vídeo',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.grey),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          const Divider(color: Colors.grey, height: 1),

          // Options list
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: widget.options.length,
            itemBuilder: (context, index) {
              final option = widget.options[index];
              final isSelected =
                  widget.selectedOption?.serverIndex == option.serverIndex;
              final isLoading = _loadingIndex == index;

              return _buildOptionTile(option, isSelected, isLoading, index);
            },
          ),

          // Auto quality option
          _buildAutoQualityTile(),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildOptionTile(
    VideoOption option,
    bool isSelected,
    bool isLoading,
    int index,
  ) {
    return ListTile(
      leading: Container(
        width: 50,
        height: 30,
        decoration: BoxDecoration(
          gradient: _getQualityGradient(option.quality),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Center(
          child: Text(
            option.quality.badge.isNotEmpty ? option.quality.badge : 'SD',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
      title: Text(
        option.label,
        style: TextStyle(
          color: isSelected ? Colors.pinkAccent : Colors.white,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      subtitle: Text(
        _getQualityDescription(option.quality),
        style: TextStyle(color: Colors.grey[500], fontSize: 12),
      ),
      trailing: isLoading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.pinkAccent,
              ),
            )
          : isSelected
          ? const Icon(Icons.check_circle, color: Colors.pinkAccent)
          : const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: isLoading
          ? null
          : () async {
              setState(() => _loadingIndex = index);
              widget.onSelect(option);
            },
    );
  }

  Widget _buildAutoQualityTile() {
    return ListTile(
      leading: Container(
        width: 50,
        height: 30,
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Colors.green, Colors.teal]),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Center(
          child: Icon(Icons.auto_awesome, color: Colors.white, size: 16),
        ),
      ),
      title: const Text(
        'Auto (Melhor Disponível)',
        style: TextStyle(color: Colors.white),
      ),
      subtitle: Text(
        'Seleciona automaticamente a melhor qualidade',
        style: TextStyle(color: Colors.grey[500], fontSize: 12),
      ),
      trailing: widget.selectedOption == null
          ? const Icon(Icons.check_circle, color: Colors.green)
          : const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: () => Navigator.of(context).pop(),
    );
  }

  LinearGradient _getQualityGradient(VideoQuality quality) {
    switch (quality) {
      case VideoQuality.fhd:
      case VideoQuality.fullHd:
        return const LinearGradient(colors: [Colors.purple, Colors.deepPurple]);
      case VideoQuality.hd:
        return const LinearGradient(colors: [Colors.blue, Colors.indigo]);
      case VideoQuality.sd:
        return const LinearGradient(colors: [Colors.teal, Colors.cyan]);
      case VideoQuality.mobile:
        return const LinearGradient(colors: [Colors.orange, Colors.deepOrange]);
      case VideoQuality.unknown:
        return const LinearGradient(colors: [Colors.grey, Colors.blueGrey]);
    }
  }

  String _getQualityDescription(VideoQuality quality) {
    switch (quality) {
      case VideoQuality.fhd:
      case VideoQuality.fullHd:
        return '1080p • Melhor qualidade';
      case VideoQuality.hd:
        return '720p • Boa qualidade';
      case VideoQuality.sd:
        return '480p • Qualidade padrão';
      case VideoQuality.mobile:
        return '360p • Economiza dados';
      case VideoQuality.unknown:
        return 'Qualidade variável';
    }
  }
}

/// Widget compacto para exibir qualidade atual no player
class QualityBadge extends StatelessWidget {
  final VideoQuality? quality;
  final VoidCallback? onTap;

  const QualityBadge({super.key, this.quality, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: _getQualityColor(quality ?? VideoQuality.unknown),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              quality?.badge ?? 'AUTO',
              style: TextStyle(
                color: _getQualityColor(quality ?? VideoQuality.unknown),
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.arrow_drop_down,
              color: _getQualityColor(quality ?? VideoQuality.unknown),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Color _getQualityColor(VideoQuality quality) {
    switch (quality) {
      case VideoQuality.fhd:
      case VideoQuality.fullHd:
        return Colors.purpleAccent;
      case VideoQuality.hd:
        return Colors.blueAccent;
      case VideoQuality.sd:
        return Colors.tealAccent;
      case VideoQuality.mobile:
        return Colors.orangeAccent;
      case VideoQuality.unknown:
        return Colors.grey;
    }
  }
}
