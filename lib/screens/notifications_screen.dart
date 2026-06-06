import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:hive_app/screens/chat_screen.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../providers/goal_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/notification_provider.dart';
import '../providers/group_provider.dart';
import '../providers/event_provider.dart';
import '../providers/task_provider.dart';
import '../models/all_models.dart';
import '../theme/app_theme.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _isManualLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  Future<void> _refresh() async {
    final auth = context.read<AuthProvider>();
    final myId = auth.user?.id;
    if (myId == null) return;

    setState(() => _isManualLoading = true);

    try {
      await Future.wait([
        context.read<NotificationProvider>().loadNotifications(),
        context.read<UserProvider>().loadRequests(),
        context.read<GoalProvider>().loadGoals(myId),
        context.read<TaskProvider>().loadAllTasks(),
        context.read<EventProvider>().loadEvents(),
        context.read<GroupProvider>().loadAllRoadmaps(),
      ]);

      if (mounted) {
        context.read<NotificationProvider>().syncOverdueNotifications(
          tasks: context.read<TaskProvider>().tasks,
          events: context.read<EventProvider>().events,
          roadmapSteps: context.read<GroupProvider>().allRoadmapSteps,
        );
      }
    } catch (e) {
      debugPrint("Ошибка обновления уведомлений: $e");
    } finally {
      if (mounted) setState(() => _isManualLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final notifyProv = context.watch<NotificationProvider>();
    final userProv = context.watch<UserProvider>();
    final goalProv = context.watch<GoalProvider>();
    final taskProv = context.watch<TaskProvider>();
    final eventProv = context.watch<EventProvider>();
    final groupProv = context.watch<GroupProvider>();
    
    final myId = context.read<AuthProvider>().user?.id;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // --- ИСПРАВЛЕННАЯ ЛОГИКА ФИЛЬТРАЦИИ СРОЧНЫХ УВЕДОМЛЕНИЙ ---
    final urgent = notifyProv.notifications.where((n) {
      // 1. Правки учителя показываем всегда
      if (n.type == "TaskRejected") return true;

      final int? entityId = int.tryParse(n.data ?? '');
      if (entityId == null) return false;

      // 2. Проверка личных задач (Шаги к целям)
      if (n.type == "TaskOverdue") {
        final task = taskProv.tasks.cast<TaskResponse?>().firstWhere(
          (t) => t?.id == entityId, orElse: () => null
        );
        // Показываем только если задача не выполнена и срок ДЕЙСТВИТЕЛЬНО прошел
        return task != null && task.status != "Done" && task.dueDate.isBefore(today);
      }

      // 3. Проверка заданий из чатов (Roadmap)
      if (n.type == "RoadmapOverdue") {
        final step = groupProv.allRoadmapSteps.cast<RoadmapStepDto?>().firstWhere(
          (s) => s?.id == entityId, orElse: () => null
        );
        return step != null && step.status != "Done" && step.dueDate.isBefore(today);
      }

      // 4. Проверка событий календаря
      if (n.type == "EventOverdue") {
        final event = eventProv.events.cast<EventResponse?>().firstWhere(
          (e) => e?.id == entityId, orElse: () => null
        );
        return event != null && !event.isCompleted && event.eventDate.isBefore(now);
      }

      return false;
    }).toList();

    // Обычные уведомления (за вычетом отфильтрованных срочных и инвайтов)
    final normal = notifyProv.notifications.where((n) =>
        !urgent.contains(n) && 
        n.type != "GoalInvite" && 
        n.type != "TaskOverdue" && 
        n.type != "RoadmapOverdue" && 
        n.type != "EventOverdue"
    ).toList();

    final goalInvites = goalProv.goals.where((g) =>
        g.collaborators.any((c) => c.id == myId && !c.isConfirmed)).toList();

    final partnerRequests = userProv.pendingRequests;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.navy),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Уведомления",
          style: TextStyle(fontWeight: FontWeight.w900, color: AppColors.navy, fontSize: 20),
        ),
        actions: [
          if (_isManualLoading)
            const Padding(
              padding: EdgeInsets.all(15.0),
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            )
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          children: [
            if (urgent.isNotEmpty) ...[
              _sectionLabel("⚠️ ТРЕБУЕТ ВНИМАНИЯ", Colors.redAccent),
              ...urgent.map((n) => _buildNotificationTile(n, Colors.redAccent)),
              const SizedBox(height: 25),
            ],

            if (partnerRequests.isNotEmpty) ...[
              _sectionLabel("👥 ЗАПРОСЫ НА ОБЩЕНИЕ", Colors.blue),
              ...partnerRequests.map((r) => _buildPartnerRequestTile(r)),
              const SizedBox(height: 25),
            ],

            if (goalInvites.isNotEmpty) ...[
              _sectionLabel("🎯 НОВЫЕ МАРШРУТЫ", Colors.orange),
              ...goalInvites.map((g) => _buildGoalInviteTile(g, goalProv, myId!)),
              const SizedBox(height: 25),
            ],

            if (normal.isNotEmpty) ...[
              _sectionLabel("ОБЫЧНЫЕ", Colors.grey),
              ...normal.map((n) => _buildNotificationTile(n, AppColors.primary)),
            ],

            if (urgent.isEmpty && normal.isEmpty && partnerRequests.isEmpty && goalInvites.isEmpty && !_isManualLoading)
              _buildEmpty(),

            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text, Color color) => Padding(
    padding: const EdgeInsets.only(left: 5, bottom: 12),
    child: Text(text, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: color, letterSpacing: 1.5)),
  );

  Widget _buildPartnerRequestTile(ChatRequestDto req) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.blue.withValues(alpha:0.3), width: 1.5),
        boxShadow: [BoxShadow(color: Colors.blue.withValues(alpha:0.05), blurRadius: 10)],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 25,
            backgroundImage: req.senderAvatar != null ? MemoryImage(base64Decode(req.senderAvatar!)) : null,
            child: req.senderAvatar == null ? const Icon(Icons.person) : null,
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(req.senderName, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: AppColors.navy)),
                const Text("Хочет стать вашим партнером", style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          Row(
            children: [
              IconButton(
                onPressed: () => context.read<UserProvider>().acceptChatRequest(req.id),
                icon: const Icon(Icons.check_circle, color: Colors.green, size: 32),
              ),
              IconButton(
                onPressed: () => context.read<UserProvider>().declineChatRequest(req.id),
                icon: const Icon(Icons.cancel, color: Colors.redAccent, size: 32),
              ),
            ],
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
        color: Colors.orange.withValues(alpha:0.05),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.orange.withValues(alpha:0.3), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: Colors.orange, size: 20),
              const SizedBox(width: 10),
              Expanded(child: Text(goal.title.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.5, color: AppColors.navy))),
            ],
          ),
          const SizedBox(height: 10),
          Text(goal.description ?? "Вас пригласили в совместный маршрут обучения.", 
            style: const TextStyle(fontSize: 14, color: Colors.black87, height: 1.3)),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.navy, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  onPressed: () => prov.respondToGoalInvite(goal.id, true, myId, context),
                  child: const Text("ПРИНЯТЬ", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.redAccent), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  onPressed: () => prov.respondToGoalInvite(goal.id, false, myId, context),
                  child: const Text("ОТКЛОНИТЬ", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

// lib/screens/notifications_screen.dart

Widget _buildNotificationTile(AppNotification n, Color accentColor) {
  return Container(
    margin: const EdgeInsets.only(bottom: 12),
    decoration: BoxDecoration(
      color: accentColor.withValues(alpha:0.03),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: accentColor.withValues(alpha:0.1), width: 1),
    ),
    child: ListTile(
      onTap: () async {
        final int? entityId = int.tryParse(n.data ?? '');

        // 1. Если ученик сдал задание -> Переходим в ЧАТ
        if (n.type == "TaskSubmission") {
          final groupProv = context.read<GroupProvider>();
          try {
            // Ищем шаг в загруженных данных, чтобы получить GroupId
            final step = groupProv.allRoadmapSteps.firstWhere((s) => s.id == entityId);
            final group = groupProv.groups.firstWhere((g) => g.id == step.groupId);
            
            Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(group: group)));
          } catch (e) {
            // Если данных нет в кэше, просто закрываем и обновляем
            context.read<NotificationProvider>().markAsRead(n.id);
          }
          return;
        }

        // 2. Если это просрочка (Task, Event, Roadmap) -> Переходим на календарь (TasksScreen)
        if (n.type != null && n.type!.contains("Overdue")) {
          DateTime? jumpDate;
          try {
            if (n.type == "TaskOverdue") {
              jumpDate = context.read<TaskProvider>().tasks.firstWhere((t) => t.id == entityId).dueDate;
            } else if (n.type == "EventOverdue") {
              jumpDate = context.read<EventProvider>().events.firstWhere((e) => e.id == entityId).eventDate;
            } else if (n.type == "RoadmapOverdue") {
              jumpDate = context.read<GroupProvider>().allRoadmapSteps.firstWhere((s) => s.id == entityId).dueDate;
            }
          } catch (e) { jumpDate = n.createdAt; }

          if (jumpDate != null) {
            // Возвращаем дату в MainScreen для переключения календаря
            Navigator.pop(context, jumpDate);
            return;
          }
        }

        // По умолчанию помечаем как прочитанное
        context.read<NotificationProvider>().markAsRead(n.id);
      },
      contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
      leading: Icon(n.type == "TaskRejected" ? Icons.edit_notifications : Icons.notifications_none, color: accentColor),
      title: Text(n.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
      subtitle: Text(n.message, style: const TextStyle(fontSize: 13, height: 1.3)),
      trailing: IconButton(
        icon: const Icon(Icons.close, size: 18),
        onPressed: () => context.read<NotificationProvider>().markAsRead(n.id),
      ),
    ),
  );
}
  Widget _buildEmpty() => Center(
    child: Padding(
      padding: const EdgeInsets.only(top: 100),
      child: Column(
        children: [
          Icon(Icons.notifications_off_outlined, size: 60, color: Colors.grey.shade300),
          const SizedBox(height: 15),
          const Text("Уведомлений пока нет", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
        ],
      ),
    ),
  );
}