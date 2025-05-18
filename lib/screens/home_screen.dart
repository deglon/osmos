import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'profile_screen.dart'; // Assuming ProfileScreen exists
import 'ask_osmos/vocal_chatbot_screen.dart'; // Assuming VocalChatbotScreen exists
import 'stats_screen.dart'; // Import the StatsScreen

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  // Define the list of screens for each tab
  // Ensure these screens exist and have default constructors or required parameters handled
  final List<Widget> _screens = [
    const _HomeTab(), // Placeholder for Home tab content
    const StatsScreen(), // Content for the Stats tab
    const VocalChatbotScreen(), // Content for the Ask Osmos tab
    const _NotificationsTab(), // Placeholder for Notifications tab content
    const _ProfileTab(), // Placeholder for Profile tab content
  ];

  // Define the titles for the AppBar for each screen
  final List<String> _appBarTitles = const [
    'Home',
    'Reports', // Title for the Stats/Reports screen
    'Ask Osmos',
    'Notifications',
    'Profile',
  ];

  // You might want to load user name here if needed for the AppBar title
  // String _userName = '';
  // @override
  // void initState() {
  //   super.initState();
  //   _loadUserName(); // Implement this method if needed
  // }

  // Future<void> _loadUserName() async {
  //   // Load user name logic here
  // }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // AppBar changes based on the selected tab
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(
          _appBarTitles[_currentIndex], // Use title based on current index
          style: const TextStyle(
            color: Color(0xFF00785A),
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        // Add leading/actions icons here based on the current screen if needed
        // For example, a menu icon might be in the actions list for all screens
        actions: [
           IconButton(
             icon: const Icon(Icons.menu, color: Color(0xFF00785A)),
             onPressed: () {
               // TODO: Implement menu functionality (e.g., open a Drawer)
             },
           ),
         ],
      ),
      body: _screens[_currentIndex], // Display the screen based on current index
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF00B77D),
        unselectedItemColor: Colors.grey,
        currentIndex: _currentIndex, // Control selected item
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.show_chart), label: 'Stats'),
          BottomNavigationBarItem(
            icon: Icon(Icons.question_answer),
            label: 'Ask Osmos',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications),
            label: 'Notifications',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
        onTap: (index) {
          setState(() {
            _currentIndex = index; // Update index on tap
          });
        },
      ),
      // If you want a FloatingActionButton, you can add it here,
      // but consider if it should be tied to a specific tab or global.
      // floatingActionButton: FloatingActionButton(
      //   onPressed: () {
      //     // Action for FAB
      //   },
      //   child: const Icon(Icons.add),
      // ),
      // floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked, // Example location
    );
  }
}

// --- Placeholder Widgets for Tabs ---

// Content for the Home tab
class _HomeTab extends StatelessWidget {
  const _HomeTab();

  @override
  Widget build(BuildContext context) {
    // This screen will only contain the body content for the Home tab
    // You can add your actual Home screen UI here
    return const Center(
      child: Text('Home Screen Content'),
    );
  }
}

// Content for the Notifications tab
class _NotificationsTab extends StatelessWidget {
  const _NotificationsTab();

  @override
  Widget build(BuildContext context) {
    // This screen will only contain the body content for the Notifications tab
    // You can add your actual Notifications screen UI here
    return const Center(
      child: Text('Notifications Screen Content'),
    );
  }
}

// Content for the Profile tab
class _ProfileTab extends StatelessWidget {
  const _ProfileTab();

  @override
  Widget build(BuildContext context) {
    // This screen will only contain the body content for the Profile tab
    // You can add your actual Profile screen UI here
    return const Center(
      child: Text('Profile Screen Content'),
    );
  }
}

// Note: StatsScreen and VocalChatbotScreen are imported from their respective files.
// Ensure those files contain the correct class definitions.