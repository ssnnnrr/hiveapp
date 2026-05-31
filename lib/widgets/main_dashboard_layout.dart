import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

// Импорты ваших провайдеров и тем
import '../theme/app_theme.dart';
import '../providers/auth_provider.dart';
import '../providers/user_provider.dart';
import '../providers/task_provider.dart';
import '../providers/event_provider.dart';
import '../providers/group_provider.dart';
import '../providers/goal_provider.dart';
import '../screens/auth_screen.dart';
import '../screens/notifications_screen.dart';
import '../screens/main_screen.dart';

class MainDashboardLayout extends StatelessWidget {
  final Widget child;
  final int selectedIndex;
  final Function(DateTime)? onJumpToDate;
  final Function(int)? onTabSelected;

  const MainDashboardLayout({
    super.key,
    required this.child,
    required this.selectedIndex,
    this.onJumpToDate,
    this.onTabSelected,
  });

  // Градиент для брендовых элементов
  final navigationGradient = const LinearGradient(
    colors: [Color(0xFF003385), Color(0xFF4A8DE9)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  @override
  Widget build(BuildContext context) {
    double width = MediaQuery.of(context).size.width;
    bool isWide = width > 1000;

    final userProv = context.watch<UserProvider>();
    final taskProv = context.watch<TaskProvider>();
    final goalProv = context.watch<GoalProvider>();
    final groupProv = context.watch<GroupProvider>();
    final eventProv = context.watch<EventProvider>();
    final authProv = context.read<AuthProvider>();
    final myId = authProv.user?.id;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Логика наличия уведомлений
    bool hasNotifications = 
        userProv.pendingRequests.isNotEmpty || 
        taskProv.tasks.any((t) => t.dueDate.isBefore(today) && t.status != "Done") ||
        goalProv.goals.any((g) => g.collaborators.any((c) => c.id == myId && !c.isConfirmed)) ||
        groupProv.allRoadmapSteps.any((s) => s.dueDate.isBefore(now) && s.status != "Done") ||
        eventProv.events.any((e) => e.eventDate.isBefore(now) && !e.isCompleted);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFD),
      body: Stack(
        children: [
          // Основной контент
          Column(
            children: [
              // Отступ сверху для веба, чтобы контент не перекрывался панелью
              if (isWide) const SizedBox(height: 85) 
              else _buildMobileTopBar(context, hasNotifications),
              
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: isWide ? 1450 : double.infinity, 
                    ),
                    child: child,
                  ),
                ),
              ),
            ],
          ),

          // Стеклянная верхняя панель (только для Web/Wide)
          if (isWide)
            Positioned(
              top: 0, left: 0, right: 0,
              child: _buildTopNavigationBar(context, userProv, hasNotifications),
            ),
        ],
      ),
      bottomNavigationBar: isWide ? null : _buildBottomBar(context),
    );
  }

  // --- ВЕРХНЯЯ ПАНЕЛЬ (WEB) ---
  Widget _buildTopNavigationBar(BuildContext context, UserProvider userProv, bool hasNotif) {
    final profile = userProv.myProfile;
    
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          height: 85,
          padding: const EdgeInsets.symmetric(horizontal: 40),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.8),
            border: Border(
              bottom: BorderSide(color: AppColors.navy.withOpacity(0.06), width: 1),
            ),
          ),
          child: Row(
            children: [
              // 1. ЛОГОТИП
              _buildBranding(),

              const Spacer(),

              // 2. ЦЕНТРАЛЬНЫЙ ОСТРОВОК НАВИГАЦИИ
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: AppColors.navy.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _navItem(context, 0, "Дашборд", Icons.grid_view_rounded),
                    _navItem(context, 1, "Цели", Icons.track_changes_rounded),
                    _navItem(context, 2, "Поиск", Icons.explore_rounded),
                    _navItem(context, 3, "Чаты", Icons.forum_rounded),
                    _navItem(context, 4, "Профиль", Icons.account_circle_rounded),
                  ],
                ),
              ),

              const Spacer(),

              // 3. ПРАВАЯ ЧАСТЬ
              _buildActionArea(context, profile, hasNotif),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBranding() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            gradient: navigationGradient,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(color: const Color(0xFF003385).withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))
            ],
          ),
          child: const Icon(Icons.hexagon_rounded, color: Colors.white, size: 24),
        ),
        const SizedBox(width: 14),
        Text(
          "HIVE",
          style: GoogleFonts.orbitron(
            color: AppColors.navy,
            fontWeight: FontWeight.w900,
            fontSize: 22,
            letterSpacing: 4,
          ),
        ),
      ],
    );
  }

  Widget _buildActionArea(BuildContext context, profile, bool hasNotif) {
    return Row(
      children: [
        // Уведомления
        _notificationIcon(context, hasNotif),
        
        const SizedBox(width: 25),
        
        // Капсула пользователя
        Container(
          height: 48,
          padding: const EdgeInsets.only(left: 6, right: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.navy.withOpacity(0.08)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8)],
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.background,
                backgroundImage: profile?.avatarUrl != null 
                    ? MemoryImage(base64Decode(profile!.avatarUrl!)) 
                    : null,
                child: profile?.avatarUrl == null 
                    ? const Icon(Icons.person, size: 18, color: AppColors.navy) 
                    : null,
              ),
              const SizedBox(width: 12),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    profile?.username ?? "...",
                    style: const TextStyle(color: AppColors.navy, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const Text("Online", style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(width: 10),
              IconButton(
                onPressed: () => _handleLogout(context),
                icon: const Icon(Icons.logout_rounded, size: 16, color: Colors.redAccent),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _notificationIcon(BuildContext context, bool hasNotif) {
    return Stack(
      children: [
        IconButton(
          icon: Icon(
            hasNotif ? Icons.notifications_active_rounded : Icons.notifications_none_rounded,
            color: hasNotif ? AppColors.nectarGold : AppColors.navy.withOpacity(0.4),
            size: 26,
          ),
          onPressed: () => _openNotifications(context, true),
        ),
        if (hasNotif)
          Positioned(
            right: 8, top: 8,
            child: Container(
              width: 10, height: 10,
              decoration: BoxDecoration(
                color: AppColors.nectarGold,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
          ),
      ],
    );
  }

  Widget _navItem(BuildContext context, int index, String label, IconData icon) {
    bool isSelected = selectedIndex == index;
    
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          if (onTabSelected != null) {
            onTabSelected!(index);
          } else {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => MainScreen(initialIndex: index)),
              (route) => false,
            );
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            boxShadow: isSelected ? [
              BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))
            ] : [],
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 19,
                color: isSelected ? AppColors.primary : AppColors.navy.withOpacity(0.4),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? AppColors.navy : AppColors.navy.withOpacity(0.5),
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- МОБИЛЬНЫЕ КОМПОНЕНТЫ ---
  Widget _buildMobileTopBar(BuildContext context, bool hasNotif) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0.5,
      title: Text("HIVE", style: GoogleFonts.orbitron(fontWeight: FontWeight.w900, fontSize: 18, color: AppColors.navy)),
      actions: [
        IconButton(
          icon: Icon(Icons.notifications_none_rounded, color: hasNotif ? Colors.amber : Colors.grey),
          onPressed: () => _openNotifications(context, false),
        ),
      ],
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: selectedIndex,
      onTap: (index) {
        if (onTabSelected != null) onTabSelected!(index);
        else {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => MainScreen(initialIndex: index)), (route) => false,
          );
        }
      },
      type: BottomNavigationBarType.fixed,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: Colors.grey,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.dashboard_rounded), label: "Главная"),
        BottomNavigationBarItem(icon: Icon(Icons.flag_rounded), label: "Цели"),
        BottomNavigationBarItem(icon: Icon(Icons.sync_alt_rounded), label: "Поиск"),
        BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_rounded), label: "Чаты"),
        BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: "Профиль"),
      ],
    );
  }

  // --- ВСПОМОГАТЕЛЬНЫЕ МЕТОДЫ ---
  void _openNotifications(BuildContext context, bool isWide) async {
    DateTime? resultDate;
    if (isWide) {
      resultDate = await showDialog<DateTime>(
        context: context,
        builder: (ctx) => Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 550, maxHeight: 750),
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(30),
              clipBehavior: Clip.antiAlias,
              child: const NotificationsScreen(),
            ),
          ),
        ),
      );
    } else {
      resultDate = await Navigator.push<DateTime>(
        context, MaterialPageRoute(builder: (_) => const NotificationsScreen())
      );
    }
    if (resultDate != null && onJumpToDate != null) onJumpToDate!(resultDate);
  }

  void _handleLogout(BuildContext context) async {
    context.read<UserProvider>().clearData();
    await context.read<AuthProvider>().logout(context);
    if (context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const AuthScreen()), (route) => false,
      );
    }
  }

  static void showHiveDialog(BuildContext context, Widget content) {
    double width = MediaQuery.of(context).size.width;
    showDialog(
      context: context,
      builder: (ctx) => Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: width > 1000 ? 600 : width * 0.9,
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
            elevation: 20,
            child: content,
          ),
        ),
      ),
    );
  }
}