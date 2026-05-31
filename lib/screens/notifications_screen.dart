import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:hive_app/providers/event_provider.dart';
import 'package:hive_app/providers/task_provider.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../providers/goal_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/notification_provider.dart';
import '../providers/group_provider.dart';
import '../models/all_models.dart';
import '../theme/app_theme.dart';
import 'chat_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refresh();
    });
  }

  // В файле notifications_screen.dart

void _refresh() async {
  final auth = context.read<AuthProvider>();
  final user = auth.user;
  if (user != null) {
    await Future.wait([
      context.read<NotificationProvider>().loadNotifications(),
      context.read<UserProvider>().loadRequests(),
      context.read<GoalProvider>().loadGoals(user.id),
      context.read<GroupProvider>().loadAllRoadmaps(),
      context.read<EventProvider>().loadEvents(), // <-- ОБЯЗАТЕЛЬНО
    ]);

    if (mounted) {
      context.read<NotificationProvider>().syncOverdueNotifications(
        tasks: context.read<TaskProvider>().tasks,
        events: context.read<EventProvider>().events,
        roadmapSteps: context.read<GroupProvider>().allRoadmapSteps,
      );
    }
  }
}

  @override
  Widget build(BuildContext context) {
    final notifyProv = context.watch<NotificationProvider>();
    final userProv = context.watch<UserProvider>();
    final goalProv = context.watch<GoalProvider>();
    final myId = context.read<AuthProvider>().user?.id;

    // Группировка уведомлений по важности
    final urgent = notifyProv.notifications.where((n) =>
        n.type == "EventOverdue" ||
        n.type == "TaskOverdue" ||
        n.type == "RoadmapOverdue" ||
        n.type == "TaskRejected").toList();

    final normal = notifyProv.notifications.where((n) =>
        !urgent.contains(n) && n.type != "GoalInvite").toList();

    // Приглашения в цели (не подтвержденные мною)
    final goalInvites = goalProv.goals.where((g) =>
        g.collaborators.any((c) => c.id == myId && !c.isConfirmed)).toList();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        title: const Text(
          "Уведомления",
          style: TextStyle(fontWeight: FontWeight.w900, color: AppColors.navy, fontSize: 22),
        ),
        
      ),
      body: notifyProv.isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async => _refresh(),
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 10),
                children: [
                  // --- СЕКЦИЯ: ТРЕБУЕТ ВНИМАНИЯ (Красные) ---
                  if (urgent.isNotEmpty) ...[
                    _sectionLabel("⚠️ ТРЕБУЕТ ВНИМАНИЯ", Colors.redAccent),
                    ...urgent.map((n) => _buildNotificationTile(n, Colors.redAccent)),
                    const SizedBox(height: 25),
                  ],

                  // --- СЕКЦИЯ: ЗАЯВКИ В ДРУЗЬЯ ---
                  if (userProv.pendingRequests.isNotEmpty) ...[
                    _sectionLabel("👥 ЗАПРОСЫ В ПАРТНЕРЫ", Colors.blue),
                    ...userProv.pendingRequests.map((r) => _buildPartnerRequestTile(r)),
                    const SizedBox(height: 25),
                  ],

                  // --- СЕКЦИЯ: ПРИГЛАШЕНИЯ В ЦЕЛИ ---
                  if (goalInvites.isNotEmpty) ...[
                    _sectionLabel("🎯 НОВЫЕ МАРШРУТЫ", Colors.orange),
                    ...goalInvites.map((g) => _buildGoalInviteTile(g, goalProv, myId!)),
                    const SizedBox(height: 25),
                  ],

                  // --- СЕКЦИЯ: ОБЫЧНЫЕ ---
                  if (normal.isNotEmpty) ...[
                    _sectionLabel("ОБЫЧНЫЕ", Colors.grey),
                    ...normal.map((n) => _buildNotificationTile(n, AppColors.primary)),
                  ],

                  // ПУСТОЕ СОСТОЯНИЕ
                  if (notifyProv.notifications.isEmpty &&
                      userProv.pendingRequests.isEmpty &&
                      goalInvites.isEmpty)
                    _buildEmpty(),

                  const SizedBox(height: 100),
                ],
              ),
            ),
    );
  }

  Widget _sectionLabel(String text, Color color) => Padding(
        padding: const EdgeInsets.only(left: 5, bottom: 12),
        child: Text(
          text,
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: color, letterSpacing: 1.5),
        ),
      );

  Widget _buildNotificationTile(AppNotification n, Color accentColor) {
    bool isUrgent = accentColor == Colors.redAccent;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isUrgent ? const Color(0xFFFFF5F5) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accentColor.withOpacity(0.1), width: 1.5),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: accentColor.withOpacity(0.1), shape: BoxShape.circle),
          child: Icon(
            isUrgent ? Icons.warning_amber_rounded : Icons.notifications_none_rounded,
            color: accentColor,
            size: 22,
          ),
        ),
        title: Text(
          n.title,
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: isUrgent ? Colors.red.shade900 : AppColors.navy),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(n.message, style: TextStyle(fontSize: 13, color: Colors.grey.shade700, height: 1.3)),
        ),
        trailing: IconButton(
  icon: const Icon(Icons.close_rounded, size: 18, color: Colors.grey),
  onPressed: () {
    // Этот метод отправит запрос на сервер, поставит IsRead = true
    // И бэкенд больше никогда его не пришлет в GetMyNotifications
    context.read<NotificationProvider>().markAsRead(n.id);
  },
),
        onTap: () => _handleNotificationClick(n),
      ),
    );
  }

  Widget _buildPartnerRequestTile(ChatRequestDto req) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.blue.withOpacity(0.2)),
        boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.05), blurRadius: 10)],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundImage: req.senderAvatar != null ? MemoryImage(base64Decode(req.senderAvatar!)) : null,
            child: req.senderAvatar == null ? const Icon(Icons.person) : null,
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(req.senderName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const Text("Хочет стать напарником", style: TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
          IconButton(
            onPressed: () => context.read<UserProvider>().acceptChatRequest(req.id),
            icon: const Icon(Icons.check_circle, color: Colors.green, size: 30),
          ),
          IconButton(
            onPressed: () => context.read<UserProvider>().declineChatRequest(req.id),
            icon: const Icon(Icons.cancel, color: Colors.redAccent, size: 30),
          ),
        ],
      ),
    );
  }

  Widget _buildGoalInviteTile(GoalResponse goal, GoalProvider prov, int myId) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.03),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.orange.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: Colors.orange, size: 20),
              const SizedBox(width: 10),
              Text(goal.title.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.5)),
            ],
          ),
          const SizedBox(height: 10),
          Text(goal.description ?? "Вас пригласили в совместный путь обучения.", style: const TextStyle(fontSize: 14, color: AppColors.navy)),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.navy),
                  onPressed: () => prov.respondToGoalInvite(goal.id, true, myId, context),
                  child: const Text("ПРИНЯТЬ", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.redAccent)),
                  onPressed: () => prov.respondToGoalInvite(goal.id, false, myId, context),
                  child: const Text("ОТКАЗ", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

void _handleNotificationClick(AppNotification n) async {
  final taskProv = context.read<TaskProvider>();
  final eventProv = context.read<EventProvider>();
  final groupProv = context.read<GroupProvider>();

  // Пытаемся получить ID объекта из поля data
  final int? entityId = int.tryParse(n.data ?? '');
  DateTime? jumpDate;

  // --- ЛОГИКА 1: ПРЫЖОК В КАЛЕНДАРЬ (ПЕРЕНОС ДАТЫ) ---

  // 1. Если это просроченная личная задача
  if (n.type == "TaskOverdue" && entityId != null) {
    final task = taskProv.tasks.where((t) => t.id == entityId).firstOrNull;
    if (task != null) {
      jumpDate = task.dueDate;
    }
  } 
  // 2. Если это просроченное задание из чата (Roadmap)
  else if (n.type == "RoadmapOverdue" && entityId != null) {
    final step = groupProv.allRoadmapSteps.where((s) => s.id == entityId).firstOrNull;
    if (step != null) {
      jumpDate = step.dueDate;
    }
  }
  // 3. Если это просроченное событие
  else if (n.type == "EventOverdue" && entityId != null) {
    final event = eventProv.events.where((e) => e.id == entityId).firstOrNull;
    if (event != null) {
      jumpDate = event.eventDate;
    }
  }

  // Если мы нашли дату просроченного объекта — закрываем уведомления и возвращаем дату
  // Layout (главная страница) поймает эту дату и вызовет jumpToDate
  if (jumpDate != null) {
    Navigator.pop(context, jumpDate);
    return;
  }

  // --- ЛОГИКА 2: ПЕРЕХОД В ЧАТ (ДЛЯ ПРАВОК И ПРОВЕРОК) ---

  if ((n.type == "TaskReview" || n.type == "TaskRejected" || n.type == "TaskSubmission") && n.roadmapStepId != null) {
    // Ищем шаг, чтобы узнать ID группы (чата)
    final step = groupProv.allRoadmapSteps.where((s) => s.id == n.roadmapStepId).firstOrNull;

    if (step != null) {
      final group = groupProv.groups.where((g) => g.id == step.groupId).firstOrNull;
      if (group != null) {
        Navigator.pop(context); // Закрываем модальное окно уведомлений
        Navigator.push(
          context, 
          MaterialPageRoute(builder: (_) => ChatScreen(group: group))
        );
        return;
      }
    }
  }

  // --- ЛОГИКА 3: ОБРАБОТКА СТАРЫХ УВЕДОМЛЕНИЙ (Fallback) ---
  // Если в data все еще лежит строка с датой (на случай старых записей в БД)
  if (n.data != null && n.data!.contains('-') && n.data!.length > 10) {
    try {
      DateTime legacyDate = DateTime.parse(n.data!);
      Navigator.pop(context, legacyDate);
      return;
    } catch (_) {}
  }

  // Если ничего не подошло — просто закрываем окно
  Navigator.pop(context);
}

  Widget _buildEmpty() => const Center(
        child: Padding(
          padding: EdgeInsets.only(top: 100),
          child: Column(
            children: [
              Icon(Icons.notifications_off_outlined, size: 60, color: Color(0xFFE2E8F0)),
              SizedBox(height: 15),
              Text("У вас пока нет уведомлений", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      );
}