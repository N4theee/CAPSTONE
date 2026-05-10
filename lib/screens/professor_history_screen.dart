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
    if (ok != true || !mounted) return;
    try {
      await _db.clearProfessorHistory(widget.professorId);
      if (!mounted) return;
      setState(() {
        _subjectFilter = null;
        _sectionFilter = null;
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

  Future<void> _openSessionAttendees(ProfessorSessionHistoryItem item) async {
    if (item.sessionId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Session details unavailable for this record.')),
      );
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(ctx).size.height * 0.72,
            child: FutureBuilder<List<SessionAttendanceDetailItem>>(
              future: _db.getSessionAttendeesForProfessor(
                professorId: widget.professorId,
                sessionId: item.sessionId,
              ),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text('Failed to load attendees: ${snap.error}'),
                    ),
                  );
                }
                final attendees = snap.data ?? const [];
                if (attendees.isEmpty) {
                  return const Center(
                    child: Text('No students attended this session.'),
                  );
                }
                return Column(
                  children: [
                    ListTile(
                      title: Text('${item.subjectCode} • Section ${item.section}'),
                      subtitle: const Text('Students attended in this session'),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: ListView.separated(
                        itemCount: attendees.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final a = attendees[i];
                          final hh = a.markedAt.hour.toString().padLeft(2, '0');
                          final mm = a.markedAt.minute.toString().padLeft(2, '0');
                          return ListTile(
                            leading: CircleAvatar(
                              child: Text(
                                a.studentName.isEmpty
                                    ? '?'
                                    : a.studentName[0].toUpperCase(),
                              ),
                            ),
                            title: Text(a.studentName),
                            subtitle: Text(
                              '${a.studentId}\nDevice used: ${a.deviceUsed}',
                            ),
                            isThreeLine: true,
                            trailing: Text('$hh:$mm'),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
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
                    LayoutBuilder(
                      builder: (context, c) {
                        final narrow = c.maxWidth < 480;
                        final subjectField = DropdownButtonFormField<String>(
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
                        );
                        final sectionField = DropdownButtonFormField<String>(
                          value: _sectionFilter ?? '',
                          decoration:
                              const InputDecoration(labelText: 'Section'),
                          isExpanded: true,
                          items: [
                            const DropdownMenuItem<String>(
                              value: '',
                              child: Text('All'),
                            ),
                            ..._history
                                .map((e) => e.section)
                                .toSet()
                                .map(
                                  (section) => DropdownMenuItem(
                                    value: section,
                                    child: Text(section),
                                  ),
                                ),
                          ],
                          onChanged: (v) => setState(
                            () => _sectionFilter =
                                (v == null || v.isEmpty) ? null : v,
                          ),
                        );
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                          child: narrow
                              ? Column(
                                  children: [
                                    subjectField,
                                    const SizedBox(height: 12),
                                    sectionField,
                                  ],
                                )
                              : Row(
                                  children: [
                                    Expanded(child: subjectField),
                                    const SizedBox(width: 10),
                                    Expanded(child: sectionField),
                                  ],
                                ),
                        );
                      },
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
                        onTap: () => _openSessionAttendees(item),
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
                          label: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(item.isActive ? 'Active' : 'Done'),
                          ),
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
