import 'dart:io';
import 'package:csv/csv.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

 // this file genuinely makes me not like dart
 // a thing i did ask chat for was debug things since this file is a mess honestly
class DBService {
  static Database? _db;

  static Future<void> init() async { // db init
    if (_db != null) {
      return;
    }
    
    final path = join(await getDatabasesPath(), 'sessions.db');

    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        return _createSchema(db);
      },
    );
  }

  static Database get _database {
    if (_db == null) {
      throw Exception('Database not initialized');
    }
    return _db!;
  }

  // database schema that liens up with my csv
  static Future<void> _createSchema(Database db) async {
    await db.execute('''
      CREATE TABLE telemetry(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        timestamp REAL,
        speed_kmh REAL,
        throttle REAL,
        brake REAL,
        steer REAL
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
    
    // session table
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

  // csv inport
  static Future<void> importCsv(File file, String table) async {
    print('=== DEBUG: Starting CSV import for $table ==='); 
    // i was having issues with my csv files not being parsed correctly/unreadable so i asked chat for a fix
    // it did good for this
    String rawContent = await file.readAsString();
    rawContent = rawContent
        .replaceAll('\ufeff', '')
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .replaceAll(RegExp(r'[\[\]]'), '');

    final cleanedLines = rawContent
        .split('\n')
        .where((line) => line.trim().isNotEmpty && !line.trimLeft().startsWith('#'))
        .toList();

    if (cleanedLines.length <= 1) {
      throw Exception('CSV appears empty after cleaning.');
    }

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
    } // end chat

    List<dynamic> header = listCsv.first.map((element) => element.toString().trim()).toList();
    final dataRows = listCsv.skip(1).where((row) => row.isNotEmpty).toList();
    
    if (dataRows.isEmpty) {
      throw Exception('No data rows found after header row.');
    }

    Map<String, int> columnMap = {};
    for (int i = 0; i < header.length; i++) {
      String colName = header[i].toString().toLowerCase();
      columnMap[colName] = i;
    }

    final batch = _database.batch();
    int successfulInserts = 0;
    
    for (final row in dataRows) { // process each row
      try {
        if (table == 'lane') {
          int? frameIdx = columnMap['frame'];
          int? timestampIdx;
          
          if (columnMap['timestamp_ms'] != null) {
            timestampIdx = columnMap['timestamp_ms'];
          } else {
            timestampIdx = columnMap['timestamp'];
          }
          
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

    await _database.delete(table);
    await batch.commit(noResult: true);
    print('Successfully imported $successfulInserts rows into $table');
  }

  static Future<int> saveSession({ // saving a specific session
    required double score,
    required String teleFilePath,
    required String laneFilePath,
    required String teleFileName,
    required String laneFileName,
  }) async { // save to db
    final id = await _database.insert('sessions', {
      'date_created': DateTime.now().toIso8601String(),
      'score': score,
      'tele_file_path': teleFilePath,
      'lane_file_path': laneFilePath,
      'tele_file_name': teleFileName,
      'lane_file_name': laneFileName,
    });

    return id;
  }

  // getting all from db
  static Future<List<Map<String, dynamic>>> getAllSessions() async {
    try {
      return await _database.rawQuery('''
        SELECT * FROM sessions 
        ORDER BY date_created DESC
      ''');
    } catch (e) {
      print('Error getting sessions: $e');

      await _database.execute('DROP TABLE IF EXISTS sessions');
      await _database.execute('''
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

  static Future<Map<String, dynamic>?> getSessionById(int id) async { // get by id
    final results = await _database.rawQuery(
      'SELECT * FROM sessions WHERE id = ?',
      [id],
    );
    
    if (results.isEmpty) {
      return null;
    } else {
      return results.first;
    }
  }

  static Future<List<Map<String, dynamic>>> getSessionLaneData(int sessionId) async {
    final session = await getSessionById(sessionId);
    if (session == null) {
      throw Exception('Session not found');
    }

    final laneFile = File(session['lane_file_path']);
    if (!await laneFile.exists()) {
      throw Exception('Lane file no longer exists: ${session['lane_file_path']}');
    }

    await _database.delete('lane');
    await importCsv(laneFile, 'lane');
    
    return await _database.rawQuery(
      'SELECT timestamp, lane_offset_px FROM lane ORDER BY timestamp'
    );
  }

  static Future<void> deleteSession(int id) async { // delete by id
    await _database.delete('sessions', where: 'id = ?', whereArgs: [id]);
  }

  static Future<List<Map<String, dynamic>>> query(String sql) async { // raw query
    return _database.rawQuery(sql);
  }

  static int _toInt(dynamic value) { // convert to int
    if (value is int) {
      return value;
    } else {
      double? parsed = double.tryParse(value.toString());
      if (parsed != null) {
        return parsed.toInt();
      } else {
        return 0;
      }
    }
  }

  static double _toDouble(dynamic value) { // convert to double
    if (value is num) { 
      return value.toDouble();
    } else {
      double? parsed = double.tryParse(value.toString());
      if (parsed != null) {
        return parsed;
      } else {
        return 0.0;
      }
    }
  }
}
