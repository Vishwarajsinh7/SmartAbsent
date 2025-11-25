import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:demo1/widget/add_subject_dialog.dart';
import 'package:flutter/material.dart';

class TimetableScreen extends StatefulWidget {
  const TimetableScreen({super.key});

  @override
  State<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends State<TimetableScreen> {
  final List<String> _orderedDays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];

  void _deleteSubject(String docId) {
    FirebaseFirestore.instance.collection('subject').doc(docId).delete();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Subject deleted')),
    );
  }

  // UPDATED: Now accepts optional arguments for editing
  void _showAddDialog({String? docId, Map<String, dynamic>? existingData}) {
    showDialog(
      context: context,
      builder: (context) => AddSubjectDialog(
        docId: docId, 
        
        subjectToEdit: existingData, // Pass the existing data here
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Timetable Management'),
        backgroundColor: Colors.white,
        elevation: 0,
        titleTextStyle: const TextStyle(color: Colors.black, fontSize: 20, fontWeight: FontWeight.bold),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('subject').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildEmptyState();
          }

          final allDocs = snapshot.data!.docs;

          return ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Timetable', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add'),
                    onPressed: () => _showAddDialog(), // Add mode (no arguments)
                  ),
                ],
              ),
              const SizedBox(height: 16),

              ..._orderedDays.map((day) {
                final dayClasses = allDocs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return data['day'] == day;
                }).toList();

                if (dayClasses.isEmpty) return const SizedBox.shrink();

                return DaySchedule(
                  day: day,
                  docs: dayClasses,
                  onDelete: _deleteSubject,
                  onEdit: _showAddDialog, // Pass the function down
                );
              }),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('No classes added yet.', style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Add Class'),
            onPressed: () => _showAddDialog(),
          ),
        ],
      ),
    );
  }
}

class DaySchedule extends StatelessWidget {
  final String day;
  final List<QueryDocumentSnapshot> docs;
  final Function(String) onDelete;
  final Function({String? docId, Map<String, dynamic>? existingData}) onEdit; // Added onEdit

  const DaySchedule({
    super.key,
    required this.day,
    required this.docs,
    required this.onDelete,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(day, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Text('${docs.length} slots', style: const TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 8),
          ...docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return ClassEntryTile(
              data: data, // Pass full data object
              docId: doc.id,
              onDelete: onDelete,
              onEdit: onEdit,
            );
          }),
        ],
      ),
    );
  }
}

class ClassEntryTile extends StatelessWidget {
  final Map<String, dynamic> data; // Changed to accept full data map
  final String docId;
  final Function(String) onDelete;
  final Function({String? docId, Map<String, dynamic>? existingData}) onEdit;

  const ClassEntryTile({
    super.key,
    required this.data,
    required this.docId,
    required this.onDelete,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final subject = data['subjectName'] ?? 'Unknown';
    final faculty = data['facultyName'] ?? '';
    final time = data['timeSlot'] ?? '';
    final bgColor = _getSubjectColor(subject);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: TextSpan(
                      style: const TextStyle(color: Colors.black87, fontSize: 16),
                      children: [
                        TextSpan(text: subject, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E40AF))),
                        const TextSpan(text: " - "),
                        TextSpan(text: faculty, style: const TextStyle(fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    time,
                    style: TextStyle(color: Colors.blue[800], fontSize: 13),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.blue, size: 20),
              onPressed: () {
                // Call the edit function with the ID and Data
                onEdit(docId: docId, existingData: data);
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.redAccent, size: 20),
              onPressed: () => onDelete(docId),
            ),
          ],
        ),
      ),
    );
  }

  Color _getSubjectColor(String subject) {
    if (subject.toLowerCase().contains('android')) return const Color(0xFFECFDF5);
    if (subject.toLowerCase().contains('se')) return const Color(0xFFEFF6FF);
    return const Color(0xFFEFF6FF);
  }
}
