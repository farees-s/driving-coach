import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'db_service.dart';
import 'offset_chart.dart';

class SessionDetailPage extends StatefulWidget {
  final int sessionId;
  final int dayNumber;

  const SessionDetailPage({
    super.key,
    required this.sessionId,
    required this.dayNumber,
  });

  @override
  State<SessionDetailPage> createState() => _SessionDetailPageState();
}

class _SessionDetailPageState extends State<SessionDetailPage> {
  Map<String, dynamic>? _session;
  List<Map<String, dynamic>> _laneData = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSessionDetail();
  }

  Future<void> _loadSessionDetail() async {
    try {
      setState(() => _loading = true);
      
      // Load session info
      final session = await DBService.getSessionById(widget.sessionId);
      if (session == null) {
        throw Exception('Session not found');
      }

      // Load lane data for this session
      final laneData = await DBService.getSessionLaneData(widget.sessionId);

      setState(() {
        _session = session;
        _laneData = laneData;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  String _formatDate(String isoDate) {
    try {
      final date = DateTime.parse(isoDate);
      return DateFormat('EEEE, MMM dd, yyyy at HH:mm').format(date);
    } catch (e) {
      return isoDate;
    }
  }

  Color _getScoreColor(double score) {
    if (score >= 80) return Colors.green;
    if (score >= 60) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Day ${widget.dayNumber} Details'),
        backgroundColor: Colors.blueGrey,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error, size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      Text(
                        'Error loading session',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadSessionDetail,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _session == null
                  ? const Center(child: Text('Session not found'))
                  : Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Session Info Card
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 30,
                                        backgroundColor: _getScoreColor(
                                          (_session!['score'] as num).toDouble(),
                                        ),
                                        child: Text(
                                          'D${widget.dayNumber}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 18,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Day ${widget.dayNumber}',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .headlineSmall,
                                            ),
                                            Text(
                                              _formatDate(_session!['date_created']),
                                              style: const TextStyle(
                                                color: Colors.grey,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          color: _getScoreColor(
                                            (_session!['score'] as num).toDouble(),
                                          ),
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                        child: Text(
                                          '${(_session!['score'] as num).toStringAsFixed(1)} / 100',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  const Divider(),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Files Used:',
                                    style: Theme.of(context).textTheme.titleSmall,
                                  ),
                                  const SizedBox(height: 4),
                                  Text('• Telemetry: ${_session!['tele_file_name']}'),
                                  Text('• Lane: ${_session!['lane_file_name']}'),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Data Points: ${_laneData.length}',
                                    style: const TextStyle(color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Chart Section
                          Text(
                            'Lane Offset Chart',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            child: _laneData.isEmpty
                                ? const Center(
                                    child: Text(
                                      'No lane data available',
                                      style: TextStyle(color: Colors.grey),
                                    ),
                                  )
                                : Card(
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: OffsetChart(rows: _laneData),
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ),
    );
  }
}