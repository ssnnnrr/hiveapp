import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../providers/goal_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/notification_provider.dart';
import '../providers/event_provider.dart';
import '../providers/task_provider.dart';
import '../providers/group_provider.dart';
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refresh();
    });
  }

  void _refresh() async {
    final user = context.read<AuthProvider>().user;
    if (user != null) {
      await context.read<NotificationProvider>().loadNotifications();
      context.read<UserProvider>().loadRequests(); 
      context.read<GoalProvider>().loadGoals(user.id);
      
      if (mounted) _cleanupStaleNotifications();
    }
  }

  void _cleanupStaleNotifications() {
    final notifProv = context.read<NotificationProvider>();
    final eventProv = context.read<EventProvider>();
    final taskProv = context.read<TaskProvider>();
    final groupProv = context.read<GroupProvider>();
    
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    List<int> idsToRemove = [];

    for (var notification in notifProv.notifications) {
      bool isStale = false;

      if (notification.type == "EventOverdue") {
        final liveEvent = eventProv.events.firstWhere(
          (e) => notification.message.contains(e.title),
          orElse: () => EventResponse(id: -1, title: '', eventDate: DateTime.now(), isCompleted: false, creatorName: ''),
        );
        if (liveEvent.id == -1 || liveEvent.isCompleted || !liveEvent.eventDate.toLocal().isBefore(now)) {
          isStale = true;
        }
      } 
      else if (notification.type == "TaskOverdue") {
        final liveTask = taskProv.tasks.firstWhere(
          (t) => notification.message.contains(t.title),
          orElse: () => TaskResponse(id: -1, title: '', dueDate: DateTime.now(), status: '', goalId: 0, goalTitle: '', creatorId: 0, completions: []),
        );
        if (liveTask.id == -1 || liveTask.status == "Done" || !liveTask.dueDate.toLocal().isBefore(today)) {
          isStale = true;
        }
      } 
      else if (notification.type == "RoadmapOverdue") {
        final liveStep = groupProv.allRoadmapSteps.firstWhere(
          (s) => notification.message.contains(s.content),
          orElse: () => RoadmapStepDto(id: -1, content: '', dueDate: DateTime.now(), status: '', creatorId: 0),
        );
        if (liveStep.id == -1 || liveStep.status == "Done" || !liveStep.dueDate.toLocal().isBefore(now)) {
          isStale = true;
        }
      }

      if (isStale) idsToRemove.add(notification.id);
    }

    if (idsToRemove.isNotEmpty) {
      for (var id in idsToRemove) notifProv.markAsRead(id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final notifyProv = context.watch<NotificationProvider>();
    final userProv = context.watch<UserProvider>();
    final goalProv = context.watch<GoalProvider>();
    final myId = context.read<AuthProvider>().user?.id;

    double width = MediaQuery.of(context).size.width;
    bool isWide = width > 850;

    final goalInvites = goalProv.goals.where((g) => 
      g.collaborators.any((c) => c.id == myId && !c.isConfirmed)).toList();

    return Scaffold(
      backgroundColor: isWide ? const Color(0xFFE2E8F0) : const Color(0xFFF8FAFC),
      appBar: isWide ? null : AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: const BackButton(color: AppColors.navy),
        title: const Text("Уведомления", style: TextStyle(color: AppColors.navy, fontWeight: FontWeight.bold)),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: isWide ? 750 : double.infinity),
          child: Container(
            margin: EdgeInsets.symmetric(vertical: isWide ? 40 : 0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(isWide ? 25 : 0),
              boxShadow: isWide ? [BoxShadow(color: Colors.black12, blurRadius: 20)] : null,
            ),
            child: Column(
              children: [
                if (isWide) _buildWebHeader(notifyProv),
                Expanded(
                  child: notifyProv.isLoading 
                    ? const Center(child: CircularProgressIndicator())
                    : RefreshIndicator(
                        onRefresh: () async => _refresh(),
                        child: ListView(
                          padding: const EdgeInsets.all(25),
                          children: [
                            if (notifyProv.notifications.isNotEmpty) ...[
                              _sectionLabel("АКТУАЛЬНОЕ"),
                              ...notifyProv.notifications.map((n) => _buildNotificationTile(n)),
                              const SizedBox(height: 25),
                            ],
                            if (userProv.pendingRequests.isNotEmpty) ...[
                              _sectionLabel("ПАРТНЕРСТВО"),
                              ...userProv.pendingRequests.map((r) => _buildPartnerRequestTile(r)),
                              const SizedBox(height: 25),
                            ],
                            if (goalInvites.isNotEmpty) ...[
                              _sectionLabel("КОМАНДНЫЕ ЦЕЛИ"),
                              ...goalInvites.map((g) => _buildGoalInviteTile(g, goalProv, myId!)),
                            ],
                            if (notifyProv.notifications.isEmpty && userProv.pendingRequests.isEmpty && goalInvites.isEmpty)
                              _buildEmpty(),
                          ],
                        ),
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWebHeader(NotificationProvider prov) => Container(
    padding: const EdgeInsets.all(25),
    decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9)))),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text("Уведомления", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.navy)),
        TextButton.icon(onPressed: () => prov.markAllAsRead(), icon: const Icon(Icons.done_all), label: const Text("Очистить все"))
      ],
    ),
  );

  Widget _sectionLabel(String t) => Padding(padding: const EdgeInsets.only(bottom: 15, left: 5), child: Text(t, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1.5)));

  Widget _buildNotificationTile(AppNotification n) {
  bool isUrgent = n.type == "EventOverdue" || n.type == "TaskOverdue" || n.type == "RoadmapOverdue";
      return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isUrgent ? const Color(0xFFFFF5F5) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: isUrgent ? Colors.redAccent.withOpacity(0.1) : Colors.transparent),
      ),
      child: ListTile(
      leading: Icon(isUrgent ? Icons.warning : Icons.notifications, color: isUrgent ? Colors.red : Colors.blue),
      title: Text(n.title),
      subtitle: Text(n.message),
      onTap: () {
        context.read<NotificationProvider>().markAsRead(n.id);
        
        // ЕСЛИ ЕСТЬ ДАННЫЕ О ДАТЕ (должны приходить с бэкенда в поле Data)
        if (n.data != null) {
          try {
            // Парсим дату просроченного задания
            DateTime targetDate = DateTime.parse(n.data!);
            // Возвращаемся на главный экран и передаем дату
            Navigator.pop(context, targetDate); 
          } catch (e) {
            Navigator.pop(context);
          }
        } else {
          Navigator.pop(context);
        }
      },
    ),
  );
}

  Widget _buildPartnerRequestTile(ChatRequestDto req) {
    final userProv = context.read<UserProvider>();
    return Card(
      elevation: 0, color: const Color(0xFFF8FAFC), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: ListTile(
        leading: CircleAvatar(backgroundImage: req.senderAvatar != null ? MemoryImage(base64Decode(req.senderAvatar!)) : null, child: req.senderAvatar == null ? Text(req.senderName[0]) : null),
        title: Text(req.senderName, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: const Text("Запрос на обмен навыками"),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [IconButton(icon: const Icon(Icons.check_circle, color: Colors.green), onPressed: () => userProv.acceptChatRequest(req.id)), IconButton(icon: const Icon(Icons.cancel, color: Colors.redAccent), onPressed: () => userProv.declineChatRequest(req.id))]),
      ),
    );
  }

  Widget _buildGoalInviteTile(GoalResponse goal, GoalProvider prov, int myId) => Card(
    elevation: 0, color: const Color(0xFFF8FAFC), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
    child: ListTile(
      title: Text(goal.title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: const Text("Приглашение в команду"),
      trailing: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: AppColors.navy), onPressed: () => prov.respondToGoalInvite(goal.id, true, myId), child: const Text("ПРИНЯТЬ", style: TextStyle(color: Colors.white, fontSize: 10))),
    ),
  );

  Widget _buildEmpty() => const Center(child: Padding(padding: EdgeInsets.all(40), child: Text("Уведомлений нет", style: TextStyle(color: Colors.grey))));
}