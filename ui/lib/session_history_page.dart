import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'db_service.dart';
import 'session_detail_page.dart';

class SessionHistoryPage extends StatefulWidget {
  const SessionHistoryPage({super.key});

  @override
  State<SessionHistoryPage> createState() => _SessionHistoryPageState();
}

class _SessionHistoryPageState extends State<SessionHistoryPage> {
  List<Map<String, dynamic>> _sessions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    try {
      final s = await DBService.getAllSessions();
      setState(() {
        _sessions = s;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error loading sessions: $e')));
      }
    }
  }

  /* ───────── utils ───────── */
  String _formatDate(Map<String, dynamic> sess) {
    // All sessions now use 'date_created' with ISO format
    final iso = sess['date_created'] ?? '';
    try {
      return DateFormat('MMM d, yyyy · HH:mm').format(DateTime.parse(iso));
    } catch (_) {
      return iso.toString();
    }
  }

  Color _scoreColor(double v) =>
      v >= 80 ? Colors.green : v >= 60 ? Colors.orange : Colors.red;

  /* ───────── build ───────── */
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Session History'),
        backgroundColor: Colors.blueGrey,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _sessions.isEmpty
              ? const _EmptyPlaceholder()
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _sessions.length,
                  itemBuilder: (ctx, i) {
                    final s = _sessions[i];
                    final score = (s['score'] as num).toDouble();
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: _scoreColor(score),
                          child: Text('D${i + 1}',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold)),
                        ),
                        title: Text('Day ${i + 1}',
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_formatDate(s)),
                            const SizedBox(height: 4),
                            Text(
                              'Files: ${s['tele_file_name']}, ${s['lane_file_name']}',
                              style: TextStyle(
                                  color: Colors.grey[600], fontSize: 12),
                            ),
                          ],
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                              color: _scoreColor(score),
                              borderRadius: BorderRadius.circular(12)),
                          child: Text(score.toStringAsFixed(1),
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold)),
                        ),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => SessionDetailPage(
                                sessionId: s['id'],
                                dayNumber: i + 1,
                              )),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

/* ───────── empty state widget ───────── */
class _EmptyPlaceholder extends StatelessWidget {
  const _EmptyPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text('No sessions yet',
              style: TextStyle(fontSize: 18, color: Colors.grey)),
          SizedBox(height: 8),
          Text('Process some CSV files to see your driving history!',
              style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}