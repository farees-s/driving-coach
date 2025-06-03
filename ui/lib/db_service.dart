import 'dart:io';
import 'package:csv/csv.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DBService {
  static Database? _db;

  /* ───────── init ───────── */
  static Future<void> init() async {
    if (_db != null) return;
    final path = join(await getDatabasesPath(), 'sessions.db');

    _db = await openDatabase(
      path,
      version: 6, // ← BUMP VERSION to force migration
      onCreate: (db, _) async => _createSchema(db),
      onUpgrade: (db, oldV, __) async => _runMigrations(db, oldV),
    );
  }

  static Database get _ => _db!;

  /* ───────── schema helpers ───────── */
  static Future<void> _createSchema(Database db) async {
    await db.execute('''
      CREATE TABLE telemetry(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        timestamp REAL,
        speed_kmh REAL,
        throttle REAL,
        brake REAL,
        steer REAL,
        accel REAL,
        jerk REAL,
        brake_spike INTEGER
      );
    ''');
    await db.execute('''
      CREATE TABLE lane(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        frame INTEGER,
        timestamp REAL,
        lane_offset_px REAL
      );
    ''');
    // Sessions table with consistent schema
    await db.execute('''
      CREATE TABLE sessions(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date_created TEXT,
        score REAL,
        tele_file_path TEXT,
        lane_file_path TEXT,
        tele_file_name TEXT,
        lane_file_name TEXT
      );
    ''');
  }

  static Future<void> _runMigrations(Database db, int from) async {
    print('Running migrations from version $from');
    
    if (from < 2) {
      await _ensureCol(db, 'telemetry', 'speed_kmh', 'REAL');
      await _ensureCol(db, 'telemetry', 'throttle', 'REAL');
      await _ensureCol(db, 'telemetry', 'brake', 'REAL');
      await _ensureCol(db, 'telemetry', 'steer', 'REAL');
    }
    if (from < 3) {
      await _ensureCol(db, 'telemetry', 'accel', 'REAL');
      await _ensureCol(db, 'telemetry', 'jerk', 'REAL');
      await _ensureCol(db, 'telemetry', 'brake_spike', 'INTEGER');
    }
    if (from < 4) {
      // Create sessions table if it doesn't exist
      await db.execute('''
        CREATE TABLE IF NOT EXISTS sessions(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          date_created TEXT,
          score REAL,
          tele_file_path TEXT,
          lane_file_path TEXT,
          tele_file_name TEXT,
          lane_file_name TEXT
        );
      ''');
    }
    if (from < 5) {
      // Force recreation of sessions table to ensure all columns exist
      print('Recreating sessions table to fix schema...');
      
      // Check if sessions table exists and has the right structure
      final tables = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND name='sessions'");
      if (tables.isNotEmpty) {
        // Get existing data if any
        List<Map<String, dynamic>> existingData = [];
        try {
          existingData = await db.rawQuery('SELECT * FROM sessions');
        } catch (e) {
          print('Could not read existing sessions data: $e');
        }
        
        // Drop and recreate
        await db.execute('DROP TABLE IF EXISTS sessions');
        await db.execute('''
          CREATE TABLE sessions(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            date_created TEXT,
            score REAL,
            tele_file_path TEXT,
            lane_file_path TEXT,
            tele_file_name TEXT,
            lane_file_name TEXT
          );
        ''');
        
        // Restore data if it was readable and had the right structure
        for (final row in existingData) {
          try {
            await db.insert('sessions', {
              'date_created': row['date_created'] ?? DateTime.now().toIso8601String(),
              'score': row['score'] ?? 0.0,
              'tele_file_path': row['tele_file_path'] ?? '',
              'lane_file_path': row['lane_file_path'] ?? '',
              'tele_file_name': row['tele_file_name'] ?? '',
              'lane_file_name': row['lane_file_name'] ?? '',
            });
          } catch (e) {
            print('Could not restore session row: $e');
          }
        }
      } else {
        // Table doesn't exist, create it
        await db.execute('''
          CREATE TABLE sessions(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            date_created TEXT,
            score REAL,
            tele_file_path TEXT,
            lane_file_path TEXT,
            tele_file_name TEXT,
            lane_file_name TEXT
          );
        ''');
      }
    }
    if (from < 6) {
      // Fix any inconsistencies in the sessions table schema
      print('Ensuring sessions table has consistent schema...');
      
      // Check current table structure
      final columns = await db.rawQuery('PRAGMA table_info(sessions)');
      final columnNames = columns.map((col) => col['name'].toString()).toSet();
      
      // Get existing data if any
      List<Map<String, dynamic>> existingData = [];
      try {
        existingData = await db.rawQuery('SELECT * FROM sessions');
      } catch (e) {
        print('Could not read existing sessions data: $e');
      }
      
      // Drop and recreate with correct schema
      await db.execute('DROP TABLE IF EXISTS sessions');
      await db.execute('''
        CREATE TABLE sessions(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          date_created TEXT,
          score REAL,
          tele_file_path TEXT,
          lane_file_path TEXT,
          tele_file_name TEXT,
          lane_file_name TEXT
        );
      ''');
      
      // Restore data, converting formats if needed
      for (final row in existingData) {
        try {
          String dateCreated;
          if (row.containsKey('date') && row['date'] != null) {
            // Convert from epoch milliseconds to ISO string
            final epochMs = row['date'] as int;
            dateCreated = DateTime.fromMillisecondsSinceEpoch(epochMs).toIso8601String();
          } else if (row.containsKey('date_created') && row['date_created'] != null) {
            dateCreated = row['date_created'].toString();
          } else {
            dateCreated = DateTime.now().toIso8601String();
          }
          
          await db.insert('sessions', {
            'date_created': dateCreated,
            'score': row['score'] ?? 0.0,
            'tele_file_path': row['tele_file_path'] ?? '',
            'lane_file_path': row['lane_file_path'] ?? '',
            'tele_file_name': row['tele_file_name'] ?? '',
            'lane_file_name': row['lane_file_name'] ?? '',
          });
        } catch (e) {
          print('Could not restore session row: $e');
        }
      }
    }
  }

  static Future<void> _ensureCol(Database db, String t, String c, String type) async {
    final cols = await db.rawQuery('PRAGMA table_info($t)');
    if (!cols.any((row) => row['name'] == c)) {
      await db.execute('ALTER TABLE $t ADD COLUMN $c $type;');
    }
  }

  /* ───────── CSV import (keep existing method) ───────── */
  static Future<void> importCsv(File f, String table) async {
    print('=== DEBUG: Starting CSV import for $table ===');
    
    String raw = await f.readAsString();
    raw = raw
        .replaceAll('\ufeff', '')
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .replaceAll(RegExp(r'[\[\]]'), '');

    final cleanedLines = raw
        .split('\n')
        .where((l) => l.trim().isNotEmpty && !l.trimLeft().startsWith('#'))
        .toList();

    if (cleanedLines.length <= 1) {
      throw Exception('CSV appears empty after cleaning.');
    }

    // Parse CSV - process each line individually
    final listCsv = <List<dynamic>>[];
    for (final line in cleanedLines) {
      try {
        final parsed = const CsvToListConverter(shouldParseNumbers: false)
            .convert(line);
        if (parsed.isNotEmpty && parsed.first.isNotEmpty) {
          listCsv.add(parsed.first);
        }
      } catch (e) {
        print('Error parsing line: $line, error: $e');
      }
    }

    List<dynamic> header = listCsv.first.map((e) => e.toString().trim()).toList();
    final dataRows = listCsv.skip(1).where((r) => r.isNotEmpty).toList();
    
    if (dataRows.isEmpty) {
      throw Exception('No data rows found after header row.');
    }

    Map<String, int> columnMap = {};
    for (int i = 0; i < header.length; i++) {
      String colName = header[i].toString().toLowerCase();
      columnMap[colName] = i;
    }

    final batch = _.batch();
    int successfulInserts = 0;
    
    for (final row in dataRows) {
      try {
        if (table == 'lane') {
          int? frameIdx = columnMap['frame'];
          int? timestampIdx = columnMap['timestamp_ms'] ?? columnMap['timestamp'];
          int? offsetIdx = columnMap['lane_offset_px'];

          if (frameIdx != null && timestampIdx != null && offsetIdx != null && 
              row.length > frameIdx && row.length > timestampIdx && row.length > offsetIdx) {
            
            double timestamp = _toDouble(row[timestampIdx]);
            if (timestamp < 100000) {
              timestamp = timestamp / 1000.0;
            }
            
            batch.insert(table, {
              'frame': _toInt(row[frameIdx]),
              'timestamp': timestamp,
              'lane_offset_px': _toDouble(row[offsetIdx]),
            });
            successfulInserts++;
          }
        } else if (table == 'telemetry') {
          int? timestampIdx = columnMap['timestamp'];
          int? speedIdx = columnMap['speed_kmh'];
          int? throttleIdx = columnMap['throttle'];
          int? brakeIdx = columnMap['brake'];
          int? steerIdx = columnMap['steer'];

          if (timestampIdx != null && speedIdx != null && throttleIdx != null && 
              brakeIdx != null && steerIdx != null &&
              row.length > timestampIdx && row.length > speedIdx && 
              row.length > throttleIdx && row.length > brakeIdx && row.length > steerIdx) {
            
            batch.insert(table, {
              'timestamp': _toDouble(row[timestampIdx]),
              'speed_kmh': _toDouble(row[speedIdx]),
              'throttle': _toDouble(row[throttleIdx]),
              'brake': _toDouble(row[brakeIdx]),
              'steer': _toDouble(row[steerIdx]),
            });
            successfulInserts++;
          }
        }
      } catch (e) {
        print('Error processing row: $row, error: $e');
      }
    }

    if (successfulInserts == 0) {
      throw Exception('No valid rows found to import.');
    }

    await _.delete(table);
    await batch.commit(noResult: true);
    print('Successfully imported $successfulInserts rows into $table');
  }

  /* ───────── Session Management ───────── */
  /// Save a new session after processing.
  static Future<int> saveSession({
    required double score,
    required String teleFilePath,
    required String laneFilePath,
    required String teleFileName,
    required String laneFileName,
  }) async {
    // Insert the new row with consistent column names
    final id = await _.insert('sessions', {
      'date_created': DateTime.now().toIso8601String(),
      'score': score,
      'tele_file_path': teleFilePath,
      'lane_file_path': laneFilePath,
      'tele_file_name': teleFileName,
      'lane_file_name': laneFileName,
    });

    return id;
  }

  /// Get all sessions ordered by date (newest first)
  static Future<List<Map<String, dynamic>>> getAllSessions() async {
    try {
      return await _.rawQuery('''
        SELECT * FROM sessions 
        ORDER BY date_created DESC
      ''');
    } catch (e) {
      print('Error getting sessions: $e');
      // Try to recreate table if it's corrupted
      await _.execute('DROP TABLE IF EXISTS sessions');
      await _.execute('''
        CREATE TABLE sessions(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          date_created TEXT,
          score REAL,
          tele_file_path TEXT,
          lane_file_path TEXT,
          tele_file_name TEXT,
          lane_file_name TEXT
        );
      ''');
      return [];
    }
  }

  /// Get session by ID
  static Future<Map<String, dynamic>?> getSessionById(int id) async {
    final results = await _.rawQuery(
      'SELECT * FROM sessions WHERE id = ?',
      [id],
    );
    return results.isEmpty ? null : results.first;
  }

  /// Load lane data for a specific session (re-import from file)
  static Future<List<Map<String, dynamic>>> getSessionLaneData(int sessionId) async {
    final session = await getSessionById(sessionId);
    if (session == null) throw Exception('Session not found');

    final laneFile = File(session['lane_file_path']);
    if (!await laneFile.exists()) {
      throw Exception('Lane file no longer exists: ${session['lane_file_path']}');
    }

    // Clear current lane data and re-import
    await _.delete('lane');
    await importCsv(laneFile, 'lane');
    
    // Return the lane data
    return await _.rawQuery(
      'SELECT timestamp, lane_offset_px FROM lane ORDER BY timestamp'
    );
  }

  /// Delete a session
  static Future<void> deleteSession(int id) async {
    await _.delete('sessions', where: 'id = ?', whereArgs: [id]);
  }

  /* ───────── util ───────── */
  static Future<List<Map<String, dynamic>>> query(String sql) async =>
      _.rawQuery(sql);

  static int _toInt(dynamic v) =>
      v is int ? v : (double.tryParse(v.toString()) ?? 0).toInt();

  static double _toDouble(dynamic v) =>
      v is num ? v.toDouble() : double.tryParse(v.toString()) ?? 0.0;
}