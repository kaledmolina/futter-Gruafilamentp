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
        order_number TEXT NOT NULL,
        image_path TEXT NOT NULL
      )
    ''');
  }

  // CAMBIO: Ahora recibe el número de orden
  Future<void> addPendingPhoto(String orderNumber, String imagePath) async {
    final db = await instance.database;
    await db.insert('pending_photos', {'order_number': orderNumber, 'image_path': imagePath});
  }

  Future<List<Map<String, dynamic>>> getPendingPhotos() async {
    final db = await instance.database;
    return await db.query('pending_photos', orderBy: 'id');
  }
  
  // CAMBIO: Ahora busca por número de orden
  Future<List<Map<String, dynamic>>> getPendingPhotosForOrder(String orderNumber) async {
    final db = await instance.database;
    return await db.query('pending_photos', where: 'order_number = ?', whereArgs: [orderNumber]);
  }

  Future<void> deletePendingPhoto(int id) async {
    final db = await instance.database;
    await db.delete('pending_photos', where: 'id = ?', whereArgs: [id]);
  }
}