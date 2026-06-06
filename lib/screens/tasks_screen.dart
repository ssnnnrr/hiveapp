import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_app/widgets/main_dashboard_layout.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/all_models.dart';
import '../providers/task_provider.dart';
import '../providers/event_provider.dart';
import '../providers/goal_provider.dart';
import '../providers/group_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/notification_provider.dart';
import '../theme/app_theme.dart';
import 'create_event_screen.dart';
import 'chat_screen.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => TasksScreenState();
}

class TasksScreenState extends State<TasksScreen> {
  CalendarFormat _calendarFormat = CalendarFormat.week;
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndRefresh();
    });
  }

  void _checkAndRefresh() {
    _refreshData();
  }

  void _refreshData() async {
  if (!mounted) return;
  final auth = context.read<AuthProvider>();
  if (auth.user == null) return;

  // 1. Загружаем все данные
  await Future.wait([
    context.read<TaskProvider>().loadAllTasks(),
    context.read<EventProvider>().loadEvents(),
    context.read<GroupProvider>().loadAllRoadmaps(),
    context.read<NotificationProvider>().loadNotifications(),
    context.read<GoalProvider>().loadGoals(auth.user!.id),
  ]);

  if (mounted) {
    final taskProv = context.read<TaskProvider>();
    final eventProv = context.read<EventProvider>();
    final groupProv = context.read<GroupProvider>();
    final notifyProv = context.read<NotificationProvider>();
    final goalProv = context.read<GoalProvider>();

    // Очистка сиротских задач (у вас уже было)
    taskProv.cleanupOrphanedTasks(goalProv);

    // 2. АВТОМАТИЧЕСКАЯ СИНХРОНИЗАЦИЯ УВЕДОМЛЕНИЙ
    notifyProv.syncOverdueNotifications(
      tasks: taskProv.tasks,
      events: eventProv.events,
      roadmapSteps: groupProv.allRoadmapSteps,
    );

    setState(() {});
  }
}


void _syncNotifications() {
  final taskProv = context.read<TaskProvider>();
  final eventProv = context.read<EventProvider>();
  final groupProv = context.read<GroupProvider>();
  
  context.read<NotificationProvider>().syncOverdueNotifications(
    tasks: taskProv.tasks,
    events: eventProv.events,
    roadmapSteps: groupProv.allRoadmapSteps,
  );
}


  void jumpToDate(DateTime date) {
    setState(() {
      _selectedDay = DateTime(date.year, date.month, date.day);
      _focusedDay = _selectedDay;
    });
  }

  // --- ЛОГИКА ДЕЙСТВИЙ ---

void _handleTaskCheckbox(TaskResponse t, String myName, String? myAvatar, bool isCurrentlyDone) async {
  
  // ИСПРАВЛЕНИЕ: Шаги к личным целям (Personal Goals) ВСЕГДА можно отмечать чекбоксом.
  // Мы блокируем чекбокс только если это ГРУППОВАЯ цель И у задачи стоит флаг необходимости файла.
  
  // Если задача требует артефакт (isRequired) - отправляем в диалог сдачи
  // В TaskResponse мы проверяем флаг isSolo. Если цель личная (isSolo == true), 
  // то никакой артефакт не нужен, это просто галочка для себя.
  if (t.isSolo == false && t.artifactUrl != null && !isCurrentlyDone) {
    _showGeneralTaskSubmissionDialog(t);
    return;
  }

  // Для личных целей и обычных задач — просто ставим Done
  await context.read<TaskProvider>().updateTaskStatus(
    taskId: t.id,
    newStatus: isCurrentlyDone ? "ToDo" : "Done",
    comment: null,
    userName: myName,
    userAvatar: myAvatar,
    goalProvider: context.read<GoalProvider>(),
  );

  if (!isCurrentlyDone) {
    context.read<NotificationProvider>().removeOverdueNotification(t.id, "task");
  }
}


 void _handlePartnerTaskAction(RoadmapStepDto task) async {
    // 1. Если это тест
    if (task.isTest) {
      _showTestActionDialog(task);
      return;
    }

    // 2. Если это обязательное задание (требует отчет)
    if (task.isRequired) {
      _showArtifactStatusDialog(task);
    } else {
      // 3. ОБЫЧНОЕ ПЕРЕКЛЮЧЕНИЕ (Исправленный вызов с именованными аргументами)
      await context.read<GroupProvider>().toggleStepComplete(
        stepId: task.id, 
        groupId: task.groupId,
      );
      
      if (mounted) {
        _syncNotifications();
      }
    }
  }

  void _showGeneralTaskSubmissionDialog(TaskResponse t) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Требуется подтверждение"),
        content: Text(
          "Для задачи '${t.title}' необходимо прикрепить результат (ссылку или файл) в деталях цели.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("ОК"),
          ),
        ],
      ),
    );
  }

  void _showTestActionDialog(RoadmapStepDto task) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.quiz, color: Colors.purple),
            SizedBox(width: 10),
            Text("ТЕСТ"),
          ],
        ),
        content: Text(
          "Пройти тест: ${task.content}?\nВас перенаправит в учебный чат.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("ОТМЕНА"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _navigateToChat(task);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.navy),
            child: const Text("В ЧАТ"),
          ),
        ],
      ),
    );
  }


  void _navigateToChat(RoadmapStepDto task) {
    final groupProv = context.read<GroupProvider>();
    final group = groupProv.groups.firstWhere(
      (g) => g.id == task.groupId,
      orElse: () => groupProv.groups.first,
    );
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ChatScreen(group: group)),
    ).then((_) => _refreshData());
  }

  void _openCreateEvent({EventResponse? event}) {
    double screenWidth = MediaQuery.of(context).size.width;
    bool isWeb = screenWidth > 1000;

    if (isWeb) {
      MainDashboardLayout.showHiveDialog(
        context,
        CreateEventScreen(
          initialDate: _selectedDay,
          event: event,
          isOverlay: true,
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CreateEventScreen(
            initialDate: _selectedDay,
            event: event,
            isOverlay: false,
          ),
        ),
      ).then((_) => _refreshData());
    }
  }


void _showArtifactStatusDialog(RoadmapStepDto s) {
  MainDashboardLayout.showHiveDialog(
    context,
    StatefulBuilder(
      builder: (ctx, setSt) {
        // Логика состояний
        bool isRejected = s.teacherComment != null && s.status == "ToDo";
        bool hasArtifact = s.artifactUrl != null;
        bool isUnderReview = s.status == "UnderReview";
        bool isDone = s.status == "Done";

        return Padding(
          padding: const EdgeInsets.all(32),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Иконка в зависимости от статуса
                Icon(
                  isDone
                      ? Icons.check_circle_rounded
                      : (isRejected
                          ? Icons.edit_notifications_rounded
                          : (isUnderReview
                              ? Icons.hourglass_top_rounded
                              : Icons.cloud_upload_outlined)),
                  size: 54,
                  color: isDone
                      ? Colors.green
                      : (isRejected
                          ? Colors.orange
                          : (isUnderReview ? Colors.blue : AppColors.primary)),
                ),
                const SizedBox(height: 16),
                
                // Заголовок
                Text(
                  isDone
                      ? "ЗАДАНИЕ ПРИНЯТО"
                      : (isRejected
                          ? "НУЖНЫ ПРАВКИ"
                          : (isUnderReview ? "НА ПРОВЕРКЕ" : "СДАТЬ РАБОТУ")),
                  style: GoogleFonts.manrope(
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    color: AppColors.navy,
                  ),
                ),
                const SizedBox(height: 8),
                
                // Текст задания (с переносом)
                Flexible(
                  child: Text(
                    s.content,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.grey, fontSize: 13, height: 1.4),
                  ),
                ),

                // Блок правок учителя
                if (isRejected)
                  Container(
                    margin: const EdgeInsets.only(top: 20),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha:0.08),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: Colors.orange.withValues(alpha:0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "КОММЕНТАРИЙ УЧИТЕЛЯ:",
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 10,
                            color: Colors.orange,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          s.teacherComment!,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.navy,
                            fontWeight: FontWeight.w600,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 25),

                // Отображение сданного ранее ответа
                if (hasArtifact)
                  InkWell(
                    onTap: () => _handleResourceOpen(s.artifactUrl),
                    borderRadius: BorderRadius.circular(15),
                    child: Container(
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F4F9),
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                          color: isUnderReview
                              ? Colors.blue.withValues(alpha:0.2)
                              : Colors.transparent,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            s.artifactUrl!.startsWith('http')
                                ? Icons.link_rounded
                                : Icons.description_rounded,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "ВАШ ПОСЛЕДНИЙ ОТВЕТ (НАЖМИТЕ):",
                                  style: TextStyle(
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey,
                                  ),
                                ),
                                Text(
                                  s.artifactUrl!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: AppColors.navy,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Кнопка удаления для пересдачи
                          if (!isDone)
                            IconButton(
                              onPressed: () => setSt(() => s.artifactUrl = null),
                              icon: const Icon(Icons.delete_sweep_rounded,
                                  color: Colors.redAccent),
                              tooltip: "Сбросить и прикрепить заново",
                            ),
                        ],
                      ),
                    ),
                  ),

                const SizedBox(height: 30),

                // Кнопки действий
                if (!hasArtifact && !isDone)
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            _showAddLinkDialog(s.id, s.groupId);
                          },
                          icon: const Icon(Icons.link, size: 18),
                          label: const Text("ССЫЛКА",
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            // Вызов метода загрузки файла из GroupProvider
                            await context.read<GroupProvider>().uploadArtifact(
                                  s.id,
                                  s.groupId,
                                );
                            Navigator.pop(context);
                            _refreshData();
                          },
                          icon: const Icon(Icons.upload_file,
                              color: Colors.white, size: 18),
                          label: const Text("ФАЙЛ",
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.navy,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  )
                else
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("ЗАКРЫТЬ",
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

Future<void> _handleResourceOpen(String? path) async {
  if (path == null || path.isEmpty) return;

  try {
    Uri uri;
    if (path.startsWith('http')) {
      // Если это прямая ссылка (Google Drive, GitHub)
      uri = Uri.parse(path);
    } else {
      // Если это файл на нашем сервере ( uploads/filename )
      // Замените localhost на ваш IP или домен для тестов на реальном устройстве
      final downloadUrl = 'http://localhost:5254/api/Chat/download/${Uri.encodeComponent(path)}';
      uri = Uri.parse(downloadUrl);
    }

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      throw 'Could not launch $uri';
    }
  } catch (e) {
    debugPrint("Ошибка открытия ресурса: $e");
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Не удалось открыть файл или ссылку"),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }
}

  // --- ВЕРСТКА ---

  @override
  Widget build(BuildContext context) {
    final eventProv = context.watch<EventProvider>();
    final taskProv = context.watch<TaskProvider>();
    final groupProv = context.watch<GroupProvider>();
    final goalProv = context.watch<GoalProvider>();
    final auth = context.read<AuthProvider>();

    final myName = auth.user?.username ?? "";
    final myId = auth.user?.id ?? 0;
    final myAvatar = auth.user?.avatarUrl;

    final activeGoalIds = goalProv.goals.map((g) => g.id).toSet();
    final activeTasks = taskProv.tasks
        .where((t) => activeGoalIds.contains(t.goalId))
        .toList();

    final dailyEvents = eventProv.events
        .where((e) => isSameDay(e.eventDate.toLocal(), _selectedDay))
        .toList();
    final dailyTasks = activeTasks
        .where((t) => isSameDay(t.dueDate.toLocal(), _selectedDay))
        .toList();
    final partnerTasks = groupProv.allRoadmapSteps
        .where(
          (s) =>
              isSameDay(s.dueDate.toLocal(), _selectedDay) &&
              s.creatorId != myId,
        )
        .toList();

    bool isWeb = MediaQuery.of(context).size.width > 1000;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          _buildCalendarHeader(),
          _buildCalendarSection(
            eventProv.events,
            activeTasks,
            groupProv.allRoadmapSteps,
          ),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: isWeb ? 3 : 1,
                  child: ListView(
                    padding: EdgeInsets.symmetric(
                      horizontal: isWeb ? 30 : 15,
                      vertical: 5,
                    ),
                    children: [
                      if (dailyEvents.isNotEmpty) ...[
                        _buildBlockHeader(Icons.calendar_month, "СОБЫТИЯ ДНЯ"),
                        ...dailyEvents.map((e) => _buildEventCard(e)),
                      ],
                      if (dailyTasks.isNotEmpty) ...[
                        _buildBlockHeader(Icons.rocket_launch, "ШАГИ К ЦЕЛЯМ"),
                        ...dailyTasks.map(
                          (t) =>
                              _buildEnhancedTaskCard(t, myName, myAvatar, myId),
                        ),
                      ],
                      if (partnerTasks.isNotEmpty) ...[
                        _buildBlockHeader(
                          Icons.people_alt,
                          "ЗАДАНИЯ ИЗ ЧАТОВ",
                          color: Colors.purple,
                        ),
                        ...partnerTasks.map(
                          (s) => _buildEnhancedPartnerCard(s),
                        ),
                      ],
                      if (dailyEvents.isEmpty &&
                          dailyTasks.isEmpty &&
                          partnerTasks.isEmpty)
                        _buildEmptyState(),
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
                if (isWeb)
                  SizedBox(
                    width: 370,
                    child: SingleChildScrollView(
                      child: _buildWeeklyProgressCard(
                        activeTasks,
                        eventProv.events,
                        groupProv.allRoadmapSteps,
                        myName,
                        myId,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openCreateEvent(),
        backgroundColor: AppColors.navy,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          "СОБЫТИЕ",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  // --- КАРТОЧКИ ---

  Widget _buildEnhancedTaskCard(
    TaskResponse t,
    String myName,
    String? myAvatar,
    int myId,
  ) {
    bool isDone =
        t.status == "Done" || t.completions.any((c) => c.username == myName);
    final today = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
    bool isOverdue = t.dueDate.toLocal().isBefore(today) && !isDone;

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isOverdue
                  ? Colors.redAccent.withValues(alpha:0.4)
                  : const Color(0xFFF1F5F9),
              width: isOverdue ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha:0.02), blurRadius: 10),
            ],
          ),
          child: Column(
            children: [
              ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                leading: Checkbox(
                  value: isDone,
                  activeColor: Colors.green,
                  onChanged: (v) =>
                      _handleTaskCheckbox(t, myName, myAvatar, isDone),
                ),
                title: Text(
                  t.title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    decoration: isDone ? TextDecoration.lineThrough : null,
                    color: isDone ? Colors.grey : AppColors.navy,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "ЦЕЛЬ: ${t.goalTitle.toUpperCase()}",
                      style: const TextStyle(
                        fontSize: 9,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (isOverdue)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: InkWell(
                          onTap: () => _rescheduleGeneral(t.id, 'task'),
                          child: const Text(
                            "ПРОПУЩЕНО. ПЕРЕНЕСТИ?",
                            style: TextStyle(
                              color: Colors.red,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    _buildCompletionRow(t),
                  ],
                ),
                trailing: _buildActionsMenu(t.id, 'task', t),
              ),
              _buildComments(t, myId),
            ],
          ),
        ),
      ),
    );
  }

 Widget _buildEnhancedPartnerCard(RoadmapStepDto s) {
  bool isDone = s.status == "Done";
  bool isReview = s.status == "UnderReview";
  bool isRejected = s.teacherComment != null && s.status == "ToDo";
  bool isSimpleTask = !s.isTest && !s.isRequired;

  final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
  bool isOverdue = s.dueDate.toLocal().isBefore(today) && !isDone && !isReview;

  Color accentColor = s.isTest ? Colors.purple : AppColors.primary;

  return Container(
    margin: const EdgeInsets.only(bottom: 15),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(
        // Используем isRejected для рамки
        color: isOverdue 
            ? Colors.redAccent.withValues(alpha:0.6) 
            : (isRejected ? Colors.orange.withValues(alpha:0.4) : (isDone ? Colors.green.withValues(alpha:0.2) : accentColor.withValues(alpha:0.1))), 
        width: isOverdue ? 2.0 : 1.5,
      ),
      boxShadow: [
        BoxShadow(
          color: isOverdue ? Colors.redAccent.withValues(alpha:0.05) : Colors.black.withValues(alpha:0.02), 
          blurRadius: 10
        )
      ],
    ),
    child: Column(
      children: [
        ListTile(
          contentPadding: const EdgeInsets.all(15),
          leading: isSimpleTask 
            ? Checkbox(
                value: isDone,
                activeColor: Colors.green,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                onChanged: (val) {
                  // ИСПРАВЛЕНО: Именованные аргументы (строка 148)
                  context.read<GroupProvider>().toggleStepComplete(
                    stepId: s.id, 
                    groupId: s.groupId
                  );
                },
              )
            : (isDone 
                ? const Icon(Icons.check_circle, color: Colors.green, size: 28)
                : (isReview || isRejected 
                    ? const Icon(Icons.hourglass_bottom, color: Colors.orange, size: 28) 
                    : Icon(Icons.circle_outlined, color: isOverdue ? Colors.redAccent : Colors.grey.shade400, size: 28))),
          
          title: Text(
            s.content, 
            style: TextStyle(
              fontWeight: FontWeight.w800, 
              decoration: isDone ? TextDecoration.lineThrough : null, 
              color: isDone ? Colors.grey : AppColors.navy
            )
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "ОТ: ${s.creatorName ?? 'Учитель'}", 
                  style: TextStyle(fontSize: 10, color: accentColor, fontWeight: FontWeight.bold)
                ),
                if (isOverdue)
                  const Text("⚠️ СРОК ИСТЕК", style: TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.w900)),
                if (isRejected) 
                  const Text("⚠️ ТРЕБУЮТСЯ ПРАВКИ", style: TextStyle(color: Colors.orange, fontSize: 10, fontWeight: FontWeight.w900)),
              ],
            ),
          ),
          // Используем метод, который был помечен как unused (строка 704)
          trailing: isSimpleTask ? null : _buildTinyActionButton(s),
          onTap: isSimpleTask ? null : () => _handlePartnerTaskAction(s),
        ),

        if (isRejected && s.teacherComment != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(15, 0, 15, 15),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha:0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.comment_outlined, size: 14, color: Colors.orange),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      s.teacherComment!,
                      style: const TextStyle(fontSize: 12, color: AppColors.navy),
                    ),
                  ),
                ],
              ),
            ),
          ),
        _buildTinyResources(s), 
      ],
    ),
  );
}

void _showAddLinkDialog(int stepId, int groupId) {
  final linkCtrl = TextEditingController();
  MainDashboardLayout.showHiveDialog(
    context,
    Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.link_rounded, size: 48, color: AppColors.primary),
          const SizedBox(height: 20),
          const Text("ССЫЛКА НА РАБОТУ", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
          const SizedBox(height: 25),
          TextField(
            controller: linkCtrl,
            decoration: AppDecorations.smartInput("https://...", Icons.insert_link),
          ),
          const SizedBox(height: 30),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () async {
                    if (linkCtrl.text.isEmpty) return;
                    // ИСПРАВЛЕНО: Именованные аргументы (строка 735)
                    await context.read<GroupProvider>().submitStepResult(
                      stepId: stepId,
                      artifactUrl: linkCtrl.text.trim(),
                      studentComment: "Сдано с главной",
                      groupId: groupId,
                    );
                    Navigator.pop(context);
                    _refreshData();
                  },
                  child: const Text("ОТПРАВИТЬ"),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

Widget _buildTinyActionButton(RoadmapStepDto s) {
  if (s.isTest) return const Icon(Icons.quiz, color: Colors.purple, size: 20);
  if (s.isRequired) return const Icon(Icons.upload_file, color: Colors.blue, size: 20);
  return const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey);
}

Widget _buildTinyResources(RoadmapStepDto s) {
  if (s.instructionUrl == null && s.artifactUrl == null) return const SizedBox.shrink();
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    decoration: BoxDecoration(
      color: const Color(0xFFF8FAFC), 
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(22)),
      border: Border(top: BorderSide(color: Colors.grey.shade100))
    ),
    child: Wrap( // Используем Wrap для красивого переноса, если кнопок много
      spacing: 15,
      runSpacing: 10,
      children: [
        if (s.instructionUrl != null) 
          _tinyBadge(
            Icons.menu_book, 
            "Материал", 
            Colors.blue, 
            () => _handleResourceOpen(s.instructionUrl) // ВЫЗОВ МЕТОДА ТУТ
          ),
        if (s.artifactUrl != null) 
          _tinyBadge(
            Icons.description, 
            "Отчет сдан", 
            Colors.green, 
            () => _handleResourceOpen(s.artifactUrl) // ВЫЗОВ МЕТОДА ТУТ
          ),
      ],
    ),
  );
}

Widget _tinyBadge(IconData icon, String label, Color col, VoidCallback onTap) {
  return InkWell( // Делаем бейдж кликабельным
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: col.withValues(alpha:0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: col.withValues(alpha:0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: col),
          const SizedBox(width: 5),
          Text(
            label, 
            style: TextStyle(fontSize: 10, color: col, fontWeight: FontWeight.bold)
          ),
        ],
      ),
    ),
  );
}


  Widget _buildEventCard(EventResponse e) {
    DateTime displayTime = e.eventDate;
    bool isOverdue = displayTime.isBefore(DateTime.now()) && !e.isCompleted;

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: () => _openCreateEvent(event: e),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isOverdue
                    ? Colors.redAccent.withValues(alpha:0.3)
                    : Colors.transparent,
                width: 2,
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 75,
                      height: 80,
                      decoration: BoxDecoration(
                        color: isOverdue
                            ? Colors.red.withValues(alpha:0.05)
                            : const Color(0xFFF8FAFC),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(18),
                          bottomLeft: Radius.circular(18),
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            DateFormat('HH:mm').format(displayTime),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isOverdue ? Colors.red : AppColors.navy,
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              context.read<EventProvider>().toggleEvent(e.id);
                            },
                            child: Checkbox(
                              value: e.isCompleted,
                              activeColor: Colors.green,
                              onChanged: (v) => context
                                  .read<EventProvider>()
                                  .toggleEvent(e.id),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(15),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              e.title,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                decoration: e.isCompleted
                                    ? TextDecoration.lineThrough
                                    : null,
                                color: AppColors.navy,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (e.description != null &&
                                e.description!.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                e.description!,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                            if (e.location != null &&
                                e.location!.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.location_on_outlined,
                                    size: 12,
                                    color: AppColors.primary,
                                  ),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      e.location!,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.primary,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            if (e.linkUrl != null && e.linkUrl!.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.link,
                                    size: 12,
                                    color: Colors.blue,
                                  ),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      e.linkUrl!,
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: Colors.blue,
                                        decoration: TextDecoration.underline,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            if (isOverdue) ...[
                              const SizedBox(height: 10),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: () => _rescheduleEvent(e),
                                  icon: const Icon(Icons.schedule, size: 16),
                                  label: const Text(
                                    "ПЕРЕНЕСТИ",
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.redAccent
                                        .withValues(alpha:0.1),
                                    foregroundColor: Colors.redAccent,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    if (e.imageUrl != null)
                      ClipRRect(
                        borderRadius: const BorderRadius.only(
                          topRight: Radius.circular(18),
                          bottomRight: Radius.circular(18),
                        ),
                        child: Image.memory(
                          base64Decode(e.imageUrl!),
                          width: 90,
                          height: 80,
                          fit: BoxFit.cover,
                        ),
                      ),
                    _buildActionsMenu(e.id, 'event', e),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

 void _rescheduleEvent(EventResponse event) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 0)), // Не даем выбирать прошедшие дни
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: AppColors.navy),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate == null) return;

    if (!mounted) return;
    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(event.eventDate),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: AppColors.navy),
          ),
          child: child!,
        );
      },
    );

    if (pickedTime == null) return;

    final newDateTime = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );

    // ПРОВЕРКА ПЕРЕД ОТПРАВКОЙ:
    if (newDateTime.isBefore(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Ошибка: Время переноса уже прошло. Выберите будущее время."),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    await context.read<EventProvider>().updateEvent(
      event.id,
      event.title,
      event.description,
      newDateTime,
      event.linkUrl,
      event.location,
      event.imageUrl,
    );

    _refreshData();
  }

  Widget _buildComments(TaskResponse t, int myId) {
    final ctrl = TextEditingController();
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 15),
      child: Column(
        children: [
          if (t.comments.isNotEmpty) ...[
            const Divider(),
            ...t.comments.map(
              (c) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: "${c.userName}: ",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                                color: AppColors.navy,
                              ),
                            ),
                            TextSpan(
                              text: c.text,
                              style: const TextStyle(fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (c.userId == myId)
                      IconButton(
                        onPressed: () => context
                            .read<TaskProvider>()
                            .deleteComment(t.id, c.id),
                        icon: const Icon(
                          Icons.close,
                          size: 12,
                          color: Colors.grey,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 8),
          TextField(
            controller: ctrl,
            style: const TextStyle(fontSize: 12),
            decoration: InputDecoration(
              hintText: "Комментировать...",
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              fillColor: const Color(0xFFF8FAFC),
              filled: true,
              isDense: true,
              suffixIcon: IconButton(
                icon: const Icon(Icons.send, size: 16),
                onPressed: () {
                  if (ctrl.text.trim().isNotEmpty) {
                    context.read<TaskProvider>().addComment(
                      t.id,
                      ctrl.text.trim(),
                    );
                    ctrl.clear();
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- КАЛЕНДАРЬ И ХЕЛПЕРЫ ---

 Widget _buildCalendarHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(25, 20, 20, 10),
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // БЛОК НАВИГАЦИИ ПО ДАТАМ
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded, color: AppColors.navy),
                onPressed: () {
                  setState(() {
                    // Перематываем фокус назад в зависимости от формата
                    if (_calendarFormat == CalendarFormat.month) {
                      _focusedDay = DateTime(_focusedDay.year, _focusedDay.month - 1, _focusedDay.day);
                    } else {
                      _focusedDay = _focusedDay.subtract(const Duration(days: 7));
                    }
                  });
                },
              ),
              const SizedBox(width: 5),
              Text(
                // Показываем Месяц и Год, если смотрим месяц, иначе полную дату
                _calendarFormat == CalendarFormat.month
                    ? DateFormat('MMMM yyyy', 'ru').format(_focusedDay).toUpperCase()
                    : DateFormat('EEEE, d MMMM', 'ru').format(_selectedDay).toUpperCase(),
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  color: AppColors.navy,
                  fontSize: 14,
                ),
              ),
              const SizedBox(width: 5),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded, color: AppColors.navy),
                onPressed: () {
                  setState(() {
                    // Перематываем фокус вперед
                    if (_calendarFormat == CalendarFormat.month) {
                      _focusedDay = DateTime(_focusedDay.year, _focusedDay.month + 1, _focusedDay.day);
                    } else {
                      _focusedDay = _focusedDay.add(const Duration(days: 7));
                    }
                  });
                },
              ),
            ],
          ),
          
          Row(
            children: [
              TextButton(
                onPressed: () {
                  jumpToDate(DateTime.now());
                },
                child: const Text("СЕГОДНЯ"),
              ),
              _buildViewSwitcher(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildViewSwitcher() => Container(
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: const Color(0xFFF1F4F8),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      children: [
        _viewItem("НЕД", CalendarFormat.week),
        _viewItem("МЕС", CalendarFormat.month),
      ],
    ),
  );

  Widget _viewItem(String label, CalendarFormat format) => GestureDetector(
    onTap: () => setState(() => _calendarFormat = format),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _calendarFormat == format ? Colors.white : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: _calendarFormat == format ? AppColors.navy : Colors.grey,
        ),
      ),
    ),
  );

 Widget _buildCalendarSection(
    List<EventResponse> evs,
    List<TaskResponse> ts,
    List<RoadmapStepDto> rs,
  ) {
    return Container(
      color: Colors.white,
      child: AnimatedSize(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        child: TableCalendar(
          key: ValueKey(_calendarFormat),
          locale: 'ru_RU',
          firstDay: DateTime.now().subtract(const Duration(days: 365 * 2)), // 2 года назад
          lastDay: DateTime.now().add(const Duration(days: 365 * 2)),    // 2 года вперед
          focusedDay: _focusedDay,
          calendarFormat: _calendarFormat,
          headerVisible: false, // Оставляем false, так как сделали свой заголовок выше
          startingDayOfWeek: StartingDayOfWeek.monday,
          selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
          onDaySelected: (sel, foc) => setState(() {
            _selectedDay = sel;
            _focusedDay = foc;
          }),
          
          // ВАЖНО: Обновляем фокус при свайпе календаря вручную
          onPageChanged: (focusedDay) {
            setState(() {
              _focusedDay = focusedDay;
            });
          },

          onFormatChanged: (format) {
            setState(() {
              _calendarFormat = format;
            });
          },
          eventLoader: (day) {
            bool hasEvent = evs.any((e) => isSameDay(e.eventDate.toLocal(), day));
            bool hasTask = ts.any((t) => isSameDay(t.dueDate.toLocal(), day));
            bool hasRoadmap = rs.any((s) => isSameDay(s.dueDate.toLocal(), day));
            return (hasEvent || hasTask || hasRoadmap) ? ['event'] : [];
          },
          calendarBuilders: CalendarBuilders(
            markerBuilder: (context, date, events) {
              if (events.isNotEmpty) {
                return Positioned(
                  bottom: 2,
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Color(0xFF2196F3),
                      shape: BoxShape.circle,
                    ),
                  ),
                );
              }
              return null;
            },
          ),
          calendarStyle: const CalendarStyle(
            selectedDecoration: BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
            todayDecoration: BoxDecoration(color: Color(0x1A00B4D8), shape: BoxShape.circle, border: Border.fromBorderSide(BorderSide(color: AppColors.primary, width: 1))),
            markerDecoration: BoxDecoration(color: Color(0xFF2196F3), shape: BoxShape.circle),
            outsideDaysVisible: false, // Прячем дни соседних месяцев для чистоты
          ),
        ),
      ),
    );
  }

  Widget _buildWeeklyProgressCard(
    List<TaskResponse> tasks,
    List<EventResponse> events,
    List<RoadmapStepDto> roadmapSteps,
    String myName,
    int myId,
  ) {
    // ИСПРАВЛЕНИЕ: Берем начало недели от выбранного дня (_selectedDay), а не от текущего (now)
    final startOfWeek = _selectedDay
        .subtract(Duration(days: _selectedDay.weekday - 1))
        .copyWith(hour: 0, minute: 0, second: 0);
    final endOfWeek = startOfWeek.add(const Duration(days: 7));

    // Фильтруем данные именно для выбранной недели
    final weekTasks = tasks.where((t) => 
      t.dueDate.isAfter(startOfWeek.subtract(const Duration(seconds: 1))) && 
      t.dueDate.isBefore(endOfWeek)).toList();
      
    final weekEvents = events.where((e) => 
      e.eventDate.isAfter(startOfWeek.subtract(const Duration(seconds: 1))) && 
      e.eventDate.isBefore(endOfWeek)).toList();
    
    final weekLessons = roadmapSteps.where((s) => 
      s.dueDate.isAfter(startOfWeek.subtract(const Duration(seconds: 1))) && 
      s.dueDate.isBefore(endOfWeek) &&
      s.creatorId != myId
    ).toList();
    
    // Убираем дубликаты уроков
    final uniqueLessonIds = <int>{};
    final uniqueWeekLessons = weekLessons.where((lesson) {
      if (uniqueLessonIds.contains(lesson.id)) return false;
      uniqueLessonIds.add(lesson.id);
      return true;
    }).toList();

    int doneTasks = weekTasks.where((t) => t.completions.any((c) => c.username == myName)).length;
    int doneEvents = weekEvents.where((e) => e.isCompleted).length;
    int doneLessons = uniqueWeekLessons.where((l) => l.status == "Done").length;

    int totalItems = weekTasks.length + weekEvents.length + uniqueWeekLessons.length;
    int totalDone = doneTasks + doneEvents + doneLessons;
    double totalProgress = totalItems == 0 ? 0 : (totalDone / totalItems);

    return Container(
      width: 320,
      margin: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(35),
        boxShadow: [BoxShadow(color: AppColors.navy.withValues(alpha:0.06), blurRadius: 30, offset: const Offset(0, 15))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color.fromARGB(255, 0, 51, 133), Color.fromARGB(255, 74, 141, 233)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(35)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Неделя ${DateFormat('dd.MM').format(startOfWeek)} - ${DateFormat('dd.MM').format(endOfWeek.subtract(const Duration(days: 1)))}", 
                  style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)
                ),
              ],
            ),
          ),
          Container(
            height: 80,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned(left: 30, right: 30, child: Container(height: 2, decoration: BoxDecoration(color: Colors.grey.shade200))),
                AnimatedAlign(
                  duration: const Duration(milliseconds: 1500),
                  curve: Curves.easeInOutBack,
                  alignment: Alignment(totalProgress * 2 - 1, 0),
                  child: SizedBox(
                    width: 60, height: 60,
                    child: Lottie.asset('animations/bee.json', repeat: true, fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => const Icon(Icons.emoji_nature, size: 40, color: Colors.amber)),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildModernStatRow("События", doneEvents, weekEvents.length, Colors.blue, Icons.calendar_today_rounded),
                const SizedBox(height: 12),
                _buildModernStatRow("Задания", doneTasks, weekTasks.length, Colors.green, Icons.rocket_launch_rounded),
                const SizedBox(height: 12),
                _buildModernStatRow("Уроки", doneLessons, uniqueWeekLessons.length, Colors.purple, Icons.school_rounded),
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.all(15),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha:0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.amber.withValues(alpha:0.2)),
            ),
            child: Row(
              children: [
                const Text("🍯", style: TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    totalProgress == 1.0 ? "Неделя закрыта идеально!" : "Сделано $totalDone из $totalItems задач. Вперед!",
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.navy),
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildModernStatRow(
    String label,
    int done,
    int total,
    Color color,
    IconData icon,
  ) {
    double val = total == 0 ? 0 : done / total;
    return Column(
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withValues(alpha:0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 14, color: color),
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: AppColors.navy,
              ),
            ),
            const Spacer(),
            Text(
              "$done/$total",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: color.withValues(alpha:0.8),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: val,
            minHeight: 7,
            backgroundColor: color.withValues(alpha:0.05),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  Widget _buildBlockHeader(
    IconData i,
    String t, {
    Color color = AppColors.navy,
  }) => Padding(
    padding: const EdgeInsets.only(top: 25, bottom: 15),
    child: Row(
      children: [
        Icon(i, size: 16, color: color),
        const SizedBox(width: 10),
        Text(
          t,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w900,
            color: color,
            letterSpacing: 1.2,
          ),
        ),
      ],
    ),
  );

  Widget _buildEmptyState() => const Center(
    child: Padding(
      padding: EdgeInsets.only(top: 60),
      child: Text(
        "На сегодня ничего нет",
        style: TextStyle(color: Colors.grey),
      ),
    ),
  );

  bool isSameDay(DateTime? a, DateTime? b) =>
      a?.year == b?.year && a?.month == b?.month && a?.day == b?.day;

  Widget _buildCompletionRow(TaskResponse t) {
    if (t.isSolo == true || t.completions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(
        spacing: -8,
        children: t.completions
            .map(
              (c) => Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: CircleAvatar(
                  radius: 12,
                  backgroundImage: c.avatarUrl != null
                      ? MemoryImage(base64Decode(c.avatarUrl!))
                      : null,
                  child: c.avatarUrl == null
                      ? Text(
                          c.username[0],
                          style: const TextStyle(fontSize: 10),
                        )
                      : null,
                ),
              ),
            )
            .toList(),
      ),
    );
  }

Widget _buildActionsMenu(int id, String type, dynamic obj) {
  final myId = context.read<AuthProvider>().user?.id;

  // ПРАВИЛО: Если это шаг цели (task), меню доступно ТОЛЬКО создателю.
  // Приглашенные партнеры вообще не видят три точки управления.
  if (type == 'task' && obj.creatorId != myId) {
    return const SizedBox.shrink();
  }

  return PopupMenuButton<String>(
    icon: const Icon(Icons.more_vert, size: 20, color: Colors.grey),
    onSelected: (v) {
      if (v == 'del') {
        // Удаление
        type == 'task'
            ? context.read<TaskProvider>().deleteTask(id, obj.goalId, context.read<GoalProvider>())
            : _deleteEvent(id);
      }
      if (v == 'reschedule') {
        // Перенос даты (для задач и событий)
        if (type == 'task') {
          _rescheduleGeneral(id, type); // Вызывает showDatePicker
        } else {
          _rescheduleEvent(obj);
        }
      }
      if (v == 'edit' && type == 'event') {
        // Редактирование текста доступно ТОЛЬКО для личных событий (Events)
        _openCreateEvent(event: obj);
      }
    },
    itemBuilder: (ctx) => [
      // Кнопка "Редактировать" (текст) скрыта для шагов цели (Tasks), видна только для Events
      if (type == 'event')
        const PopupMenuItem(value: 'edit', child: Text("Редактировать")),

      const PopupMenuItem(value: 'reschedule', child: Text("Перенести")),
      const PopupMenuItem(
        value: 'del',
        child: Text("Удалить", style: TextStyle(color: Colors.red)),
      ),
    ],
  );
}

  void _deleteEvent(int eventId) {
    MainDashboardLayout.showHiveDialog(
      context,
      Padding(
        padding: const EdgeInsets.all(35),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.delete_forever_rounded,
              color: Colors.redAccent,
              size: 60,
            ),
            const SizedBox(height: 20),
            const Text(
              "УДАЛИТЬ СОБЫТИЕ?",
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 18,
                color: AppColors.navy,
              ),
            ),
            const SizedBox(height: 15),
            const Text(
              "Это действие нельзя отменить. Вы уверены?",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 30),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    child: const Text("ОТМЕНА"),
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    onPressed: () {
                      context.read<EventProvider>().deleteEvent(eventId);
                      Navigator.pop(context);
                      _refreshData();
                    },
                    child: const Text(
                      "УДАЛИТЬ",
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _rescheduleGeneral(int id, String type) async {
    if (type == 'event') {
      final ev = context.read<EventProvider>().events.firstWhere(
        (e) => e.id == id,
      );
      _openCreateEvent(event: ev);
      return;
    }

    final DateTime? d = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (d != null && type == 'task') {
      await context.read<TaskProvider>().updateTaskDate(
        id,
        d,
        context.read<GoalProvider>(),
      );
      _refreshData();
    }
  }
}
