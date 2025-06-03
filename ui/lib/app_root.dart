import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'video_service.dart';
import 'db_service.dart';
import 'offset_chart.dart';
import 'session_history_page.dart';

class AppRoot extends StatefulWidget {
  const AppRoot({super.key});
  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> {
  File? _laneFile, _teleFile;
  List<Map<String, dynamic>> _laneRows = [];
  double? _score;
  bool _busy = false;
  String _msg = '';

  static const _defaultDir = '/Users/foyezsiddiqui/Documents/assetoproject'; // specific folder

  Future<void> _pickVideo() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.video,
      initialDirectory: _defaultDir,
      dialogTitle: 'Select drive video',
    );
    if (res == null) return;
    final video = File(res.files.single.path!);

    setState(() {
      _busy = true;
      _msg = 'Processing video…';
    });

    try {
      final lanePath = await VideoService.processVideo(video);
      _laneFile = File(lanePath);
      setState(() {
        _msg = 'Video processed. Now import telemetry CSV.';
      });
    } catch (e) {
      _snack('Video error: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }


  Future<void> _pickTelemetryCsv() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
      initialDirectory: _defaultDir,
      dialogTitle: 'Select telemetry.csv',
    );
    if (res == null) return;
    setState(() {
      _teleFile = File(res.files.single.path!);
      _msg = 'Telemetry CSV selected.';
    });
  }

  Future<void> _syncAndScore() async {
    if (_laneFile == null || _teleFile == null) return;
    setState(() {
      _busy = true;
      _msg = 'Syncing & scoring…';
    });

    try {
      // Call sync.py to align lane.csv + telemetry.csv
      final result = await Process.run('python3', [
        '../backend/scripts/sync.py',
        _laneFile!.path,
        _teleFile!.path,
        '--horn-frame',
        '0',
        '--horn-row',
        '0',
      ]);
      if (result.exitCode != 0) {
        throw Exception('Sync failed: ${result.stderr}');
      }

      // Import both CSVs into SQLite
      await DBService.importCsv(_laneFile!, 'lane');
      await DBService.importCsv(_teleFile!, 'telemetry');

      // Compute lane-keeping score
      final rows = await DBService.query(
          'SELECT timestamp,lane_offset_px FROM lane ORDER BY timestamp');
      if (rows.isEmpty) throw Exception('Lane table is empty.');

      const frameCenter = 640.0;
      final avgDev = rows
          .map((r) =>
              ((r['lane_offset_px'] as num).toDouble() - frameCenter).abs())
          .reduce((a, b) => a + b) /
          rows.length;
      double calcScore = (1 - avgDev / frameCenter) * 100;
      calcScore = calcScore.clamp(0, 100);

      //Save session
      await DBService.saveSession(
        score: calcScore,
        teleFilePath: _teleFile!.path,
        laneFilePath: _laneFile!.path,
        teleFileName: _teleFile!.path.split('/').last,
        laneFileName: _laneFile!.path.split('/').last,
      );

      setState(() {
        _laneRows = rows;
        _score = calcScore;
        _msg = 'Done – session saved!';
      });
    } catch (e) {
      _snack('Sync/Score error: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  bool _readyToSync() => !_busy && _laneFile != null && _teleFile != null;

  void _snack(String txt, Color c) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(txt), backgroundColor: c));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Driving-Coach Dashboard')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Import video
            ElevatedButton.icon(
              onPressed: _busy ? null : _pickVideo,
              icon: const Icon(Icons.video_file),
              label: const Text('Import video'),
            ),
            const SizedBox(height: 12),

            // Import telemetry CSV
            ElevatedButton.icon(
              onPressed: _busy ? null : _pickTelemetryCsv,
              icon: const Icon(Icons.file_present),
              label: const Text('Import telemetry.csv'),
            ),
            const SizedBox(height: 12),

            // Sync & Score
            ElevatedButton.icon(
              onPressed: _readyToSync() ? _syncAndScore : null,
              icon: const Icon(Icons.analytics),
              label: const Text('Sync & Score'),
            ),
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
