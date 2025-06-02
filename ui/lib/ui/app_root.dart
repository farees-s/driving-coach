import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../db_service.dart';
import '../offset_chart.dart';

class AppRoot extends StatefulWidget {
  const AppRoot({super.key});

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> {
  List<Map<String, dynamic>> _offsetData = [];
  double? _overallScore;

  Future<void> _import() async {
    final picked = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );
    if (picked == null) return;

    final files = picked.paths.map((p) => File(p!)).toList();
    final tele = files.firstWhere((f) => f.path.contains('tele'), orElse: () => files.first);
    final lane = files.firstWhere((f) => f.path.contains('lane'), orElse: () => files.last);

    await DBService.importCsv(tele, 'telemetry');
    await DBService.importCsv(lane, 'lane');

    final rs = DBService.query('SELECT timestamp,lane_offset_px FROM lane ORDER BY timestamp');

    final rows = List.generate(rs.rows.length, (i) {
      final r = rs.rows[i];
      return {
        rs.columnName(0): r[0],
        rs.columnName(1): r[1],
      };
    });

    final avgAbs = rows.fold<double>(0, (s, r) => s + (r['lane_offset_px'] as num).abs()) / rows.length;

    setState(() {
      _offsetData = rows.cast<Map<String, dynamic>>();
      _overallScore = (100 - avgAbs).clamp(0, 100);
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Driving‑Coach Dashboard',
      theme: ThemeData(useMaterial3: true),
      home: Scaffold(
        appBar: AppBar(title: const Text('Dashboard')),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              ElevatedButton.icon(
                onPressed: _import,
                icon: const Icon(Icons.upload_file),
                label: const Text('Import CSV files'),
              ),
              const SizedBox(height: 24),
              if (_overallScore != null)
                Text('Overall Score: ${_overallScore!.toStringAsFixed(1)}',
                    style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 24),
              if (_offsetData.isNotEmpty)
                Expanded(child: OffsetChart(rows: _offsetData)),
            ],
          ),
        ),
      ),
    );
  }
}
