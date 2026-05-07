import 'dart:async';

import 'package:flutter/material.dart';

import '../services/supabase_service.dart';
import '../ui/responsive.dart';
import '../widgets/course_dashboard_card.dart';
import 'home_screen.dart';
import 'student_history_screen.dart';
import 'student_screen.dart';

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
  Map<String, int> _enrollmentByOffering = {};
  StreamSubscription<List<SessionNotificationItem>>? _notificationSub;
  final List<SessionNotificationItem> _notifications = [];
  late String _displayName;

  static const _gradientTop = Color(0xFF0D9488);
  static const _gradientBottom = Color(0xFF115E59);
  static const _cardTop = Color(0xFF14B8A6);
  static const _cardTopBorder = Color(0xFF5EEAD4);

  @override
  void initState() {
    super.initState();
    _displayName = widget.user.fullName;
    _load();
    _listenForRealtimeNotifications();
  }

  Future<void> _load() async {
    final rows = await _db.getStudentOfferings(widget.user.linkedId);
    final counts = await _db.getEnrollmentCountsForOfferings(
      rows.map((e) => e.id).toList(),
    );
    if (mounted) {
      setState(() {
        _offerings = rows;
        _enrollmentByOffering = counts;
        _loading = false;
      });
    }
  }

  void _listenForRealtimeNotifications() {
    _notificationSub = _db
        .watchStudentSessionNotifications(widget.user.linkedId)
        .listen((items) {
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
        });
  }

  void _openNotifications() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        if (_notifications.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: SizedBox(
              height: 80,
              child: Center(child: Text('No notifications yet.')),
            ),
          );
        }
        final h = MediaQuery.sizeOf(ctx).height * 0.55;
        return SizedBox(
          height: h,
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemBuilder: (_, i) {
              final n = _notifications[i];
              final hh = n.startedAt.hour.toString().padLeft(2, '0');
              final mm = n.startedAt.minute.toString().padLeft(2, '0');
              return ListTile(
                leading: const Icon(Icons.campaign_outlined),
                title: Text('${n.subjectCode} - ${n.subjectTitle}'),
                subtitle: Text('Section ${n.section} • ${n.professorName}'),
                trailing: Text('$hh:$mm'),
              );
            },
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemCount: _notifications.length,
          ),
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Name updated.')));
  }

  void _signOut() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (_) => false,
    );
  }

  void _openHistory() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StudentHistoryScreen(studentId: widget.user.linkedId),
      ),
    );
  }

  Widget _buildHeader() {
    final iconColor = Colors.white.withValues(alpha: 0.95);
    final compact = AppBreakpoints.useCompactDashboardActions(context);

    final brand = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.wifi_tethering, color: iconColor, size: 26),
        const SizedBox(width: 8),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: const Text(
              'Attendximitty',
              maxLines: 1,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 20,
                letterSpacing: -0.5,
              ),
            ),
          ),
        ),
      ],
    );

    if (compact) {
      return Row(
        children: [
          Expanded(child: brand),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert_rounded, color: iconColor),
            color: const Color.fromARGB(255, 82, 189, 182),
            onSelected: (v) {
              if (v == 'notifications') {
                _openNotifications();
              } else if (v == 'edit') {
                _editName();
              } else if (v == 'refresh' && !_loading) {
                _load();
              } else if (v == 'history') {
                _openHistory();
              } else if (v == 'logout') {
                _signOut();
              }
            },
            itemBuilder: (ctx) => [
              PopupMenuItem(
                value: 'notifications',
                child: Text(
                  _notifications.isEmpty
                      ? 'Notifications'
                      : 'Notifications (${_notifications.length})',
                ),
              ),
              const PopupMenuItem(value: 'edit', child: Text('Edit name')),
              PopupMenuItem(
                value: 'refresh',
                enabled: !_loading,
                child: const Text('Refresh'),
              ),
              const PopupMenuItem(
                value: 'history',
                child: Text('Attendance history'),
              ),
              const PopupMenuItem(value: 'logout', child: Text('Sign out')),
            ],
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(child: brand),
        IconButton(
          tooltip: 'Notifications',
          onPressed: _openNotifications,
          icon: Badge(
            isLabelVisible: _notifications.isNotEmpty,
            label: Text('${_notifications.length}'),
            child: Icon(Icons.notifications_none_rounded, color: iconColor),
          ),
        ),
        IconButton(
          tooltip: 'Edit Name',
          onPressed: _editName,
          icon: Icon(Icons.edit_outlined, color: iconColor),
        ),
        IconButton(
          tooltip: 'Refresh',
          onPressed: _loading ? null : _load,
          icon: Icon(Icons.refresh_rounded, color: iconColor),
        ),
        IconButton(
          tooltip: 'Attendance History',
          onPressed: _openHistory,
          icon: Icon(Icons.history_rounded, color: iconColor),
        ),
        IconButton(
          tooltip: 'Sign out',
          onPressed: _signOut,
          icon: Icon(Icons.logout_rounded, color: iconColor),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final pad = AppBreakpoints.horizontalPadding(context);
    final cols = AppBreakpoints.courseGridColumns(context);
    final aspect = AppBreakpoints.courseGridChildAspectRatio(context, cols);
    final w = AppBreakpoints.width(context);
    final markSize = (w * 0.28).clamp(72.0, 120.0);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_gradientTop, _gradientBottom],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              Positioned(
                left: 0,
                right: 0,
                bottom: -20,
                child: IgnorePointer(
                  child: Text(
                    'ATX',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: markSize,
                      fontWeight: FontWeight.w900,
                      height: 0.85,
                      color: Colors.white.withValues(alpha: 0.07),
                    ),
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: pad, vertical: 8),
                    child: _buildHeader(),
                  ),
                  Expanded(
                    child: _loading
                        ? const Center(
                            child: CircularProgressIndicator(
                              color: Colors.white,
                            ),
                          )
                        : RefreshIndicator(
                            color: _gradientTop,
                            onRefresh: _load,
                            child: _offerings.isEmpty
                                ? ListView(
                                    physics:
                                        const AlwaysScrollableScrollPhysics(),
                                    children: const [
                                      SizedBox(height: 120),
                                      Center(
                                        child: Text(
                                          'No enrolled courses yet.',
                                          style: TextStyle(
                                            color: Colors.white70,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ),
                                    ],
                                  )
                                : GridView.builder(
                                    padding: EdgeInsets.fromLTRB(
                                      pad,
                                      8,
                                      pad,
                                      32,
                                    ),
                                    physics:
                                        const AlwaysScrollableScrollPhysics(),
                                    gridDelegate:
                                        SliverGridDelegateWithFixedCrossAxisCount(
                                          crossAxisCount: cols,
                                          mainAxisSpacing: 14,
                                          crossAxisSpacing: 14,
                                          childAspectRatio: aspect,
                                        ),
                                    itemCount: _offerings.length,
                                    itemBuilder: (_, i) {
                                      final o = _offerings[i];
                                      final n =
                                          _enrollmentByOffering[o.id] ?? 0;
                                      return CourseDashboardCard(
                                        title:
                                            '${o.subjectCode} - ${o.subjectTitle}',
                                        sectionLine: 'Section ${o.section}',
                                        footerLine:
                                            '$n ${n == 1 ? 'student' : 'students'}',
                                        cardTop: _cardTop,
                                        cardTopBorder: _cardTopBorder,
                                        footerBar: const Color(0xFF134E4A),
                                        footerText: Colors.white,
                                        chevron: Colors.white,
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
                                      );
                                    },
                                  ),
                          ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _notificationSub?.cancel();
    super.dispose();
  }
}
