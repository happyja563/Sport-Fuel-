import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DBHelper {
  static final DBHelper _instance = DBHelper._internal();
  factory DBHelper() => _instance;

  DBHelper._internal();

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDB();
    return _db!;
  }

  Future<Database> _initDB() async {
    String dbPath = join(await getDatabasesPath(), 'profile.db');
    return await openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE profile (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT,
            age INTEGER,
            gender TEXT,
            sportsType TEXT,
            weight REAL,
            height REAL
          )
        ''');
      },
    );
  }

  // Insert or Update Profile (only 1 row)
  Future<void> saveProfile(Map<String, dynamic> profile) async {
    final db = await database;
    // Clear old profile (only storing one)
    await db.delete('profile');
    await db.insert('profile', profile);
  }

  // Get Profile
  Future<Map<String, dynamic>?> getProfile() async {
    final db = await database;
    final res = await db.query('profile', limit: 1);
    if (res.isNotEmpty) {
      return res.first;
    }
    return null;
  }

  // Delete Profile
  Future<void> deleteProfile() async {
    final db = await database;
    await db.delete('profile');
  }
}