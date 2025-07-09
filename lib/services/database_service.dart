import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._init();
  static Database? _database;

  DatabaseService._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('offline_tasks.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE pending_photos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        order_id INTEGER NOT NULL,
        image_path TEXT NOT NULL
      )
    ''');
  }

  Future<void> addPendingPhoto(int orderId, String imagePath) async {
    final db = await instance.database;
    await db.insert('pending_photos', {'order_id': orderId, 'image_path': imagePath});
  }

  Future<List<Map<String, dynamic>>> getPendingPhotos() async {
    final db = await instance.database;
    return await db.query('pending_photos', orderBy: 'id');
  }
  
  // NUEVO: Método para obtener fotos pendientes para una orden específica
  Future<List<Map<String, dynamic>>> getPendingPhotosForOrder(int orderId) async {
    final db = await instance.database;
    return await db.query('pending_photos', where: 'order_id = ?', whereArgs: [orderId]);
  }

  Future<void> deletePendingPhoto(int id) async {
    final db = await instance.database;
    await db.delete('pending_photos', where: 'id = ?', whereArgs: [id]);
  }
}