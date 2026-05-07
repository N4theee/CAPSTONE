import 'package:flutter/material.dart';

import '../services/supabase_service.dart';

class StudentHistoryScreen extends StatefulWidget {
  const StudentHistoryScreen({
    super.key,
    required this.studentId,
  });

  final String studentId;

  @override
  State<StudentHistoryScreen> createState() => _StudentHistoryScreenState();
}

class _StudentHistoryScreenState extends State<StudentHistoryScreen> {
  final _db = SupabaseService();
  bool _loading = true;
  String? _error;
  List<StudentAttendanceHistoryItem> _history = [];
  DateTimeRange? _dateRange;
  String? _subjectFilter;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await _db.getStudentAttendanceHistory(widget.studentId);
      if (!mounted) return;
      setState(() {
        _history = rows;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  String _fmt(DateTime dt) {
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final y = dt.year.toString();
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $hh:$mm';
  }

  List<StudentAttendanceHistoryItem> get _filteredHistory {
    return _history.where((item) {
      if (_dateRange != null) {
        final end = _dateRange!.end.add(const Duration(days: 1));
        if (item.markedAt.isBefore(_dateRange!.start) || !item.markedAt.isBefore(end)) {
          return false;
        }
      }
      if (_subjectFilter != null && _subjectFilter!.isNotEmpty) {
        if (item.subjectCode != _subjectFilter) return false;
      }
      return true;
    }).toList();
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 1),
      initialDateRange: _dateRange,
    );
    if (picked == null || !mounted) return;
    setState(() => _dateRange = picked);
  }

  Future<void> _clearHistory() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear History'),
        content: const Text('Delete all your attendance history? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Clear')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await _db.clearStudentHistory(widget.studentId);
      if (!mounted) return;
      setState(() {
        _subjectFilter = null;
        _dateRange = null;
      });
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('History cleared.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not clear history: $e')),
      );
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance History'),
        actions: [
          IconButton(
            tooltip: 'Filter by date',
            onPressed: _pickDateRange,
            icon: const Icon(Icons.date_range),
          ),
          IconButton(
            tooltip: 'Clear history',
            onPressed: _history.isEmpty ? null : _clearHistory,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Failed to load history.\n$_error',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: _load,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
          : _history.isEmpty
              ? const Center(
                  child: Text('No attendance history yet.'),
                )
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                      child: DropdownButtonFormField<String>(
                        value: _subjectFilter ?? '',
                        decoration:
                            const InputDecoration(labelText: 'Subject'),
                        isExpanded: true,
                        items: [
                          const DropdownMenuItem<String>(
                            value: '',
                            child: Text('All'),
                          ),
                          ..._history
                              .map((e) => e.subjectCode)
                              .toSet()
                              .map(
                                (code) => DropdownMenuItem(
                                  value: code,
                                  child: Text(code),
                                ),
                              ),
                        ],
                        onChanged: (v) => setState(
                          () => _subjectFilter =
                              (v == null || v.isEmpty) ? null : v,
                        ),
                      ),
                    ),
                    if (_dateRange != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Date: ${_fmt(_dateRange!.start)} to ${_fmt(_dateRange!.end)}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _filteredHistory.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final item = _filteredHistory[i];
                    return Card(
                      child: ListTile(
                        title: Text(
                          '${item.subjectCode} - ${item.subjectTitle}',
                        ),
                        subtitle: Text(
                          'Section ${item.section} • ${item.professorName}\n'
                          'Class started: ${_fmt(item.sessionStartedAt)}\n'
                          'You attended: ${_fmt(item.markedAt)}',
                        ),
                        isThreeLine: true,
                      ),
                    );
                  },
                ),
                    ),
                  ],
                ),
    );
  }
}
