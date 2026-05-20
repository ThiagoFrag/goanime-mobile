import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/favorite_item.dart';
import 'favorites_service.dart';

/// Cloud-sync com o backend mangascraper.
///
/// O backend é opcional: se [SYNC_BASE_URL] não estiver definido em `.env`,
/// todas as operações retornam estado offline em vez de tentar `localhost`,
/// que jamais resolveria em um dispositivo físico.
class SyncService {
  static const String _userIdKey = 'sync_user_id';
  static const String _lastSyncKey = 'last_sync_at';

  final FavoritesService _favoritesService = FavoritesService();

  /// Base URL configurada via .env. Vazio = sync desabilitado.
  String get baseUrl => dotenv.env['SYNC_BASE_URL'] ?? '';

  bool get isEnabled => baseUrl.isNotEmpty;

  /// Obtém ou cria um ID de usuário único
  Future<String> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    String? userId = prefs.getString(_userIdKey);

    if (userId == null || userId.isEmpty) {
      userId = 'mobile_${DateTime.now().millisecondsSinceEpoch}';
      await prefs.setString(_userIdKey, userId);
    }

    return userId;
  }

  Future<void> setUserId(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userIdKey, userId);
  }

  Future<bool> isServerOnline() async {
    if (!isEnabled) return false;
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/health'))
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('[SyncService] Server offline: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>?> getSyncStatus() async {
    if (!isEnabled) return null;
    try {
      final userId = await getUserId();
      final response = await http
          .get(Uri.parse('$baseUrl/api/sync/status?user_id=$userId'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
    } catch (e) {
      debugPrint('[SyncService] Error getting status: $e');
    }
    return null;
  }

  Future<SyncResult> syncWithServer() async {
    if (!isEnabled) {
      return SyncResult(
        success: false,
        message: 'Sync desabilitado (SYNC_BASE_URL não configurado)',
      );
    }
    try {
      final userId = await getUserId();
      final localFavorites = await _favoritesService.getAllFavorites();

      final syncData = {
        'user_id': userId,
        'device_info': 'goanime-mobile',
        'favorites': localFavorites.map(_favoriteToJson).toList(),
        'settings': {'content_language': 'pt-BR'},
      };

      final response = await http
          .post(
            Uri.parse('$baseUrl/api/sync'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode(syncData),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        if (result['success'] == true && result['data'] != null) {
          final serverData = result['data'];
          final serverFavorites = serverData['favorites'] as List? ?? [];

          int imported = 0;
          for (final fav in serverFavorites) {
            final item = _jsonToFavorite(fav);
            if (item != null) {
              final exists = await _favoritesService.isFavorite(item.itemId);
              if (!exists) {
                await _favoritesService.addToFavorites(item);
                imported++;
              }
            }
          }

          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_lastSyncKey, DateTime.now().toIso8601String());

          return SyncResult(
            success: true,
            message: 'Sincronização concluída!',
            itemsSynced: localFavorites.length,
            itemsImported: imported,
            lastSync: serverData['last_sync_at'],
          );
        }
      }

      return SyncResult(
        success: false,
        message: 'Erro ao sincronizar: ${response.statusCode}',
      );
    } catch (e) {
      debugPrint('[SyncService] Sync error: $e');
      return SyncResult(success: false, message: 'Erro de conexão: $e');
    }
  }

  Future<bool> addFavoriteToServer(FavoriteItem item) async {
    if (!isEnabled) return false;
    try {
      final userId = await getUserId();
      final response = await http
          .post(
            Uri.parse('$baseUrl/api/sync/favorites'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'user_id': userId,
              'favorite': _favoriteToJson(item),
            }),
          )
          .timeout(const Duration(seconds: 10));
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('[SyncService] Error adding favorite: $e');
      return false;
    }
  }

  Future<bool> removeFavoriteFromServer(String itemId, String type) async {
    if (!isEnabled) return false;
    try {
      final userId = await getUserId();
      final response = await http
          .delete(
            Uri.parse(
              '$baseUrl/api/sync/favorites?user_id=$userId&item_id=$itemId&type=$type',
            ),
          )
          .timeout(const Duration(seconds: 10));
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('[SyncService] Error removing favorite: $e');
      return false;
    }
  }

  Future<List<FavoriteItem>> getServerFavorites() async {
    if (!isEnabled) return const [];
    try {
      final userId = await getUserId();
      final response = await http
          .get(Uri.parse('$baseUrl/api/sync?user_id=$userId'))
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        if (result['success'] == true && result['data'] != null) {
          final favorites = result['data']['favorites'] as List? ?? [];
          return favorites
              .map(_jsonToFavorite)
              .whereType<FavoriteItem>()
              .toList();
        }
      }
    } catch (e) {
      debugPrint('[SyncService] Error getting server favorites: $e');
    }
    return const [];
  }

  Future<String?> registerUser({String? username}) async {
    if (!isEnabled) return null;
    try {
      final userId = await getUserId();
      final response = await http
          .post(
            Uri.parse('$baseUrl/api/sync/register'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'user_id': userId,
              'username': username ?? 'Mobile User',
              'device_info': 'goanime-mobile',
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        if (result['success'] == true) {
          return result['user_id'];
        }
      }
    } catch (e) {
      debugPrint('[SyncService] Error registering: $e');
    }
    return null;
  }

  Future<SyncResult> linkWithAccount(String existingUserId) async {
    if (!isEnabled) {
      return SyncResult(
        success: false,
        message: 'Sync desabilitado (SYNC_BASE_URL não configurado)',
      );
    }
    try {
      await setUserId(existingUserId);
      return await syncWithServer();
    } catch (e) {
      return SyncResult(success: false, message: 'Erro ao vincular conta: $e');
    }
  }

  Future<DateTime?> getLastSyncDate() async {
    final prefs = await SharedPreferences.getInstance();
    final lastSync = prefs.getString(_lastSyncKey);
    if (lastSync != null) {
      return DateTime.tryParse(lastSync);
    }
    return null;
  }

  Map<String, dynamic> _favoriteToJson(FavoriteItem item) {
    return {
      'item_id': item.itemId,
      'title': item.title,
      'cover_image': item.coverImage,
      'url': item.url,
      'type': item.type.name,
      'source': item.source,
      'genres': item.genres,
      'added_at': item.addedAt.toIso8601String(),
      'last_read_at': item.lastReadAt?.toIso8601String(),
      'last_read': item.lastRead,
      'progress': item.progress,
    };
  }

  FavoriteItem? _jsonToFavorite(dynamic raw) {
    if (raw is! Map<String, dynamic>) return null;
    try {
      return FavoriteItem(
        itemId: raw['item_id'] ?? '',
        title: raw['title'] ?? '',
        coverImage: raw['cover_image'] ?? '',
        url: raw['url'] ?? '',
        type: raw['type'] == 'manga' ? FavoriteType.manga : FavoriteType.anime,
        source: raw['source'],
        genres: (raw['genres'] as List?)?.cast<String>(),
        addedAt: raw['added_at'] != null
            ? DateTime.parse(raw['added_at'])
            : DateTime.now(),
        lastReadAt: raw['last_read_at'] != null
            ? DateTime.tryParse(raw['last_read_at'])
            : null,
        lastRead: raw['last_read'],
        progress: (raw['progress'] as num?)?.toDouble(),
      );
    } catch (e) {
      debugPrint('[SyncService] Error parsing favorite: $e');
      return null;
    }
  }
}

class SyncResult {
  final bool success;
  final String message;
  final int itemsSynced;
  final int itemsImported;
  final String? lastSync;

  SyncResult({
    required this.success,
    required this.message,
    this.itemsSynced = 0,
    this.itemsImported = 0,
    this.lastSync,
  });
}
