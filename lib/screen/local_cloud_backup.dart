import 'dart:io'; // Required for File
import 'package:demo1/screen/sidebar.dart';
import 'package:firebase_core/firebase_core.dart'; // Required for Firebase
import 'package:firebase_storage/firebase_storage.dart'; // Required for Storage
import 'package:flutter/material.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:image_picker/image_picker.dart'; // Required for Camera

void main() async {
  // 1. Initialize Firebase before running the app
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const BackupApp());
}

class BackupApp extends StatelessWidget {
  const BackupApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF9FAFB),
        fontFamily: 'Poppins',
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          elevation: 1,
          iconTheme: IconThemeData(color: Colors.black87),
          titleTextStyle: TextStyle(
            color: Colors.black87,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      home: const BackupScreen(),
    );
  }
}

// Data model for a file
class BackupFile {
  final String name;
  bool isOnline;
  bool isOffline;

  BackupFile({required this.name, this.isOnline = false, this.isOffline = true});
}

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  // --- LOGIC VARIABLES ---
  final ImagePicker _picker = ImagePicker();
  File? _selectedImage;
  bool _isUploading = false;

  // Sample list (We will add new uploads to this list)
  final List<BackupFile> _files = [
    BackupFile(name: '23082025.pdf', isOnline: true, isOffline: true),
    BackupFile(name: '24082025.pdf', isOnline: false, isOffline: true),
  ];

  // --- FUNCTION 1: Pick Image from Camera ---
  Future<void> _pickImage() async {
    try {
      final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
      if (photo != null) {
        setState(() {
          _selectedImage = File(photo.path);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error picking image: $e')));
    }
  }

  // --- FUNCTION 2: Upload to Firebase Storage ---
  Future<void> _uploadToFirebase() async {
    if (_selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please take a photo first!')),
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      // 1. Create a unique filename based on time
      String fileName = "attendance_${DateTime.now().millisecondsSinceEpoch}.jpg";

      // 2. Create Reference (Folder: backups)
      final ref = FirebaseStorage.instance.ref().child('backups/$fileName');

      // 3. Upload
      await ref.putFile(_selectedImage!);

      // 4. Update UI on Success
      setState(() {
        // Add to the list so the user sees it immediately
        _files.insert(0, BackupFile(name: fileName, isOnline: true, isOffline: true));
        _selectedImage = null; // Clear preview
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Upload Successful!')),
        );
      }
    } catch (e) {
      print(e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload Failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('BackUp'),
      ),
      drawer: const Drawer(
        child: Sidebar(),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildUploadCard(),
            const SizedBox(height: 24),
            
            // --- PREVIEW SECTION (Only shows if image picked) ---
            if (_selectedImage != null) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  children: [
                    const Text("Preview", style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(_selectedImage!, height: 200, width: double.infinity, fit: BoxFit.cover),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton.icon(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          label: const Text("Remove", style: TextStyle(color: Colors.red)),
                          onPressed: () => setState(() => _selectedImage = null),
                        )
                      ],
                    )
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            _buildUploadedFilesCard(),
            const SizedBox(height: 24),
            
            // --- UPLOAD BUTTON ---
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isUploading ? null : _uploadToFirebase, // Disable if uploading
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: _isUploading 
                  ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Upload to Cloud', style: TextStyle(fontSize: 18, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadCard() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.camera_alt_outlined, color: Colors.green),
                SizedBox(width: 8),
                Text('Capture Attendance', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 16),
            DottedBorder(
              borderType: BorderType.RRect,
              radius: const Radius.circular(12),
              color: Colors.grey,
              strokeWidth: 1.5,
              dashPattern: const [6, 6],
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 32),
                width: double.infinity,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.camera_enhance, size: 48, color: Colors.grey.shade400),
                    const SizedBox(height: 8),
                    Text(
                      _selectedImage == null ? 'Take a photo to upload' : 'Photo selected',
                      style: const TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _pickImage,
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Open Camera'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadedFilesCard() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Uploaded Files', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            // Header Row
            const Row(
              children: [
                Expanded(child: Text('File Name', style: TextStyle(fontWeight: FontWeight.bold))),
                SizedBox(width: 60, child: Text('Cloud', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold))),
                SizedBox(width: 60, child: Text('Local', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold))),
              ],
            ),
            const Divider(),
            // Files List
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _files.length,
              itemBuilder: (context, index) {
                final file = _files[index];
                return FileRow(
                  file: file,
                  onOnlineChanged: (value) => setState(() => file.isOnline = value!),
                  onOfflineChanged: (value) => setState(() => file.isOffline = value!),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// A reusable widget for displaying a single file row
class FileRow extends StatelessWidget {
  final BackupFile file;
  final ValueChanged<bool?> onOnlineChanged;
  final ValueChanged<bool?> onOfflineChanged;

  const FileRow({
    super.key,
    required this.file,
    required this.onOnlineChanged,
    required this.onOfflineChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                const Icon(Icons.insert_drive_file, color: Colors.redAccent, size: 20),
                const SizedBox(width: 8),
                Flexible(child: Text(file.name, overflow: TextOverflow.ellipsis)),
              ],
            )
          ),
          // Cloud Checkbox (Disabled if it's already uploaded, purely visual)
          SizedBox(width: 60, child: Checkbox(
            value: file.isOnline, 
            activeColor: Colors.green,
            onChanged: onOnlineChanged
          )),
          SizedBox(width: 60, child: Checkbox(value: file.isOffline, onChanged: onOfflineChanged)),
        ],
      ),
    );
  }
}
