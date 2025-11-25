import 'package:demo1/screen/absentMessage.dart';
import 'package:demo1/screen/local_cloud_backup.dart';
import 'package:demo1/screen/recordandreport.dart';
import 'package:demo1/screen/studentManagement.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

void main()  async{
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Attendance App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'Poppins',
      ),
   
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {

  int _selectedIndex = 0; 


  static const List<Widget> _screens = <Widget>[
    AbsenceMessageGeneratorScreen(), // Index 0
    BackupScreen(),                  // Index 1
    ReportScreen(),                    // Index 2
    StudentManagementScreen(),      // Index 3
  ];

  
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Scaffold is the main layout for our app.
    return Scaffold(
      // The body of the scaffold shows the currently selected screen.
      // This is the most important part!
      // `_screens.elementAt(_selectedIndex)` gets the widget from our list
      // based on which tab is currently selected.
      body: _screens.elementAt(_selectedIndex),
      
      // Here we define our bottom navigation bar.
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble),
            label: 'Generator',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.backup),
            label: 'Backup',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart),
            label: 'Reports',
          ),
          
        ],
        currentIndex: _selectedIndex, // This tells the bar which tab to highlight.
        selectedItemColor: const Color(0xFF2563EB), // Color for the active tab.
        onTap: _onItemTapped, // This is what happens when you tap a tab.
      ),
    );
  }
}
