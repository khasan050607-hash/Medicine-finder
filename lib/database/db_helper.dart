import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/medicine.dart';

/// Single shared connection to the local SQLite database.
/// Everything is on-device — nothing leaves the phone.
class DBHelper {
  DBHelper._internal();
  static final DBHelper instance = DBHelper._internal();

  static Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDB();
    return _db!;
  }

  Future<Database> _initDB() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'medicine_finder.db');

    return openDatabase(
      path,
      version: 1,
      onCreate: _createTables,
    );
  }

  Future<void> _createTables(Database db, int version) async {
    await db.execute('''
      CREATE TABLE medicines (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        shelf TEXT NOT NULL,
        category TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE medicine_photos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        medicine_id INTEGER NOT NULL,
        image_path TEXT NOT NULL,
        embedding TEXT,
        label TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (medicine_id) REFERENCES medicines (id)
          ON DELETE CASCADE
      )
    ''');

    // Speeds up name search (Task 3) as the medicine list grows.
    await db.execute('CREATE INDEX idx_medicine_name ON medicines (name)');
    await db.execute('CREATE INDEX idx_medicine_shelf ON medicines (shelf)');
  }

  // ---------- Medicine CRUD ----------

  Future<int> insertMedicine(Medicine medicine) async {
    final db = await database;
    return db.insert('medicines', medicine.toMap()..remove('id'));
  }

  Future<List<Medicine>> getAllMedicines() async {
    final db = await database;
    final result = await db.query('medicines', orderBy: 'name ASC');
    return result.map((m) => Medicine.fromMap(m)).toList();
  }

  Future<List<Medicine>> searchMedicines(String query) async {
    final db = await database;
    final result = await db.query(
      'medicines',
      where: 'name LIKE ?',
      whereArgs: ['%$query%'],
      orderBy: 'name ASC',
    );
    return result.map((m) => Medicine.fromMap(m)).toList();
  }

  Future<int> updateMedicine(Medicine medicine) async {
    final db = await database;
    return db.update(
      'medicines',
      medicine.toMap(),
      where: 'id = ?',
      whereArgs: [medicine.id],
    );
  }

  Future<int> deleteMedicine(int id) async {
    final db = await database;
    // Photos are removed too so we don't keep orphaned image files' records.
    await db.delete('medicine_photos', where: 'medicine_id = ?', whereArgs: [id]);
    return db.delete('medicines', where: 'id = ?', whereArgs: [id]);
  }

  // ---------- Medicine Photo CRUD ----------

  Future<int> insertPhoto(MedicinePhoto photo) async {
    final db = await database;
    return db.insert('medicine_photos', photo.toMap()..remove('id'));
  }

  Future<List<MedicinePhoto>> getPhotosForMedicine(int medicineId) async {
    final db = await database;
    final result = await db.query(
      'medicine_photos',
      where: 'medicine_id = ?',
      whereArgs: [medicineId],
    );
    return result.map((p) => MedicinePhoto.fromMap(p)).toList();
  }

  Future<int> deletePhoto(int photoId) async {
    final db = await database;
    return db.delete('medicine_photos', where: 'id = ?', whereArgs: [photoId]);
  }

  /// Used by Camera Match (Phase 5) to pull every stored embedding
  /// for similarity comparison against a live camera frame.
  Future<List<MedicinePhoto>> getAllPhotosWithEmbeddings() async {
    final db = await database;
    final result = await db.query(
      'medicine_photos',
      where: 'embedding IS NOT NULL',
    );
    return result.map((p) => MedicinePhoto.fromMap(p)).toList();
  }
}
