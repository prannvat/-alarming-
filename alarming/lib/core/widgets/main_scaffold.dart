import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../../features/home/view/home_screen.dart';
import '../../features/alarm/view/alarms_screen.dart';
import '../../features/world_clock/view/world_clock_screen.dart';
import '../../features/stopwatch/view/stopwatch_screen.dart';
import '../../features/leaderboard/view/leaderboard_screen.dart';
import '../services/notification_service.dart';

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _currentIndex = 0; // Default to Home tab

  @override
  void initState() {
    super.initState();
    _requestNotificationPermissions();
  }

  Future<void> _requestNotificationPermissions() async {
    // Request permissions when the app starts
    await NotificationService().requestPermissions();
  }

  final List<Widget> _screens = [
    const HomeScreen(),
    const AlarmsScreen(),
    const WorldClockScreen(),
    const StopwatchScreen(),
    const LeaderboardScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: const Color(0xFF1C1C1E), // Apple Tab Bar Grey
        selectedItemColor: const Color(0xFFFF9F0A), // Apple Orange
        unselectedItemColor: const Color(0xFF8E8E93), // Apple Grey
        currentIndex: _currentIndex,
        type: BottomNavigationBarType.fixed,
        selectedFontSize: 10,
        unselectedFontSize: 10,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.alarm_fill),
            label: 'Alarm',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.globe),
            label: 'World Clock',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.stopwatch_fill),
            label: 'Stopwatch',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.chart_bar_fill),
            label: 'Leaderboard',
          ),
        ],
      ),
    );
  }
}

class PlaceholderScreen extends StatelessWidget {
  final String title;

  const PlaceholderScreen({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              title == 'Leaderboard' ? Icons.leaderboard : Icons.person,
              size: 80,
              color: const Color(0xFFA0A0B0).withOpacity(0.5),
            ),
            const SizedBox(height: 24),
            Text(
              '$title coming soon!',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
      ),
    );
  }
}
