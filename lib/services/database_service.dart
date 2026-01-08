import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._init();
  static Database? _database;
  static const int _databaseVersion = 3;

  DatabaseService._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('offline_tasks.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future _createDB(Database db, int version) async {
    // Tabla pending_photos
    await db.execute('''
      CREATE TABLE pending_photos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        order_number TEXT NOT NULL,
        image_path TEXT NOT NULL,
        created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
        sync_status TEXT NOT NULL DEFAULT 'pending',
        last_error TEXT
      )
    ''');

    // Tabla orders
    await db.execute('''
      CREATE TABLE orders (
        id INTEGER PRIMARY KEY,
        numero_orden TEXT NOT NULL UNIQUE,
        numero_expediente TEXT,
        nombre_cliente TEXT NOT NULL,
        fecha_hora TEXT NOT NULL,
        valor_servicio REAL,
        placa TEXT,
        referencia TEXT,
        nombre_asignado TEXT,
        celular TEXT,
        unidad_negocio TEXT,
        movimiento TEXT,
        servicio TEXT,
        modalidad TEXT,
        tipo_activo TEXT,
        marca TEXT,
        ciudad_origen TEXT NOT NULL,
        direccion_origen TEXT NOT NULL,
        observaciones_origen TEXT,
        ciudad_destino TEXT NOT NULL,
        direccion_destino TEXT NOT NULL,
        observaciones_destino TEXT,
        es_programada INTEGER NOT NULL DEFAULT 0,
        fecha_programada TEXT,
        status TEXT NOT NULL,
        synced_at INTEGER,
        updated_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))
      )
    ''');

    // Tabla pending_operations
    await db.execute('''
      CREATE TABLE pending_operations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        operation_type TEXT NOT NULL,
        order_number TEXT NOT NULL,
        operation_data TEXT NOT NULL,
        created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
        retry_count INTEGER NOT NULL DEFAULT 0,
        last_error TEXT
      )
    ''');

    // Tabla pending_inspections
    await db.execute('''
      CREATE TABLE pending_inspections (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        inspection_data TEXT NOT NULL,
        created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
        retry_count INTEGER NOT NULL DEFAULT 0,
        last_error TEXT
      )
    ''');

    // Tabla sync_metadata
    await db.execute('''
      CREATE TABLE sync_metadata (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL,
        updated_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))
      )
    ''');

    // Inicializar sync_metadata
    await db.insert('sync_metadata', {
      'key': 'last_sync_orders',
      'value': '0',
    });
    await db.insert('sync_metadata', {
      'key': 'last_sync_profile',
      'value': '0',
    });
    await db.insert('sync_metadata', {
      'key': 'pending_operations_count',
      'value': '0',
    });
    await db.insert('sync_metadata', {
      'key': 'sync_status',
      'value': 'idle',
    });
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Migrar pending_photos
      // Migrar pending_photos (Fix: SQLite no soporta ADD COLUMN con dynamic default)
      try {
        await db.transaction((txn) async {
          // 1. Renombrar tabla existente
          await txn.execute('ALTER TABLE pending_photos RENAME TO pending_photos_old');
          
          // 2. Crear nueva tabla con la estructura correcta (v2)
          await txn.execute('''
            CREATE TABLE pending_photos (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              order_number TEXT NOT NULL,
              image_path TEXT NOT NULL,
              created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
              sync_status TEXT NOT NULL DEFAULT 'pending'
            )
          ''');

          // 3. Copiar datos
          await txn.execute('''
            INSERT INTO pending_photos (id, order_number, image_path)
            SELECT id, order_number, image_path FROM pending_photos_old
          ''');

          // 4. Eliminar tabla antigua
          await txn.execute('DROP TABLE pending_photos_old');
        });
      } catch (e) {
        print('Error during migration v2 pending_photos: $e');
        // Si falla, intentamos restaurar o lanzar error crítico
        rethrow;
      }

      // Crear nuevas tablas
      await db.execute('''
        CREATE TABLE orders (
          id INTEGER PRIMARY KEY,
          numero_orden TEXT NOT NULL UNIQUE,
          numero_expediente TEXT,
          nombre_cliente TEXT NOT NULL,
          fecha_hora TEXT NOT NULL,
          valor_servicio REAL,
          placa TEXT,
          referencia TEXT,
          nombre_asignado TEXT,
          celular TEXT,
          unidad_negocio TEXT,
          movimiento TEXT,
          servicio TEXT,
          modalidad TEXT,
          tipo_activo TEXT,
          marca TEXT,
          ciudad_origen TEXT NOT NULL,
          direccion_origen TEXT NOT NULL,
          observaciones_origen TEXT,
          ciudad_destino TEXT NOT NULL,
          direccion_destino TEXT NOT NULL,
          observaciones_destino TEXT,
          es_programada INTEGER NOT NULL DEFAULT 0,
          fecha_programada TEXT,
          status TEXT NOT NULL,
          synced_at INTEGER,
          updated_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))
        )
      ''');

      await db.execute('''
        CREATE TABLE pending_operations (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          operation_type TEXT NOT NULL,
          order_number TEXT NOT NULL,
          operation_data TEXT NOT NULL,
          created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
          retry_count INTEGER NOT NULL DEFAULT 0,
          last_error TEXT
        )
      ''');

      await db.execute('''
        CREATE TABLE pending_inspections (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          inspection_data TEXT NOT NULL,
          created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
          retry_count INTEGER NOT NULL DEFAULT 0,
          last_error TEXT
        )
      ''');

      await db.execute('''
        CREATE TABLE sync_metadata (
          key TEXT PRIMARY KEY,
          value TEXT NOT NULL,
          updated_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))
        )
      ''');

      // Inicializar sync_metadata
      await db.insert('sync_metadata', {
        'key': 'last_sync_orders',
        'value': '0',
      });
      await db.insert('sync_metadata', {
        'key': 'last_sync_profile',
        'value': '0',
      });
      await db.insert('sync_metadata', {
        'key': 'pending_operations_count',
        'value': '0',
      });
      await db.insert('sync_metadata', {
        'key': 'sync_status',
        'value': 'idle',
      });
    }

    if (oldVersion < 3) {
      await db.execute('''
        ALTER TABLE pending_photos 
        ADD COLUMN last_error TEXT
      ''');
    }
  }

  // ========== PENDING PHOTOS ==========
  Future<void> addPendingPhoto(String orderNumber, String imagePath) async {
    final db = await database;
    await db.insert('pending_photos', {
      'order_number': orderNumber,
      'image_path': imagePath,
      'sync_status': 'pending',
    });
  }

  Future<List<Map<String, dynamic>>> getPendingPhotos() async {
    final db = await database;
    return await db.query('pending_photos', orderBy: 'id');
  }

  Future<List<Map<String, dynamic>>> getPendingPhotosForOrder(String orderNumber) async {
    final db = await database;
    return await db.query(
      'pending_photos',
      where: 'order_number = ?',
      whereArgs: [orderNumber],
    );
  }

  Future<void> deletePendingPhoto(int id) async {
    final db = await database;
    await db.delete('pending_photos', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> updatePendingPhotoError(int id, String error) async {
    final db = await database;
    await db.update(
      'pending_photos',
      {'last_error': error},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ========== ORDERS ==========
  Future<void> saveOrder(Map<String, dynamic> orderData) async {
    final db = await database;
    await db.insert(
      'orders',
      orderData,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> saveOrders(List<Map<String, dynamic>> orders) async {
    final db = await database;
    final batch = db.batch();
    for (var order in orders) {
      batch.insert(
        'orders',
        order,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<Map<String, dynamic>>> getOrders({String? status}) async {
    final db = await database;
    if (status != null && status != 'todas') {
      return await db.query(
        'orders',
        where: 'status = ?',
        whereArgs: [status],
        orderBy: 'fecha_hora DESC',
      );
    }
    return await db.query('orders', orderBy: 'fecha_hora DESC');
  }

  Future<List<Map<String, dynamic>>> getOrdersInProcess() async {
    final db = await database;
    return await db.query(
      'orders',
      where: 'status = ?',
      whereArgs: ['en proceso'],
      orderBy: 'fecha_hora DESC',
    );
  }

  Future<Map<String, dynamic>?> getOrderByNumber(String numeroOrden) async {
    final db = await database;
    final results = await db.query(
      'orders',
      where: 'numero_orden = ?',
      whereArgs: [numeroOrden],
      limit: 1,
    );
    return results.isNotEmpty ? results.first : null;
  }

  Future<void> updateOrder(String numeroOrden, Map<String, dynamic> updates) async {
    final db = await database;
    updates['updated_at'] = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    await db.update(
      'orders',
      updates,
      where: 'numero_orden = ?',
      whereArgs: [numeroOrden],
    );
  }

  Future<void> deleteOrder(String numeroOrden) async {
    final db = await database;
    await db.delete('orders', where: 'numero_orden = ?', whereArgs: [numeroOrden]);
  }

  // ========== PENDING OPERATIONS ==========
  Future<int> addPendingOperation({
    required String operationType,
    required String orderNumber,
    required Map<String, dynamic> operationData,
  }) async {
    final db = await database;
    final id = await db.insert('pending_operations', {
      'operation_type': operationType,
      'order_number': orderNumber,
      'operation_data': jsonEncode(operationData),
    });
    await _updatePendingOperationsCount();
    return id;
  }

  Future<List<Map<String, dynamic>>> getPendingOperations() async {
    final db = await database;
    return await db.query('pending_operations', orderBy: 'created_at ASC');
  }

  Future<List<Map<String, dynamic>>> getPendingOperationsForOrder(String orderNumber) async {
    final db = await database;
    return await db.query(
      'pending_operations',
      where: 'order_number = ?',
      whereArgs: [orderNumber],
      orderBy: 'created_at ASC',
    );
  }

  Future<void> deletePendingOperation(int id) async {
    final db = await database;
    await db.delete('pending_operations', where: 'id = ?', whereArgs: [id]);
    await _updatePendingOperationsCount();
  }

  Future<void> incrementRetryCount(int id, String? error) async {
    final db = await database;
    final result = await db.query(
      'pending_operations',
      where: 'id = ?',
      whereArgs: [id],
      columns: ['retry_count'],
      limit: 1,
    );
    if (result.isNotEmpty) {
      final currentCount = result.first['retry_count'] as int;
      await db.update(
        'pending_operations',
        {
          'retry_count': currentCount + 1,
          'last_error': error,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
    }
  }

  // ========== PENDING INSPECTIONS ==========
  Future<int> addPendingInspection(Map<String, dynamic> inspectionData) async {
    final db = await database;
    return await db.insert('pending_inspections', {
      'inspection_data': jsonEncode(inspectionData),
    });
  }

  Future<List<Map<String, dynamic>>> getPendingInspections() async {
    final db = await database;
    return await db.query('pending_inspections', orderBy: 'created_at ASC');
  }

  Future<void> deletePendingInspection(int id) async {
    final db = await database;
    await db.delete('pending_inspections', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> incrementInspectionRetryCount(int id, String? error) async {
    final db = await database;
    final result = await db.query(
      'pending_inspections',
      where: 'id = ?',
      whereArgs: [id],
      columns: ['retry_count'],
      limit: 1,
    );
    if (result.isNotEmpty) {
      final currentCount = result.first['retry_count'] as int;
      await db.update(
        'pending_inspections',
        {
          'retry_count': currentCount + 1,
          'last_error': error,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
    }
  }

  // ========== SYNC METADATA ==========
  Future<void> setSyncMetadata(String key, String value) async {
    final db = await database;
    await db.insert(
      'sync_metadata',
      {
        'key': key,
        'value': value,
        'updated_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<String?> getSyncMetadata(String key) async {
    final db = await database;
    final results = await db.query(
      'sync_metadata',
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    return results.isNotEmpty ? results.first['value'] as String? : null;
  }

  Future<int> getLastSyncOrders() async {
    final value = await getSyncMetadata('last_sync_orders');
    return int.tryParse(value ?? '0') ?? 0;
  }

  Future<void> setLastSyncOrders(int timestamp) async {
    await setSyncMetadata('last_sync_orders', timestamp.toString());
  }

  Future<int> getLastSyncProfile() async {
    final value = await getSyncMetadata('last_sync_profile');
    return int.tryParse(value ?? '0') ?? 0;
  }

  Future<void> setLastSyncProfile(int timestamp) async {
    await setSyncMetadata('last_sync_profile', timestamp.toString());
  }

  Future<String> getSyncStatus() async {
    return await getSyncMetadata('sync_status') ?? 'idle';
  }

  Future<void> setSyncStatus(String status) async {
    await setSyncMetadata('sync_status', status);
  }

  Future<int> getPendingOperationsCount() async {
    final value = await getSyncMetadata('pending_operations_count');
    return int.tryParse(value ?? '0') ?? 0;
  }

  Future<void> _updatePendingOperationsCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM pending_operations');
    final count = result.first['count'] as int;
    await setSyncMetadata('pending_operations_count', count.toString());
  }
}