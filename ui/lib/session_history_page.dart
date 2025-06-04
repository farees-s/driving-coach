import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'db_service.dart';
import 'session_detail_page.dart';

class SessionHistoryPage extends StatefulWidget {
  const SessionHistoryPage({super.key});

  @override
  State<SessionHistoryPage> createState() { // make state
    return _SessionHistoryPageState();
  }
}

class _SessionHistoryPageState extends State<SessionHistoryPage> {
  List<Map<String, dynamic>> _sessions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async { // load sessions
    try {
      final List<Map<String, dynamic>> sessions = await DBService.getAllSessions(); // this reminds me so much of mobilea pp lol
      setState(() {
        _sessions = sessions;
        _loading = false;
      });
    } catch (error) {
      setState(() {
        _loading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading sessions: $error'),
          ),
        );
      }
    }
  }

  String _formatDate(Map<String, dynamic> session) {
    final String iso = session['date_created'] ?? '';
    try {
      DateTime dateTime = DateTime.parse(iso);
      return DateFormat('MMM d, yyyy · HH:mm').format(dateTime);
    } catch (error) {
      return iso.toString();
    }
  }

  Color _scoreColor(double value) {
    if (value >= 80) {
      return Colors.green;
    } else if (value >= 60) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }

  @override
  Widget build(BuildContext context) { // build the UI, lots of documentation for how to build a UI in flutter
    return Scaffold(
      appBar: AppBar(
        title: const Text('Session History'),
        backgroundColor: Colors.blueGrey,
        foregroundColor: Colors.white,
      ),
      body: Builder(
        builder: (context) {
          if (_loading) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }
          
          if (_sessions.isEmpty) {
            return const _EmptyPlaceholder();
          }
          
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _sessions.length,
            itemBuilder: (BuildContext context, int index) {
              Map<String, dynamic> session = _sessions[index];
              double score = (session['score'] as num).toDouble();

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: _scoreColor(score),
                    child: Text(
                      'D${index + 1}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(
                    'Day ${index + 1}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_formatDate(session)),
                      const SizedBox(height: 4),
                      Text(
                        'Files: ${session['tele_file_name']}, ${session['lane_file_name']}',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _scoreColor(score),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      score.toStringAsFixed(1),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (BuildContext context) {
                          return SessionDetailPage(
                            sessionId: session['id'],
                            dayNumber: index + 1,
                          );
                        },
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _EmptyPlaceholder extends StatelessWidget {
  const _EmptyPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history,
            size: 64,
            color: Colors.grey,
          ),
          SizedBox(height: 16),
          Text(
            'No sessions yet',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Process some CSV files to see your driving history!',
            style: TextStyle(
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}