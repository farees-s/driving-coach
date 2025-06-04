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
  State<AppRoot> createState() => AppRootState();
}

class AppRootState extends State<AppRoot> {
  
  File? laneFile;          
  File? teleFile;          
  List<Map<String, dynamic>> laneRows = []; 
  double? score;           
  bool busy = false;
  String msg = '';         

  static const defaultDir = '/Users/foyezsiddiqui/Documents/assetoproject';

  Future<void> pickVideo() async {
    final FilePickerResult? res = await FilePicker.platform.pickFiles(
      type: FileType.video,
      initialDirectory: defaultDir,
      dialogTitle: 'Select drive video',
    );

    if (res == null) return;

    final File video = File(res.files.single.path!);

    setState(() {
      busy = true;
      msg = 'Processing video…';
    });

    try {
      final String lanePath = await VideoService.processVideo(video); // video process call
      laneFile = File(lanePath);
      setState(() {
        msg = 'Video processed, waiting for telemetry CSV import';
      });
    } catch (e) {
      snack('Video error: $e', Colors.red);
    } finally {
      if (mounted) {
        setState(() {
          busy = false;
        });
      }
    }
  }

  Future<void> pickTelemetryCsv() async { //specifically csv selection
    final FilePickerResult? res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'], 
      initialDirectory: defaultDir,
      dialogTitle: 'Select telemetry.csv',
    );

    if (res == null) return;

    setState(() {
      teleFile = File(res.files.single.path!);
      msg = 'Telemetry CSV selected.';
    });
  }

  Future<void> processCsvs() async { // runns processing and scoring
    if (laneFile == null || teleFile == null) {
      snack('Please import both lane.csv and telemetry.csv first', Colors.orange);
      return;
    }

    setState(() {
      busy = true;
      msg = 'Processing & scoring…';
    });

    try {
      await DBService.importCsv(laneFile!, 'lane');
      await DBService.importCsv(teleFile!, 'telemetry');

      final List<Map<String, dynamic>> rows = await DBService.query(
          'SELECT timestamp, lane_offset_px FROM lane ORDER BY timestamp');

      if (rows.isEmpty) {
        throw Exception('Lane table is empty.');
      }

      const double frameCenter = 640.0;
      double sumDeviation = 0.0;

      for (var row in rows) {
        double offset = (row['lane_offset_px'] as num).toDouble();
        sumDeviation = sumDeviation + (offset - frameCenter).abs(); // for avg deviation
      }

      double avgDev = sumDeviation / rows.length; //  avg dev for lane offset scoring part
      double laneScore = (1 - avgDev / frameCenter) * 100;
      laneScore = laneScore.clamp(0.0, 100.0); // clamped

      // telemetry part of scoring
      final List<Map<String, dynamic>> teleRows = await DBService.query(
          'SELECT timestamp, steer FROM telemetry ORDER BY timestamp');
      double telePenalty = 0.0;
      if (teleRows.length > 1) {
        double sumSteerDiff = 0.0;
        for (int i = 1; i < teleRows.length; i++) {
          double prev = (teleRows[i - 1]['steer'] as num).toDouble();
          double curr = (teleRows[i]['steer'] as num).toDouble();
          sumSteerDiff += (curr - prev).abs(); // this makes it based on how smooth steering is
        }
        double avgSteerChange = sumSteerDiff / (teleRows.length - 1); // calcudiths
        double smoothScore = (1 - (avgSteerChange / 1.0)) * 100;
        smoothScore = smoothScore.clamp(0.0, 100.0);//clamp
        score = (laneScore * 0.7) + (smoothScore * 0.3);
      } else {
        score = laneScore; // THIS IS A FALLBACK IF NO TELEMETRY DATA
      }

      await DBService.saveSession( // save session so u can see in history
        score: score!,
        teleFilePath: teleFile!.path,
        laneFilePath: laneFile!.path,
        teleFileName: teleFile!.path.split('/').last,
        laneFileName: laneFile!.path.split('/').last,
      );

      setState(() {
        laneRows = rows;
        msg = 'Done, session saved';
      });
    } catch (e) {
      snack('Processing error: $e', Colors.red);
    } finally {
      if (mounted) {
        setState(() {
          busy = false;
        });
      }
    }
  }

  bool readyToProcess() { 
    return !busy && laneFile != null && teleFile != null;
  }

  void snack(String txt, Color c) { // THIS IS CHATGPT HELPER FOR DEBUGGING
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(txt),
        backgroundColor: c,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Driving Coach Dashboard'),
        actions: [
          IconButton( // this is the history button
            icon: const Icon(Icons.history),
            onPressed: () {
              Navigator.push( // navigate to history page
                context,
                MaterialPageRoute(
                  builder: (context) => const SessionHistoryPage(),
                ),
              );
            },
          ),
        ],
      ),
      body: Padding( // main ui
        padding: const EdgeInsets.all(16), // android ptsd lol
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch, // most of this is from docs
          children: [
            ElevatedButton.icon(
              onPressed: busy ? null : pickVideo,
              icon: const Icon(Icons.video_file),
              label: const Text('Import video'),
            ),
            const SizedBox(height: 12),

            ElevatedButton.icon(
              onPressed: busy ? null : pickTelemetryCsv,
              icon: const Icon(Icons.file_present),
              label: const Text('Import telemetry.csv'),
            ),
            const SizedBox(height: 12),

            ElevatedButton.icon(
              onPressed: readyToProcess() ? processCsvs : null,
              icon: const Icon(Icons.analytics),
              label: const Text('Process & Score'),
            ),
            const SizedBox(height: 20),

            if (msg.isNotEmpty) Text(msg),
            if (score != null) ...[
              const SizedBox(height: 20),
              Text(
                'Score: ${score!.toStringAsFixed(1)} / 100',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ],
            if (laneRows.isNotEmpty) ...[
              const SizedBox(height: 20),
              Expanded(child: OffsetChart(rows: laneRows)),
            ],
          ],
        ),
      ),
    );
  }
}
