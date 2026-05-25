import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:hive_app/providers/group_provider.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../providers/auth_provider.dart';
import '../providers/user_provider.dart';
import '../providers/task_provider.dart';
import '../providers/event_provider.dart';
import '../providers/notification_provider.dart';
import 'tasks_screen.dart';
import 'goals_screen.dart';
import 'skill_exchange_screen.dart';
import 'groups_screen.dart';
import 'profile_screen.dart';
import 'notifications_screen.dart';

class MainScreen extends StatefulWidget {
  
  const MainScreen({super.key});
  
  
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  DateTime? _focusDate;
  final GlobalKey<TasksScreenState> _tasksKey = GlobalKey(); 

  

  @override
  Widget build(BuildContext context) {
    final taskProv = context.watch<TaskProvider>();
    final eventProv = context.watch<EventProvider>();
    final userProv = context.watch<UserProvider>();
    final groupProv = context.watch<GroupProvider>();
    final notifyProv = context.watch<NotificationProvider>();

    // Логика "Желтого колокольчика"
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    bool hasOverdue = taskProv.tasks.any((t) => t.dueDate.isBefore(today) && t.status != "Done") ||
                      groupProv.allRoadmapSteps.any((s) => s.dueDate.isBefore(now) && s.status != "Done") ||
                      eventProv.events.any((e) => e.eventDate.isBefore(now) && !e.isCompleted);

    final List<Widget> pages = [
      // Исправлено: TasksScreen теперь без focusDate
      TasksScreen(key: _tasksKey),
      const GoalsScreen(),
      const SkillExchangeScreen(),
      const GroupsScreen(),
      const ProfileScreen(),
    ];

    double width = MediaQuery.of(context).size.width;
    bool isWide = width > 850;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Row(
        children: [
          if (isWide) _buildWebSidebar(),
          Expanded(
            child: Column(
              children: [
                _buildTopBar(hasOverdue, userProv, notifyProv),
                Expanded(
                  child: IndexedStack(
                    index: _selectedIndex,
                    children: pages,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: !isWide ? BottomNavigationBar(
        currentIndex: _selectedIndex,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: Colors.grey,
        onTap: (i) => setState(() { _selectedIndex = i; _focusDate = null; }),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard_rounded), label: "ЗАДАЧИ"),
          BottomNavigationBarItem(icon: Icon(Icons.flag_rounded), label: "ЦЕЛИ"),
          BottomNavigationBarItem(icon: Icon(Icons.sync_alt_rounded), label: "БИРЖА"),
          BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_rounded), label: "ЧАТЫ"),
          BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: "ПРОФИЛЬ"),
        ],
      ) : null,
    );
  }

  Widget _buildTopBar(bool overdue, UserProvider up, NotificationProvider np) {
    return Container(
      height: 80,
      padding: const EdgeInsets.symmetric(horizontal: 25),
      decoration: const BoxDecoration(
        color: Colors.white, 
        border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9)))
      ),
      child: Row(
        children: [
          if (MediaQuery.of(context).size.width < 850)
            Text(
              "HIVE", 
              style: GoogleFonts.orbitron(
                fontWeight: FontWeight.w900, 
                color: AppColors.navy, 
                letterSpacing: 2, 
                fontSize: 18
              ),
            ),
          const Spacer(),
          
          // Колокольчик с индикатором просроченных задач
          Stack(
            children: [
              IconButton(
                icon: Icon(
                  Icons.notifications_active_rounded, 
                  color: overdue ? Colors.amber : AppColors.navy,
                  size: 28,
                ),
                onPressed: () async {
                  final dynamic result = await Navigator.push(
                    context, 
                    MaterialPageRoute(builder: (_) => const NotificationsScreen())
                  );

                  // Обработка результата, если нужно сфокусироваться на дате
                  if (result != null && result is DateTime) {
                    setState(() {
                      _focusDate = result;
                      _selectedIndex = 0;
                    });
                    // Здесь можно добавить логику фокусировки на задачах с этой датой
                    _focusOnDate(result);
                  }
                },
              ),
              if (overdue)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: Colors.amber,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 15),
          GestureDetector(
            onTap: () => setState(() => _selectedIndex = 4),
            child: CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.background,
              backgroundImage: up.myProfile?.avatarUrl != null 
                ? MemoryImage(base64Decode(up.myProfile!.avatarUrl!)) 
                : null,
              child: up.myProfile?.avatarUrl == null 
                ? const Icon(Icons.person, size: 20) 
                : null,
            ),
          ),
        ],
      ),
    );
  }

  // Метод для фокусировки на задачах с определенной датой
  void _focusOnDate(DateTime date) {
    _tasksKey.currentState?.jumpToDate(date); // Ключ находит состояние TasksScreen и вызывает его метод

    // Здесь можно добавить логику фильтрации задач по дате
    // Например, прокрутить к задачам на эту дату
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Показаны задачи на ${_formatDate(date)}'),
        duration: const Duration(seconds: 2),
        action: SnackBarAction(
          label: 'Сбросить',
          onPressed: () {
            setState(() {
              _focusDate = null;
            });
          },
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final months = [
      'января', 'февраля', 'марта', 'апреля', 'мая', 'июня',
      'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря'
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  Widget _buildWebSidebar() {
    return Container(
      width: 260,
      color: AppColors.navy,
      child: Column(
        children: [
          const SizedBox(height: 50),
          // Логотип
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.2), width: 2),
            ),
            child: const Icon(Icons.hive_rounded, color: Colors.white, size: 40),
          ),
          const SizedBox(height: 8),
          Text(
            "HIVE",
            style: GoogleFonts.orbitron(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 40),
          _sidebarItem(0, "Рабочий стол", Icons.dashboard_rounded),
          _sidebarItem(1, "Маршруты целей", Icons.flag_rounded),
          _sidebarItem(2, "Биржа навыков", Icons.sync_alt_rounded),
          _sidebarItem(3, "Обсуждения", Icons.chat_bubble_rounded),
          _sidebarItem(4, "Мой профиль", Icons.person_rounded),
          const Spacer(),
          // Информация о пользователе в сайдбаре
          Consumer<UserProvider>(
            builder: (context, userProv, _) {
              return Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: Colors.white24,
                      backgroundImage: userProv.myProfile?.avatarUrl != null 
                        ? MemoryImage(base64Decode(userProv.myProfile!.avatarUrl!)) 
                        : null,
                      child: userProv.myProfile?.avatarUrl == null 
                        ? Text(
                            userProv.myProfile?.username?.substring(0, 1).toUpperCase() ?? "?",
                            style: const TextStyle(color: Colors.white),
                          )
                        : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            userProv.myProfile?.username ?? "Пользователь",
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            userProv.myProfile?.email ?? "",
                            style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.logout_rounded, color: Colors.white54),
            title: const Text("Выйти", style: TextStyle(color: Colors.white54)),
            onTap: () => context.read<AuthProvider>().logout(context),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _sidebarItem(int index, String title, IconData icon) {
    bool sel = _selectedIndex == index;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: sel ? Colors.white.withOpacity(0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        selected: sel,
        leading: Icon(icon, color: sel ? AppColors.primary : Colors.white60, size: 22),
        title: Text(
          title, 
          style: TextStyle(
            color: sel ? Colors.white : Colors.white60,
            fontWeight: sel ? FontWeight.w600 : FontWeight.normal,
            fontSize: 14,
          ),
        ),
        onTap: () => setState(() { 
          _selectedIndex = index; 
          _focusDate = null; 
        }),
      ),
    );
  }
}