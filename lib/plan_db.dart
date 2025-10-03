import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Model representing a meal/food entry in the plan screen.
class Meal {
  final int? id;
  final String dateKey; // yyyy-MM-dd
  final String name;
  final String time; // e.g., '08:15 AM'
  final int calories;
  final int protein;
  final int carbs;
  final int fat;

  Meal({
    this.id,
    required this.dateKey,
    required this.name,
    required this.time,
    this.calories = 0,
    this.protein = 0,
    this.carbs = 0,
    this.fat = 0,
  });

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'date_key': dateKey,
      'name': name,
      'time': time,
      'calories': calories,
      'protein': protein,
      'carbs': carbs,
      'fat': fat,
    };
  }

  static Meal fromMap(Map<String, Object?> m) {
    return Meal(
      id: m['id'] as int?,
      dateKey: m['date_key'] as String,
      name: m['name'] as String,
      time: m['time'] as String,
      calories: (m['calories'] as num?)?.toInt() ?? 0,
      protein: (m['protein'] as num?)?.toInt() ?? 0,
      carbs: (m['carbs'] as num?)?.toInt() ?? 0,
      fat: (m['fat'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Macro goals model (used for both global and per-day goals).
class MacroGoals {
  final int calories;
  final int protein;
  final int carbs;
  final int fat;

  const MacroGoals({
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
  });

  Map<String, Object?> toMap() => {
    'calories': calories,
    'protein': protein,
    'carbs': carbs,
    'fat': fat,
  };

  static MacroGoals fromMap(Map<String, Object?> m) => MacroGoals(
    calories: (m['calories'] as num?)?.toInt() ?? 0,
    protein: (m['protein'] as num?)?.toInt() ?? 0,
    carbs: (m['carbs'] as num?)?.toInt() ?? 0,
    fat: (m['fat'] as num?)?.toInt() ?? 0,
  );
}

/// Aggregated totals for a given date.
class MacroTotals {
  final int calories;
  final int protein;
  final int carbs;
  final int fat;

  const MacroTotals({
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
  });
}

/// Database for meals + macro goals.
class PlanDb {
  PlanDb._();
  static final PlanDb instance = PlanDb._();

  static const _dbName = 'plan_db.sqlite';
  static const _dbVersion = 4; // bumped to 3 for per-day goals

  static const tableMeals = 'meals';
  static const tableGoals = 'macro_goals';
  static const tableGoalsDaily = 'macro_goals_daily';

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final docs = await getApplicationDocumentsDirectory();
    final path = p.join(docs.path, _dbName);
    return await openDatabase(
      path,
      version: _dbVersion,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE daily_quotes (
            date_key TEXT PRIMARY KEY,
            quote TEXT NOT NULL,
            author TEXT
          );
        ''');

        await db.execute('''
          CREATE TABLE $tableMeals (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            date_key TEXT NOT NULL,
            name TEXT NOT NULL,
            time TEXT NOT NULL,
            calories INTEGER NOT NULL DEFAULT 0,
            protein INTEGER NOT NULL DEFAULT 0,
            carbs INTEGER NOT NULL DEFAULT 0,
            fat INTEGER NOT NULL DEFAULT 0
          );
        ''');

        await db.execute('''
          CREATE TABLE $tableGoals (
            id INTEGER PRIMARY KEY CHECK (id = 1),
            calories INTEGER NOT NULL DEFAULT 0,
            protein INTEGER NOT NULL DEFAULT 0,
            carbs INTEGER NOT NULL DEFAULT 0,
            fat INTEGER NOT NULL DEFAULT 0
          );
        ''');

        await db.execute('''
          CREATE TABLE $tableGoalsDaily (
            date_key TEXT PRIMARY KEY,
            calories INTEGER NOT NULL DEFAULT 0,
            protein INTEGER NOT NULL DEFAULT 0,
            carbs INTEGER NOT NULL DEFAULT 0,
            fat INTEGER NOT NULL DEFAULT 0
          );
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 4) {
          await db.execute('''
          CREATE TABLE IF NOT EXISTS daily_quotes (
            date_key TEXT PRIMARY KEY,
            quote TEXT NOT NULL,
            author TEXT
           );
         ''');
        }

        if (oldVersion < 2) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS $tableGoals (
              id INTEGER PRIMARY KEY CHECK (id = 1),
              calories INTEGER NOT NULL DEFAULT 0,
              protein INTEGER NOT NULL DEFAULT 0,
              carbs INTEGER NOT NULL DEFAULT 0,
              fat INTEGER NOT NULL DEFAULT 0
            );
          ''');
        }
        if (oldVersion < 3) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS $tableGoalsDaily (
              date_key TEXT PRIMARY KEY,
              calories INTEGER NOT NULL DEFAULT 0,
              protein INTEGER NOT NULL DEFAULT 0,
              carbs INTEGER NOT NULL DEFAULT 0,
              fat INTEGER NOT NULL DEFAULT 0
            );
          ''');
        }
      },
    );
  }

  Future<void> saveDailyQuote(
      String dateKey,
      String quote, {
        String? author,
      }) async {
    final db = await database;
    await db.insert('daily_quotes', {
      'date_key': dateKey,
      'quote': quote,
      'author': author,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Map<String, String>?> getDailyQuote(String dateKey) async {
    final db = await database;
    final rows = await db.query(
      'daily_quotes',
      where: 'date_key = ?',
      whereArgs: [dateKey],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final r = rows.first;
    return {
      'quote': (r['quote'] as String?) ?? '',
      'author': (r['author'] as String?) ?? '',
    };
  }

  // Meals CRUD
  Future<int> addMeal(Meal meal) async {
    final db = await database;
    return db.insert(
      tableMeals,
      meal.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Meal>> getMealsByDate(String dateKey) async {
    final db = await database;
    final rows = await db.query(
      tableMeals,
      where: 'date_key = ?',
      whereArgs: [dateKey],
      orderBy: 'id ASC',
    );
    return rows.map((e) => Meal.fromMap(e)).toList();
  }

  Future<int> deleteMeal(int id) async {
    final db = await database;
    return db.delete(tableMeals, where: 'id = ?', whereArgs: [id]);
  }

  // Global goals
  Future<void> saveGoals(MacroGoals goals) async {
    final db = await database;
    await db.insert(tableGoals, {
      ...goals.toMap(),
      'id': 1,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<MacroGoals?> getGoals() async {
    final db = await database;
    final rows = await db.query(tableGoals, where: 'id = 1', limit: 1);
    if (rows.isEmpty) return null;
    return MacroGoals.fromMap(rows.first);
  }

  // Per-day goals
  Future<void> saveGoalsForDate(String dateKey, MacroGoals goals) async {
    final db = await database;
    await db.insert(tableGoalsDaily, {
      'date_key': dateKey,
      ...goals.toMap(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<MacroGoals?> getGoalsForDate(String dateKey) async {
    final db = await database;
    final rows = await db.query(
      tableGoalsDaily,
      where: 'date_key = ?',
      whereArgs: [dateKey],
    );
    if (rows.isEmpty) return null;
    return MacroGoals.fromMap(rows.first);
  }

  // Daily totals
  Future<MacroTotals> getDailyTotals(String dateKey) async {
    final db = await database;
    final res = await db.rawQuery(
      '''
      SELECT
        COALESCE(SUM(calories), 0) AS t_cal,
        COALESCE(SUM(protein), 0)  AS t_pro,
        COALESCE(SUM(carbs), 0)    AS t_car,
        COALESCE(SUM(fat), 0)      AS t_fat
      FROM $tableMeals
      WHERE date_key = ?
    ''',
      [dateKey],
    );
    final row = res.first;
    return MacroTotals(
      calories: (row['t_cal'] as num?)?.toInt() ?? 0,
      protein: (row['t_pro'] as num?)?.toInt() ?? 0,
      carbs: (row['t_car'] as num?)?.toInt() ?? 0,
      fat: (row['t_fat'] as num?)?.toInt() ?? 0,
    );
  }
}
