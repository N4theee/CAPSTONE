import 'package:flutter/material.dart';

import '../services/supabase_service.dart';
import '../ui/professor_attendance_ui.dart';
import '../ui/responsive.dart';

class ProfessorSessionDetailScreen extends StatefulWidget {
  const ProfessorSessionDetailScreen({
    super.key,
    required this.professorId,
    required this.session,
  });

  final String professorId;
  final ProfessorSessionHistoryItem session;

  @override
  State<ProfessorSessionDetailScreen> createState() =>
      _ProfessorSessionDetailScreenState();
}

class _ProfessorSessionDetailScreenState
    extends State<ProfessorSessionDetailScreen> {
  final _db = SupabaseService();
  late Future<Map<String, dynamic>> _detailsFuture;

  @override
  void initState() {
    super.initState();
    _detailsFuture = _load();
  }

  void _retry() {
    setState(() => _detailsFuture = _load());
  }

  Future<Map<String, dynamic>> _load() async {
    final sessionId = widget.session.sessionId;
    final attendeesFuture = _db.getSessionAttendeesForProfessor(
      professorId: widget.professorId,
      sessionId: sessionId,
    );
    final anomaliesFuture = _db.getSessionDeviceAnomalies(sessionId);
    final attendees = await attendeesFuture;
    List<AttendanceAnomaly> anomalies;
    try {
      anomalies = await anomaliesFuture;
    } catch (_) {
      anomalies = const [];
    }
    return {'attendees': attendees, 'anomalies': anomalies};
  }

  @override
  Widget build(BuildContext context) {
    final pad = AppBreakpoints.horizontalPadding(context);
    final maxW = AppBreakpoints.historyContentMaxWidth(
      MediaQuery.sizeOf(context).width,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Session Details'),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _detailsFuture,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: EdgeInsets.all(pad),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Failed to load attendees.\n${snap.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _retry,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }
          final data = snap.data ?? const <String, dynamic>{};
          final attendees =
              (data['attendees'] as List<SessionAttendanceDetailItem>?) ??
                  const <SessionAttendanceDetailItem>[];
          final anomalies =
              (data['anomalies'] as List<AttendanceAnomaly>?) ??
                  const <AttendanceAnomaly>[];

          if (attendees.isEmpty) {
            return Center(
              child: Padding(
                padding: EdgeInsets.all(pad),
                child: const Text(
                  'No enrolled students for this class section.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: ProfessorAttendanceUi.textSecondary),
                ),
              ),
            );
          }

          return LayoutBuilder(
            builder: (context, constraints) {
              final useWide = constraints.maxWidth >= 720;
              final listPad = EdgeInsets.fromLTRB(pad, 0, pad, pad);

              final header = Padding(
                padding: EdgeInsets.fromLTRB(pad, 12, pad, 8),
                child: Align(
                  alignment: Alignment.center,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxW),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${widget.session.subjectCode} • Section ${widget.session.section}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Enrolled students — Absent if they did not mark attendance',
                          style: TextStyle(
                            color: ProfessorAttendanceUi.textSecondary
                                .withValues(alpha: 0.95),
                            fontSize: 13,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );

              final anomalyBox = anomalies.isNotEmpty
                  ? Padding(
                      padding: EdgeInsets.fromLTRB(pad, 0, pad, 12),
                      child: Align(
                        alignment: Alignment.center,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: maxW),
                          child: _AnomalyBanner(anomalies: anomalies),
                        ),
                      ),
                    )
                  : const SizedBox.shrink();

              final list = ListView.separated(
                padding: listPad,
                itemCount: attendees.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 10),
                itemBuilder: (_, i) {
                  return Align(
                    alignment: Alignment.center,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: maxW),
                      child: _AttendanceTile(
                        detail: attendees[i],
                        wideLayout: useWide,
                      ),
                    ),
                  );
                },
              );

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  header,
                  anomalyBox,
                  Expanded(child: list),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _AnomalyBanner extends StatelessWidget {
  const _AnomalyBanner({required this.anomalies});

  final List<AttendanceAnomaly> anomalies;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ProfessorAttendanceUi.anomalyRed.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: ProfessorAttendanceUi.anomalyRed.withValues(alpha: 0.85),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.error_outline_rounded,
                color: ProfessorAttendanceUi.anomalyRed,
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Anomaly detected',
                      style: TextStyle(
                        color: ProfessorAttendanceUi.anomalyRed,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'One device is being used by more than one student to mark attendance in this session.',
                      style: TextStyle(
                        color: ProfessorAttendanceUi.anomalyRed
                            .withValues(alpha: 0.92),
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Shared device',
            style: TextStyle(
              color: ProfessorAttendanceUi.anomalyRed.withValues(alpha: 0.95),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          ...anomalies.map((a) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    a.deviceLabel,
                    style: TextStyle(
                      color: ProfessorAttendanceUi.anomalyRed
                          .withValues(alpha: 0.88),
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: a.students
                        .map(
                          (s) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: ProfessorAttendanceUi.surface,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: ProfessorAttendanceUi.anomalyRed
                                    .withValues(alpha: 0.55),
                              ),
                            ),
                            child: Text(
                              s,
                              style: const TextStyle(
                                color: ProfessorAttendanceUi.anomalyRed,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _AttendanceTile extends StatelessWidget {
  const _AttendanceTile({
    required this.detail,
    required this.wideLayout,
  });

  final SessionAttendanceDetailItem detail;
  final bool wideLayout;

  @override
  Widget build(BuildContext context) {
    final initial = detail.studentName.isEmpty
        ? '?'
        : detail.studentName[0].toUpperCase();
    final timeStr = detail.isPresent && detail.markedAt != null
        ? _time(detail.markedAt!)
        : '—';

    final avatarBg = detail.isPresent
        ? ProfessorAttendanceUi.presentGreen.withValues(alpha: 0.22)
        : ProfessorAttendanceUi.absentOrange.withValues(alpha: 0.22);
    final avatarFg = detail.isPresent
        ? ProfessorAttendanceUi.presentGreen
        : ProfessorAttendanceUi.absentOrange;

    final badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: detail.isPresent
            ? ProfessorAttendanceUi.presentGreen.withValues(alpha: 0.2)
            : ProfessorAttendanceUi.absentOrange.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: detail.isPresent
              ? ProfessorAttendanceUi.presentGreen
              : ProfessorAttendanceUi.absentOrange,
          width: 1,
        ),
      ),
      child: Text(
        detail.isPresent ? 'Present' : 'Absent',
        style: TextStyle(
          color: detail.isPresent
              ? ProfessorAttendanceUi.presentGreen
              : ProfessorAttendanceUi.absentOrange,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );

    final subtitle = detail.isPresent
        ? 'Device: ${detail.deviceUsed ?? 'Unknown'}'
        : 'Did not mark attendance';

    final textBlock = Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            detail.studentName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              color: ProfessorAttendanceUi.textSecondary,
              fontSize: 12,
              height: 1.3,
            ),
            maxLines: wideLayout ? 2 : 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            timeStr,
            style: const TextStyle(
              color: ProfessorAttendanceUi.textSecondary,
              fontSize: 12,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );

    return Material(
      color: ProfessorAttendanceUi.surface,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: wideLayout ? 18 : 14,
          vertical: 14,
        ),
        child: wideLayout
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: avatarBg,
                    child: Text(
                      initial,
                      style: TextStyle(
                        color: avatarFg,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  textBlock,
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [badge],
                  ),
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: avatarBg,
                    child: Text(
                      initial,
                      style: TextStyle(
                        color: avatarFg,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  textBlock,
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [badge],
                  ),
                ],
              ),
      ),
    );
  }

  String _time(DateTime dt) {
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }
}
