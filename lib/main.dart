import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';

// import 'dart:ui'; // No longer needed for ImageFilter

import 'new_bill_page.dart';
import 'history_page.dart';
import 'appointments_page.dart';
import 'login_page.dart';
import 'analytics_page.dart';

// --- GlassMorphicContainer Widget is removed ---
// No longer needed, as we are removing glassmorphism.

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Arul Ananth Salon',
      theme: ThemeData(
        brightness: Brightness.dark, // Overall dark theme
        primarySwatch: Colors.red, // For general accents
        scaffoldBackgroundColor:
            Colors.black, // Dark background, will be overridden by gradient
        // --- AppBar Theme (no longer transparent, but a dark color) ---
        appBarTheme: AppBarTheme(
          backgroundColor: const Color.fromARGB(
            255,
            0,
            0,
            0,
          ), // Dark grey for AppBar
          elevation: 4, // Add a subtle shadow back
          foregroundColor: Colors.white, // Text/icon color
          iconTheme: const IconThemeData(
            color: Colors.white,
          ), // Ensure icons are white
        ),

        // --- BottomNavigationBar Theme (no longer transparent) ---
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          backgroundColor: const Color.fromARGB(
            255,
            0,
            0,
            0,
          ), // Dark grey for BNV
          selectedItemColor: Colors.red, // Red accent for selected
          unselectedItemColor:
              Colors.grey[600], // Slightly lighter grey for unselected
          elevation: 8, // Add a more prominent shadow
          type:
              BottomNavigationBarType.fixed, // Ensure labels are always visible
        ),

        textTheme: Theme.of(context).textTheme.apply(
          bodyColor: Colors.white, // Default text color
          displayColor: Colors.white,
        ),
        // cardColor: Colors.transparent, // No longer strictly needed without glassmorphism on cards
      ),
      home:
          FirebaseAuth.instance.currentUser == null ? LoginPage() : HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  static List<Widget> _tabs = <Widget>[
    NewBillPage(),
    HistoryPage(),
    AnalyticsPage(),
    AppointmentsPage(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // --- Removed extendBodyBehindAppBar and extendBody ---
      // These are not needed when AppBar/BottomNavigationBar are not transparent/glassmorphic.
      appBar: AppBar(
        title: const Text('Arul Ananth Salon'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (!mounted) return;
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => LoginPage()),
                (route) => false,
              );
            },
          ),
        ],
      ),
      body: Container(
        // --- Main Background Gradient retained ---
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF330000), // Dark Red
              Colors.black, // Black
              Color(0xFF330000), // Dark Red
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child:
              _tabs[_selectedIndex], // Directly show the selected tab content
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.add), label: 'New Bill'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'History'),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart),
            label: 'Analytics',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today),
            label: 'Appointments',
          ),
        ],
      ),
    );
  }
}
