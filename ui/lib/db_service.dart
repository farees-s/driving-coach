import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:csv/csv.dart';

class DBService {
  static late final Database _db;

  /// open (or create) the sessions.db file in the user‑documents folder
  static Future<void> init() async {
    final dir = await getApplicationDocumentsDirectory();
    final dbPath = '${dir.path}/sessions.db';
    _db = sqlite3.open(dbPath);

    // simple schema — extend as required
    _db.execute('''
      CREATE TABLE IF NOT EXISTS telemetry(
        timestamp     REAL,
        speed_kmh     REAL,
        throttle      REAL,
        brake         REAL,
        steer         REAL
      );
    ''');

    _db.execute('''
      CREATE TABLE IF NOT EXISTS lane(
        timestamp      REAL,
        lane_offset_px REAL
      );
    ''');
  }

  /// bulk‑insert a CSV file into `table`
  static Future<void> importCsv(File f, String table) async {
    final rows = const CsvToListConverter(eol: '\n').convert(await f.readAsString());
    if (rows.isEmpty) return;

    final cols = rows.first.cast<String>();    // header row
    final stmt = _db.prepare(
        'INSERT INTO $table (${cols.join(',')}) VALUES (${List.filled(cols.length, '?').join(',')});');

    for (var i = 1; i < rows.length; i++) {
      stmt.execute(rows[i]);
    }
    stmt.dispose();
  }

  /// run a SELECT and return the [ResultSet]
  static ResultSet query(String sql) => _db.select(sql);
}
