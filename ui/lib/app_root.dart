// app_root.dart
// Main dashboard + session history + optional DB reset.

import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'db_service.dart';
import 'offset_chart.dart';
import 'session_history_page.dart';

class AppRoot extends StatefulWidget {
  const AppRoot({super.key});
  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> {
  /* ───────── state ───────── */
  File? _laneFile, _teleFile;
  List<Map<String, dynamic>> _laneRows = [];
  double? _score;
  bool _busy = false;
  String _msg = '';

  // default browse folder on macOS
  static const _defaultDir =
      '/Users/foyezsiddiqui/Documents/assetoproject';

  /* ───────── file picker ───────── */
  Future<void> _pickCsv() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
      initialDirectory: _defaultDir,
      dialogTitle: 'Select a CSV file',
    );
    if (res == null) return;

    final file = File(res.files.single.path!);
    final name = res.files.single.name.toLowerCase();

    setState(() {
      if (name.contains('tele')) {
        _teleFile = file;
      } else {
        _laneFile = file;
      }
      _msg = '${res.files.single.name} selected';
    });
  }

  /* ───────── import + score ───────── */
  Future<void> _process() async {
    if (_laneFile == null || _teleFile == null) {
      _snack('Pick both lane and telemetry CSVs first', Colors.orange);
      return;
    }
    try {
      setState(() {
        _busy = true;
        _msg = 'Importing…';
      });

      await DBService.importCsv(_laneFile!, 'lane');
      await DBService.importCsv(_teleFile!, 'telemetry');

      final rows = await DBService.query(
          'SELECT timestamp,lane_offset_px FROM lane ORDER BY timestamp');
      if (rows.isEmpty) throw Exception('Lane table empty after import');

      /* ----- lane‑keeping score ----- */
      const frameCenter = 640.0;
      final avgDev = rows
              .map((r) =>
                  ((r['lane_offset_px'] as num).toDouble() - frameCenter).abs())
              .reduce((a, b) => a + b) /
          rows.length;

      double calcScore = (1 - avgDev / frameCenter) * 100;
      calcScore = calcScore.clamp(0, 100);
      /* ------------------------------ */

      setState(() {
        _laneRows = rows;
        _score = calcScore;
        _msg = 'Done – ${rows.length} pts';
      });

      /* ----- save session via DBService.saveSession ----- */
      await DBService.saveSession(
        score: _score!,
        teleFilePath: _teleFile!.path,
        laneFilePath: _laneFile!.path,
        teleFileName: _teleFile!.path.split('/').last,
        laneFileName: _laneFile!.path.split('/').last,
      );
      /* --------------------------------------------------- */
    } catch (e) {
      _snack('Failed: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /* ───────── helpers ───────── */
  void _snack(String txt, Color c) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(txt), backgroundColor: c));
  }

  Future<void> _resetDb() async {
    try {
      await DBService.query('DELETE FROM sessions');
      await DBService.query('DELETE FROM lane');
      await DBService.query('DELETE FROM telemetry');
      setState(() {
        _laneRows.clear();
        _score = null;
        _msg = 'Database cleared';
      });
    } catch (e) {
      _snack('Reset failed: $e', Colors.red);
    }
  }

  /* ───────── UI ───────── */
  @override
  Widget build(BuildContext context) {
    final ready = !_busy && _laneFile != null && _teleFile != null;

    return Scaffold(
      appBar: AppBar(title: const Text('Driving‑Coach Dashboard')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton.icon(
              onPressed: _busy ? null : _pickCsv,
              icon: const Icon(Icons.upload_file),
              label: const Text('Choose CSV'),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: ready ? _process : null,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Process'),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SessionHistoryPage()),
              ),
              icon: const Icon(Icons.history),
              label: const Text('Session History'),
            ),
            /* ---------- optional reset button ---------- */
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _busy ? null : _resetDb,
              icon: const Icon(Icons.delete_forever),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              label: const Text('Reset DB'),
            ),
            /* ------------------------------------------- */
            const SizedBox(height: 20),
            if (_msg.isNotEmpty) Text(_msg),
            if (_score != null) ...[
              const SizedBox(height: 20),
              Text('Score: ${_score!.toStringAsFixed(1)} / 100',
                  style: Theme.of(context).textTheme.headlineMedium),
            ],
            if (_laneRows.isNotEmpty) ...[
              const SizedBox(height: 20),
              Expanded(child: OffsetChart(rows: _laneRows)),
            ],
          ],
        ),
      ),
    );
  }
}
