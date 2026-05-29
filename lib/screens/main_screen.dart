import 'package:flutter/material.dart';
import 'package:hive_app/widgets/main_dashboard_layout.dart';
import 'tasks_screen.dart';
import 'goals_screen.dart';
import 'skill_exchange_screen.dart';
import 'groups_screen.dart';
import 'profile_screen.dart';

class MainScreen extends StatefulWidget {
  final int initialIndex;
  final DateTime? jumpToDate;
  
  const MainScreen({
    super.key, 
    this.initialIndex = 0, 
    this.jumpToDate,
  });
  
  @override
  State<MainScreen> createState() => MainScreenState();
}

class MainScreenState extends State<MainScreen> {
  late int _selectedIndex;
  final GlobalKey<TasksScreenState> _tasksKey = GlobalKey<TasksScreenState>();

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
  }

  void setIndex(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _handleJumpToDate(DateTime date) {
    // Быстро переключаемся на рабочий стол
    if (_selectedIndex != 0) {
      setState(() {
        _selectedIndex = 0;
      });
    }
    
    // Даем время на переключение и прыгаем к дате
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _tasksKey.currentState?.jumpToDate(date);
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      TasksScreen(key: _tasksKey),
      const GoalsScreen(),
      const SkillExchangeScreen(),
      const GroupsScreen(),
      const ProfileScreen(),
    ];

    return MainDashboardLayout(
      selectedIndex: _selectedIndex,
      onJumpToDate: _handleJumpToDate,
      child: IndexedStack(
        index: _selectedIndex,
        children: pages,
      ),
    );
  }
}