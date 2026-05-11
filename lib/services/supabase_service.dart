import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AppUser {
  const AppUser({
    required this.role,
    required this.linkedId,
    required this.fullName,
    required this.username,
  });

  final String role;
  final String linkedId;
  final String fullName;
  final String username;
}

class SubjectOffering {
  const SubjectOffering({
    required this.id,
    required this.subjectCode,
    required this.subjectTitle,
    required this.section,
    required this.professorId,
    required this.professorName,
    required this.beaconUuid,
    required this.beaconName,
  });

  final String id;
  final String subjectCode;
  final String subjectTitle;
  final String section;
  final String professorId;
  final String professorName;
  final String beaconUuid;
  final String beaconName;

  String get label => '$subjectCode ($section)';
}

class StudentBasic {
  const StudentBasic({
    required this.id,
    required this.fullName,
  });

  final String id;
  final String fullName;
}

class ProfessorBasic {
  const ProfessorBasic({
    required this.id,
    required this.fullName,
  });

  final String id;
  final String fullName;
}

class ProfessorSessionHistoryItem {
  const ProfessorSessionHistoryItem({
    required this.sessionId,
    required this.subjectCode,
    required this.subjectTitle,
    required this.section,
    required this.startedAt,
    required this.endedAt,
    required this.isActive,
  });

  final String sessionId;
  final String subjectCode;
  final String subjectTitle;
  final String section;
  final DateTime startedAt;
  final DateTime? endedAt;
  final bool isActive;
}

class SessionAttendanceDetailItem {
  const SessionAttendanceDetailItem({
    required this.studentId,
    required this.studentName,
    required this.markedAt,
    required this.deviceUsed,
  });

  final String studentId;
  final String studentName;
  final DateTime markedAt;
  final String deviceUsed;
}

class StudentAttendanceHistoryItem {
  const StudentAttendanceHistoryItem({
    required this.subjectCode,
    required this.subjectTitle,
    required this.section,
    required this.professorName,
    required this.sessionStartedAt,
    required this.markedAt,
  });

  final String subjectCode;
  final String subjectTitle;
  final String section;
  final String professorName;
  final DateTime sessionStartedAt;
  final DateTime markedAt;
}

class EnrollmentRecord {
  const EnrollmentRecord({
    required this.studentId,
    required this.studentName,
    required this.offeringId,
    required this.professorId,
    required this.professorName,
    required this.subjectCode,
    required this.subjectTitle,
    required this.section,
  });

  final String studentId;
  final String studentName;
  final String offeringId;
  final String professorId;
  final String professorName;
  final String subjectCode;
  final String subjectTitle;
  final String section;

  String get label =>
      '$studentName ($studentId) -> $subjectCode $section ($professorName)';
}

class AdminAttendanceReportItem {
  const AdminAttendanceReportItem({
    required this.sessionId,
    required this.sessionStartedAt,
    required this.sessionEndedAt,
    required this.subjectCode,
    required this.subjectTitle,
    required this.section,
    required this.professorId,
    required this.professorName,
    required this.studentId,
    required this.studentName,
    required this.markedAt,
    required this.deviceName,
    required this.deviceMac,
    required this.deviceFingerprint,
  });

  final String sessionId;
  final DateTime sessionStartedAt;
  final DateTime? sessionEndedAt;
  final String subjectCode;
  final String subjectTitle;
  final String section;
  final String professorId;
  final String professorName;
  final String studentId;
  final String studentName;
  final DateTime markedAt;
  final String? deviceName;
  final String? deviceMac;
  final String? deviceFingerprint;
}

class AttendanceAnomaly {
  const AttendanceAnomaly({
    required this.deviceLabel,
    required this.deviceUuid,
    required this.students,
  });

  final String deviceLabel;
  final String deviceUuid;
  final List<String> students;
}

class SessionNotificationItem {
  const SessionNotificationItem({
    required this.sessionId,
    required this.offeringId,
    required this.subjectCode,
    required this.subjectTitle,
    required this.section,
    required this.professorName,
    required this.startedAt,
  });

  final String sessionId;
  final String offeringId;
  final String subjectCode;
  final String subjectTitle;
  final String section;
  final String professorName;
  final DateTime startedAt;
}

class SupabaseService {
  static final SupabaseService _i = SupabaseService._();
  factory SupabaseService() => _i;
  SupabaseService._();

  final _db = Supabase.instance.client;

  // ── AUTH + ADMIN ───────────────────────────────────────────

  Future<AppUser?> login({
    required String username,
    required String password,
    required String role,
  }) async {
    final raw = await _db.rpc(
      'app_login',
      params: {
        'p_username': username.trim(),
        'p_password': password.trim(),
        'p_role': role.trim(),
      },
    );
    if (raw is! List || raw.isEmpty) return null;
    final row = raw.first as Map<String, dynamic>;
    return AppUser(
      role: row['role'] as String,
      linkedId: row['linked_id'] as String,
      fullName: row['full_name'] as String,
      username: row['username'] as String,
    );
  }

  Future<String> registerStudent({
    required String studentId,
    required String fullName,
    required String username,
    required String password,
    String? deviceUuid,
    String? deviceName,
  }) async {
    final baseParams = {
      'p_student_id': studentId.trim(),
      'p_full_name': fullName.trim(),
      'p_username': username.trim(),
      'p_password': password.trim(),
    };
    try {
      final result = await _db.rpc(
        'register_student',
        params: {
          ...baseParams,
          'p_device_uuid': deviceUuid,
          'p_device_name': deviceName?.trim(),
        },
      );
      return result as String;
    } on PostgrestException catch (e) {
      if (e.code != 'PGRST202') rethrow;
      final result = await _db.rpc(
        'register_student',
        params: baseParams,
      );
      return result as String;
    }
  }

  Future<List<StudentBasic>> getAllStudents() async {
    final rows = await _db
        .from('students')
        .select('id, full_name')
        .order('full_name');
    return rows
        .map((e) => StudentBasic(
              id: e['id'] as String,
              fullName: e['full_name'] as String,
            ))
        .toList();
  }

  Future<List<ProfessorBasic>> getAllProfessors() async {
    final rows = await _db.from('professors').select('id, full_name').order(
          'full_name',
        );
    return rows
        .map((e) => ProfessorBasic(
              id: e['id'] as String,
              fullName: e['full_name'] as String,
            ))
        .toList();
  }

  Future<String> createProfessorByAdmin({
    required String professorId,
    required String fullName,
    required String username,
    required String password,
    int maxStudents = 30,
  }) async {
    final params = {
      'p_professor_id': professorId.trim(),
      'p_full_name': fullName.trim(),
      'p_username': username.trim(),
      'p_password': password.trim(),
      'p_max_students': maxStudents,
    };
    try {
      final result = await _db.rpc(
        'admin_create_professor_account',
        params: params,
      );
      return result as String;
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST202') {
        throw Exception(
          'Database function missing. Run latest SQL schema and reload PostgREST cache.',
        );
      }
      rethrow;
    }
  }

  Future<void> createSubjectOfferingByAdmin({
    required String professorId,
    required String subjectCode,
    required String subjectTitle,
    required String section,
    required String beaconUuid,
    required String beaconName,
  }) async {
    try {
      await _db.rpc(
        'admin_create_subject_offering',
        params: {
          'p_professor_id': professorId.trim(),
          'p_subject_code': subjectCode.trim(),
          'p_subject_title': subjectTitle.trim(),
          'p_section': section.trim(),
          'p_beacon_uuid': beaconUuid.trim(),
          'p_beacon_name': beaconName.trim(),
        },
      );
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST202') {
        throw Exception(
          'Database function missing. Run the latest SQL schema then retry.',
        );
      }
      rethrow;
    }
  }

  Future<List<SubjectOffering>> getAllOfferings() async {
    final rows = await _db
        .from('subject_offerings')
        .select('id, subject_code, subject_title, section, professor_id, '
            'beacon_uuid, beacon_name, professors!subject_offerings_professor_id_fkey(full_name)')
        .eq('is_active', true)
        .order('subject_code');
    return rows.map(_offeringFromSelect).toList();
  }

  Future<void> enrollStudentToOffering({
    required String studentId,
    required String offeringId,
  }) async {
    await _db.rpc(
      'admin_assign_student_to_offering',
      params: {
        'p_student_id': studentId.trim(),
        'p_offering_id': offeringId,
      },
    );
  }

  Future<List<EnrollmentRecord>> getAdminEnrollments() async {
    final rows = await _db.rpc('get_admin_enrollments');
    if (rows is! List) return [];
    return rows.map((e) {
      final map = e as Map<String, dynamic>;
      return EnrollmentRecord(
        studentId: map['student_id'] as String,
        studentName: map['student_name'] as String,
        offeringId: map['offering_id'] as String,
        professorId: map['professor_id'] as String,
        professorName: map['professor_name'] as String,
        subjectCode: map['subject_code'] as String,
        subjectTitle: map['subject_title'] as String,
        section: map['section'] as String,
      );
    }).toList();
  }

  Future<void> removeEnrollment({
    required String studentId,
    required String offeringId,
  }) async {
    await _db
        .from('student_subject_enrollments')
        .delete()
        .eq('student_id', studentId)
        .eq('offering_id', offeringId);
  }

  Future<List<AdminAttendanceReportItem>> getAdminAttendanceReport({
    DateTime? from,
    DateTime? to,
    String? professorId,
    String? subjectCode,
    String? section,
  }) async {
    var query = _db.from('attendance').select(
          'session_id, student_id, student_name, marked_at, '
          'device_name, device_mac, device_fingerprint, '
          'sessions!attendance_session_id_fkey(id, started_at, ended_at, '
          'offering_id, professor_id, '
          'subject_offerings!sessions_offering_id_fkey(subject_code, subject_title, section, professor_id, '
          'professors!subject_offerings_professor_id_fkey(full_name)))',
        );

    if (from != null) {
      query = query.gte('marked_at', from.toUtc().toIso8601String());
    }
    if (to != null) {
      query = query.lte('marked_at', to.toUtc().toIso8601String());
    }
    if (professorId != null && professorId.trim().isNotEmpty) {
      query = query.eq('sessions.professor_id', professorId.trim());
    }
    if (subjectCode != null && subjectCode.trim().isNotEmpty) {
      query = query.eq(
        'sessions.subject_offerings.subject_code',
        subjectCode.trim(),
      );
    }
    if (section != null && section.trim().isNotEmpty) {
      query = query.eq('sessions.subject_offerings.section', section.trim());
    }

    final rows = await query.order('marked_at', ascending: false);
    return rows.map((row) {
      final map = row;
      final session = map['sessions'] as Map<String, dynamic>? ?? {};
      final offering =
          session['subject_offerings'] as Map<String, dynamic>? ?? {};
      final professor = offering['professors'] as Map<String, dynamic>? ?? {};

      return AdminAttendanceReportItem(
        sessionId: (map['session_id'] as String?) ?? '',
        sessionStartedAt: DateTime.parse(
          (session['started_at'] as String?) ?? map['marked_at'] as String,
        ).toLocal(),
        sessionEndedAt: (session['ended_at'] as String?) == null
            ? null
            : DateTime.parse(session['ended_at'] as String).toLocal(),
        subjectCode: (offering['subject_code'] as String?) ?? 'SUBJECT',
        subjectTitle: (offering['subject_title'] as String?) ?? 'Untitled',
        section: (offering['section'] as String?) ?? 'N/A',
        professorId: (session['professor_id'] as String?) ?? '',
        professorName: (professor['full_name'] as String?) ?? 'Professor',
        studentId: (map['student_id'] as String?) ?? '',
        studentName: (map['student_name'] as String?) ?? 'Student',
        markedAt: DateTime.parse(map['marked_at'] as String).toLocal(),
        deviceName: map['device_name'] as String?,
        deviceMac: map['device_mac'] as String?,
        deviceFingerprint: map['device_fingerprint'] as String?,
      );
    }).toList();
  }

  Future<void> updateDisplayName({
    required String role,
    required String linkedId,
    required String fullName,
  }) async {
    await _db.rpc(
      'update_display_name',
      params: {
        'p_role': role,
        'p_linked_id': linkedId,
        'p_full_name': fullName.trim(),
      },
    );
  }

  Future<List<SubjectOffering>> getStudentOfferings(String studentId) async {
    final rows = await _db.rpc(
      'get_student_dashboard',
      params: {'p_student_id': studentId},
    );
    if (rows is! List) return [];
    return rows
        .map((e) => _offeringFromMap(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<SubjectOffering>> getProfessorOfferings(String professorId) async {
    final rows = await _db
        .from('subject_offerings')
        .select('id, subject_code, subject_title, section, professor_id, '
            'beacon_uuid, beacon_name, professors!subject_offerings_professor_id_fkey(full_name)')
        .eq('professor_id', professorId)
        .order('subject_code');
    return rows.map(_offeringFromSelect).toList();
  }

  /// Enrollment counts per offering (for dashboard cards).
  Future<Map<String, int>> getEnrollmentCountsForOfferings(
      List<String> offeringIds) async {
    if (offeringIds.isEmpty) return {};
    final rows = await _db
        .from('student_subject_enrollments')
        .select('offering_id')
        .inFilter('offering_id', offeringIds);
    final map = {for (final id in offeringIds) id: 0};
    for (final r in rows) {
      final id = r['offering_id'] as String;
      map[id] = (map[id] ?? 0) + 1;
    }
    return map;
  }

  SubjectOffering _offeringFromMap(Map<String, dynamic> e) {
    return SubjectOffering(
      id: e['offering_id'] as String,
      subjectCode: e['subject_code'] as String,
      subjectTitle: e['subject_title'] as String,
      section: e['section'] as String,
      professorId: e['professor_id'] as String,
      professorName: e['professor_name'] as String,
      beaconUuid: e['beacon_uuid'] as String,
      beaconName: e['beacon_name'] as String,
    );
  }

  SubjectOffering _offeringFromSelect(Map<String, dynamic> e) {
    final professor = (e['professors'] as Map<String, dynamic>? ?? {});
    return SubjectOffering(
      id: e['id'] as String,
      subjectCode: e['subject_code'] as String,
      subjectTitle: e['subject_title'] as String,
      section: e['section'] as String,
      professorId: e['professor_id'] as String,
      professorName: (professor['full_name'] as String?) ?? 'Professor',
      beaconUuid: e['beacon_uuid'] as String,
      beaconName: e['beacon_name'] as String,
    );
  }

  // ── PROFESSOR ATTENDANCE ───────────────────────────────────

  Future<Map<String, dynamic>> startSession({
    required String professorId,
    required String offeringId,
    required String subject,
    required String beaconUuid,
    required String beaconName,
  }) async {
    // End any previous active sessions first
    try {
      await _db
          .from('sessions')
          .update({'is_active': false, 'ended_at': DateTime.now().toIso8601String()})
          .eq('professor_id', professorId)
          .eq('offering_id', offeringId)
          .eq('is_active', true);
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST204' && e.message.contains('offering_id')) {
        await _db
            .from('sessions')
            .update({'is_active': false, 'ended_at': DateTime.now().toIso8601String()})
            .eq('professor_id', professorId)
            .eq('is_active', true);
      } else {
        rethrow;
      }
    }

    Map<String, dynamic> result;
    try {
      result = await _db
          .from('sessions')
          .insert({
            'professor_id': professorId,
            'offering_id': offeringId,
            'subject': subject,
            'beacon_uuid': beaconUuid,
            'beacon_name': beaconName,
            'is_active': true,
          })
          .select()
          .single();
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST204' && e.message.contains('beacon_name')) {
        result = await _db
            .from('sessions')
            .insert({
              'professor_id': professorId,
              'offering_id': offeringId,
              'subject': subject,
              'beacon_uuid': beaconUuid,
              'is_active': true,
            })
            .select()
            .single();
      } else if (e.code == 'PGRST204' && e.message.contains('offering_id')) {
        result = await _db
            .from('sessions')
            .insert({
              'professor_id': professorId,
              'subject': subject,
              'beacon_uuid': beaconUuid,
              'beacon_name': beaconName,
              'is_active': true,
            })
            .select()
            .single();
      } else {
        rethrow;
      }
    }

    debugPrint('[DB] Session started: ${result['id']}');
    return result;
  }

  Future<void> endSession(String sessionId) async {
    await _db.from('sessions').update({
      'is_active': false,
      'ended_at': DateTime.now().toIso8601String(),
    }).eq('id', sessionId);
    debugPrint('[DB] Session ended: $sessionId');
  }

  // ── STUDENT ────────────────────────────────────────────────

  Future<Map<String, dynamic>?> getActiveSessionForOffering(
      String offeringId) async {
    List<Map<String, dynamic>> result;
    try {
      result = await _db
          .from('sessions')
          .select()
          .eq('is_active', true)
          .eq('offering_id', offeringId)
          .order('started_at', ascending: false)
          .limit(1);
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST204' && e.message.contains('offering_id')) {
        result = await _db
            .from('sessions')
            .select()
            .eq('is_active', true)
            .order('started_at', ascending: false)
            .limit(1);
      } else {
        rethrow;
      }
    }
    if (result.isEmpty) return null;
    debugPrint('[DB] Active session found: ${result.first}');
    return result.first;
  }

  Future<bool> markAttendance({
    required String sessionId,
    required String studentId,
    required String studentName,
    String? deviceUuid,
    String? deviceName,
    String? deviceMac,
    String? deviceFingerprint,
  }) async {
    try {
      final payload = <String, dynamic>{
        'session_id': sessionId,
        'student_id': studentId,
        'student_name': studentName,
        'marked_at': DateTime.now().toIso8601String(),
      };
      if (deviceName != null && deviceName.trim().isNotEmpty) {
        payload['device_name'] = deviceName.trim();
      }
      if (deviceUuid != null && deviceUuid.trim().isNotEmpty) {
        payload['device_uuid'] = deviceUuid.trim();
      }
      if (deviceMac != null && deviceMac.trim().isNotEmpty) {
        payload['device_mac'] = deviceMac.trim();
      }
      if (deviceFingerprint != null && deviceFingerprint.trim().isNotEmpty) {
        payload['device_fingerprint'] = deviceFingerprint.trim();
      }

      await _db.from('attendance').insert(payload);
      debugPrint('[DB] Attendance marked for $studentName');
      return true;
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST204' &&
          (e.message.contains('device_uuid') ||
              e.message.contains('device_name') ||
              e.message.contains('device_mac') ||
              e.message.contains('device_fingerprint'))) {
        await _db.from('attendance').insert({
          'session_id': sessionId,
          'student_id': studentId,
          'student_name': studentName,
          'marked_at': DateTime.now().toIso8601String(),
        });
        debugPrint('[DB] Attendance marked for $studentName (legacy schema)');
        return true;
      }
      if (e.code == '23505') {
        debugPrint('[DB] Already marked!');
        return false;
      }
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getAttendees(String sessionId) async {
    return await _db
        .from('attendance')
        .select()
        .eq('session_id', sessionId)
        .order('marked_at');
  }

  List<AttendanceAnomaly> detectSharedDeviceAnomalies(
    List<Map<String, dynamic>> attendees,
  ) {
    final buckets = <String, Set<String>>{};
    final labels = <String, String>{};

    for (final row in attendees) {
      final deviceUuid = (row['device_uuid'] as String?)?.trim();
      if (deviceUuid == null || deviceUuid.isEmpty) continue;

      final studentName =
          ((row['student_name'] as String?)?.trim().isNotEmpty ?? false)
              ? (row['student_name'] as String).trim()
              : ((row['student_id'] as String?) ?? 'Unknown student');
      final deviceName = (row['device_name'] as String?)?.trim();
      final displayName =
          (deviceName != null && deviceName.isNotEmpty) ? deviceName : 'Unknown device';
      final shortUuid =
          deviceUuid.length > 8 ? deviceUuid.substring(0, 8) : deviceUuid;
      final label = '$displayName • $shortUuid';

      buckets.putIfAbsent(deviceUuid, () => <String>{}).add(studentName);
      labels.putIfAbsent(deviceUuid, () => label);
    }

    final anomalies = <AttendanceAnomaly>[];
    buckets.forEach((deviceUuid, students) {
      if (students.length < 2) return;
      final sortedStudents = students.toList()..sort();
      anomalies.add(
        AttendanceAnomaly(
          deviceLabel: labels[deviceUuid] ?? 'Unknown device',
          deviceUuid: deviceUuid,
          students: sortedStudents,
        ),
      );
    });

    anomalies.sort((a, b) => b.students.length.compareTo(a.students.length));
    return anomalies;
  }

  // Realtime stream — fires whenever session row changes
  Stream<bool> watchSessionActive(String sessionId) {
    return _db
        .from('sessions')
        .stream(primaryKey: ['id'])
        .eq('id', sessionId)
        .map((rows) => rows.isNotEmpty && (rows.first['is_active'] as bool));
  }

  Stream<List<SessionNotificationItem>> watchStudentSessionNotifications(
    String studentId,
  ) async* {
    final offerings = await getStudentOfferings(studentId);
    final offeringById = {
      for (final offering in offerings) offering.id: offering,
    };
    if (offeringById.isEmpty) {
      yield const [];
      return;
    }

    final emitted = <String>{};
    await for (final rows in _db
        .from('sessions')
        .stream(primaryKey: ['id'])
        .eq('is_active', true)
        .order('started_at')) {
      final notifications = <SessionNotificationItem>[];
      for (final row in rows) {
        final offeringId = row['offering_id'] as String?;
        if (offeringId == null || !offeringById.containsKey(offeringId)) {
          continue;
        }
        final sessionId = row['id'] as String? ?? '';
        if (sessionId.isEmpty || emitted.contains(sessionId)) {
          continue;
        }
        emitted.add(sessionId);
        final offering = offeringById[offeringId]!;
        notifications.add(
          SessionNotificationItem(
            sessionId: sessionId,
            offeringId: offeringId,
            subjectCode: offering.subjectCode,
            subjectTitle: offering.subjectTitle,
            section: offering.section,
            professorName: offering.professorName,
            startedAt: DateTime.parse(row['started_at'] as String).toLocal(),
          ),
        );
      }
      if (notifications.isNotEmpty) {
        notifications.sort((a, b) => b.startedAt.compareTo(a.startedAt));
        yield notifications;
      }
    }
  }

  Future<List<ProfessorSessionHistoryItem>> getProfessorSessionHistory(
    String professorId,
  ) async {
    final rows = await _db.rpc(
      'get_professor_session_history',
      params: {'p_professor_id': professorId},
    );
    if (rows is! List) return [];

    return rows.map((row) {
      final map = row as Map<String, dynamic>;
      return ProfessorSessionHistoryItem(
        sessionId: (map['session_id'] as String?) ?? '',
        subjectCode: (map['subject_code'] as String?) ?? 'SUBJECT',
        subjectTitle: (map['subject_title'] as String?) ?? 'Untitled',
        section: (map['section'] as String?) ?? 'N/A',
        startedAt: DateTime.parse(map['started_at'] as String).toLocal(),
        endedAt: map['ended_at'] == null
            ? null
            : DateTime.parse(map['ended_at'] as String).toLocal(),
        isActive: (map['is_active'] as bool?) ?? false,
      );
    }).toList();
  }

  Future<List<SessionAttendanceDetailItem>> getSessionAttendeesForProfessor({
    required String professorId,
    required String sessionId,
  }) async {
    try {
      final rows = await _db.rpc(
        'get_professor_session_attendees',
        params: {
          'p_professor_id': professorId.trim(),
          'p_session_id': sessionId,
        },
      );
      if (rows is! List) return [];

      return rows.map((row) {
        final map = row as Map<String, dynamic>;
        return SessionAttendanceDetailItem(
          studentId: (map['student_id'] as String?) ?? '',
          studentName: (map['student_name'] as String?) ?? 'Student',
          markedAt: DateTime.parse(map['marked_at'] as String).toLocal(),
          deviceUsed: ((map['device_used'] as String?)?.trim().isNotEmpty ?? false)
              ? (map['device_used'] as String).trim()
              : 'Unknown device',
        );
      }).toList();
    } on PostgrestException catch (e) {
      if (e.code != 'PGRST202') rethrow;

      // Fallback for deployments where RPC is not yet created.
      final rows = await _db
          .from('attendance')
          .select('student_id, student_name, marked_at, device_name, device_uuid, device_fingerprint')
          .eq('session_id', sessionId)
          .order('marked_at');

      return rows.map((map) {
        final deviceName = (map['device_name'] as String?)?.trim();
        final deviceUuid = (map['device_uuid'] as String?)?.trim();
        final fp = (map['device_fingerprint'] as String?)?.trim();
        final deviceUsed = (deviceName != null && deviceName.isNotEmpty)
            ? ((deviceUuid != null && deviceUuid.isNotEmpty)
                ? '$deviceName (UUID-Device: $deviceUuid)'
                : deviceName)
            : ((deviceUuid != null && deviceUuid.isNotEmpty)
                ? 'UUID-Device: $deviceUuid'
                : ((fp != null && fp.isNotEmpty) ? fp : 'Unknown device'));
        return SessionAttendanceDetailItem(
          studentId: (map['student_id'] as String?) ?? '',
          studentName: (map['student_name'] as String?) ?? 'Student',
          markedAt: DateTime.parse(map['marked_at'] as String).toLocal(),
          deviceUsed: deviceUsed,
        );
      }).toList();
    }
  }

  Future<List<AttendanceAnomaly>> getSessionDeviceAnomalies(
    String sessionId,
  ) async {
    final rows = await _db.rpc(
      'get_session_device_anomalies',
      params: {'p_session_id': sessionId},
    );
    if (rows is! List) return [];

    final anomalies = rows.map((row) {
      final map = row as Map<String, dynamic>;
      final rawUuid = (map['device_uuid'] as String?)?.trim() ?? '';
      final shortUuid = rawUuid.length > 8 ? rawUuid.substring(0, 8) : rawUuid;
      final namesRaw = map['student_names'];
      final idsRaw = map['student_ids'];

      final names = namesRaw is List
          ? namesRaw.whereType<String>().map((e) => e.trim()).where((e) => e.isNotEmpty).toList()
          : <String>[];
      final ids = idsRaw is List
          ? idsRaw.whereType<String>().map((e) => e.trim()).where((e) => e.isNotEmpty).toList()
          : <String>[];
      final students = names.isNotEmpty ? names : ids;

      return AttendanceAnomaly(
        deviceLabel:
            shortUuid.isEmpty ? 'Unknown UUID-Device' : 'UUID-Device: $shortUuid',
        deviceUuid: rawUuid,
        students: students,
      );
    }).toList();

    anomalies.sort((a, b) => b.students.length.compareTo(a.students.length));
    return anomalies;
  }

  Future<bool> hasStudentMarkedAttendance({
    required String sessionId,
    required String studentId,
  }) async {
    final rows = await _db
        .from('attendance')
        .select('id')
        .eq('session_id', sessionId)
        .eq('student_id', studentId)
        .limit(1);
    return rows.isNotEmpty;
  }

  Future<void> clearProfessorHistory(String professorId) async {
    final id = professorId.trim();
    try {
      await _db.rpc(
        'clear_professor_history',
        params: {'p_professor_id': id},
      );
      return;
    } on PostgrestException catch (e) {
      if (e.code != 'PGRST202') rethrow;
    }

    // Backward-compat: some deployments used a different RPC name.
    try {
      await _db.rpc(
        'clear_professor_session_history',
        params: {'p_professor_id': id},
      );
      return;
    } on PostgrestException catch (e) {
      if (e.code != 'PGRST202') rethrow;
    }

    // Final fallback: direct delete (RLS allows deletes).
    // Must delete attendance first to satisfy FK attendance.session_id -> sessions.id
    final rawSessions = await _db
        .from('sessions')
        .select('id')
        .eq('professor_id', id);

    final rows = rawSessions.cast<Map<String, dynamic>>();
    final ids = rows
        .map((e) => e['id'])
        .whereType<String>()
        .where((s) => s.isNotEmpty)
        .toList();

    const chunkSize = 100;
    for (var i = 0; i < ids.length; i += chunkSize) {
      final chunk = ids.sublist(
        i,
        (i + chunkSize) > ids.length ? ids.length : (i + chunkSize),
      );
      await _db.from('attendance').delete().inFilter('session_id', chunk);
    }

    await _db.from('sessions').delete().eq('professor_id', id);
  }

  Future<List<StudentAttendanceHistoryItem>> getStudentAttendanceHistory(
    String studentId,
  ) async {
    final rows = await _db.rpc(
      'get_student_attendance_history',
      params: {'p_student_id': studentId},
    );
    if (rows is! List) return [];

    return rows.map((row) {
      final map = row as Map<String, dynamic>;

      return StudentAttendanceHistoryItem(
        subjectCode: (map['subject_code'] as String?) ?? 'SUBJECT',
        subjectTitle: (map['subject_title'] as String?) ?? 'Untitled',
        section: (map['section'] as String?) ?? 'N/A',
        professorName: (map['professor_name'] as String?) ?? 'Professor',
        sessionStartedAt: DateTime.parse(map['session_started_at'] as String)
            .toLocal(),
        markedAt: DateTime.parse(map['marked_at'] as String).toLocal(),
      );
    }).toList();
  }

  Future<void> clearStudentHistory(String studentId) async {
    final id = studentId.trim();
    try {
      await _db.rpc(
        'clear_student_history',
        params: {'p_student_id': id},
      );
      return;
    } on PostgrestException catch (e) {
      if (e.code != 'PGRST202') rethrow;
    }

    // Final fallback: direct delete (RLS allows deletes).
    await _db.from('attendance').delete().eq('student_id', id);
  }
}