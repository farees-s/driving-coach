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
  bool _isLoading = false;
  String _statusMessage = '';
  
  // Track uploaded files
  File? _telemetryFile;
  File? _laneFile;

  Future<void> _uploadCSV() async {
    try {
      setState(() {
        _isLoading = true;
        _statusMessage = 'Selecting CSV file...';
      });
      
      final picked = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );
      
      if (picked == null || picked.files.isEmpty) {
        setState(() {
          _isLoading = false;
          _statusMessage = 'No file selected';
        });
        return;
      }

      final file = File(picked.files.first.path!);
      final fileName = picked.files.first.name.toLowerCase();
      
      // Determine file type based on filename or let user choose
      bool? isTelemetry;
      
      if (fileName.contains('tele')) {
        isTelemetry = true;
      } else if (fileName.contains('lane')) {
        isTelemetry = false;
      } else {
        // Show dialog to let user specify file type
        isTelemetry = await _showFileTypeDialog();
        if (isTelemetry == null) {
          setState(() {
            _isLoading = false;
            _statusMessage = 'File upload cancelled';
          });
          return;
        }
      }
      
      // Store the file
      if (isTelemetry) {
        _telemetryFile = file;
        setState(() {
          _statusMessage = 'Telemetry file uploaded successfully!';
        });
      } else {
        _laneFile = file;
        setState(() {
          _statusMessage = 'Lane file uploaded successfully!';
        });
      }
      
      // Clear status message after 3 seconds
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() => _statusMessage = '');
        }
      });
      
    } catch (e) {
      setState(() => _statusMessage = 'Error uploading file: $e');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error uploading file: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<bool?> _showFileTypeDialog() async {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select File Type'),
          content: const Text('What type of CSV file is this?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Telemetry'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Lane Data'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _processData() async {
    if (_telemetryFile == null || _laneFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please upload both telemetry and lane CSV files first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      setState(() {
        _isLoading = true;
        _statusMessage = 'Processing data...';
      });
      
      // Import telemetry data
      setState(() => _statusMessage = 'Importing telemetry data...');
      await DBService.importCsv(_telemetryFile!, 'telemetry');
      
      // Import lane data
      setState(() => _statusMessage = 'Importing lane data...');
      await DBService.importCsv(_laneFile!, 'lane');

      // Query lane data
      setState(() => _statusMessage = 'Calculating metrics...');
      final rows = await DBService.query(
        'SELECT timestamp, lane_offset_px FROM lane ORDER BY timestamp'
      );

      if (rows.isNotEmpty) {
        // Calculate average absolute offset
        final avgAbs = rows.fold<double>(
          0, 
          (s, r) => s + (r['lane_offset_px'] as num).abs()
        ) / rows.length;

        setState(() {
          _offsetData = rows;
          _overallScore = (100 - avgAbs).clamp(0, 100);
          _statusMessage = 'Processing completed! ${rows.length} data points loaded.';
        });
        
        // Clear status message after 3 seconds
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            setState(() => _statusMessage = '');
          }
        });
      } else {
        setState(() => _statusMessage = 'No data found in lane file');
      }
    } catch (e) {
      setState(() => _statusMessage = 'Error processing data: $e');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error processing data: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _clearData() {
    setState(() {
      _telemetryFile = null;
      _laneFile = null;
      _offsetData = [];
      _overallScore = null;
      _statusMessage = 'Data cleared';
    });
    
    // Clear status message after 2 seconds
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() => _statusMessage = '');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool canProcess = _telemetryFile != null && _laneFile != null && !_isLoading;
    final bool hasData = _offsetData.isNotEmpty;

    return MaterialApp(
      title: 'Driving‑Coach Dashboard',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ),
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Driving Coach Dashboard'),
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // File upload section
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Upload CSV Files',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      
                      // File status indicators
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: _telemetryFile != null 
                                    ? Colors.green.shade50 
                                    : Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: _telemetryFile != null 
                                      ? Colors.green.shade200 
                                      : Colors.grey.shade300,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    _telemetryFile != null 
                                        ? Icons.check_circle 
                                        : Icons.radio_button_unchecked,
                                    color: _telemetryFile != null 
                                        ? Colors.green 
                                        : Colors.grey,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Telemetry CSV',
                                    style: TextStyle(
                                      color: _telemetryFile != null 
                                          ? Colors.green.shade700 
                                          : Colors.grey.shade600,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: _laneFile != null 
                                    ? Colors.green.shade50 
                                    : Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: _laneFile != null 
                                      ? Colors.green.shade200 
                                      : Colors.grey.shade300,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    _laneFile != null 
                                        ? Icons.check_circle 
                                        : Icons.radio_button_unchecked,
                                    color: _laneFile != null 
                                        ? Colors.green 
                                        : Colors.grey,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Lane CSV',
                                    style: TextStyle(
                                      color: _laneFile != null 
                                          ? Colors.green.shade700 
                                          : Colors.grey.shade600,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 12),
                      
                      // Upload button
                      ElevatedButton.icon(
                        onPressed: _isLoading ? null : _uploadCSV,
                        icon: _isLoading 
                            ? const SizedBox(
                                width: 20, 
                                height: 20, 
                                child: CircularProgressIndicator(strokeWidth: 2)
                              )
                            : const Icon(Icons.upload_file),
                        label: Text(_isLoading ? 'Uploading...' : 'Upload CSV File'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Process data section
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: canProcess ? _processData : null,
                      icon: const Icon(Icons.analytics),
                      label: const Text('Process Data'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        backgroundColor: canProcess 
                            ? Theme.of(context).colorScheme.primary
                            : null,
                        foregroundColor: canProcess 
                            ? Theme.of(context).colorScheme.onPrimary
                            : null,
                      ),
                    ),
                  ),
                  if (hasData || _telemetryFile != null || _laneFile != null) ...[
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _clearData,
                      icon: const Icon(Icons.clear),
                      label: const Text('Clear'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ],
                ],
              ),
              
              // Status message
              if (_statusMessage.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _statusMessage.startsWith('Error') 
                        ? Colors.red.shade50 
                        : Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _statusMessage.startsWith('Error') 
                          ? Colors.red.shade200 
                          : Colors.blue.shade200,
                    ),
                  ),
                  child: Text(
                    _statusMessage,
                    style: TextStyle(
                      color: _statusMessage.startsWith('Error') 
                          ? Colors.red.shade700 
                          : Colors.blue.shade700,
                    ),
                  ),
                ),
              ],
              
              const SizedBox(height: 24),
              
              // Overall score
              if (_overallScore != null) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Text(
                          'Overall Driving Score',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${_overallScore!.toStringAsFixed(1)}/100',
                          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                            color: _overallScore! >= 80 
                                ? Colors.green 
                                : _overallScore! >= 60 
                                    ? Colors.orange 
                                    : Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
              
              // Chart
              if (_offsetData.isNotEmpty)
                Expanded(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Lane Offset Over Time',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 16),
                          Expanded(child: OffsetChart(rows: _offsetData)),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}