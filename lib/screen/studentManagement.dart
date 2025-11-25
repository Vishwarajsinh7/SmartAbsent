import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:demo1/data/student.dart';
import 'package:demo1/widget/add_student_dialog.dart';
import 'package:flutter/material.dart';

class StudentManagementScreen extends StatefulWidget {
  const StudentManagementScreen({super.key});

  @override
  State<StudentManagementScreen> createState() => _StudentManagementScreenState();
}

class _StudentManagementScreenState extends State<StudentManagementScreen> {
  void _showAddStudentDialog({AbsentStudent? studentToEdit, String? docId}) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        // We will implement the edit logic later, for now just showing the dialog
        return AddStudentDialog(student: studentToEdit);
      },
    );
  }

  // A helper to delete a student
  void _deleteStudent(String docId) {
    FirebaseFirestore.instance.collection('student').doc(docId).delete();
     ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Student deleted successfully')),
      );
  }

  @override
  Widget build(BuildContext context) {
    // Using a slightly off-white background to make cards pop
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA), 
      appBar: AppBar(
        title: const Text('Student Detail', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('student').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No students found. Add one!'));
          }

          // Mapping data and keeping the Document ID for deletion/editing
          final docs = snapshot.data!.docs;
          final ceStudentsData = <(AbsentStudent, String)>[]; // Storing (Student, DocId) tuples
          final itStudentsData = <(AbsentStudent, String)>[];

          for (var doc in docs) {
            final data = doc.data() as Map<String, dynamic>;
            final student = AbsentStudent(
              name: data['name'] ?? 'Unknown',
              rollNo: data['rollNo'] ?? '',
              department: data['department'] ?? '',
              enrollmentNo: data['enrollmentNo'] ?? '',
            );
            
            if (student.department == 'Computer') {
              ceStudentsData.add((student, doc.id));
            } else if (student.department == 'IT') {
              itStudentsData.add((student, doc.id));
            }
          }

          return ListView(
            padding: const EdgeInsets.all(20.0),
            children: [
              // Modern Header Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Students', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Color(0xFF2D3748))),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4299E1), // Modern blue
                      foregroundColor: Colors.white,
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    icon: const Icon(Icons.add, size: 20),
                    label: const Text('Add', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    onPressed: () => _showAddStudentDialog(),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // CE Table
              if (ceStudentsData.isNotEmpty)
                StudentListCard(
                  title: 'Student CE', 
                  studentsData: ceStudentsData,
                  onDelete: _deleteStudent,
                  onEdit: (student, id) => _showAddStudentDialog(studentToEdit: student, docId: id),
                ),
              
              const SizedBox(height: 24),

              // IT Table
              if (itStudentsData.isNotEmpty)
                 StudentListCard(
                  title: 'Student IT', 
                  studentsData: itStudentsData,
                   onDelete: _deleteStudent,
                   onEdit: (student, id) => _showAddStudentDialog(studentToEdit: student, docId: id),
                ),
            ],
          );
        },
      ),
    );
  }
}

// ==================== MODERN REUSABLE WIDGET ====================

class StudentListCard extends StatelessWidget {
  final String title;
  // Passing tuples of (Student Data, Document ID)
  final List<(AbsentStudent, String)> studentsData;
  final Function(String docId) onDelete;
  final Function(AbsentStudent student, String docId) onEdit;

  const StudentListCard({
    super.key, 
    required this.title, 
    required this.studentsData,
    required this.onDelete,
    required this.onEdit,
  });

  // Text styles for consistency
  final TextStyle _headerStyle = const TextStyle(fontWeight: FontWeight.bold,fontSize: 14, color: Color(0xFF718096));
  final TextStyle _cellStyle = const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: Color(0xFF2D3748));

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header outside the card
        Padding(
          padding: const EdgeInsets.only(left: 8.0, bottom: 12.0),
          child: Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF2D3748))),
        ),
        Card(
          elevation: 4, // Softer shadow
          shadowColor: Colors.black12,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Column(
              children: [
                // --- Table Header ---
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: Row(
                    children: [
                      Expanded(flex: 2, child: Text('Roll No', style: _headerStyle)),
                      Expanded(flex: 4, child: Text('Name', style: _headerStyle)),
                      Expanded(flex: 2, child: Text('Dept', style: _headerStyle)),
                      SizedBox(width: 80, child: Text('Actions', textAlign: TextAlign.center, style: _headerStyle)),
                    ],
                  ),
                ),
                const Divider(height: 1, color: Color(0xFFE2E8F0)),

                // --- Student Rows ---
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: studentsData.length,
                  separatorBuilder: (context, index) => const Divider(height: 1, indent: 16, endIndent: 16, color: Color(0xFFEDF2F7)),
                  itemBuilder: (context, index) {
                    final student = studentsData[index].$1;
                    final docId = studentsData[index].$2;
                    // Helper to shorten department name for the table view
                    String shortDept = student.department == 'Computer' ? 'CE' : student.department;

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
                      child: Row(
                        children: [
                          Expanded(flex: 2, child: Text(student.rollNo, style: _cellStyle)),
                          Expanded(flex: 4, child: Text(student.name, style: _cellStyle)),
                           // Using a tag-like look for Dept
                          Expanded(flex: 2, child: Align(
                             alignment: Alignment.centerLeft,
                             child: Container(
                               padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                               decoration: BoxDecoration(
                                 color: const Color(0xFFEBF8FF),
                                 borderRadius: BorderRadius.circular(6)
                               ),
                               child: Text(shortDept, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF3182CE)))
                             ),
                           )),
                          // --- Actions Column ---
                          SizedBox(width: 80, child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Edit button (Blue)
                              InkWell(
                                onTap: () => onEdit(student, docId),
                                borderRadius: BorderRadius.circular(8),
                                child: const Padding(
                                  padding: EdgeInsets.all(6.0),
                                  child: Icon(Icons.edit_outlined, color: Color(0xFF3182CE), size: 22),
                                ),
                              ),
                              const SizedBox(width: 4),
                              // Delete button (Red)
                              InkWell(
                                onTap: () => onDelete(docId),
                                 borderRadius: BorderRadius.circular(8),
                                child: const Padding(
                                  padding: EdgeInsets.all(6.0),
                                  child: Icon(Icons.delete_outline, color: Color(0xFFE53E3E), size: 22),
                                ),
                              ),
                            ],
                          )),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
