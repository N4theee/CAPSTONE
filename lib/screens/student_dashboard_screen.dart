import 'package:flutter/material.dart';
import 'dart:async';

import 'student_history_screen.dart';
import '../services/supabase_service.dart';
import 'student_screen.dart';
import 'home_screen.dart';

class StudentDashboardScreen extends StatefulWidget {
  const StudentDashboardScreen({super.key, required this.user});

  final AppUser user;

  @override
  State<StudentDashboardScreen> createState() => _StudentDashboardScreenState();
}

class _StudentDashboardScreenState extends State<StudentDashboardScreen> {
  final _db = SupabaseService();
  bool _loading = true;
  List<SubjectOffering> _offerings = [];
  StreamSubscription<List<SessionNotificationItem>>? _notificationSub;
  final List<SessionNotificationItem> _notifications = [];
  late String _displayName;

  @override
  void initState() {
    super.initState();
    _displayName = widget.user.fullName;
    _load();
    _listenForRealtimeNotifications();
  }

  Future<void> _load() async {
    final rows = await _db.getStudentOfferings(widget.user.linkedId);
    if (mounted) {
      setState(() {
        _offerings = rows;
        _loading = false;
      });
    }
  }

  void _listenForRealtimeNotifications() {
    _notificationSub =
        _db.watchStudentSessionNotifications(widget.user.linkedId).listen(
      (items) {
        if (!mounted || items.isEmpty) return;
        setState(() {
          _notifications.insertAll(0, items);
        });
        final latest = items.first;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'New session started: ${latest.subjectCode} ${latest.section}',
            ),
          ),
        );
      },
    );
  }

  void _openNotifications() {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) {
        if (_notifications.isEmpty) {
          return const SizedBox(
            height: 120,
            child: Center(child: Text('No notifications yet.')),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemBuilder: (_, i) {
            final n = _notifications[i];
            final hh = n.startedAt.hour.toString().padLeft(2, '0');
            final mm = n.startedAt.minute.toString().padLeft(2, '0');
            return ListTile(
              leading: const Icon(Icons.campaign_outlined),
              title: Text('${n.subjectCode} - ${n.subjectTitle}'),
              subtitle: Text(
                'Section ${n.section} • ${n.professorName}',
              ),
              trailing: Text('$hh:$mm'),
            );
          },
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemCount: _notifications.length,
        );
      },
    );
  }

  Future<void> _editName() async {
    final ctrl = TextEditingController(text: _displayName);
    final value = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Student Name'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(labelText: 'Full Name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (value == null || value.isEmpty || value == _displayName) return;
    await _db.updateDisplayName(
      role: 'student',
      linkedId: widget.user.linkedId,
      fullName: value,
    );
    if (!mounted) return;
    setState(() => _displayName = value);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Name updated.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Student Dashboard - $_displayName'),
        actions: [
          IconButton(
            tooltip: 'Notifications',
            icon: Badge.count(
              count: _notifications.length,
              isLabelVisible: _notifications.isNotEmpty,
              child: const Icon(Icons.notifications_none),
            ),
            onPressed: _openNotifications,
          ),
          IconButton(
            tooltip: 'Edit Name',
            icon: const Icon(Icons.edit),
            onPressed: _editName,
          ),
          IconButton(
            tooltip: 'Attendance History',
            icon: const Icon(Icons.history),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      StudentHistoryScreen(studentId: widget.user.linkedId),
                ),
              );
            },
          ),
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const HomeScreen()),
                (_) => false,
              );
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _offerings.length,
              itemBuilder: (_, i) {
                final o = _offerings[i];
                return Card(
                  child: ListTile(
                    title: Text('${o.subjectCode} - ${o.subjectTitle}'),
                    subtitle: Text(
                      '$_displayName • Section ${o.section} • ${o.professorName}',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => StudentScreen(
                            studentId: widget.user.linkedId,
                            studentName: _displayName,
                            offering: o,
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
    );
  }

  @override
  void dispose() {
    _notificationSub?.cancel();
    super.dispose();
  }
}
