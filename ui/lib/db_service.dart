import 'dart:io';
import 'package:csv/csv.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DBService {
  static Database? _db;

  /// Initialize the database
  static Future<void> init() async {
    if (_db != null) return;

    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'sessions.db');

    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        // Create telemetry table
        await db.execute('''
          CREATE TABLE telemetry (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            timestamp REAL,
            speed_kmh REAL,
            throttle REAL,
            brake REAL,
            steer REAL
          )
        ''');

        // Create lane table
        await db.execute('''
          CREATE TABLE lane (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            frame INTEGER,
            timestamp REAL,
            lane_offset_px REAL
          )
        ''');
      },
    );
  }

  /// Get database instance
  static Database get db {
    if (_db == null) {
      throw Exception('Database not initialized. Call DBService.init() first.');
    }
    return _db!;
  }

  /// Import CSV file into specified table
  static Future<void> importCsv(File csvFile, String tableName) async {
    try {
      final csvContent = await csvFile.readAsString();
      final List<List<dynamic>> csvData = const CsvToListConverter().convert(csvContent);
      
      if (csvData.isEmpty) return;
      
      // Clear existing data for this table
      await db.delete(tableName);
      
      // Prepare batch insert
      final batch = db.batch();
      
      // Get header row to understand the structure
      final headers = csvData.first.map((h) => h.toString().toLowerCase().trim()).toList();
      print('CSV Headers for $tableName: $headers');
      
      // Skip header row and insert data
      for (int i = 1; i < csvData.length; i++) {
        final row = csvData[i];
        if (row.isEmpty) continue;
        
        if (tableName == 'lane') {
          // Expected format: frame,timestamp_ms,lane_offset_px
          // Or handle different column orders
          int frameIndex = _findColumnIndex(headers, ['frame']);
          int timestampIndex = _findColumnIndex(headers, ['timestamp_ms', 'timestamp']);
          int offsetIndex = _findColumnIndex(headers, ['lane_offset_px', 'offset']);
          
          if (frameIndex != -1 && timestampIndex != -1 && offsetIndex != -1) {
            batch.insert('lane', {
              'frame': _parseInt(row[frameIndex]),
              'timestamp': _parseDouble(row[timestampIndex]) / 1000.0, // Convert ms to seconds
              'lane_offset_px': _parseDouble(row[offsetIndex]),
            });
          } else {
            // Fallback: assume columns are in order
            if (row.length >= 3) {
              batch.insert('lane', {
                'frame': _parseInt(row[0]),
                'timestamp': _parseDouble(row[1]) / 1000.0, // Convert ms to seconds
                'lane_offset_px': _parseDouble(row[2]),
              });
            }
          }
        } else if (tableName == 'telemetry') {
          // Expected format: timestamp,speed_kmh,throttle,brake,steer
          int timestampIndex = _findColumnIndex(headers, ['timestamp']);
          int speedIndex = _findColumnIndex(headers, ['speed_kmh', 'speed']);
          int throttleIndex = _findColumnIndex(headers, ['throttle']);
          int brakeIndex = _findColumnIndex(headers, ['brake']);
          int steerIndex = _findColumnIndex(headers, ['steer', 'steering']);
          
          if (timestampIndex != -1 && speedIndex != -1 && throttleIndex != -1 && 
              brakeIndex != -1 && steerIndex != -1) {
            batch.insert('telemetry', {
              'timestamp': _parseDouble(row[timestampIndex]),
              'speed_kmh': _parseDouble(row[speedIndex]),
              'throttle': _parseDouble(row[throttleIndex]),
              'brake': _parseDouble(row[brakeIndex]),
              'steer': _parseDouble(row[steerIndex]),
            });
          } else {
            // Fallback: assume columns are in order
            if (row.length >= 5) {
              batch.insert('telemetry', {
                'timestamp': _parseDouble(row[0]),
                'speed_kmh': _parseDouble(row[1]),
                'throttle': _parseDouble(row[2]),
                'brake': _parseDouble(row[3]),
                'steer': _parseDouble(row[4]),
              });
            }
          }
        }
      }
      
      // Execute batch insert
      await batch.commit(noResult: true);
      print('Successfully imported ${csvData.length - 1} rows into $tableName');
    } catch (e) {
      print('Error importing CSV: $e');
      rethrow;
    }
  }

  /// Helper method to find column index by name variations
  static int _findColumnIndex(List<String> headers, List<String> possibleNames) {
    for (String name in possibleNames) {
      for (int i = 0; i < headers.length; i++) {
        if (headers[i].contains(name.toLowerCase())) {
          return i;
        }
      }
    }
    return -1;
  }

  /// Helper method to safely parse integers
  static int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) {
      return int.tryParse(value) ?? 0;
    }
    return 0;
  }

  /// Helper method to safely parse doubles
  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      return double.tryParse(value) ?? 0.0;
    }
    return 0.0;
  }

  /// Query method that returns List<Map<String, dynamic>>
  static Future<List<Map<String, dynamic>>> query(String sql, [List<Object?> params = const []]) async {
    return await db.rawQuery(sql, params);
  }

  /// Insert a row into a table
  static Future<int> insert(String table, Map<String, Object?> row) async {
    return await db.insert(table, row);
  }

  /// Update rows in a table
  static Future<int> update(String table, Map<String, Object?> values, {String? where, List<Object?>? whereArgs}) async {
    return await db.update(table, values, where: where, whereArgs: whereArgs);
  }

  /// Delete rows from a table
  static Future<int> delete(String table, {String? where, List<Object?>? whereArgs}) async {
    return await db.delete(table, where: where, whereArgs: whereArgs);
  }

  /// Close the database
  static Future<void> dispose() async {
    await _db?.close();
    _db = null;
  }
}