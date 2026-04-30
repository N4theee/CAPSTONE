import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../services/supabase_service.dart';

class AdminWebPanelScreen extends StatefulWidget {
  const AdminWebPanelScreen({super.key});

  @override
  State<AdminWebPanelScreen> createState() => _AdminWebPanelScreenState();
}

class _AdminWebPanelScreenState extends State<AdminWebPanelScreen> {
  final _db = SupabaseService();
  final _profIdCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _maxStudentsCtrl = TextEditingController(text: '30');
  final _subjectCodeCtrl = TextEditingController();
  final _subjectTitleCtrl = TextEditingController();
  final _sectionCtrl = TextEditingController();
  final _beaconNameCtrl = TextEditingController();
  bool _loading = false;
  bool _creatingOffering = false;
  bool _enrolling = false;
  bool _loadingLists = true;
  bool _loadingReport = false;
  List<StudentBasic> _students = [];
  List<ProfessorBasic> _professors = [];
  List<SubjectOffering> _offerings = [];
  List<EnrollmentRecord> _enrollments = [];
  List<AdminAttendanceReportItem> _reportRows = [];
  DateTimeRange? _reportRange;
  String? _selectedOfferingProfessorId;
  String? _selectedBeaconUuid;
  List<String> _beaconUuidOptions = [];
  String? _selectedStudentId;
  String? _selectedProfessorId;
  String? _selectedSubjectCode;
  String? _selectedSection;
  String? _selectedOfferingId;
  String? _selectedEnrollmentKey;

  @override
  void initState() {
    super.initState();
    _loadLists();
  }

  @override
  void dispose() {
    _profIdCtrl.dispose();
    _nameCtrl.dispose();
    _userCtrl.dispose();
    _passCtrl.dispose();
    _maxStudentsCtrl.dispose();
    _subjectCodeCtrl.dispose();
    _subjectTitleCtrl.dispose();
    _sectionCtrl.dispose();
    _beaconNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _createProfessor() async {
    setState(() => _loading = true);
    try {
      final id = await _db.createProfessorByAdmin(
        professorId: _profIdCtrl.text,
        fullName: _nameCtrl.text,
        username: _userCtrl.text,
        password: _passCtrl.text,
        maxStudents: int.tryParse(_maxStudentsCtrl.text.trim()) ?? 30,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Professor created successfully ($id).')),
      );
      await _loadLists();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Create failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _createOffering() async {
    setState(() => _creatingOffering = true);
    try {
      if (_selectedOfferingProfessorId == null) {
        throw Exception('Please select a professor.');
      }
      if (_selectedBeaconUuid == null || _selectedBeaconUuid!.isEmpty) {
        throw Exception('Please select a beacon UUID.');
      }
      await _db.createSubjectOfferingByAdmin(
        professorId: _selectedOfferingProfessorId!,
        subjectCode: _subjectCodeCtrl.text,
        subjectTitle: _subjectTitleCtrl.text,
        section: _sectionCtrl.text,
        beaconUuid: _selectedBeaconUuid!,
        beaconName: _beaconNameCtrl.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Class section created successfully.')),
      );
      await _loadLists();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Create class failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _creatingOffering = false);
    }
  }

  void _regenBeaconUuids() {
    final uuid = const Uuid();
    final next = <String>{};
    while (next.length < 12) {
      next.add(uuid.v4());
    }
    setState(() {
      _beaconUuidOptions = next.toList();
      _beaconUuidOptions.sort();
      _selectedBeaconUuid =
          _beaconUuidOptions.isEmpty ? null : _beaconUuidOptions.first;
    });
  }

  Future<void> _loadLists() async {
    setState(() => _loadingLists = true);
    try {
      final students = await _db.getAllStudents();
      final professors = await _db.getAllProfessors();
      final offerings = await _db.getAllOfferings();
      final enrollments = await _db.getAdminEnrollments();
      if (!mounted) return;
      final selectedProfessorId = professors.any((p) => p.id == _selectedProfessorId)
          ? _selectedProfessorId
          : (professors.isNotEmpty ? professors.first.id : null);
      final offeringsByProfessor = selectedProfessorId == null
          ? <SubjectOffering>[]
          : offerings.where((o) => o.professorId == selectedProfessorId).toList();
      final subjectCodes = offeringsByProfessor
          .map((o) => o.subjectCode)
          .toSet()
          .toList()
        ..sort();
      final selectedSubjectCode = subjectCodes.contains(_selectedSubjectCode)
          ? _selectedSubjectCode
          : (subjectCodes.isNotEmpty ? subjectCodes.first : null);
      final sections = offeringsByProfessor
          .where((o) => o.subjectCode == selectedSubjectCode)
          .map((o) => o.section)
          .toSet()
          .toList()
        ..sort();
      final selectedSection = sections.contains(_selectedSection)
          ? _selectedSection
          : (sections.isNotEmpty ? sections.first : null);
      final selectedOfferingId = offeringsByProfessor
          .where((o) =>
              o.subjectCode == selectedSubjectCode && o.section == selectedSection)
          .map((o) => o.id)
          .cast<String?>()
          .firstWhere((_) => true, orElse: () => null);

      setState(() {
        _students = students;
        _professors = professors;
        _offerings = offerings;
        _enrollments = enrollments;
        _selectedOfferingProfessorId =
            professors.any((p) => p.id == _selectedOfferingProfessorId)
                ? _selectedOfferingProfessorId
                : (professors.isNotEmpty ? professors.first.id : null);
        _selectedStudentId = students.any((s) => s.id == _selectedStudentId)
            ? _selectedStudentId
            : (students.isNotEmpty ? students.first.id : null);
        _selectedProfessorId = selectedProfessorId;
        _selectedSubjectCode = selectedSubjectCode;
        _selectedSection = selectedSection;
        _selectedOfferingId = selectedOfferingId;
      });
      if (_beaconUuidOptions.isEmpty) {
        _regenBeaconUuids();
      }
    } finally {
      if (mounted) setState(() => _loadingLists = false);
    }
  }

  Future<void> _enrollStudent() async {
    if (_selectedStudentId == null || _selectedOfferingId == null) return;
    setState(() => _enrolling = true);
    try {
      await _db.enrollStudentToOffering(
        studentId: _selectedStudentId!,
        offeringId: _selectedOfferingId!,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enrollment saved successfully.')),
      );
      await _loadLists();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Enrollment failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _enrolling = false);
    }
  }

  Future<void> _removeSelectedEnrollment() async {
    if (_selectedEnrollmentKey == null) return;
    final parts = _selectedEnrollmentKey!.split('|');
    if (parts.length != 2) return;
    setState(() => _enrolling = true);
    try {
      await _db.removeEnrollment(studentId: parts[0], offeringId: parts[1]);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enrollment removed.')),
      );
      await _loadLists();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Remove failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _enrolling = false);
    }
  }

  Future<void> _generateReport() async {
    setState(() => _loadingReport = true);
    try {
      final rows = await _db.getAdminAttendanceReport(
        from: _reportRange?.start,
        to: _reportRange?.end,
      );
      if (!mounted) return;
      setState(() => _reportRows = rows);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Report generated: ${rows.length} records')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Report generation failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _loadingReport = false);
    }
  }

  Future<void> _pickReportRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 1),
      initialDateRange: _reportRange,
    );
    if (picked == null || !mounted) return;
    setState(() => _reportRange = picked);
  }

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) {
      return const Scaffold(
        body: Center(
          child: Text('Admin panel is web-only.'),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Panel'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Text(
                'Create Professor Account',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              TextField(controller: _profIdCtrl, decoration: const InputDecoration(labelText: 'Professor ID (ex: prof_joel)')),
              const SizedBox(height: 10),
              TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Professor Full Name')),
              const SizedBox(height: 10),
              TextField(controller: _userCtrl, decoration: const InputDecoration(labelText: 'Professor Username')),
              const SizedBox(height: 10),
              TextField(controller: _passCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'Professor Password')),
              const SizedBox(height: 10),
              TextField(
                controller: _maxStudentsCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Max Students (default 30)',
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Section assignment is now done per class offering and student enrollment.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: _loading ? null : _createProfessor,
                icon: _loading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.person_add_alt_1),
                label: const Text('Create Professor'),
              ),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 12),
              const Text(
                'Create Class Section (Subject Offering)',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: _selectedOfferingProfessorId,
                decoration: const InputDecoration(
                  labelText: 'Professor (owner of this class)',
                ),
                items: _professors
                    .map(
                      (p) => DropdownMenuItem(
                        value: p.id,
                        child: Text('${p.fullName} (${p.id})'),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _selectedOfferingProfessorId = v),
              ),
              const SizedBox(height: 10),
              TextField(controller: _subjectCodeCtrl, decoration: const InputDecoration(labelText: 'Subject Code (ex: IT401)')),
              const SizedBox(height: 10),
              TextField(controller: _subjectTitleCtrl, decoration: const InputDecoration(labelText: 'Subject Title')),
              const SizedBox(height: 10),
              TextField(controller: _sectionCtrl, decoration: const InputDecoration(labelText: 'Section (ex: BSIT-4A)')),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedBeaconUuid,
                      decoration: const InputDecoration(labelText: 'Beacon UUID'),
                      items: _beaconUuidOptions
                          .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                          .toList(),
                      onChanged: (v) => setState(() => _selectedBeaconUuid = v),
                    ),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    onPressed: _regenBeaconUuids,
                    icon: const Icon(Icons.refresh),
                    label: const Text('New UUIDs'),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(controller: _beaconNameCtrl, decoration: const InputDecoration(labelText: 'Beacon Name')),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _creatingOffering ? null : _createOffering,
                icon: _creatingOffering
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.class_),
                label: const Text('Create Class Section'),
              ),
              const SizedBox(height: 26),
              const Divider(),
              const SizedBox(height: 12),
              const Text(
                'Enroll Student to Subject',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                'Admin can edit student-professor-section assignment here.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              ),
              const SizedBox(height: 12),
              if (_loadingLists) const LinearProgressIndicator(),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: _selectedStudentId,
                decoration: const InputDecoration(labelText: 'Student'),
                items: _students
                    .map((s) => DropdownMenuItem(
                          value: s.id,
                          child: Text('${s.fullName} (${s.id})'),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _selectedStudentId = v),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: _selectedProfessorId,
                decoration: const InputDecoration(labelText: 'Professor'),
                items: _professors
                    .map((p) => DropdownMenuItem(
                          value: p.id,
                          child: Text('${p.fullName} (${p.id})'),
                        ))
                    .toList(),
                onChanged: (v) {
                  setState(() {
                    _selectedProfessorId = v;
                    final codes = _subjectCodesForProfessor;
                    _selectedSubjectCode = codes.isNotEmpty ? codes.first : null;
                    final sections = _sectionsForSubject;
                    _selectedSection = sections.isNotEmpty ? sections.first : null;
                    _resolveSelectedOffering();
                  });
                },
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: _selectedSubjectCode,
                decoration: const InputDecoration(labelText: 'Subject'),
                items: _subjectCodesForProfessor
                    .map((code) => DropdownMenuItem(
                          value: code,
                          child: Text(code),
                        ))
                    .toList(),
                onChanged: (v) {
                  setState(() {
                    _selectedSubjectCode = v;
                    final sections = _sectionsForSubject;
                    _selectedSection = sections.isNotEmpty ? sections.first : null;
                    _resolveSelectedOffering();
                  });
                },
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: _selectedSection,
                decoration: const InputDecoration(labelText: 'Section'),
                items: _sectionsForSubject
                    .map((section) => DropdownMenuItem(
                          value: section,
                          child: Text(section),
                        ))
                    .toList(),
                onChanged: (v) {
                  setState(() {
                    _selectedSection = v;
                    _resolveSelectedOffering();
                  });
                },
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: _selectedOfferingId,
                decoration: const InputDecoration(labelText: 'Resolved Class Offering'),
                items: _filteredByProfessor
                    .where((o) => _selectedSubjectCode == null || o.subjectCode == _selectedSubjectCode)
                    .where((o) => _selectedSection == null || o.section == _selectedSection)
                    .map((o) => DropdownMenuItem(
                          value: o.id,
                          child: Text(
                              '${o.subjectCode} ${o.section} - ${o.professorName}'),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _selectedOfferingId = v),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _selectedEnrollmentKey,
                decoration: const InputDecoration(
                  labelText: 'Existing Enrollment (for editing/removal)',
                ),
                items: _enrollments
                    .map((e) => DropdownMenuItem(
                          value: '${e.studentId}|${e.offeringId}',
                          child: Text(e.label),
                        ))
                    .toList(),
                onChanged: (v) {
                  setState(() => _selectedEnrollmentKey = v);
                  if (v == null) return;
                  final parts = v.split('|');
                  if (parts.length != 2) return;
                  final studentId = parts[0];
                  final offeringId = parts[1];
                  final enrollment = _enrollments.firstWhere(
                    (e) => e.studentId == studentId && e.offeringId == offeringId,
                  );
                  setState(() {
                    _selectedStudentId = enrollment.studentId;
                    _selectedProfessorId = enrollment.professorId;
                    _selectedSubjectCode = enrollment.subjectCode;
                    _selectedSection = enrollment.section;
                    _resolveSelectedOffering();
                  });
                },
              ),
              if (_offerings.isEmpty) ...[
                const SizedBox(height: 8),
                const Text(
                  'No offerings yet. Create a professor account above first.',
                  style: TextStyle(color: Colors.orange),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _loadingLists ? null : _loadLists,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh lists'),
                ),
              ],
              const SizedBox(height: 14),
              ElevatedButton.icon(
                onPressed:
                    (_enrolling || _selectedStudentId == null || _selectedOfferingId == null)
                        ? null
                        : _enrollStudent,
                icon: _enrolling
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.how_to_reg),
                label: const Text('Save Enrollment'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: (_enrolling || _selectedEnrollmentKey == null)
                    ? null
                    : _removeSelectedEnrollment,
                icon: const Icon(Icons.delete_outline),
                label: const Text('Remove Selected Enrollment'),
              ),
              const SizedBox(height: 26),
              const Divider(),
              const SizedBox(height: 12),
              const Text(
                'Admin Reports',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _reportRange == null
                          ? 'Date range: All records'
                          : 'Date range: ${_reportRange!.start.toLocal().toString().split(' ').first} to ${_reportRange!.end.toLocal().toString().split(' ').first}',
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey.shade700),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _pickReportRange,
                    icon: const Icon(Icons.date_range),
                    label: const Text('Pick range'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: _loadingReport ? null : _generateReport,
                icon: _loadingReport
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.summarize_outlined),
                label: const Text('Generate Attendance Report'),
              ),
              const SizedBox(height: 12),
              if (_reportRows.isNotEmpty)
                SizedBox(
                  height: 280,
                  child: Card(
                    child: ListView.separated(
                      itemCount: _reportRows.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final row = _reportRows[i];
                        return ListTile(
                          dense: true,
                          title: Text(
                            '${row.subjectCode} ${row.section} • ${row.studentName}',
                          ),
                          subtitle: Text(
                            '${row.professorName} • ${row.markedAt.toLocal()}',
                          ),
                        );
                      },
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  List<SubjectOffering> get _filteredByProfessor {
    if (_selectedProfessorId == null) return [];
    return _offerings
        .where((o) => o.professorId == _selectedProfessorId)
        .toList();
  }

  List<String> get _subjectCodesForProfessor {
    final codes = _filteredByProfessor.map((o) => o.subjectCode).toSet().toList()
      ..sort();
    return codes;
  }

  List<String> get _sectionsForSubject {
    final sections = _filteredByProfessor
        .where((o) => o.subjectCode == _selectedSubjectCode)
        .map((o) => o.section)
        .toSet()
        .toList()
      ..sort();
    return sections;
  }

  void _resolveSelectedOffering() {
    final match = _filteredByProfessor.firstWhere(
      (o) =>
          o.subjectCode == _selectedSubjectCode && o.section == _selectedSection,
      orElse: () => const SubjectOffering(
        id: '',
        subjectCode: '',
        subjectTitle: '',
        section: '',
        professorId: '',
        professorName: '',
        beaconUuid: '',
        beaconName: '',
      ),
    );
    _selectedOfferingId = match.id.isEmpty ? null : match.id;
  }
}
