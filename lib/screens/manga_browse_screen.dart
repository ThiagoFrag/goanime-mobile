import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/manga/extension_service.dart';
import '../services/manga/extension_models.dart';

/// Browse screen for managing manga extensions (Mihon-style)
class MangaBrowseScreen extends StatefulWidget {
  const MangaBrowseScreen({super.key});

  @override
  State<MangaBrowseScreen> createState() => _MangaBrowseScreenState();
}

class _MangaBrowseScreenState extends State<MangaBrowseScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ExtensionService _service = ExtensionService.instance;
  String _selectedLang = 'all';
  String _searchQuery = '';
  bool _initialized = false;

  final List<Map<String, String>> _languages = [
    {'code': 'all', 'name': 'Todos', 'flag': '🌐'},
    {'code': 'pt-br', 'name': 'Português', 'flag': '🇧🇷'},
    {'code': 'en', 'name': 'English', 'flag': '🇺🇸'},
    {'code': 'es', 'name': 'Español', 'flag': '🇪🇸'},
    {'code': 'ja', 'name': '日本語', 'flag': '🇯🇵'},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _initService();
  }

  Future<void> _initService() async {
    await _service.initialize();
    if (mounted) {
      setState(() => _initialized = true);
    }
    _service.addListener(_onServiceChanged);
  }

  void _onServiceChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _service.removeListener(_onServiceChanged);
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0D0D0D) : Colors.grey[100],
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        title: const Text('Fontes de Mangá'),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: theme.colorScheme.primary,
          labelColor: theme.colorScheme.primary,
          unselectedLabelColor: Colors.grey,
          tabs: [
            Tab(
              icon: const Icon(Icons.extension, size: 20),
              text: 'Instaladas (${_service.installedExtensions.length})',
            ),
            Tab(icon: const Icon(Icons.explore, size: 20), text: 'Navegar'),
            Tab(icon: const Icon(Icons.settings, size: 20), text: 'Repos'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _service.isLoading
                ? null
                : () => _service.refreshExtensions(),
          ),
        ],
      ),
      body: !_initialized
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildInstalledTab(),
                _buildBrowseTab(),
                _buildReposTab(),
              ],
            ),
    );
  }

  /// Tab 1: Installed Extensions
  Widget _buildInstalledTab() {
    final installed = _service.installedExtensionsList;
    final updates = _service.updatableExtensions;

    if (installed.isEmpty) {
      return _buildEmptyState(
        icon: Icons.extension_off,
        title: 'Nenhuma extensão instalada',
        subtitle: 'Vá para a aba "Navegar" para instalar fontes de mangá',
        action: ElevatedButton.icon(
          icon: const Icon(Icons.explore),
          label: const Text('Navegar'),
          onPressed: () => _tabController.animateTo(1),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Updates section
        if (updates.isNotEmpty) ...[
          _buildSectionHeader(
            'Atualizações disponíveis',
            trailing: TextButton(
              onPressed: () => _updateAll(updates),
              child: const Text('Atualizar todas'),
            ),
          ),
          const SizedBox(height: 8),
          ...updates.map((e) => _buildExtensionCard(e, showUpdate: true)),
          const SizedBox(height: 24),
        ],

        // Installed section
        _buildSectionHeader('Instaladas'),
        const SizedBox(height: 8),
        ...installed
            .where((e) => !updates.contains(e))
            .map((e) => _buildExtensionCard(e)),
      ],
    );
  }

  /// Tab 2: Browse Extensions
  Widget _buildBrowseTab() {
    final extensions = _getFilteredExtensions();

    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Buscar extensões...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
            ),
            onChanged: (value) => setState(() => _searchQuery = value),
          ),
        ),

        // Language filter
        SizedBox(
          height: 40,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _languages.length,
            itemBuilder: (context, index) {
              final lang = _languages[index];
              final isSelected = _selectedLang == lang['code'];
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  selected: isSelected,
                  label: Text('${lang['flag']} ${lang['name']}'),
                  onSelected: (selected) {
                    setState(() => _selectedLang = lang['code']!);
                  },
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 16),

        // Extensions grid
        Expanded(
          child: _service.isLoading
              ? const Center(child: CircularProgressIndicator())
              : extensions.isEmpty
              ? _buildEmptyState(
                  icon: Icons.search_off,
                  title: 'Nenhuma extensão encontrada',
                  subtitle: _searchQuery.isNotEmpty
                      ? 'Tente outro termo de busca'
                      : 'Adicione um repositório para ver extensões',
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.85,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: extensions.length,
                  itemBuilder: (context, index) {
                    return _buildExtensionGridItem(extensions[index]);
                  },
                ),
        ),
      ],
    );
  }

  /// Tab 3: Repository Management
  Widget _buildReposTab() {
    final repos = _service.repositories;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Info card
        Card(
          color: Theme.of(context).colorScheme.primaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Repositórios fornecem extensões de mangá. '
                    'O Keiyoushi é o repositório padrão da comunidade.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Add repository button
        OutlinedButton.icon(
          icon: const Icon(Icons.add),
          label: const Text('Adicionar Repositório'),
          onPressed: _showAddRepoDialog,
          style: OutlinedButton.styleFrom(padding: const EdgeInsets.all(16)),
        ),

        const SizedBox(height: 24),

        _buildSectionHeader('Repositórios (${repos.length})'),
        const SizedBox(height: 8),

        ...repos.map((repo) => _buildRepoCard(repo)),

        if (repos.isEmpty)
          _buildEmptyState(
            icon: Icons.folder_off,
            title: 'Nenhum repositório',
            subtitle: 'Adicione um repositório para baixar extensões',
          ),
      ],
    );
  }

  List<MangaExtension> _getFilteredExtensions() {
    var extensions = List<MangaExtension>.from(_service.availableExtensions);

    // Filter by language
    if (_selectedLang != 'all') {
      extensions = extensions
          .where(
            (e) =>
                e.lang.toLowerCase() == _selectedLang.toLowerCase() ||
                e.lang.toLowerCase().startsWith(_selectedLang.split('-')[0]),
          )
          .toList();
    }

    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      extensions = extensions
          .where(
            (e) =>
                e.name.toLowerCase().contains(query) ||
                e.pkg.toLowerCase().contains(query),
          )
          .toList();
    }

    // Sort: installed first, then by name
    extensions.sort((a, b) {
      if (a.isInstalled != b.isInstalled) {
        return a.isInstalled ? -1 : 1;
      }
      return a.name.compareTo(b.name);
    });

    return extensions;
  }

  Widget _buildSectionHeader(String title, {Widget? trailing}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        if (trailing != null) trailing,
      ],
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? action,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: TextStyle(color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[const SizedBox(height: 24), action],
          ],
        ),
      ),
    );
  }

  Widget _buildExtensionCard(MangaExtension ext, {bool showUpdate = false}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: _buildExtensionIcon(ext),
        title: Text(ext.name),
        subtitle: Text(
          '${ext.langFlag} ${ext.versionName}${ext.nsfw ? ' • 18+' : ''}',
        ),
        trailing: showUpdate
            ? ElevatedButton(
                onPressed: () => _updateExtension(ext),
                child: const Text('Atualizar'),
              )
            : IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _confirmUninstall(ext),
              ),
      ),
    );
  }

  Widget _buildExtensionGridItem(MangaExtension ext) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      clipBehavior: Clip.antiAlias,
      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      child: InkWell(
        onTap: () => _showExtensionDetails(ext),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Icon
            Expanded(
              child: Container(
                color: isDark ? const Color(0xFF2A2A2A) : Colors.grey[100],
                child: Center(child: _buildExtensionIcon(ext, size: 64)),
              ),
            ),
            // Info
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ext.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(ext.langFlag, style: const TextStyle(fontSize: 12)),
                      const SizedBox(width: 4),
                      Text(
                        ext.versionName,
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                      if (ext.nsfw) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            '18+',
                            style: TextStyle(color: Colors.white, fontSize: 10),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ext.isInstalled
                        ? OutlinedButton(
                            onPressed: () => _confirmUninstall(ext),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                            ),
                            child: const Text('Remover'),
                          )
                        : ElevatedButton(
                            onPressed: () => _installExtension(ext),
                            child: const Text('Instalar'),
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

  Widget _buildExtensionIcon(MangaExtension ext, {double size = 40}) {
    if (ext.iconUrl != null && ext.iconUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: CachedNetworkImage(
          imageUrl: ext.iconUrl!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          placeholder: (_, __) => _buildDefaultIcon(size),
          errorWidget: (_, __, ___) => _buildDefaultIcon(size),
        ),
      );
    }
    return _buildDefaultIcon(size);
  }

  Widget _buildDefaultIcon(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        Icons.menu_book,
        size: size * 0.5,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }

  Widget _buildRepoCard(ExtensionRepository repo) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primary,
          child: Text(
            repo.name.substring(0, 1).toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(repo.name),
        subtitle: Text(
          repo.url,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        trailing: repo.isDefault
            ? Chip(
                label: const Text('Padrão'),
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.primary.withOpacity(0.1),
              )
            : IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: () => _confirmRemoveRepo(repo),
              ),
      ),
    );
  }

  void _showAddRepoDialog() {
    final urlController = TextEditingController();
    final nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Adicionar Repositório'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: urlController,
              decoration: const InputDecoration(
                labelText: 'URL do repositório',
                hintText: 'https://..../index.min.json',
                prefixIcon: Icon(Icons.link),
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Nome (opcional)',
                prefixIcon: Icon(Icons.label_outline),
              ),
            ),
            const SizedBox(height: 16),
            // Quick add button for Keiyoushi
            OutlinedButton.icon(
              icon: const Icon(Icons.flash_on),
              label: const Text('Adicionar Keiyoushi'),
              onPressed: () {
                urlController.text =
                    'https://raw.githubusercontent.com/keiyoushi/extensions/repo/index.min.json';
                nameController.text = 'Keiyoushi';
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final url = urlController.text.trim();
              if (url.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Digite a URL do repositório')),
                );
                return;
              }

              Navigator.pop(context);

              final success = await _service.addRepository(
                url,
                name: nameController.text.trim().isNotEmpty
                    ? nameController.text.trim()
                    : null,
              );

              if (!success && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(_service.error ?? 'Erro ao adicionar'),
                    backgroundColor: Colors.red,
                  ),
                );
                _service.clearError();
              } else if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Repositório adicionado com sucesso!'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            child: const Text('Adicionar'),
          ),
        ],
      ),
    );
  }

  void _confirmRemoveRepo(ExtensionRepository repo) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remover Repositório'),
        content: Text(
          'Remover "${repo.name}"?\n\n'
          'As extensões deste repositório serão removidas.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(context);
              _service.removeRepository(repo);
            },
            child: const Text('Remover'),
          ),
        ],
      ),
    );
  }

  void _showExtensionDetails(MangaExtension ext) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  _buildExtensionIcon(ext, size: 64),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ext.name,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${ext.langFlag} ${ext.langDisplayName} • v${ext.versionName}',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: ext.isInstalled
                        ? OutlinedButton.icon(
                            icon: const Icon(Icons.delete_outline),
                            label: const Text('Desinstalar'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                            ),
                            onPressed: () {
                              Navigator.pop(context);
                              _confirmUninstall(ext);
                            },
                          )
                        : ElevatedButton.icon(
                            icon: const Icon(Icons.download),
                            label: const Text('Instalar'),
                            onPressed: () {
                              Navigator.pop(context);
                              _installExtension(ext);
                            },
                          ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Info
              _buildInfoRow('Pacote', ext.pkg),
              _buildInfoRow(
                'Versão',
                '${ext.versionName} (${ext.versionCode})',
              ),
              _buildInfoRow('Idioma', '${ext.langFlag} ${ext.langDisplayName}'),
              if (ext.nsfw) _buildInfoRow('Classificação', '🔞 Adulto'),
              if (ext.sources.isNotEmpty)
                _buildInfoRow(
                  'Fontes',
                  ext.sources.map((s) => s.name).join(', '),
                ),
              if (ext.description != null)
                _buildInfoRow('Descrição', ext.description!),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Future<void> _installExtension(MangaExtension ext) async {
    final success = await _service.installExtension(ext);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? '${ext.name} instalada com sucesso!'
                : 'Erro ao instalar ${ext.name}',
          ),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  void _confirmUninstall(MangaExtension ext) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Desinstalar Extensão'),
        content: Text('Remover "${ext.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(context);
              await _service.uninstallExtension(ext);
              if (mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('${ext.name} removida')));
              }
            },
            child: const Text('Remover'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateExtension(MangaExtension ext) async {
    final success = await _service.updateExtension(ext);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? '${ext.name} atualizada!'
                : 'Erro ao atualizar ${ext.name}',
          ),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  Future<void> _updateAll(List<MangaExtension> extensions) async {
    for (final ext in extensions) {
      await _service.updateExtension(ext);
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Todas as extensões foram atualizadas!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }
}
