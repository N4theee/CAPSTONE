class ProfessorProfile {
  const ProfessorProfile({
    required this.id,
    required this.name,
    required this.subject,
    required this.beaconUuid,
    required this.beaconName,
    this.maxStudents = 30,
  });

  final String id;
  final String name;
  final String subject;
  final String beaconUuid;
  final String beaconName;
  final int maxStudents;
}

class StudentProfile {
  const StudentProfile({
    required this.id,
    required this.name,
    required this.professorId,
  });

  final String id;
  final String name;
  final String professorId;
}

class DemoData {
  static const List<ProfessorProfile> professors = [
    ProfessorProfile(
      id: 'prof_nath',
      name: 'Prof Nath',
      subject: 'MOBILE301',
      beaconUuid: '11111111-1111-1111-1111-111111111111',
      beaconName: 'NATH301',
    ),
    ProfessorProfile(
      id: 'prof_cana',
      name: 'Prof Cana',
      subject: 'NET302',
      beaconUuid: '22222222-2222-2222-2222-222222222222',
      beaconName: 'CANA302',
    ),
    ProfessorProfile(
      id: 'prof_rus',
      name: 'Prof Rus',
      subject: 'IOT303',
      beaconUuid: '33333333-3333-3333-3333-333333333333',
      beaconName: 'RUS303',
    ),
  ];

  static const List<StudentProfile> students = [
    StudentProfile(id: 'nath_001', name: 'Nath Student 01', professorId: 'prof_nath'),
    StudentProfile(id: 'nath_002', name: 'Nath Student 02', professorId: 'prof_nath'),
    StudentProfile(id: 'nath_003', name: 'Nath Student 03', professorId: 'prof_nath'),
    StudentProfile(id: 'nath_004', name: 'Nath Student 04', professorId: 'prof_nath'),
    StudentProfile(id: 'nath_005', name: 'Nath Student 05', professorId: 'prof_nath'),
    StudentProfile(id: 'cana_001', name: 'Cana Student 01', professorId: 'prof_cana'),
    StudentProfile(id: 'cana_002', name: 'Cana Student 02', professorId: 'prof_cana'),
    StudentProfile(id: 'cana_003', name: 'Cana Student 03', professorId: 'prof_cana'),
    StudentProfile(id: 'cana_004', name: 'Cana Student 04', professorId: 'prof_cana'),
    StudentProfile(id: 'cana_005', name: 'Cana Student 05', professorId: 'prof_cana'),
    StudentProfile(id: 'rus_001', name: 'Rus Student 01', professorId: 'prof_rus'),
    StudentProfile(id: 'rus_002', name: 'Rus Student 02', professorId: 'prof_rus'),
    StudentProfile(id: 'rus_003', name: 'Rus Student 03', professorId: 'prof_rus'),
    StudentProfile(id: 'rus_004', name: 'Rus Student 04', professorId: 'prof_rus'),
    StudentProfile(id: 'rus_005', name: 'Rus Student 05', professorId: 'prof_rus'),
  ];

  static ProfessorProfile professorById(String professorId) {
    return professors.firstWhere((p) => p.id == professorId);
  }
}
