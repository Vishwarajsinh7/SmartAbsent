import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:demo1/data/student.dart'; 

class AddStudentDialog extends StatefulWidget {
  final AbsentStudent? student;

  const AddStudentDialog({super.key, this.student});

  @override
  State<AddStudentDialog> createState() => _AddStudentDialogState();
}

class _AddStudentDialogState extends State<AddStudentDialog> {
  final _nameController = TextEditingController();
  final _rollNoController = TextEditingController();
  final _enrollmentController = TextEditingController();
  String? _selectedDepartment;
  bool _isLoading = false; // To show a loading state while uploading

  final List<String> _departments = ['Computer', 'IT'];

  @override
  void initState() {
    super.initState();
    if (widget.student != null) {
      _nameController.text = widget.student!.name;
      _rollNoController.text = widget.student!.rollNo;
      _enrollmentController.text = widget.student!.enrollmentNo;
      _selectedDepartment = widget.student!.department;
    }
  }

  Future<void> uploadTaskTODb() async {
    // 1. Validation: Check if fields are empty
    if (_nameController.text.isEmpty ||
        _rollNoController.text.isEmpty ||
        _enrollmentController.text.isEmpty ||
        _selectedDepartment == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // 2. Upload to Firebase
      await FirebaseFirestore.instance.collection('student').add({
        'name': _nameController.text.trim(),
        'rollNo': _rollNoController.text.trim(),
        'enrollmentNo': _enrollmentController.text.trim(),
        'department': _selectedDepartment,
      });

      // 3. Close the Dialog on success
      if (mounted) {
        Navigator.of(context).pop(); 
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Student added successfully')),
        );
      }
    } catch (e) {
      print(e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _rollNoController.dispose();
    _enrollmentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.student != null;

    return AlertDialog(
      title: Text(isEditing ? 'Edit Student' : 'Add New Student'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Student Name'),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _rollNoController,
              decoration: const InputDecoration(labelText: 'Roll Number'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _enrollmentController,
              decoration: const InputDecoration(labelText: 'Enrollment Number'),
              keyboardType: TextInputType.text,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedDepartment,
              hint: const Text('Select Department'),
              items: _departments
                  .map((dept) => DropdownMenuItem(value: dept, child: Text(dept)))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _selectedDepartment = value;
                });
              },
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : uploadTaskTODb, // Disable button while loading
          child: _isLoading 
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
            : Text(isEditing ? 'Save Changes' : 'Add Student'),
        ),
      ],
    );
  }
}
