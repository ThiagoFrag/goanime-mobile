import 'package:flutter/foundation.dart';
import '../models/favorite_item.dart';
import 'favorites_service.dart';

/// Provider para gerenciar estado dos favoritos
class FavoritesNotifier extends ChangeNotifier {
  final FavoritesService _service = FavoritesService();

  List<FavoriteItem> _favorites = [];
  List<FavoriteItem> _animes = [];
  List<FavoriteItem> _mangas = [];
  bool _isLoading = false;

  List<FavoriteItem> get favorites => _favorites;
  List<FavoriteItem> get animes => _animes;
  List<FavoriteItem> get mangas => _mangas;
  bool get isLoading => _isLoading;

  int get totalCount => _favorites.length;
  int get animeCount => _animes.length;
  int get mangaCount => _mangas.length;

  /// Carregar todos os favoritos
  Future<void> loadFavorites() async {
    _isLoading = true;
    notifyListeners();

    try {
      _favorites = await _service.getAllFavorites();
      _animes = _favorites.where((f) => f.type == FavoriteType.anime).toList();
      _mangas = _favorites.where((f) => f.type == FavoriteType.manga).toList();
    } catch (e) {
      debugPrint('Erro ao carregar favoritos: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Verificar se um item está nos favoritos
  Future<bool> isFavorite(String itemId) async {
    // Primeiro verifica em memória para resposta rápida
    if (_favorites.any((f) => f.itemId == itemId)) {
      return true;
    }
    // Caso contrário, verifica no banco
    return _service.isFavorite(itemId);
  }

  /// Verificar síncronamente se está nos favoritos (apenas memória)
  bool isFavoriteSync(String itemId) {
    return _favorites.any((f) => f.itemId == itemId);
  }

  /// Adicionar aos favoritos
  Future<bool> addToFavorites(FavoriteItem item) async {
    final success = await _service.addToFavorites(item);
    if (success) {
      _favorites.insert(0, item);
      if (item.type == FavoriteType.anime) {
        _animes.insert(0, item);
      } else {
        _mangas.insert(0, item);
      }
      notifyListeners();
    }
    return success;
  }

  /// Remover dos favoritos
  Future<bool> removeFromFavorites(String itemId) async {
    final success = await _service.removeFromFavorites(itemId);
    if (success) {
      FavoriteType? removedType;
      for (final f in _favorites) {
        if (f.itemId == itemId) {
          removedType = f.type;
          break;
        }
      }
      _favorites.removeWhere((f) => f.itemId == itemId);
      if (removedType == FavoriteType.anime) {
        _animes.removeWhere((f) => f.itemId == itemId);
      } else if (removedType == FavoriteType.manga) {
        _mangas.removeWhere((f) => f.itemId == itemId);
      }
      notifyListeners();
    }
    return success;
  }

  /// Toggle favorito
  Future<bool> toggleFavorite(FavoriteItem item) async {
    final exists = isFavoriteSync(item.itemId);
    if (exists) {
      return removeFromFavorites(item.itemId);
    } else {
      return addToFavorites(item);
    }
  }

  /// Atualizar progresso
  Future<bool> updateProgress(
    String itemId, {
    String? lastRead,
    double? progress,
  }) async {
    final success = await _service.updateProgress(
      itemId,
      lastRead: lastRead,
      progress: progress,
    );
    if (success) {
      await loadFavorites(); // Recarrega para atualizar a lista
    }
    return success;
  }

  /// Limpar todos os favoritos
  Future<bool> clearAll() async {
    final success = await _service.clearAllFavorites();
    if (success) {
      _favorites.clear();
      _animes.clear();
      _mangas.clear();
      notifyListeners();
    }
    return success;
  }

  /// Exportar para JSON
  Future<List<Map<String, dynamic>>> export() async {
    return _service.exportToJson();
  }

  /// Importar de JSON
  Future<int> import(List<dynamic> jsonList) async {
    final count = await _service.importFromJson(jsonList);
    await loadFavorites();
    return count;
  }
}
