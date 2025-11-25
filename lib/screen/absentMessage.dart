import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:demo1/screen/sidebar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart'; 

void main() {
  runApp(const AttendanceApp());
}

// 1. DATA MODEL
class SubjectData {
  String title;
  String time;
  TextEditingController ceController = TextEditingController();
  TextEditingController itController = TextEditingController();
  
  // Logic Update:
  // true = "Direct Mode" (Typed numbers are ABSENT)
  // false = "Inverse Mode" (Typed numbers are PRESENT, calculate the rest)
  bool ceDirectMode = true; 
  bool itDirectMode = true;

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
  
  List<SubjectData> _subjects = [];
  Map<String, String> _studentLookup = {}; 
  
  // NEW: Store all roll numbers to calculate inverse logic
  List<String> _allCERollNos = []; 
  List<String> _allITRollNos = [];

  bool _isLoading = true;
  String _currentDay = '';

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    
    try {
      DateTime now = DateTime.now();
      List<String> weekDays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
      _currentDay = weekDays[now.weekday - 1]; 
      
      // 1. Fetch Subjects
      final subjectSnapshot = await FirebaseFirestore.instance
          .collection('subject') 
          .where('day', isEqualTo: _currentDay) 
          .get();

      List<SubjectData> loadedSubjects = [];
      for (var doc in subjectSnapshot.docs) {
        final data = doc.data();
        String subName = data['subjectName'] ?? 'Unknown';
        String facName = data['facultyName'] ?? 'Unknown';
        String time = data['timeSlot'] ?? 'No Time';

        loadedSubjects.add(SubjectData(
          title: "$subName - $facName",
          time: time,
        ));
      }

      // 2. Fetch Students & Populate Master Lists
      final studentSnapshot = await FirebaseFirestore.instance.collection('student').get();
      Map<String, String> lookup = {};
      List<String> ceRolls = [];
      List<String> itRolls = [];
      
      for (var doc in studentSnapshot.docs) {
        final data = doc.data();
        
        String dept = data['department'] ?? "";
        String roll = data['rollNo'] ?? "";
        String name = data['name'] ?? "Unknown";
        
        if (dept.isNotEmpty && roll.isNotEmpty) {
           lookup['${dept}_${roll}'] = name;

           // Add to master lists for inverse calculation
           if (dept == "Computer") ceRolls.add(roll);
           if (dept == "IT") itRolls.add(roll);
        }
      }

      // Sort the lists numerically for better output
      ceRolls.sort((a, b) => int.tryParse(a)!.compareTo(int.tryParse(b)!));
      itRolls.sort((a, b) => int.tryParse(a)!.compareTo(int.tryParse(b)!));

      if (mounted) {
        setState(() {
          _subjects = loadedSubjects;
          _studentLookup = lookup;
          _allCERollNos = ceRolls;
          _allITRollNos = itRolls;
          _isLoading = false;
        });
      }

    } catch (e) {
      print("ERROR: $e");
      if(mounted) setState(() => _isLoading = false);
    }
  }

  void _generateMessage() {
    DateTime now = DateTime.now();
    String dateStr = "${now.day.toString().padLeft(2, '0')}-${now.month.toString().padLeft(2, '0')}-${now.year}";

    StringBuffer buffer = StringBuffer();

    buffer.writeln("આજે $dateStr ($_currentDay) ના રોજ ગેરહાજર રહેલા વિદ્યાર્થીઓની યાદી નીચે મુજબ છે");
    buffer.writeln("Following is the list of students who remained absent today $dateStr ($_currentDay)\n");

    if (_subjects.isEmpty) {
      buffer.writeln("No classes scheduled for today.");
    }

    for (var subject in _subjects) {
      buffer.writeln("${subject.title} (${subject.time})\n");

      // --- CE Logic ---
      buffer.writeln("CE Absentees :");
      List<String> ceAbsentees = _calculateAbsentees(
        subject.ceController.text, 
        subject.ceDirectMode, 
        _allCERollNos
      );
      buffer.writeln(_formatOutput(ceAbsentees, "CE"));
      buffer.writeln(); 

      // --- IT Logic ---
      buffer.writeln("IT Absentees :");
      List<String> itAbsentees = _calculateAbsentees(
        subject.itController.text, 
        subject.itDirectMode, 
        _allITRollNos
      );
      buffer.writeln(_formatOutput(itAbsentees, "IT"));

      buffer.writeln("\n------------------------\n");
    }

    setState(() {
      _outputController.text = buffer.toString();
    });
  }

  // CORE LOGIC: Determines who is absent based on Checkbox state
  List<String> _calculateAbsentees(String input, bool isDirectMode, List<String> allStudents) {
    if (input.trim().isEmpty) return []; // No input means None

    List<String> typedRolls = input.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

    if (isDirectMode) {
      // Checked: Typed numbers ARE the absentees
      return typedRolls;
    } else {
      // Unchecked: Typed numbers are PRESENT. We need to find who is NOT in this list.
      // Logic: Total Students - Present Students = Absent Students
      List<String> actualAbsentees = [];
      for (var roll in allStudents) {
        if (!typedRolls.contains(roll)) {
          actualAbsentees.add(roll);
        }
      }
      return actualAbsentees;
    }
  }

  // HELPER: Adds Names to the Roll numbers
  String _formatOutput(List<String> rollList, String deptKey) {
    if (rollList.isEmpty) return "None";

    List<String> formattedNames = [];
    String dbDept = deptKey == "CE" ? "Computer" : "IT";

    for (var roll in rollList) {
      String key = "${dbDept}_${roll}";
      String name = _studentLookup[key] ?? "";
      
      if (name.isNotEmpty) {
        formattedNames.add("$roll - $name");
      } else {
        formattedNames.add(roll);
      }
    }
    return formattedNames.join('\n');
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
            
            DepartmentRow(
              name: 'CE', 
              controller: data.ceController, 
              isDirectMode: data.ceDirectMode, 
              onModeChanged: (v) => data.ceDirectMode = v
            ),
            DepartmentRow(
              name: 'IT', 
              controller: data.itController, 
              isDirectMode: data.itDirectMode, 
              onModeChanged: (v) => data.itDirectMode = v
            ),
          ],
        ),
      ),
    );
  }
}

class DepartmentRow extends StatefulWidget {
  final String name;
  final TextEditingController controller;
  final bool isDirectMode;
  final Function(bool) onModeChanged;

  const DepartmentRow({super.key, required this.name, required this.controller, required this.isDirectMode, required this.onModeChanged});

  @override
  State<DepartmentRow> createState() => _DepartmentRowState();
}

class _DepartmentRowState extends State<DepartmentRow> {
  late bool _localIsDirect;

  @override
  void initState() {
    super.initState();
    _localIsDirect = widget.isDirectMode;
  }

  @override
  Widget build(BuildContext context) {
    // 
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          SizedBox(width: 30, child: Text(widget.name, style: const TextStyle(fontWeight: FontWeight.w500))),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: widget.controller,
              // ENABLED ALWAYS now, because we type numbers in both cases
              enabled: true, 
              decoration: InputDecoration(
                // Hint changes based on mode
                hintText: _localIsDirect ? 'Enter Absent Rolls' : 'Enter Present Rolls',
                hintStyle: TextStyle(
                  color: _localIsDirect ? Colors.grey : Colors.orange.shade700,
                  fontSize: 13
                ),
                isDense: true,
              ),
              keyboardType: TextInputType.number, 
            ),
          ),
          Tooltip(
            message: _localIsDirect ? "Tick: Entering Absentees" : "Untick: Entering Present (Calc Inverse)",
            child: Checkbox(
              value: _localIsDirect,
              activeColor: Colors.blue, // Blue = Standard Mode
              side: _localIsDirect ? null : const BorderSide(color: Colors.orange, width: 2), // Orange border = Inverse Mode
              onChanged: (value) {
                setState(() => _localIsDirect = value ?? true);
                widget.onModeChanged(_localIsDirect);
                // We do NOT clear text here, because user might want to toggle logic on existing numbers
              },
            ),
          ),
        ],
      ),
    );
  }
}
