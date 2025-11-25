import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:demo1/screen/sidebar.dart';
import 'package:flutter/material.dart';

// --- MODELS ---
class LectureSlot {
  final String title;
  final String presentCount;
  final String absentCount;
  final String attendancePercent;
  final Color percentColor;
  final List<AbsentStudent> absentStudents;

  LectureSlot({
    required this.title,
    required this.presentCount,
    required this.absentCount,
    required this.attendancePercent,
    required this.percentColor,
    required this.absentStudents,
  });
}

class AbsentStudent {
  final String rollNo;
  final String name; // We might not have names stored in logs, only Rolls. Will handle this.
  final String department;

  const AbsentStudent({required this.rollNo, required this.name, required this.department});
}

// --- MAIN WIDGET ---
class Todayreport extends StatelessWidget {
  const Todayreport({super.key});

  @override
  Widget build(BuildContext context) {
    // No MaterialApp here, just the screen widget if navigating from another screen
    return const DetailedReportScreen();
  }
}

class DetailedReportScreen extends StatefulWidget {
  const DetailedReportScreen({super.key});

  @override
  State<DetailedReportScreen> createState() => _DetailedReportScreenState();
}

class _DetailedReportScreenState extends State<DetailedReportScreen> {
  bool _isLoading = true;
  
  // Data Variables
  String _totalAbsent = "0";
  String _attendancePercent = "0%";
  List<LectureSlot> _lectureData = [];
  
  // We use a map to track expanded state by index
  final Map<int, bool> _expandedState = {};

  // Student Name Lookup Cache
  Map<String, String> _studentNames = {};

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      // 1. Fetch Student Names first (to show names instead of just roll numbers)
      final studentsSnapshot = await FirebaseFirestore.instance.collection('student').get();
      Map<String, String> namesMap = {};
      for (var doc in studentsSnapshot.docs) {
        final data = doc.data();
        String key = "${data['department']}_${data['rollNo']}"; // Key format: "Computer_1"
        namesMap[key] = data['name'] ?? "Unknown";
      }
      _studentNames = namesMap;

      // 2. Fetch Today's Logs
      DateTime now = DateTime.now();
      String dateStr = "${now.day.toString().padLeft(2, '0')}-${now.month.toString().padLeft(2, '0')}-${now.year}";
      
      final logsSnapshot = await FirebaseFirestore.instance
          .collection('attendance_logs')
          .where('date', isEqualTo: dateStr)
          .get();

      int dayTotalStudents = 0;
      int dayTotalAbsent = 0;
      List<LectureSlot> lectures = [];

      for (var doc in logsSnapshot.docs) {
        final data = doc.data();
        
        // Get basic counts
        int total = (data['totalCeStudents'] ?? 0) + (data['totalItStudents'] ?? 0);
        List ceAbs = data['ceAbsentees'] is List ? data['ceAbsentees'] : [];
        List itAbs = data['itAbsentees'] is List ? data['itAbsentees'] : [];
        
        int absentCount = ceAbs.length + itAbs.length;
        int presentCount = total - absentCount;
        
        // Create Absent Student List for this lecture
        List<AbsentStudent> studentsList = [];
        
        // Add CE Absentees
        for (var roll in ceAbs) {
          String name = _studentNames["Computer_$roll"] ?? "Unknown";
          studentsList.add(AbsentStudent(rollNo: roll.toString(), name: name, department: "CE"));
        }
        // Add IT Absentees
        for (var roll in itAbs) {
          String name = _studentNames["IT_$roll"] ?? "Unknown";
          studentsList.add(AbsentStudent(rollNo: roll.toString(), name: name, department: "IT"));
        }

        // Sort by Roll No
        try {
           studentsList.sort((a, b) => int.parse(a.rollNo).compareTo(int.parse(b.rollNo)));
        } catch (e) {/* ignore sort error */}

        int percent = total == 0 ? 0 : ((presentCount / total) * 100).round();

        dayTotalStudents += total;
        dayTotalAbsent += absentCount;

        lectures.add(LectureSlot(
          title: "${data['subjectName']} (${data['timeSlot']})",
          presentCount: presentCount.toString(),
          absentCount: absentCount.toString(),
          attendancePercent: "$percent%",
          percentColor: percent < 75 ? Colors.red : Colors.green,
          absentStudents: studentsList,
        ));
      }

      int dayPercent = dayTotalStudents == 0 ? 0 : (((dayTotalStudents - dayTotalAbsent) / dayTotalStudents) * 100).round();

      if (mounted) {
        setState(() {
          _totalAbsent = dayTotalAbsent.toString();
          _attendancePercent = "$dayPercent%";
          _lectureData = lectures;
          // Initialize first item as expanded if exists
          if (lectures.isNotEmpty) _expandedState[0] = true;
          _isLoading = false;
        });
      }

    } catch (e) {
      print("Error: $e");
      if(mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black),
        title: const Text('Today\'s Detailed Report', style: TextStyle(color: Colors.black)),
      ),
      // Only show drawer if this is the root screen (optional)
      // drawer: const Drawer(child: Sidebar()), 
      
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              Card(
                color: Colors.white,
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // --- Header Section ---
                      const Row(
                        children: [
                          Icon(Icons.bar_chart, color: Colors.purple),
                          SizedBox(width: 8),
                          Text('Today Attendance Reports', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      // --- Summary Boxes ---
                      Row(
                        children: [
                          Expanded(
                            child: SummaryBox(
                              label: 'Absent Today',
                              value: _totalAbsent,
                              backgroundColor: const Color(0xFFFEF2F2),
                              valueColor: const Color(0xFFB91C1C),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: SummaryBox(
                              label: 'Attendance %',
                              value: _attendancePercent,
                              backgroundColor: const Color(0xFFF0FDF4),
                              valueColor: const Color(0xFF15803D),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      
                      const Text('Lecture-wise Breakdown', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),

                      if (_lectureData.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Center(child: Text("No lectures recorded today.", style: TextStyle(color: Colors.grey))),
                        )
                      else
                        // --- Lecture Slots Loop ---
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _lectureData.length,
                          separatorBuilder: (ctx, index) => const Divider(),
                          itemBuilder: (ctx, index) {
                            return LectureSlotWidget(
                              slot: _lectureData[index],
                              isExpanded: _expandedState[index] ?? false,
                              onTap: () {
                                setState(() {
                                  // Toggle state
                                  bool current = _expandedState[index] ?? false;
                                  _expandedState[index] = !current;
                                });
                              },
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
    );
  }
}

// --- WIDGETS ---

class LectureSlotWidget extends StatelessWidget {
  final LectureSlot slot;
  final bool isExpanded;
  final VoidCallback onTap;

  const LectureSlotWidget({
    super.key, 
    required this.slot, 
    required this.isExpanded, 
    required this.onTap
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Row(
              children: [
                Expanded( // Allow title to wrap if long
                  child: Text(slot.title, style: const TextStyle(fontWeight: FontWeight.w500)),
                ),
                //const Spacer(), 
                InfoChip(text: slot.presentCount, color: const Color(0xFF3B82F6), textColor: Colors.white),
                const SizedBox(width: 8),
                InfoChip(text: slot.absentCount, color: const Color(0xFFFEF2F2), textColor: const Color(0xFFB91C1C)),
                const SizedBox(width: 16),
                SizedBox(
                  width: 45, // Fixed width for alignment
                  child: Text(slot.attendancePercent, textAlign: TextAlign.end, style: TextStyle(color: slot.percentColor, fontWeight: FontWeight.bold)),
                ),
                Icon(isExpanded ? Icons.expand_less : Icons.expand_more, color: Colors.grey),
              ],
            ),
          ),
        ),
        if (isExpanded)
          StudentList(students: slot.absentStudents),
      ],
    );
  }
}

class StudentList extends StatelessWidget {
  final List<AbsentStudent> students;
  const StudentList({super.key, required this.students});

  @override
  Widget build(BuildContext context) {
    if (students.isEmpty) {
        return const Padding(
          padding: EdgeInsets.all(8.0),
          child: Text("All students present!", style: TextStyle(color: Colors.green, fontStyle: FontStyle.italic)),
        );
    }

    return Container(
      padding: const EdgeInsets.only(top: 8.0),
      color: Colors.grey.shade50, // Slight background for list
      child: Column(
        children: [
          const Row(
            children: [
              Expanded(flex: 1, child: Text('Roll No', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              Expanded(flex: 3, child: Text('Name', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              Expanded(flex: 1, child: Text('Dept', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
            ],
          ),
          const Divider(),
          Column(
            children: students.map((student) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Row(
                children: [
                  Expanded(flex: 1, child: Text(student.rollNo, style: const TextStyle(fontSize: 13))),
                  Expanded(flex: 3, child: Text(student.name, style: const TextStyle(fontSize: 13))),
                  Expanded(flex: 1, child: Text(student.department, style: const TextStyle(fontSize: 13))),
                ],
              ),
            )).toList(),
          ),
        ],
      ),
    );
  }
}

class InfoChip extends StatelessWidget {
  final String text;
  final Color color;
  final Color textColor;

  const InfoChip({super.key, required this.text, required this.color, required this.textColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text, style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 12)),
    );
  }
}

class SummaryBox extends StatelessWidget {
  final String label;
  final String value;
  final Color backgroundColor;
  final Color valueColor;

  const SummaryBox({
    super.key,
    required this.label,
    required this.value,
    required this.backgroundColor,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: valueColor, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(color: valueColor, fontSize: 24, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
