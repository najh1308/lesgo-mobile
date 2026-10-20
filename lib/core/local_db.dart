import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Database lokal (SQLite): cache data dari server dan pengaturan sederhana.
/// Dipakai agar aplikasi tetap menampilkan data terakhir saat tidak ada internet.
class LocalDb {
  static Database? _db;

  static Future<Database> get _database async => _db ??= await _open();

  static Future<Database> _open() async {
    final path = p.join(await getDatabasesPath(), 'lesgo.db');
    return openDatabase(path, version: 1, onCreate: (db, v) async {
      await db.execute(
          'CREATE TABLE cache (key TEXT PRIMARY KEY, json TEXT NOT NULL, updated_at INTEGER NOT NULL)');
      await db.execute(
          'CREATE TABLE pengaturan (key TEXT PRIMARY KEY, value TEXT)');
    });
  }

  static Future<void> putCache(String key, String json) async {
    final db = await _database;
    await db.insert(
      'cache',
      {'key': key, 'json': json, 'updated_at': DateTime.now().millisecondsSinceEpoch},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<String?> getCache(String key) async {
    final db = await _database;
    final rows = await db.query('cache', where: 'key = ?', whereArgs: [key], limit: 1);
    return rows.isEmpty ? null : rows.first['json'] as String;
  }

  static Future<void> setSetting(String key, String value) async {
    final db = await _database;
    await db.insert('pengaturan', {'key': key, 'value': value},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<String?> getSetting(String key) async {
    final db = await _database;
    final rows = await db.query('pengaturan', where: 'key = ?', whereArgs: [key], limit: 1);
    return rows.isEmpty ? null : rows.first['value'] as String?;
  }

  static Future<void> clearCache() async {
    final db = await _database;
    await db.delete('cache');
  }
}
