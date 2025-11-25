import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:demo1/screen/sidebar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart'; // Add intl package to pubspec.yaml if needed for simple date formatting

void main() {
  runApp(const AttendanceApp());
}

// 1. DATA MODEL
class SubjectData {
  String title;
  String time;
  TextEditingController ceController = TextEditingController();
  TextEditingController itController = TextEditingController();
  bool includeCE = true;
  bool includeIT = true;

  SubjectData({required this.title, required this.time});
}

class AttendanceApp extends StatelessWidget {
  const AttendanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        primaryColor: Colors.white,
        scaffoldBackgroundColor: const Color(0xFFF9FAFB),
        fontFamily: 'Poppins',
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          elevation: 1,
          iconTheme: IconThemeData(color: Colors.black),
          titleTextStyle: TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.w600),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
      ),
      home: const AbsenceMessageGeneratorScreen(),
    );
  }
}

class AbsenceMessageGeneratorScreen extends StatefulWidget {
  const AbsenceMessageGeneratorScreen({super.key});

  @override
  State<AbsenceMessageGeneratorScreen> createState() => _AbsenceMessageGeneratorScreenState();
}

class _AbsenceMessageGeneratorScreenState extends State<AbsenceMessageGeneratorScreen> {
  final TextEditingController _outputController = TextEditingController();
  
  // State variables
  List<SubjectData> _subjects = [];
  Map<String, String> _studentLookup = {}; // Key: "Dept_Roll", Value: "Name"
  bool _isLoading = true;
  String _currentDay = '';

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  // 2. FETCH DATA FROM FIREBASE
Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    
    try {
      // 1. Get Today's Day
      DateTime now = DateTime.now();
      List<String> weekDays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
      _currentDay = weekDays[now.weekday - 1]; 
      
      // 2. Fetch Subjects ONLY for Today
      // We added the filter back here:
      final subjectSnapshot = await FirebaseFirestore.instance
          .collection('subject') 
          .where('day', isEqualTo: _currentDay) 
          .get();

      List<SubjectData> loadedSubjects = [];
      for (var doc in subjectSnapshot.docs) {
        final data = doc.data();
        
        // Safety checks (keep these to prevent crashes)
        String subName = data['subjectName'] ?? 'Unknown';
        String facName = data['facultyName'] ?? 'Unknown';
        String time = data['timeSlot'] ?? 'No Time';

        loadedSubjects.add(SubjectData(
          title: "$subName - $facName",
          time: time,
        ));
      }

      // 3. Fetch All Students (For Name Lookup)
      final studentSnapshot = await FirebaseFirestore.instance.collection('student').get();
      Map<String, String> lookup = {};
      
      for (var doc in studentSnapshot.docs) {
        final data = doc.data();
        
        String dept = data['department'] ?? "";
        String roll = data['rollNo'] ?? "";
        String name = data['name'] ?? "Unknown";
        
        // Only add to lookup if valid data exists
        if (dept.isNotEmpty && roll.isNotEmpty) {
           lookup['${dept}_${roll}'] = name;
        }
      }

      if (mounted) {
        setState(() {
          _subjects = loadedSubjects;
          _studentLookup = lookup;
          _isLoading = false;
        });
      }

    } catch (e) {
      print("ERROR: $e");
      if(mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // 3. GENERATE MESSAGE LOGIC
  void _generateMessage() {
    DateTime now = DateTime.now();
    String dateStr = "${now.day.toString().padLeft(2, '0')}-${now.month.toString().padLeft(2, '0')}-${now.year}";

    StringBuffer buffer = StringBuffer();

    // Header
    buffer.writeln("આજે $dateStr ($_currentDay) ના રોજ ગેરહાજર રહેલા વિદ્યાર્થીઓની યાદી નીચે મુજબ છે");
    buffer.writeln("Following is the list of students who remained absent today $dateStr ($_currentDay)\n");

    if (_subjects.isEmpty) {
      buffer.writeln("No classes scheduled for today.");
    }

    for (var subject in _subjects) {
      if (!subject.includeCE && !subject.includeIT) continue;

      buffer.writeln("${subject.title} (${subject.time})\n");

      // Helper function to process comma-separated roll numbers
      String processAbsentees(String input, String deptKey) {
        if (input.trim().isEmpty) return "None";
        
        List<String> rolls = input.split(',');
        List<String> formattedNames = [];

        for (var roll in rolls) {
          String cleanRoll = roll.trim();
          if (cleanRoll.isEmpty) continue;

          // Lookup Name using our Map
          // Note: In DB you saved "Computer" but UI might mean "CE". Map accordingly.
          String dbDept = deptKey == "CE" ? "Computer" : "IT"; 
          String key = "${dbDept}_${cleanRoll}";
          
          String name = _studentLookup[key] ?? ""; // Empty string if name not found
          
          if (name.isNotEmpty) {
            formattedNames.add("$cleanRoll - $name");
          } else {
            formattedNames.add(cleanRoll); // Just number if name not found
          }
        }
        return formattedNames.join('\n');
      }

      if (subject.includeCE) {
        buffer.writeln("CE Absentees :");
        buffer.writeln(processAbsentees(subject.ceController.text, "CE"));
        buffer.writeln(); 
      }

      if (subject.includeIT) {
        buffer.writeln("IT Absentees :");
        buffer.writeln(processAbsentees(subject.itController.text, "IT"));
      }

      buffer.writeln("\n------------------------\n");
    }

    setState(() {
      _outputController.text = buffer.toString();
    });
  }

  void _copyToClipboard() {
    Clipboard.setData(ClipboardData(text: _outputController.text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Message copied!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AttendanceApp')),
      drawer: const Drawer(child: Sidebar()),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.calendar_today, color: Theme.of(context).primaryColorDark),
                    const SizedBox(width: 8),
                    Text(
                      'Schedule for $_currentDay',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                if (_subjects.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(20.0),
                    child: Center(child: Text("No subjects found for today! Add some in Timetable.")),
                  )
                else
                  ..._subjects.map((subject) => Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: SubjectCard(data: subject),
                  )),

                const SizedBox(height: 8),
                const Text('Generated Message', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                TextField(
                  controller: _outputController,
                  maxLines: 8,
                  decoration: const InputDecoration(hintText: 'Result will appear here...'),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: ElevatedButton(
                        onPressed: _generateMessage,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('Generate'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: OutlinedButton(
                        onPressed: _copyToClipboard,
                        child: const Text('Copy'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
    );
  }
}

class SubjectCard extends StatelessWidget {
  final SubjectData data;
  const SubjectCard({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${data.title} (${data.time})', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            DepartmentRow(name: 'CE', controller: data.ceController, isChecked: data.includeCE, onCheckChanged: (v) => data.includeCE = v),
            DepartmentRow(name: 'IT', controller: data.itController, isChecked: data.includeIT, onCheckChanged: (v) => data.includeIT = v),
          ],
        ),
      ),
    );
  }
}

class DepartmentRow extends StatefulWidget {
  final String name;
  final TextEditingController controller;
  final bool isChecked;
  final Function(bool) onCheckChanged;

  const DepartmentRow({super.key, required this.name, required this.controller, required this.isChecked, required this.onCheckChanged});

  @override
  State<DepartmentRow> createState() => _DepartmentRowState();
}

class _DepartmentRowState extends State<DepartmentRow> {
  late bool _localIsChecked;

  @override
  void initState() {
    super.initState();
    _localIsChecked = widget.isChecked;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          SizedBox(width: 30, child: Text(widget.name, style: const TextStyle(fontWeight: FontWeight.w500))),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: widget.controller,
              enabled: _localIsChecked,
              decoration: const InputDecoration(hintText: 'Roll Nos (e.g. 1, 5)', isDense: true),
              keyboardType: TextInputType.number, // Optimized for number entry
            ),
          ),
          Checkbox(
            value: _localIsChecked,
            onChanged: (value) {
              setState(() => _localIsChecked = value ?? false);
              widget.onCheckChanged(_localIsChecked);
            },
          ),
        ],
      ),
    );
  }
}
