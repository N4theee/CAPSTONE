import 'package:flutter/material.dart';

import 'professor_history_screen.dart';
import '../services/supabase_service.dart';
import 'professor_screen.dart';
import 'home_screen.dart';

class ProfessorDashboardScreen extends StatefulWidget {
  const ProfessorDashboardScreen({super.key, required this.user});

  final AppUser user;

  @override
  State<ProfessorDashboardScreen> createState() => _ProfessorDashboardScreenState();
}

class _ProfessorDashboardScreenState extends State<ProfessorDashboardScreen> {
  final _db = SupabaseService();
  bool _loading = true;
  List<SubjectOffering> _offerings = [];
  late String _displayName;

  @override
  void initState() {
    super.initState();
    _displayName = widget.user.fullName;
    _load();
  }

  Future<void> _load() async {
    final rows = await _db.getProfessorOfferings(widget.user.linkedId);
    if (mounted) {
      setState(() {
        _offerings = rows;
        _loading = false;
      });
    }
  }

  Future<void> _editName() async {
    final ctrl = TextEditingController(text: _displayName);
    final value = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Professor Name'),
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
      role: 'professor',
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
        title: Text('Professor Dashboard - $_displayName'),
        actions: [
          IconButton(
            tooltip: 'Edit Name',
            icon: const Icon(Icons.edit),
            onPressed: _editName,
          ),
          IconButton(
            tooltip: 'Session History',
            icon: const Icon(Icons.history),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      ProfessorHistoryScreen(professorId: widget.user.linkedId),
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
                    subtitle: Text('Section ${o.section}'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ProfessorScreen(
                            professorName: _displayName,
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
}
