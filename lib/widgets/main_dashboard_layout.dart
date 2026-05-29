import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/auth_provider.dart';
import '../providers/user_provider.dart';
import '../providers/task_provider.dart';
import '../providers/event_provider.dart';
import '../providers/group_provider.dart';
import '../screens/main_screen.dart';
import '../screens/auth_screen.dart';
import '../screens/notifications_screen.dart';

class MainDashboardLayout extends StatelessWidget {
  final Widget child;
  final int selectedIndex;
  final Function(DateTime)? onJumpToDate;

  const MainDashboardLayout({
    super.key,
    required this.child,
    required this.selectedIndex,
    this.onJumpToDate,
  });

  @override
  Widget build(BuildContext context) {
    double width = MediaQuery.of(context).size.width;
    bool isWide = width > 1000;

    final taskProv = context.watch<TaskProvider>();
    final groupProv = context.watch<GroupProvider>();
    final eventProv = context.watch<EventProvider>();
    final userProv = context.watch<UserProvider>();

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    bool hasNotifications = taskProv.tasks.any((t) => t.dueDate.isBefore(today) && t.status != "Done") ||
                      groupProv.allRoadmapSteps.any((s) => s.dueDate.isBefore(now) && s.status != "Done") ||
                      eventProv.events.any((e) => e.eventDate.isBefore(now) && !e.isCompleted) ||
                      userProv.pendingRequests.isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.background,
      drawer: isWide ? null : Drawer(child: _buildSidebarContent(context)),
      body: Row(
        children: [
          if (isWide) _buildSidebarContent(context),
          Expanded(
            child: Column(
              children: [
                _buildTopBar(context, hasNotifications, userProv, isWide),
                Expanded(
                  child: ClipRRect(
                    borderRadius: isWide 
                      ? const BorderRadius.only(topLeft: Radius.circular(32)) 
                      : BorderRadius.zero,
                    child: Container(
                      width: double.infinity,
                      decoration: const BoxDecoration(
                        color: Color(0xFFF2F5F9),
                      ),
                      child: child,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, bool overdue, UserProvider up, bool isWide) {
    return Container(
      height: 80,
      padding: const EdgeInsets.symmetric(horizontal: 25),
      color: Colors.white,
      child: Row(
        children: [
          if (!isWide)
            IconButton(
              icon: const Icon(Icons.menu, color: AppColors.navy),
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
          const Spacer(),
          
          Stack(
            children: [
              IconButton(
                icon: Icon(
                  Icons.notifications_active_rounded, 
                  color: overdue ? Colors.amber : AppColors.navy,
                  size: 26,
                ),
                onPressed: () async {
                  if (isWide) {
                    // Открываем как оверлей на вебе
                    final result = await showDialog<DateTime>(
                      context: context,
                      barrierDismissible: true,
                      barrierColor: Colors.black38,
                      builder: (ctx) => Dialog(
                        backgroundColor: Colors.transparent,
                        insetPadding: const EdgeInsets.all(40),
                        child: Container(
                          width: 750,
                          height: MediaQuery.of(context).size.height * 0.85,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black26,
                                blurRadius: 40,
                                offset: const Offset(0, 20),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(30),
                            child: NotificationsScreen(),
                          ),
                        ),
                      ),
                    );
                    
                    if (result != null && context.mounted) {
                      onJumpToDate?.call(result);
                    }
                  } else {
                    // На мобилке - полный экран
                    final result = await Navigator.push<DateTime>(
                      context, 
                      MaterialPageRoute(builder: (_) => const NotificationsScreen())
                    );
                    
                    if (result != null && context.mounted) {
                      onJumpToDate?.call(result);
                    }
                  }
                },
              ),
              if (overdue)
                Positioned(
                  right: 10, top: 10,
                  child: Container(
                    width: 8, height: 8,
                    decoration: const BoxDecoration(color: Colors.amber, shape: BoxShape.circle),
                  ),
                ),
            ],
          ),
          
          const SizedBox(width: 15),
          GestureDetector(
            onTap: () => _navigateToPage(context, 4), 
            child: CircleAvatar(
              radius: 18,
              backgroundColor: const Color(0xFFEDF2F7),
              backgroundImage: up.myProfile?.avatarUrl != null 
                ? MemoryImage(base64Decode(up.myProfile!.avatarUrl!)) 
                : null,
              child: up.myProfile?.avatarUrl == null 
                ? const Icon(Icons.person, size: 18, color: AppColors.navy) 
                : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarContent(BuildContext context) {
    return Container(
      width: 260,
      color: AppColors.navy,
      child: Column(
        children: [
          const SizedBox(height: 50),
          _buildLogo(),
          const SizedBox(height: 40),
          _sidebarItem(context, 0, "Рабочий стол", Icons.dashboard_rounded),
          _sidebarItem(context, 1, "Маршруты целей", Icons.flag_rounded),
          _sidebarItem(context, 2, "Биржа навыков", Icons.sync_alt_rounded),
          _sidebarItem(context, 3, "Обсуждения", Icons.chat_bubble_rounded),
          _sidebarItem(context, 4, "Мой профиль", Icons.person_rounded),
          const Spacer(),
          _buildUserCardInSidebar(context),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: Material(
              color: Colors.transparent,
              child: ListTile(
                leading: const Icon(Icons.logout_rounded, color: Colors.white54, size: 20),
                title: const Text("Выйти", style: TextStyle(color: Colors.white54, fontSize: 14)),
                onTap: () async {
                  context.read<UserProvider>().clearData();
                  context.read<TaskProvider>().clearData();
                  await context.read<AuthProvider>().logout(context);
                  if (context.mounted) {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (context) => const AuthScreen()),
                      (route) => false,
                    );
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildLogo() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withOpacity(0.15), width: 1.5),
          ),
          child: const Icon(Icons.hive_rounded, color: Colors.white, size: 36),
        ),
        const SizedBox(height: 12),
        Text(
          "HIVE",
          style: GoogleFonts.orbitron(
            color: Colors.white, fontSize: 18,
            fontWeight: FontWeight.w900, letterSpacing: 2.5,
          ),
        ),
      ],
    );
  }

  Widget _buildUserCardInSidebar(BuildContext context) {
    return Consumer<UserProvider>(
      builder: (context, userProv, _) {
        final profile = userProv.myProfile;
        if (profile == null) return const SizedBox.shrink();
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: Colors.white24,
                backgroundImage: profile.avatarUrl != null 
                    ? MemoryImage(base64Decode(profile.avatarUrl!)) : null,
                child: profile.avatarUrl == null ? const Icon(Icons.person, color: Colors.white) : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.username,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      profile.email,
                      style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _sidebarItem(BuildContext context, int index, String title, IconData icon) {
    bool isSelected = selectedIndex == index;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Material(
        color: isSelected ? Colors.white.withOpacity(0.12) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          selected: isSelected,
          leading: Icon(icon, color: isSelected ? AppColors.primary : Colors.white60, size: 22),
          title: Text(
            title, 
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.white60,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              fontSize: 14,
            ),
          ),
          onTap: () => _navigateToPage(context, index),
        ),
      ),
    );
  }

  void _navigateToPage(BuildContext context, int index) {
    if (selectedIndex == index) {
      if (MediaQuery.of(context).size.width <= 1000) Navigator.pop(context);
      return;
    }
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => MainScreen(initialIndex: index)),
      (route) => false,
    );
  }
}