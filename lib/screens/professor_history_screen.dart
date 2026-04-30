import 'package:flutter/material.dart';

import '../services/supabase_service.dart';

class ProfessorHistoryScreen extends StatefulWidget {
  const ProfessorHistoryScreen({
    super.key,
    required this.professorId,
  });

  final String professorId;

  @override
  State<ProfessorHistoryScreen> createState() => _ProfessorHistoryScreenState();
}

class _ProfessorHistoryScreenState extends State<ProfessorHistoryScreen> {
  final _db = SupabaseService();
  bool _loading = true;
  String? _error;
  List<ProfessorSessionHistoryItem> _history = [];
  DateTimeRange? _dateRange;
  String? _subjectFilter;
  String? _sectionFilter;

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
      final rows = await _db.getProfessorSessionHistory(widget.professorId);
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

  List<ProfessorSessionHistoryItem> get _filteredHistory {
    return _history.where((item) {
      if (_dateRange != null) {
        final end = _dateRange!.end.add(const Duration(days: 1));
        if (item.startedAt.isBefore(_dateRange!.start) || !item.startedAt.isBefore(end)) {
          return false;
        }
      }
      if (_subjectFilter != null && _subjectFilter!.isNotEmpty) {
        if (item.subjectCode != _subjectFilter) return false;
      }
      if (_sectionFilter != null && _sectionFilter!.isNotEmpty) {
        if (item.section != _sectionFilter) return false;
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
        content: const Text('Delete all your session history? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Clear')),
        ],
      ),
    );
    if (ok != true) return;
    await _db.clearProfessorHistory(widget.professorId);
    if (!mounted) return;
    setState(() {
      _history = [];
      _subjectFilter = null;
      _sectionFilter = null;
      _dateRange = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('History cleared.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Session History'),
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
                  child: Text('No session history yet.'),
                )
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: _subjectFilter,
                              decoration: const InputDecoration(labelText: 'Subject'),
                              items: [
                                const DropdownMenuItem<String>(value: '', child: Text('All')),
                                ..._history
                                    .map((e) => e.subjectCode)
                                    .toSet()
                                    .toList()
                                    .map((code) => DropdownMenuItem(value: code, child: Text(code))),
                              ],
                              onChanged: (v) => setState(() => _subjectFilter = (v == null || v.isEmpty) ? null : v),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: _sectionFilter,
                              decoration: const InputDecoration(labelText: 'Section'),
                              items: [
                                const DropdownMenuItem<String>(value: '', child: Text('All')),
                                ..._history
                                    .map((e) => e.section)
                                    .toSet()
                                    .toList()
                                    .map((section) => DropdownMenuItem(value: section, child: Text(section))),
                              ],
                              onChanged: (v) => setState(() => _sectionFilter = (v == null || v.isEmpty) ? null : v),
                            ),
                          ),
                        ],
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
                          'Section ${item.section}\n'
                          'Started: ${_fmt(item.startedAt)}\n'
                          'Ended: ${item.endedAt == null ? 'In progress' : _fmt(item.endedAt!)}',
                        ),
                        isThreeLine: true,
                        trailing: Chip(
                          label: Text(item.isActive ? 'Active' : 'Done'),
                        ),
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
