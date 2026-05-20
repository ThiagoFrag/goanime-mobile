import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/foundation.dart';
import '../models/favorite_item.dart';

/// Serviço unificado de favoritos para animes e mangás
class FavoritesService {
  static Database? _database;
  static const String tableName = 'favorites';
  static const int _dbVersion = 2;

  /// Status semântico: "favorite" (saved), "watching" (in progress),
  /// "completed", "dropped", "planned". Default = "favorite".
  static const String _defaultKind = 'favorite';

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final databasePath = await getDatabasesPath();
    final path = join(databasePath, 'favorites.db');

    return await openDatabase(
      path,
      version: _dbVersion,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $tableName (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            itemId TEXT NOT NULL UNIQUE,
            title TEXT NOT NULL,
            coverImage TEXT NOT NULL,
            url TEXT NOT NULL,
            type TEXT NOT NULL,
            source TEXT,
            genres TEXT,
            addedAt TEXT NOT NULL,
            lastReadAt TEXT,
            lastRead TEXT,
            progress REAL,
            kind TEXT NOT NULL DEFAULT '$_defaultKind'
          )
        ''');
        await db.execute('CREATE INDEX idx_type ON $tableName(type)');
        await db.execute('CREATE INDEX idx_itemId ON $tableName(itemId)');
        await db.execute('CREATE INDEX idx_kind ON $tableName(kind)');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          try {
            await db.execute(
              "ALTER TABLE $tableName ADD COLUMN kind TEXT NOT NULL DEFAULT '$_defaultKind'",
            );
            await db.execute(
              'CREATE INDEX IF NOT EXISTS idx_kind ON $tableName(kind)',
            );
          } catch (e) {
            debugPrint('[FavoritesService] migration v2 warning: $e');
          }
        }
      },
    );
  }

  /// Adicionar item aos favoritos
  Future<bool> addToFavorites(FavoriteItem item) async {
    try {
      final db = await database;
      await db.insert(
        tableName,
        item.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      debugPrint('✅ Adicionado aos favoritos: ${item.title}');
      return true;
    } catch (e) {
      debugPrint('❌ Erro ao adicionar favorito: $e');
      return false;
    }
  }

  /// Remover item dos favoritos
  Future<bool> removeFromFavorites(String itemId) async {
    try {
      final db = await database;
      await db.delete(tableName, where: 'itemId = ?', whereArgs: [itemId]);
      debugPrint('✅ Removido dos favoritos: $itemId');
      return true;
    } catch (e) {
      debugPrint('❌ Erro ao remover favorito: $e');
      return false;
    }
  }

  /// Verificar se item está nos favoritos
  Future<bool> isFavorite(String itemId) async {
    try {
      final db = await database;
      final result = await db.query(
        tableName,
        where: 'itemId = ?',
        whereArgs: [itemId],
      );
      return result.isNotEmpty;
    } catch (e) {
      debugPrint('❌ Erro ao verificar favorito: $e');
      return false;
    }
  }

  /// Obter todos os favoritos
  Future<List<FavoriteItem>> getAllFavorites() async {
    try {
      final db = await database;
      final result = await db.query(tableName, orderBy: 'addedAt DESC');
      return result.map((map) => FavoriteItem.fromMap(map)).toList();
    } catch (e) {
      debugPrint('❌ Erro ao obter favoritos: $e');
      return [];
    }
  }

  /// Obter favoritos por tipo (anime ou manga)
  Future<List<FavoriteItem>> getFavoritesByType(FavoriteType type) async {
    try {
      final db = await database;
      final result = await db.query(
        tableName,
        where: 'type = ?',
        whereArgs: [type.name],
        orderBy: 'addedAt DESC',
      );
      return result.map((map) => FavoriteItem.fromMap(map)).toList();
    } catch (e) {
      debugPrint('❌ Erro ao obter favoritos por tipo: $e');
      return [];
    }
  }

  /// Obter favoritos de animes
  Future<List<FavoriteItem>> getAnimes() async {
    return getFavoritesByType(FavoriteType.anime);
  }

  /// Obter favoritos de mangás
  Future<List<FavoriteItem>> getMangas() async {
    return getFavoritesByType(FavoriteType.manga);
  }

  /// Atualizar progresso de um item
  Future<bool> updateProgress(
    String itemId, {
    String? lastRead,
    double? progress,
  }) async {
    try {
      final db = await database;
      final updates = <String, dynamic>{
        'lastReadAt': DateTime.now().toIso8601String(),
      };
      if (lastRead != null) updates['lastRead'] = lastRead;
      if (progress != null) updates['progress'] = progress;

      await db.update(
        tableName,
        updates,
        where: 'itemId = ?',
        whereArgs: [itemId],
      );
      return true;
    } catch (e) {
      debugPrint('❌ Erro ao atualizar progresso: $e');
      return false;
    }
  }

  /// Obter um item específico
  Future<FavoriteItem?> getFavorite(String itemId) async {
    try {
      final db = await database;
      final result = await db.query(
        tableName,
        where: 'itemId = ?',
        whereArgs: [itemId],
      );
      if (result.isEmpty) return null;
      return FavoriteItem.fromMap(result.first);
    } catch (e) {
      debugPrint('❌ Erro ao obter favorito: $e');
      return null;
    }
  }

  /// Limpar todos os favoritos
  Future<bool> clearAllFavorites() async {
    try {
      final db = await database;
      await db.delete(tableName);
      return true;
    } catch (e) {
      debugPrint('❌ Erro ao limpar favoritos: $e');
      return false;
    }
  }

  /// Obter contagem de favoritos
  Future<int> getFavoritesCount() async {
    try {
      final db = await database;
      final result = await db.rawQuery('SELECT COUNT(*) FROM $tableName');
      return Sqflite.firstIntValue(result) ?? 0;
    } catch (e) {
      debugPrint('❌ Erro ao contar favoritos: $e');
      return 0;
    }
  }

  /// Obter contagem por tipo
  Future<int> getCountByType(FavoriteType type) async {
    try {
      final db = await database;
      final result = await db.rawQuery(
        'SELECT COUNT(*) FROM $tableName WHERE type = ?',
        [type.name],
      );
      return Sqflite.firstIntValue(result) ?? 0;
    } catch (e) {
      return 0;
    }
  }

  /// Exportar favoritos para JSON (para sincronização)
  Future<List<Map<String, dynamic>>> exportToJson() async {
    final favorites = await getAllFavorites();
    return favorites.map((f) => f.toJson()).toList();
  }

  /// Importar favoritos de JSON (da sincronização)
  Future<int> importFromJson(List<dynamic> jsonList) async {
    int imported = 0;
    for (final json in jsonList) {
      try {
        final item = FavoriteItem.fromJson(json as Map<String, dynamic>);
        final success = await addToFavorites(item);
        if (success) imported++;
      } catch (e) {
        debugPrint('Erro ao importar item: $e');
      }
    }
    return imported;
  }
}
