import 'package:flutter/material.dart';
// You might need to import askosmos.dart if OsmosScreen is used within StatsScreen,
// but based on the previous code, it seems OsmosScreen is a separate tab.
// import '../askosmos.dart';

class StatsScreen extends StatelessWidget { // Renamed from ReportsScreen
  const StatsScreen({super.key});

  // Moved _buildReportCard method here
  Widget _buildReportCard({
    required String title,
    required IconData icon,
    required Color color,
    required Color iconColor,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: iconColor.withOpacity(0.2),
                  spreadRadius: 1,
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: 36,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF333333),
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // This screen will only contain the body content for the Stats tab
    return SafeArea(
      child: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.2),
                    spreadRadius: 1,
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search ...',
                  hintStyle: TextStyle(color: Colors.grey.shade400),
                  prefixIcon: Icon(Icons.search, color: Colors.grey.shade400),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 15),
                ),
              ),
            ),
          ),

          // Report Categories
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: GridView.count(
                crossAxisCount: 2,
                childAspectRatio: 0.8,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                children: [
                  _buildReportCard(
                    title: 'Food',
                    icon: Icons.restaurant,
                    color: const Color(0xFFFFF176), // Yellow
                    iconColor: const Color(0xFF673AB7), // Purple
                  ),
                  _buildReportCard(
                    title: 'Activity',
                    icon: Icons.directions_run,
                    color: const Color(0xFFB2EBF2), // Light blue
                    iconColor: const Color(0xFF00B0FF), // Blue
                  ),
                  _buildReportCard(
                    title: 'Sleep',
                    icon: Icons.nightlight_round,
                    color: const Color(0xFFE1BEE7), // Light purple
                    iconColor: const Color(0xFF9C27B0), // Purple
                  ),
                  _buildReportCard(
                    title: 'Mood',
                    icon: Icons.mood,
                    color: const Color(0xFFFFCCBC), // Light orange
                    iconColor: const Color(0xFFFF5722), // Orange
                  ),
                ],
              ),
            ),
          ),

          // Add New Button
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Add New',
                  style: TextStyle(
                    color: Color(0xFF00785A),
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: const Color(0xFF00785A),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF00785A).withOpacity(0.3),
                        spreadRadius: 1,
                        blurRadius: 5,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: IconButton(
                    icon: const Icon(
                      Icons.add,
                      color: Colors.white,
                      size: 32,
                    ),
                    onPressed: () {
                      // TODO: Implement add new report functionality
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}