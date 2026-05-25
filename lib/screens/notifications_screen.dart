import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../providers/goal_provider.dart';
import '../providers/event_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/notification_provider.dart';
import '../models/all_models.dart';
import '../theme/app_theme.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    final user = context.read<AuthProvider>().user;
    if (user != null) {
      context.read<UserProvider>().loadRequests(); 
      context.read<GoalProvider>().loadGoals(user.id);
      context.read<EventProvider>().loadEvents(); 
      context.read<NotificationProvider>().loadNotifications();
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProv = context.watch<UserProvider>();
    final goalProv = context.watch<GoalProvider>();
    final eventProv = context.watch<EventProvider>();
    final notifyProv = context.watch<NotificationProvider>();
    final myId = context.read<AuthProvider>().user?.id;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // 1. Приглашения в команды (Модуль 1)
    final goalInvites = goalProv.goals.where((g) => 
      g.collaborators.any((c) => c.id == myId && !c.isConfirmed)).toList();

    // 2. Пропущенные дедлайны (Модуль 3: Для желтого колокольчика)
    final missedEvents = eventProv.events.where((e) => e.eventDate.isBefore(now) && !e.isCompleted).toList();
    final missedTasks = goalProv.goals
        .expand((g) => g.tasks)
        .where((t) => t.dueDate.isBefore(today) && t.status != "Done")
        .toList();

    // 3. Системные уведомления по обучению (Модуль 2)
    final appNotes = notifyProv.notifications.where((n) => !n.isRead).toList();

       return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: BackButton(color: AppColors.navy, onPressed: () => Navigator.pop(context)),
        title: const Text("ЦЕНТР УВЕДОМЛЕНИЙ", style: TextStyle(color: AppColors.navy, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 2)),
        centerTitle: true,
      ),
      // ЦЕНТРИРУЕМ И ОГРАНИЧИВАЕМ ШИРИНУ
      body: Center( 
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800), // Максимальная ширина 800px
          child: RefreshIndicator(
            onRefresh: () async => _refresh(),
            child: ListView(
              padding: const EdgeInsets.all(25),
              children: [
            // --- СЕКЦИЯ: ОБМЕН НАВЫКАМИ (Задания от учителя) ---
            if (appNotes.isNotEmpty) ...[
              _sectionLabel("ОБУЧЕНИЕ И ПРОВЕРКА"),
              ...appNotes.map((n) => _buildAppNoteTile(n)),
              const SizedBox(height: 25),
            ],

            // --- СЕКЦИЯ: ПРОПУЩЕННЫЕ ДЕДЛАЙНЫ (С ПЕРЕХОДОМ) ---
            if (missedEvents.isNotEmpty || missedTasks.isNotEmpty) ...[
              _sectionLabel("ПРОСРОЧЕНО (НАЖМИТЕ ДЛЯ ПЕРЕНОСА)"),
              ...missedEvents.map((e) => _buildMissedTile(e.title, e.eventDate, Icons.event_busy_rounded, Colors.orange)),
              ...missedTasks.map((t) => _buildMissedTile(t.title, t.dueDate, Icons.warning_amber_rounded, Colors.redAccent)),
              const SizedBox(height: 25),
            ],

            // --- СЕКЦИЯ: ЗАПРОСЫ В ПАРТНЕРЫ ---
            if (userProv.pendingRequests.isNotEmpty) ...[
              _sectionLabel("НОВЫЕ ЗАПРОСЫ В ПАРТНЕРЫ"),
              ...userProv.pendingRequests.map((req) => _buildPartnerRequestTile(req, userProv)),
              const SizedBox(height: 25),
            ],

            // --- СЕКЦИЯ: ПРИГЛАШЕНИЯ В ГРУППЫ ---
            if (goalInvites.isNotEmpty) ...[
              _sectionLabel("КОМАНДНЫЕ МАРШРУТЫ"),
              ...goalInvites.map((g) => _buildInviteTile(g, goalProv, myId!)),
            ],

            if (_isEmpty(userProv, goalInvites, missedEvents, missedTasks, appNotes))
              _buildEmptyState(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) => Padding(
    padding: const EdgeInsets.only(left: 5, bottom: 12),
    child: Text(text, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1)),
  );
  
  // --- ПЛИТКА ПРОСРОЧКИ (С ПЕРЕХОДОМ В КАЛЕНДАРЬ) ---
Widget _buildMissedTile(String title, DateTime date, IconData icon, Color col) {
  return Container(
    margin: const EdgeInsets.only(bottom: 12),
    decoration: AppDecorations.glassCard,
    child: ListTile(
      leading: CircleAvatar(backgroundColor: col.withOpacity(0.1), child: Icon(icon, color: col, size: 20)),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      subtitle: Text("Нужно было: ${DateFormat('dd.MM.yyyy').format(date)}", style: const TextStyle(fontSize: 11)),
      trailing: const Icon(Icons.calendar_today_rounded, size: 16, color: Colors.grey),
      // --- ВОТ ЭТА МАГИЯ ---
      onTap: () {
        Navigator.pop(context, date); // Возвращаем дату события
      },
    ),
  );
}

  // --- УВЕДОМЛЕНИЯ ПО ОБУЧЕНИЮ (МОДУЛЬ 2) ---
  Widget _buildAppNoteTile(AppNotification n) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: AppDecorations.glassCard,
      child: ListTile(
        leading: _getNoteIcon(n.type),
        title: Text(n.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        subtitle: Text(n.message, style: const TextStyle(fontSize: 12)),
        trailing: TextButton(
          onPressed: () {
            context.read<NotificationProvider>().markAsRead(n.id);
            // Возвращаем дату создания уведомления, чтобы MainScreen открыл этот день
            Navigator.pop(context, n.createdAt); 
          },
          child: const Text("ПЕРЕЙТИ", style: TextStyle(fontWeight: FontWeight.w900, color: AppColors.primary, fontSize: 10)),
        ),
      ),
    );
  }

  // --- ЗАПРОСЫ В ПАРТНЕРЫ (С АВАТАРКАМИ) ---
Widget _buildPartnerRequestTile(ChatRequestDto req, UserProvider prov) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: AppDecorations.glassCard.copyWith(
        // Добавим легкую рамку, чтобы выделить запрос среди обычных уведомлений
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.1), width: 1.5),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        
        // 1. АВАТАРКА ОТПРАВИТЕЛЯ (с использованием нашего нового хелпера)
        leading: _buildUserAvatar(req.senderAvatar, req.senderName, radius: 26),
        
        // 2. ИНФОРМАЦИЯ
        title: Text(
          req.senderName,
          style: const TextStyle(
            fontWeight: FontWeight.w800, 
            fontSize: 15, 
            color: AppColors.navy
          ),
        ),
        subtitle: const Text(
          "Хочет стать вашим партнером и обучаться вместе",
          style: TextStyle(fontSize: 12, color: Colors.grey, height: 1.3),
        ),
        
        // 3. КНОПКИ ДЕЙСТВИЯ
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Кнопка ПРИНЯТЬ
            GestureDetector(
              onTap: () => prov.acceptChatRequest(req.id),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_rounded, color: Colors.green, size: 22),
              ),
            ),
            const SizedBox(width: 12),
            // Кнопка ОТКЛОНИТЬ
            GestureDetector(
              onTap: () => prov.declineChatRequest(req.id),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close_rounded, color: Colors.redAccent, size: 22),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserAvatar(String? avatarBase64, String name, {double radius = 16}) {
  return CircleAvatar(
    radius: radius,
    backgroundColor: AppColors.navy.withValues(alpha: 0.1),
    backgroundImage: (avatarBase64 != null && avatarBase64.isNotEmpty)
        ? MemoryImage(base64Decode(avatarBase64))
        : null,
    child: (avatarBase64 == null || avatarBase64.isEmpty)
        ? Text(
            name.isNotEmpty ? name[0].toUpperCase() : "?",
            style: TextStyle(
              fontSize: radius * 0.8,
              fontWeight: FontWeight.bold,
              color: AppColors.navy,
            ),
          )
        : null,
  );
}

  // --- ПРИГЛАШЕНИЯ В ГРУППЫ (МОДУЛЬ 1) ---
  Widget _buildInviteTile(GoalResponse goal, GoalProvider prov, int myId) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: AppDecorations.glassCard,
      child: ListTile(
        leading: const Icon(Icons.group_add_rounded, color: AppColors.navy),
        title: Text(goal.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        subtitle: const Text("Вас пригласили в команду", style: TextStyle(fontSize: 11)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton(onPressed: () => prov.respondToGoalInvite(goal.id, true, myId), child: const Text("ПРИНЯТЬ")),
            TextButton(onPressed: () => prov.respondToGoalInvite(goal.id, false, myId), child: const Text("НЕТ", style: TextStyle(color: Colors.grey))),
          ],
        ),
      ),
    );
  }

  // --- ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ ---

  Widget _getNoteIcon(String? type) {
    IconData icon = Icons.notifications_active;
    Color col = AppColors.primary;
    if (type == "TaskReview") { icon = Icons.rate_review; col = Colors.orange; }
    if (type == "TaskApproved") { icon = Icons.verified; col = Colors.green; }
    if (type == "RoadmapReview") { icon = Icons.psychology; col = Colors.purple; }
    return CircleAvatar(backgroundColor: col.withOpacity(0.1), child: Icon(icon, color: col, size: 18));
  }

  bool _isEmpty(UserProvider u, List g, List e, List t, List n) => 
    u.pendingRequests.isEmpty && g.isEmpty && e.isEmpty && t.isEmpty && n.isEmpty;

  Widget _buildEmptyState() => Center(
    child: Column(
      children: [
        const SizedBox(height: 100),
        Icon(Icons.notifications_off_outlined, size: 64, color: Colors.grey.withOpacity(0.1)),
        const SizedBox(height: 20),
        const Text("Все задачи под контролем", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
      ],
    ),
  );
}