class SubjectAttendance {
  final String name;
  final int present;
  final int absent;
  
  int get percentage {
    int total = present + absent;
    if (total == 0) {
      return 100; 
    }
    return (present * 100) ~/ total;
  }

  const SubjectAttendance({
    required this.name,
    required this.present,
    required this.absent,
  });
}

class StudentReport {
  final String name;
  final String rollNo;
  final String enrollmentNo;
  final String department;
  final int totalAbsentLectures;
  final int overallAttendancePercentage;
  final List<SubjectAttendance> subjectRecords;

  const StudentReport({
    required this.name,
    required this.rollNo,
    required this.enrollmentNo,
    required this.department,
    required this.totalAbsentLectures,
    required this.overallAttendancePercentage,
    required this.subjectRecords,
  });
}
