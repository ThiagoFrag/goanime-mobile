/// Models for manga extension system (Mihon-style)
library;

/// Information about an extension repository
class ExtensionRepository {
  final String name;
  final String url;
  final bool isDefault;
  final DateTime? addedAt;

  const ExtensionRepository({
    required this.name,
    required this.url,
    this.isDefault = false,
    this.addedAt,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'url': url,
    'isDefault': isDefault,
    'addedAt': addedAt?.toIso8601String(),
  };

  factory ExtensionRepository.fromJson(Map<String, dynamic> json) =>
      ExtensionRepository(
        name: json['name'] ?? 'Unknown',
        url: json['url'] ?? '',
        isDefault: json['isDefault'] ?? false,
        addedAt: json['addedAt'] != null
            ? DateTime.tryParse(json['addedAt'])
            : null,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExtensionRepository &&
          runtimeType == other.runtimeType &&
          url == other.url;

  @override
  int get hashCode => url.hashCode;
}

/// Information about a manga extension/source
class MangaExtension {
  final String id;
  final String name;
  final String pkg;
  final String versionName;
  final int versionCode;
  final String lang;
  final bool nsfw;
  final String? iconUrl;
  final String? apkUrl; // For Android APK-based extensions
  final String sourceUrl; // Repository URL this came from
  final List<ExtensionSource> sources;
  final bool isInstalled;
  final bool hasUpdate;
  final bool isObsolete;
  final String? description;

  const MangaExtension({
    required this.id,
    required this.name,
    required this.pkg,
    required this.versionName,
    required this.versionCode,
    required this.lang,
    this.nsfw = false,
    this.iconUrl,
    this.apkUrl,
    required this.sourceUrl,
    this.sources = const [],
    this.isInstalled = false,
    this.hasUpdate = false,
    this.isObsolete = false,
    this.description,
  });

  MangaExtension copyWith({
    String? id,
    String? name,
    String? pkg,
    String? versionName,
    int? versionCode,
    String? lang,
    bool? nsfw,
    String? iconUrl,
    String? apkUrl,
    String? sourceUrl,
    List<ExtensionSource>? sources,
    bool? isInstalled,
    bool? hasUpdate,
    bool? isObsolete,
    String? description,
  }) => MangaExtension(
    id: id ?? this.id,
    name: name ?? this.name,
    pkg: pkg ?? this.pkg,
    versionName: versionName ?? this.versionName,
    versionCode: versionCode ?? this.versionCode,
    lang: lang ?? this.lang,
    nsfw: nsfw ?? this.nsfw,
    iconUrl: iconUrl ?? this.iconUrl,
    apkUrl: apkUrl ?? this.apkUrl,
    sourceUrl: sourceUrl ?? this.sourceUrl,
    sources: sources ?? this.sources,
    isInstalled: isInstalled ?? this.isInstalled,
    hasUpdate: hasUpdate ?? this.hasUpdate,
    isObsolete: isObsolete ?? this.isObsolete,
    description: description ?? this.description,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'pkg': pkg,
    'versionName': versionName,
    'versionCode': versionCode,
    'lang': lang,
    'nsfw': nsfw,
    'iconUrl': iconUrl,
    'apkUrl': apkUrl,
    'sourceUrl': sourceUrl,
    'sources': sources.map((s) => s.toJson()).toList(),
    'isInstalled': isInstalled,
    'hasUpdate': hasUpdate,
    'isObsolete': isObsolete,
    'description': description,
  };

  factory MangaExtension.fromJson(Map<String, dynamic> json) => MangaExtension(
    id: json['id'] ?? json['pkg'] ?? '',
    name: json['name'] ?? '',
    pkg: json['pkg'] ?? '',
    versionName: json['versionName'] ?? json['version'] ?? '1.0',
    versionCode: json['versionCode'] ?? 1,
    lang: json['lang'] ?? 'all',
    nsfw: _parseBool(json['nsfw']),
    iconUrl: json['iconUrl'] ?? json['icon'],
    apkUrl: json['apkUrl'] ?? json['apk'],
    sourceUrl: json['sourceUrl'] ?? '',
    sources:
        (json['sources'] as List?)
            ?.map((s) => ExtensionSource.fromJson(s))
            .toList() ??
        [],
    isInstalled: _parseBool(json['isInstalled']),
    hasUpdate: _parseBool(json['hasUpdate']),
    isObsolete: _parseBool(json['isObsolete']),
    description: json['description'],
  );

  /// Parse bool from various types (bool, int, string)
  static bool _parseBool(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is int) return value != 0;
    if (value is String) return value.toLowerCase() == 'true' || value == '1';
    return false;
  }

  /// Language display name
  String get langDisplayName {
    switch (lang.toLowerCase()) {
      case 'pt':
      case 'pt-br':
        return 'Português';
      case 'en':
        return 'English';
      case 'es':
        return 'Español';
      case 'ja':
        return '日本語';
      case 'ko':
        return '한국어';
      case 'zh':
        return '中文';
      case 'all':
        return 'Multi';
      default:
        return lang.toUpperCase();
    }
  }

  /// Flag emoji for language
  String get langFlag {
    switch (lang.toLowerCase()) {
      case 'pt':
      case 'pt-br':
        return '🇧🇷';
      case 'en':
        return '🇺🇸';
      case 'es':
        return '🇪🇸';
      case 'ja':
        return '🇯🇵';
      case 'ko':
        return '🇰🇷';
      case 'zh':
        return '🇨🇳';
      case 'all':
        return '🌐';
      default:
        return '🏳️';
    }
  }
}

/// A source within an extension
class ExtensionSource {
  final String id;
  final String name;
  final String lang;
  final String baseUrl;
  final bool nsfw;

  const ExtensionSource({
    required this.id,
    required this.name,
    required this.lang,
    required this.baseUrl,
    this.nsfw = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'lang': lang,
    'baseUrl': baseUrl,
    'nsfw': nsfw,
  };

  factory ExtensionSource.fromJson(Map<String, dynamic> json) =>
      ExtensionSource(
        id: json['id'] ?? '',
        name: json['name'] ?? '',
        lang: json['lang'] ?? 'all',
        baseUrl: json['baseUrl'] ?? '',
        nsfw: json['nsfw'] ?? false,
      );
}

/// Index response from a repository
class ExtensionIndex {
  final List<MangaExtension> extensions;
  final String? repoName;
  final String? repoUrl;

  const ExtensionIndex({required this.extensions, this.repoName, this.repoUrl});

  factory ExtensionIndex.fromJson(
    dynamic json, {
    String? sourceUrl,
    String? repoName,
  }) {
    // Handle different index formats
    if (json is List) {
      // Keiyoushi format: direct array
      return ExtensionIndex(
        extensions: json
            .map(
              (e) => MangaExtension.fromJson({
                ...e as Map<String, dynamic>,
                'sourceUrl': sourceUrl,
              }),
            )
            .toList(),
        repoName: repoName,
        repoUrl: sourceUrl,
      );
    } else if (json is Map) {
      // Object format with extensions array
      final map = json as Map<String, dynamic>;
      final exts = map['extensions'] ?? map['sources'] ?? [];
      return ExtensionIndex(
        extensions: (exts as List)
            .map(
              (e) => MangaExtension.fromJson({
                ...e as Map<String, dynamic>,
                'sourceUrl': sourceUrl,
              }),
            )
            .toList(),
        repoName: map['name'] ?? repoName,
        repoUrl: sourceUrl,
      );
    }
    return ExtensionIndex(
      extensions: [],
      repoName: repoName,
      repoUrl: sourceUrl,
    );
  }
}

/// Status of an installed extension
class InstalledExtension {
  final String id;
  final String name;
  final String pkg;
  final int versionCode;
  final String sourceUrl;
  final DateTime installedAt;
  final bool enabled;

  const InstalledExtension({
    required this.id,
    required this.name,
    required this.pkg,
    required this.versionCode,
    required this.sourceUrl,
    required this.installedAt,
    this.enabled = true,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'pkg': pkg,
    'versionCode': versionCode,
    'sourceUrl': sourceUrl,
    'installedAt': installedAt.toIso8601String(),
    'enabled': enabled,
  };

  factory InstalledExtension.fromJson(Map<String, dynamic> json) =>
      InstalledExtension(
        id: json['id'] ?? '',
        name: json['name'] ?? '',
        pkg: json['pkg'] ?? '',
        versionCode: json['versionCode'] ?? 1,
        sourceUrl: json['sourceUrl'] ?? '',
        installedAt: json['installedAt'] != null
            ? DateTime.parse(json['installedAt'])
            : DateTime.now(),
        enabled: json['enabled'] ?? true,
      );
}
