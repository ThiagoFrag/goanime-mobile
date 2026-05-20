import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'extension_models.dart';

/// Service for managing manga extension repositories (Mihon-style)
class ExtensionService extends ChangeNotifier {
  static ExtensionService? _instance;
  static const String _reposKey = 'extension_repositories';
  static const String _installedKey = 'installed_extensions';
  static const String _enabledSourcesKey = 'enabled_sources';

  final List<ExtensionRepository> _repositories = [];
  final List<MangaExtension> _availableExtensions = [];
  final Map<String, InstalledExtension> _installedExtensions = {};
  final Set<String> _enabledSources = {};
  bool _isLoading = false;
  String? _error;

  // Default repositories
  static const List<ExtensionRepository> _defaultRepos = [
    ExtensionRepository(
      name: 'Keiyoushi',
      url:
          'https://raw.githubusercontent.com/keiyoushi/extensions/repo/index.min.json',
      isDefault: true,
    ),
  ];

  // Built-in sources (always available)
  static const List<String> _builtInSources = ['mangalivre.blog', 'mangadex'];

  ExtensionService._();

  /// Get singleton instance
  static ExtensionService get instance {
    _instance ??= ExtensionService._();
    return _instance!;
  }

  // Getters
  List<ExtensionRepository> get repositories =>
      List.unmodifiable(_repositories);
  List<MangaExtension> get availableExtensions =>
      List.unmodifiable(_availableExtensions);
  Map<String, InstalledExtension> get installedExtensions =>
      Map.unmodifiable(_installedExtensions);
  Set<String> get enabledSources => Set.unmodifiable(_enabledSources);
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Get extensions filtered by language
  List<MangaExtension> getExtensionsByLang(String lang) {
    if (lang == 'all') return _availableExtensions;
    return _availableExtensions
        .where((e) => e.lang.toLowerCase() == lang.toLowerCase())
        .toList();
  }

  /// Get installed extensions
  List<MangaExtension> get installedExtensionsList {
    return _availableExtensions
        .where((e) => _installedExtensions.containsKey(e.id))
        .map((e) => e.copyWith(isInstalled: true))
        .toList();
  }

  /// Get extensions with updates available
  List<MangaExtension> get updatableExtensions {
    return _availableExtensions.where((e) {
      final installed = _installedExtensions[e.id];
      if (installed == null) return false;
      return e.versionCode > installed.versionCode;
    }).toList();
  }

  /// Get available languages
  Set<String> get availableLanguages {
    return _availableExtensions.map((e) => e.lang.toLowerCase()).toSet();
  }

  /// Initialize service
  Future<void> initialize() async {
    await _loadFromStorage();

    // Add default repos if none exist
    if (_repositories.isEmpty) {
      _repositories.addAll(_defaultRepos);
      await _saveRepositories();
    }

    // Enable built-in sources by default
    for (final source in _builtInSources) {
      if (!_enabledSources.contains(source)) {
        _enabledSources.add(source);
      }
    }
    await _saveEnabledSources();

    // Fetch extensions from repositories
    await refreshExtensions();
  }

  /// Load data from storage
  Future<void> _loadFromStorage() async {
    final prefs = await SharedPreferences.getInstance();

    // Load repositories
    final reposJson = prefs.getString(_reposKey);
    if (reposJson != null) {
      try {
        final list = jsonDecode(reposJson) as List;
        _repositories.clear();
        _repositories.addAll(list.map((r) => ExtensionRepository.fromJson(r)));
      } catch (e) {
        debugPrint('[ExtensionService] Error loading repos: $e');
      }
    }

    // Load installed extensions
    final installedJson = prefs.getString(_installedKey);
    if (installedJson != null) {
      try {
        final map = jsonDecode(installedJson) as Map<String, dynamic>;
        _installedExtensions.clear();
        map.forEach((key, value) {
          _installedExtensions[key] = InstalledExtension.fromJson(value);
        });
      } catch (e) {
        debugPrint('[ExtensionService] Error loading installed: $e');
      }
    }

    // Load enabled sources
    final enabledJson = prefs.getStringList(_enabledSourcesKey);
    if (enabledJson != null) {
      _enabledSources.clear();
      _enabledSources.addAll(enabledJson);
    }
  }

  /// Save repositories to storage
  Future<void> _saveRepositories() async {
    final prefs = await SharedPreferences.getInstance();
    final json = jsonEncode(_repositories.map((r) => r.toJson()).toList());
    await prefs.setString(_reposKey, json);
  }

  /// Save installed extensions to storage
  Future<void> _saveInstalled() async {
    final prefs = await SharedPreferences.getInstance();
    final map = <String, dynamic>{};
    _installedExtensions.forEach((key, value) {
      map[key] = value.toJson();
    });
    await prefs.setString(_installedKey, jsonEncode(map));
  }

  /// Save enabled sources to storage
  Future<void> _saveEnabledSources() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_enabledSourcesKey, _enabledSources.toList());
  }

  /// Add a new repository
  Future<bool> addRepository(String url, {String? name}) async {
    // Validate URL
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      _error = 'URL inválida. Use http:// ou https://';
      notifyListeners();
      return false;
    }

    // Check if already exists
    if (_repositories.any((r) => r.url == url)) {
      _error = 'Repositório já adicionado';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Try to fetch and validate the repository
      final index = await _fetchRepositoryIndex(url);
      if (index.extensions.isEmpty) {
        _error = 'Repositório vazio ou formato inválido';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final repo = ExtensionRepository(
        name: name ?? index.repoName ?? _extractRepoName(url),
        url: url,
        addedAt: DateTime.now(),
      );

      _repositories.add(repo);
      await _saveRepositories();

      // Add extensions from this repo
      _availableExtensions.addAll(index.extensions);

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Erro ao adicionar repositório: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Remove a repository
  Future<void> removeRepository(ExtensionRepository repo) async {
    if (repo.isDefault) {
      _error = 'Não é possível remover o repositório padrão';
      notifyListeners();
      return;
    }

    _repositories.remove(repo);

    // Remove extensions from this repo
    _availableExtensions.removeWhere((e) => e.sourceUrl == repo.url);

    // Uninstall extensions from this repo
    final toRemove = _installedExtensions.entries
        .where((e) => e.value.sourceUrl == repo.url)
        .map((e) => e.key)
        .toList();
    for (final id in toRemove) {
      _installedExtensions.remove(id);
    }

    await _saveRepositories();
    await _saveInstalled();
    notifyListeners();
  }

  /// Refresh extensions from all repositories
  Future<void> refreshExtensions() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    _availableExtensions.clear();

    for (final repo in _repositories) {
      try {
        final index = await _fetchRepositoryIndex(repo.url);
        _availableExtensions.addAll(index.extensions);
        debugPrint(
          '[ExtensionService] Loaded ${index.extensions.length} extensions from ${repo.name}',
        );
      } catch (e) {
        debugPrint('[ExtensionService] Error fetching ${repo.name}: $e');
      }
    }

    // Mark installed extensions
    _updateInstalledStatus();

    _isLoading = false;
    notifyListeners();
  }

  /// Fetch index from a repository URL
  Future<ExtensionIndex> _fetchRepositoryIndex(String url) async {
    final response = await http
        .get(
          Uri.parse(url),
          headers: {'User-Agent': 'GoMang/1.0', 'Accept': 'application/json'},
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}');
    }

    final json = jsonDecode(response.body);
    return ExtensionIndex.fromJson(
      json,
      sourceUrl: url,
      repoName: _extractRepoName(url),
    );
  }

  /// Extract repository name from URL
  String _extractRepoName(String url) {
    try {
      final uri = Uri.parse(url);
      final parts = uri.pathSegments;
      if (parts.length >= 2) {
        return parts[1]; // Usually the repo name on GitHub
      }
      return uri.host;
    } catch (_) {
      return 'Unknown';
    }
  }

  /// Update installed status on available extensions
  void _updateInstalledStatus() {
    for (int i = 0; i < _availableExtensions.length; i++) {
      final ext = _availableExtensions[i];
      final installed = _installedExtensions[ext.id];
      _availableExtensions[i] = ext.copyWith(
        isInstalled: installed != null,
        hasUpdate: installed != null && ext.versionCode > installed.versionCode,
      );
    }
  }

  /// Install an extension
  Future<bool> installExtension(MangaExtension extension) async {
    try {
      final installed = InstalledExtension(
        id: extension.id,
        name: extension.name,
        pkg: extension.pkg,
        versionCode: extension.versionCode,
        sourceUrl: extension.sourceUrl,
        installedAt: DateTime.now(),
        enabled: true,
      );

      _installedExtensions[extension.id] = installed;

      // Enable all sources from this extension
      for (final source in extension.sources) {
        _enabledSources.add(source.id);
      }
      // Also enable by extension id/pkg
      _enabledSources.add(extension.id);
      _enabledSources.add(extension.pkg);

      await _saveInstalled();
      await _saveEnabledSources();
      _updateInstalledStatus();
      notifyListeners();

      debugPrint('[ExtensionService] Installed: ${extension.name}');
      return true;
    } catch (e) {
      debugPrint('[ExtensionService] Install error: $e');
      return false;
    }
  }

  /// Uninstall an extension
  Future<bool> uninstallExtension(MangaExtension extension) async {
    try {
      _installedExtensions.remove(extension.id);

      // Disable sources from this extension
      for (final source in extension.sources) {
        _enabledSources.remove(source.id);
      }
      _enabledSources.remove(extension.id);
      _enabledSources.remove(extension.pkg);

      await _saveInstalled();
      await _saveEnabledSources();
      _updateInstalledStatus();
      notifyListeners();

      debugPrint('[ExtensionService] Uninstalled: ${extension.name}');
      return true;
    } catch (e) {
      debugPrint('[ExtensionService] Uninstall error: $e');
      return false;
    }
  }

  /// Update an extension
  Future<bool> updateExtension(MangaExtension extension) async {
    // Just reinstall with new version
    return installExtension(extension);
  }

  /// Toggle source enabled/disabled
  void toggleSource(String sourceId, bool enabled) {
    if (enabled) {
      _enabledSources.add(sourceId);
    } else {
      _enabledSources.remove(sourceId);
    }
    _saveEnabledSources();
    notifyListeners();
  }

  /// Check if a source is enabled
  bool isSourceEnabled(String sourceId) {
    return _enabledSources.contains(sourceId) ||
        _builtInSources.contains(sourceId);
  }

  /// Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
