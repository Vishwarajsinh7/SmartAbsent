import 'package:demo1/data/student_report_models.dart';
import 'package:flutter/material.dart';

class StudentDetailScreen extends StatelessWidget {
  final StudentReport student;

  const StudentDetailScreen({super.key, required this.student});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB), // Light Grey Background
      appBar: AppBar(
        title: const Text('Student Report'), // FIXED: Correct Title
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        titleTextStyle: const TextStyle(color: Colors.black, fontSize: 20, fontWeight: FontWeight.bold),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- 1. Student Header ---
            _StudentHeader(student: student),
            const SizedBox(height: 24),
            
            // --- 2. Overall Report Card ---
            _OverallReportCard(
              totalAbsent: student.totalAbsentLectures,
              attendancePercent: student.overallAttendancePercentage,
            ),
            const SizedBox(height: 24),

            // --- 3. Subject-wise Report Card ---
            _SubjectWiseReportCard(records: student.subjectRecords),
          ],
        ),
      ),
    );
  }
}

// --- HELPER WIDGETS ---

class _StudentHeader extends StatelessWidget {
  final StudentReport student;
  const _StudentHeader({required this.student});

  @override
  Widget build(BuildContext context) {
    // Logic for dynamic colors
    bool isCS = student.department == 'Computer' || student.department == 'CS';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))
        ]
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(student.name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          
          // IMPROVED: Row layout for details + Department Badge
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Roll No: ${student.rollNo}', style: const TextStyle(color: Colors.grey, fontSize: 15, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 4),
                  Text('Enroll: ${student.enrollmentNo}', style: const TextStyle(color: Colors.grey, fontSize: 15, fontWeight: FontWeight.w500)),
                ],
              ),
              const Spacer(),
              // IMPROVED: Colored Badge instead of grey Chip
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isCS ? Colors.blue.shade50 : Colors.purple.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isCS ? Colors.blue.shade100 : Colors.purple.shade100),
                ),
                child: Text(
                  isCS ? 'CS' : 'IT',
                  style: TextStyle(
                    color: isCS ? Colors.blue.shade700 : Colors.purple.shade700,
                    fontWeight: FontWeight.bold,
                    fontSize: 16
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OverallReportCard extends StatelessWidget {
  final int totalAbsent;
  final int attendancePercent;
  
  const _OverallReportCard({required this.totalAbsent, required this.attendancePercent});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Absent Box
        Expanded(
          child: _SummaryBox(
            label: 'Total Absent Lec', 
            value: '$totalAbsent', 
            bgColor: const Color(0xFFFFF1F2), // Light Red
            textColor: Colors.red,
          )
        ),
        const SizedBox(width: 16),
        // Attendance % Box
        Expanded(
          child: _SummaryBox(
            label: 'Attendance %', 
            value: '$attendancePercent%', 
            bgColor: const Color(0xFFECFDF5), // Light Green
            textColor: Colors.green,
          )
        ),
      ],
    );
  }
}

class _SubjectWiseReportCard extends StatelessWidget {
  final List<SubjectAttendance> records;
  const _SubjectWiseReportCard({required this.records});

  @override
  Widget build(BuildContext context) {
    if (records.isEmpty) {
      return const Center(child: Text("No attendance records found", style: TextStyle(color: Colors.grey)));
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.bar_chart_rounded, color: Colors.purple.shade300),
                const SizedBox(width: 8),
                const Text('Report Lecture Wise', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),
            
            // Table Header
            const Row(
              children: [
                Expanded(flex: 4, child: Text('SUBJECT', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey))),
                Expanded(flex: 2, child: Center(child: Text('Pre', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)))),
                Expanded(flex: 2, child: Center(child: Text('Abs', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)))),
                Expanded(flex: 2, child: Center(child: Text('%', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)))),
              ],
            ),
            const Divider(height: 24),
            
            // Table Rows
            ...records.map((record) => Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Row(
                children: [
                  Expanded(flex: 4, child: Text(record.name, style: const TextStyle(fontWeight: FontWeight.w600))),
                  // Present Badge
                  Expanded(flex: 2, child: Center(child: _InfoChip(text: '${record.present}', color: Colors.blue.shade600))),
                  // Absent Badge
                  Expanded(flex: 2, child: Center(child: _InfoChip(text: '${record.absent}', color: Colors.red.shade100, textColor: Colors.red.shade700))),
                  // Percentage Text
                  Expanded(flex: 2, child: Center(child: Text('${record.percentage}%', style: TextStyle(color: record.percentage < 75 ? Colors.red : Colors.green, fontWeight: FontWeight.bold)))),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }
}

// --- REUSABLE COMPONENTS ---

class _SummaryBox extends StatelessWidget {
  final String label;
  final String value;
  final Color bgColor;
  final Color textColor;

  const _SummaryBox({required this.label, required this.value, required this.bgColor, required this.textColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: textColor.withOpacity(0.8), fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: textColor)),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String text;
  final Color color;
  final Color textColor;

  const _InfoChip({required this.text, required this.color, this.textColor = Colors.white});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6)),
      child: Text(text, style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 13)),
    );
  }
}
