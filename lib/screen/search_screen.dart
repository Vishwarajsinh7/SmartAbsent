import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:demo1/data/student_report_models.dart'; // Ensure you have the model file
import 'package:demo1/screen/student_detail_screen.dart';
import 'package:flutter/material.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _searchController = TextEditingController();
  
  // We now store "StudentReport" objects because they contain both 
  // the student info AND the calculated stats (percentage, absents).
  List<StudentReport> _allReports = [];
  List<StudentReport> _filteredReports = [];
  
  bool _isLoading = true;
  String _activeFilter = 'All'; // 'All', 'Computer', 'IT'

  @override
  void initState() {
    super.initState();
    _fetchAndCalculateData();
    _searchController.addListener(_filterStudents);
  }

  // --- DATA FETCHING & CALCULATION ENGINE ---
  Future<void> _fetchAndCalculateData() async {
    setState(() => _isLoading = true);

    try {
      // 1. Fetch ALL Attendance Logs (History)
      final logsSnapshot = await FirebaseFirestore.instance
          .collection('attendance_logs')
          .orderBy('timestamp', descending: true) // Newest first
          .get();

      // 2. Fetch ALL Students
      final studentsSnapshot = await FirebaseFirestore.instance.collection('student').get();

      List<StudentReport> calculatedReports = [];

      // 3. Loop through every student to calculate their specific report
      for (var studentDoc in studentsSnapshot.docs) {
        final studentData = studentDoc.data();
        
        // Basic Info
        String name = studentData['name'] ?? 'Unknown';
        String roll = studentData['rollNo'] ?? '0';
        String dept = studentData['department'] ?? 'Computer'; // 'Computer' or 'IT'
        String enroll = studentData['enrollmentNo'] ?? '';

        // Calculation Variables
        int totalLectures = 0;
        int totalAbsent = 0;
        Map<String, Map<String, int>> subjectStats = {}; 
        // Structure: { "SubjectName": { "present": 0, "absent": 0 } }

        // 4. Check this student against EVERY attendance log
        for (var log in logsSnapshot.docs) {
          final logData = log.data();
          
          // Determine if this lecture was for this student's department
          // (Assuming logs contain both, or we check if the lists are not empty)
          List<dynamic> ceAbsentees = logData['ceAbsentees'] ?? [];
          List<dynamic> itAbsentees = logData['itAbsentees'] ?? [];
          
          bool isRelevantLecture = false;
          bool isAbsent = false;

          // Logic: If student is CE, check CE list. If IT, check IT list.
          // We assume if the list exists in the log, the lecture happened for that dept.
          if (dept == 'Computer') {
             // If the log has data for CE (or totalCeStudents > 0), count it
             if (logData.containsKey('totalCeStudents') && logData['totalCeStudents'] > 0) {
               isRelevantLecture = true;
               if (ceAbsentees.contains(roll)) isAbsent = true;
             }
          } else if (dept == 'IT') {
             if (logData.containsKey('totalItStudents') && logData['totalItStudents'] > 0) {
               isRelevantLecture = true;
               if (itAbsentees.contains(roll)) isAbsent = true;
             }
          }

          if (isRelevantLecture) {
            totalLectures++;
            
            String subjectName = logData['subjectName'] ?? 'Unknown';
            
            // Initialize subject map if new
            if (!subjectStats.containsKey(subjectName)) {
              subjectStats[subjectName] = {'present': 0, 'absent': 0};
            }

            if (isAbsent) {
              totalAbsent++;
              subjectStats[subjectName]!['absent'] = subjectStats[subjectName]!['absent']! + 1;
            } else {
              subjectStats[subjectName]!['present'] = subjectStats[subjectName]!['present']! + 1;
            }
          }
        }

        // 5. Final Calculations for this student
        double percentage = totalLectures == 0 ? 100 : ((totalLectures - totalAbsent) / totalLectures) * 100;

        // Convert map to List<SubjectAttendance>
        List<SubjectAttendance> subRecords = [];
        subjectStats.forEach((key, value) {
          subRecords.add(SubjectAttendance(
            name: key,
            present: value['present']!,
            absent: value['absent']!,
          ));
        });

        // Add to master list
        calculatedReports.add(StudentReport(
          name: name,
          rollNo: roll,
          enrollmentNo: enroll,
          department: dept,
          totalAbsentLectures: totalAbsent,
          overallAttendancePercentage: percentage.round(),
          subjectRecords: subRecords,
        ));
      }

      if (mounted) {
        setState(() {
          _allReports = calculatedReports;
          _filteredReports = calculatedReports; // Show all initially
          _isLoading = false;
        });
      }

    } catch (e) {
      print("Error calculating reports: $e");
      if(mounted) setState(() => _isLoading = false);
    }
  }

  // --- FILTER LOGIC ---
  void _filterStudents() {
    final query = _searchController.text.toLowerCase();
    
    setState(() {
      List<StudentReport> results = _allReports;

      // 1. Dept Filter
      if (_activeFilter != 'All') {
        // Note: Ensure this matches your database string ("Computer" vs "CS")
        String filterKey = _activeFilter == 'CS' ? 'Computer' : _activeFilter;
        results = results.where((s) => s.department == filterKey).toList();
      }

      // 2. Text Search
      if (query.isNotEmpty) {
        results = results.where((s) {
          return s.name.toLowerCase().contains(query) ||
                 s.rollNo.contains(query);
        }).toList();
      }
      
      _filteredReports = results;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(title: const Text('Search & Filter')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Search Bar
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search students...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0)),
                fillColor: Colors.white,
                filled: true,
              ),
            ),
            const SizedBox(height: 16),

            // Filter Chips
            Row(
              children: ['All', 'CS', 'IT'].map((dept) {
                final isSelected = _activeFilter == dept;
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ChoiceChip(
                    label: Text(dept),
                    selected: isSelected,
                    selectedColor: const Color(0xFF2563EB),
                    labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black),
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _activeFilter = dept;
                        });
                        _filterStudents();
                      }
                    },
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // List View
            Expanded(
              child: _isLoading 
                ? const Center(child: CircularProgressIndicator())
                : _filteredReports.isEmpty 
                    ? const Center(child: Text("No students found"))
                    : ListView.builder(
                        itemCount: _filteredReports.length,
                        itemBuilder: (context, index) {
                          return StudentResultCard(report: _filteredReports[index]);
                        },
                      ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- UPDATED CARD WIDGET ---
class StudentResultCard extends StatelessWidget {
  final StudentReport report;
  
  const StudentResultCard({super.key, required this.report});

  @override
  Widget build(BuildContext context) {
    bool isCS = report.department == 'Computer' || report.department == 'CS';

    return Card(
      elevation: 2,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.only(bottom: 16.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row: Name & Dept Badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    report.name, 
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                      fontSize: 12
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 8),
            
            // Info Row
            Text('Roll: ${report.rollNo}', style: const TextStyle(color: Colors.grey)),
            Text('Enroll: ${report.enrollmentNo}', style: const TextStyle(color: Colors.grey)),
            
            const SizedBox(height: 4),
            
            // Stats Preview (Optional but helpful)
            Row(
              children: [
                Text('Attendance: ', style: TextStyle(color: Colors.grey.shade700)),
                Text(
                  '${report.overallAttendancePercentage}%', 
                  style: TextStyle(
                    fontWeight: FontWeight.bold, 
                    color: report.overallAttendancePercentage < 75 ? Colors.red : Colors.green
                  )
                ),
              ],
            ),

            const SizedBox(height: 16),
            
            // View Report Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  // Navigate to Detail Screen with REAL data
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => StudentDetailScreen(student: report),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text('View Detailed Report'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
