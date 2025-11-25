import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AddSubjectDialog extends StatefulWidget {
  // We add these two variables so the screen can pass data to the dialog
  final String? docId;
  final Map<String, dynamic>? subjectToEdit;

  const AddSubjectDialog({
    super.key,
    this.docId,
    this.subjectToEdit,
  });

  @override
  State<AddSubjectDialog> createState() => _AddSubjectDialogState();
}

class _AddSubjectDialogState extends State<AddSubjectDialog> {
  final _subjectNameController = TextEditingController();
  final _facultyNameController = TextEditingController(); 
  
  String? _selectedDay;
  String? _selectedTimeSlot;
  bool _isLoading = false; 

  final List<String> _days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
  final List<String> _timeSlots = ['8:00 - 8:55', '8:55 - 9:45', '10:00 - 10:50', '10:50 - 11:40', '12:30 - 1:20', '1:20 - 2:10'];

  @override
  void initState() {
    super.initState();
    // Check if we are in "Edit Mode"
    if (widget.subjectToEdit != null) {
      // Pre-fill the form with existing data
      _subjectNameController.text = widget.subjectToEdit!['subjectName'] ?? '';
      _facultyNameController.text = widget.subjectToEdit!['facultyName'] ?? '';
      _selectedDay = widget.subjectToEdit!['day'];
      _selectedTimeSlot = widget.subjectToEdit!['timeSlot'];
    }
  }

  @override
  void dispose() {
    _subjectNameController.dispose();
    _facultyNameController.dispose();
    super.dispose();
  }

  Future<void> _saveToFirebase() async {
    if (_subjectNameController.text.isEmpty ||
        _facultyNameController.text.isEmpty || 
        _selectedDay == null ||
        _selectedTimeSlot == null) {
        return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final data = {
        'subjectName': _subjectNameController.text.trim(),
        'day': _selectedDay,
        'timeSlot': _selectedTimeSlot,
        'facultyName': _facultyNameController.text.trim(),
        'timestamp': FieldValue.serverTimestamp(),
      };

      if (widget.docId == null) {
        // Create NEW document
        await FirebaseFirestore.instance.collection('subject').add(data);
      } else {
        // Update EXISTING document
        await FirebaseFirestore.instance.collection('subject').doc(widget.docId).update(data);
      }

      if (mounted) {
        Navigator.of(context).pop(); 
      }
    } catch (e) {
      print("Error uploading: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.docId == null ? 'Add New Subject' : 'Edit Subject'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _subjectNameController,
              decoration: const InputDecoration(
                labelText: 'Subject Name',
                hintText: 'e.g., CCT',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.characters,
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _facultyNameController,
              decoration: const InputDecoration(
                labelText: 'Faculty Name',
                hintText: 'e.g., Arzoo Sir',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),

            DropdownButtonFormField<String>(
              value: _selectedDay,
              hint: const Text('Select Day'),
              items: _days.map((day) => DropdownMenuItem(value: day, child: Text(day))).toList(),
              onChanged: (value) => setState(() => _selectedDay = value),
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),

            DropdownButtonFormField<String>(
              value: _selectedTimeSlot,
              hint: const Text('Select Time Slot'),
              items: _timeSlots.map((slot) => DropdownMenuItem(value: slot, child: Text(slot))).toList(),
              onChanged: (value) => setState(() => _selectedTimeSlot = value),
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(), 
          child: const Text('Cancel')
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _saveToFirebase,
          child: _isLoading 
            ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2)) 
            : Text(widget.docId == null ? 'Add' : 'Update'),
        ),
      ],
    );
  }
}
