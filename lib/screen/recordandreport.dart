import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:demo1/screen/sidebar.dart';
import 'package:demo1/screen/todayreport.dart'; // Ensure this file exists
import 'package:flutter/material.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  // --- STATE VARIABLES ---
  bool _isLoading = true;
  String _todayAbsent = "0";
  String _todayAttendancePercent = "0%";
  List<Map<String, Object>> _todayLectures = [];

  @override
  void initState() {
    super.initState();
    _fetchReportData();
  }

  // --- FETCH DATA FROM FIREBASE ---
  Future<void> _fetchReportData() async {
    setState(() => _isLoading = true);
    try {
      DateTime now = DateTime.now();
      // Format: dd-MM-yyyy (Must match how you saved it)
      String dateStr = "${now.day.toString().padLeft(2, '0')}-${now.month.toString().padLeft(2, '0')}-${now.year}";

      // 1. Query Attendance Logs for TODAY
      final snapshot = await FirebaseFirestore.instance
          .collection('attendance_logs')
          .where('date', isEqualTo: dateStr)
          .get();

      int totalStudentsForDay = 0;
      int totalAbsentForDay = 0;
      List<Map<String, Object>> lectures = [];

      for (var doc in snapshot.docs) {
        final data = doc.data();
        
        // Get totals for this specific lecture
        int totalStudents = (data['totalCeStudents'] ?? 0) + (data['totalItStudents'] ?? 0);
        List ceAbs = data['ceAbsentees'] ?? [];
        List itAbs = data['itAbsentees'] ?? [];
        int absentCount = ceAbs.length + itAbs.length;
        int presentCount = totalStudents - absentCount;

        // Calculate Lecture Percentage
        int lecturePercent = totalStudents == 0 ? 0 : ((presentCount / totalStudents) * 100).round();

        // Add to Day Totals
        totalStudentsForDay += totalStudents;
        totalAbsentForDay += absentCount;

        // Add to Breakdown List
        lectures.add({
          'time': "${data['subjectName']} (${data['timeSlot']})",
          'percent': "$lecturePercent%",
          'color': lecturePercent < 75 ? Colors.red : Colors.green, // Red if low attendance
        });
      }

      // Calculate Overall Day Percentage
      int dayPercent = totalStudentsForDay == 0 ? 0 : (((totalStudentsForDay - totalAbsentForDay) / totalStudentsForDay) * 100).round();

      if (mounted) {
        setState(() {
          _todayAbsent = totalAbsentForDay.toString();
          _todayAttendancePercent = "$dayPercent%";
          _todayLectures = lectures;
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Error fetching reports: $e");
      if(mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1.0,
        title: const Text(
          'Report',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      drawer: const Drawer(
        child: Sidebar(),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // --- TODAY'S REPORT (Dynamic) ---
                ReportCard(
                  title: 'Today Attendance Reports',
                  absentValue: _todayAbsent,
                  attendanceValue: _todayAttendancePercent,
                  lectureSlots: _todayLectures,
                  onDetailPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const Todayreport()),
                    );
                  },
                ),
                
                const SizedBox(height: 20),

                // --- TOMORROW'S REPORT (Static/Placeholder) ---
                const ReportCard(
                  title: 'Tomorrow Report',
                  absentValue: '-', 
                  attendanceValue: '-',
                  // lectureSlots is null, so it won't show the breakdown
                ),
              ],
            ),
          ),
    );
  }
}

/// A reusable widget to display a report card.
class ReportCard extends StatelessWidget {
  final String title;
  final String absentValue;
  final String attendanceValue;
  final List<Map<String, Object>>? lectureSlots;
  final VoidCallback? onDetailPressed; // Added callback for button

  const ReportCard({
    super.key,
    required this.title,
    required this.absentValue,
    required this.attendanceValue,
    this.lectureSlots,
    this.onDetailPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      elevation: 2.0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Card Title
            Row(
              children: [
                const Icon(Icons.bar_chart, color: Colors.purple),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Summary Boxes
            Row(
              children: [
                Expanded(
                  child: SummaryBox(
                    label: 'Absent Today',
                    value: absentValue,
                    backgroundColor: const Color(0xFFFEF2F2), // Light Red
                    valueColor: const Color(0xFFB91C1C), // Dark Red
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: SummaryBox(
                    label: 'Attendance %',
                    value: attendanceValue,
                    backgroundColor: const Color(0xFFF0FDF4), // Light Green
                    valueColor: const Color(0xFF15803D), // Dark Green
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Lecture Breakdown
            if (lectureSlots != null && lectureSlots!.isNotEmpty) ...[
              const Text(
                'Lecture-wise Breakdown',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              for (var slot in lectureSlots!)
                LectureSlotRow(
                  time: slot['time'] as String,
                  percent: slot['percent'] as String,
                  percentColor: slot['color'] as Color,
                ),
            ] else if (lectureSlots != null && lectureSlots!.isEmpty) ...[
               const Text("No lectures recorded yet.", style: TextStyle(color: Colors.grey)),
            ],

            const SizedBox(height: 20),

            // "View Detailed Report" Button
            if (onDetailPressed != null)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onDetailPressed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('View Detailed Report', style: TextStyle(color: Colors.white)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A reusable widget for the small summary boxes.
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

/// A reusable widget for a single lecture breakdown row.
class LectureSlotRow extends StatelessWidget {
  final String time;
  final String percent;
  final Color percentColor;

  const LectureSlotRow({
    super.key,
    required this.time,
    required this.percent,
    required this.percentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Expanded(
            child: Text(time, style: const TextStyle(fontSize: 14), overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: 8),
          Text(percent, style: TextStyle(fontSize: 14, color: percentColor, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
