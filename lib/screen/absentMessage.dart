import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:demo1/screen/sidebar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart'; 

void main() {
  runApp(const AttendanceApp());
}

// --- 1. DATA MODEL ---
class SubjectData {
  String title;
  String time;
  TextEditingController ceController = TextEditingController();
  TextEditingController itController = TextEditingController();
  
  // Logic: 
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
  
  // State variables
  List<SubjectData> _subjects = [];
  Map<String, String> _studentLookup = {}; 
  
  // Store all roll numbers to calculate inverse logic (Present -> Absent)
  List<String> _allCERollNos = []; 
  List<String> _allITRollNos = [];

  bool _isLoading = true;
  String _currentDay = '';

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  // --- 2. FETCH DATA ---
  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    
    try {
      DateTime now = DateTime.now();
      List<String> weekDays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
      _currentDay = weekDays[now.weekday - 1]; 
      
      // A. Fetch Subjects for Today
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

      // B. Fetch Students & Populate Master Lists
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

      // Sort the lists numerically
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

  // --- 3. SAVE TO DATABASE ---
  Future<void> _saveAttendanceToFirebase() async {
    setState(() => _isLoading = true);
    DateTime now = DateTime.now();
    String dateStr = "${now.day.toString().padLeft(2, '0')}-${now.month.toString().padLeft(2, '0')}-${now.year}";

    WriteBatch batch = FirebaseFirestore.instance.batch();

    try {
      for (var subject in _subjects) {
        
        // 1. Calculate the final list of absentees using the logic
        List<String> finalCeAbsentees = _calculateAbsentees(
            subject.ceController.text, subject.ceDirectMode, _allCERollNos);
        
        List<String> finalItAbsentees = _calculateAbsentees(
            subject.itController.text, subject.itDirectMode, _allITRollNos);

        // 2. Create a reference for a new document in 'attendance_logs'
        DocumentReference docRef = FirebaseFirestore.instance.collection('attendance_logs').doc();

        // 3. Prepare the data
        Map<String, dynamic> logData = {
          'date': dateStr,
          'timestamp': FieldValue.serverTimestamp(),
          'day': _currentDay,
          'subjectName': subject.title, 
          'timeSlot': subject.time,     
          
          'ceAbsentees': finalCeAbsentees,
          'itAbsentees': finalItAbsentees,
          
          // Saving totals is useful for calculating % later
          'totalCeStudents': _allCERollNos.length, 
          'totalItStudents': _allITRollNos.length,
        };

        batch.set(docRef, logData);
      }

      // 4. Commit all changes
      await batch.commit();

      // 5. Also Generate Message on screen
      _generateMessage();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Attendance Saved Successfully!')),
        );
      }
    } catch (e) {
      print("Error saving attendance: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- 4. GENERATE MESSAGE ---
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

  // --- HELPER LOGIC ---
  
  // Determines who is absent based on Checkbox state
  List<String> _calculateAbsentees(String input, bool isDirectMode, List<String> allStudents) {
    if (input.trim().isEmpty) return []; // No input means None

    List<String> typedRolls = input.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

    if (isDirectMode) {
      // Checked: Typed numbers ARE the absentees
      return typedRolls;
    } else {
      // Unchecked: Typed numbers are PRESENT. We need to find who is NOT in this list.
      List<String> actualAbsentees = [];
      for (var roll in allStudents) {
        if (!typedRolls.contains(roll)) {
          actualAbsentees.add(roll);
        }
      }
      return actualAbsentees;
    }
  }

  // Adds Names to the Roll numbers for display
  String _formatOutput(List<String> rollList, String deptKey) {
    if (rollList.isEmpty) return "None";

    // Sort for nice display
    try {
      rollList.sort((a, b) => int.parse(a).compareTo(int.parse(b)));
    } catch (e) {
      // Ignore sort error if non-numbers are typed
    }

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
                        flex: 2,
                        child: OutlinedButton(
                          onPressed: _saveAttendanceToFirebase, 
                          style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12)),
                          child: const Text('Save & Generate'),
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          SizedBox(width: 30, child: Text(widget.name, style: const TextStyle(fontWeight: FontWeight.w500))),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: widget.controller,
              enabled: true, 
              decoration: InputDecoration(
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
              activeColor: Colors.blue, 
              side: _localIsDirect ? null : const BorderSide(color: Colors.orange, width: 2), 
              onChanged: (value) {
                setState(() => _localIsDirect = value ?? true);
                widget.onModeChanged(_localIsDirect);
              },
            ),
          ),
        ],
      ),
    );
  }
}
