import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
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

  void _refreshData() {
    if (!mounted) return;
    context.read<TaskProvider>().loadAllTasks();
    context.read<EventProvider>().loadEvents();
    context.read<GroupProvider>().loadAllRoadmaps();
    context.read<NotificationProvider>().loadNotifications();
  }

  void jumpToDate(DateTime date) {
    setState(() {
      _selectedDay = DateTime(date.year, date.month, date.day);
      _focusedDay = _selectedDay;
    });
  }

  // --- ЛОГИКА ДЕЙСТВИЙ ---

  void _handleTaskCheckbox(TaskResponse t, String myName, String? myAvatar, bool isCurrentlyDone) {
    if (t.status == "UnderReview") return; // Если на проверке - ничего не делаем

    // Если задание требует артефакт (файл/ссылку) и оно еще не сделано
    // ПРИМЕЧАНИЕ: В TaskResponse нужно поле isArtifactRequired (из C# CreateTaskRequest)
    // Если его нет в модели - замените на логику вашей модели
    bool needsFile = t.artifactUrl != null || t.status == "UnderReview"; 

    if (needsFile && !isCurrentlyDone) {
      _showGeneralTaskSubmissionDialog(t);
    } else {
      context.read<TaskProvider>().updateTaskStatus(
        taskId: t.id, 
        newStatus: isCurrentlyDone ? "ToDo" : "Done", 
        userName: myName, 
        userAvatar: myAvatar, 
        goalProvider: context.read<GoalProvider>(), 
        comment: null
      );
      
      // Удаляем уведомление о просрочке при выполнении
      if (!isCurrentlyDone) {
        context.read<NotificationProvider>().removeOverdueNotification(t.id, "task");
      }
    }
  }

  void _handlePartnerTaskAction(RoadmapStepDto task) {
    if (task.status == "Done") return;

    if (task.isTest) {
      _showTestActionDialog(task);
    } else if (task.isRequired) {
      // Если ТРЕБУЕТСЯ отчет - открываем диалог с кнопками ССЫЛКА/ФАЙЛ
      _showArtifactSubmissionDialog(task);
    } else {
      // Простая задача без отчета - завершаем
      _markPartnerTaskAsDone(task);
    }
  }

  void _showGeneralTaskSubmissionDialog(TaskResponse t) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Требуется подтверждение"),
        content: Text("Для задачи '${t.title}' необходимо прикрепить результат (ссылку или файл) в деталях цели."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("ОК")),
        ],
      ),
    );
  }

  void _showTestActionDialog(RoadmapStepDto task) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [Icon(Icons.quiz, color: Colors.purple), SizedBox(width: 10), Text("ТЕСТ")]),
        content: Text("Пройти тест: ${task.content}?\nВас перенаправит в учебный чат."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("ОТМЕНА")),
          ElevatedButton(
            onPressed: () { Navigator.pop(ctx); _navigateToChat(task); },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.navy),
            child: const Text("В ЧАТ"),
          ),
        ],
      ),
    );
  }

  void _showArtifactSubmissionDialog(RoadmapStepDto task) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Сдать работу"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(task.content),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(child: OutlinedButton(onPressed: () { Navigator.pop(ctx); _showSubmitLinkDialog(task); }, child: const Text("ССЫЛКА"))),
                const SizedBox(width: 10),
                Expanded(child: ElevatedButton(onPressed: () { Navigator.pop(ctx); _submitFile(task); }, child: const Text("ФАЙЛ"))),
              ],
            )
          ],
        ),
      ),
    );
  }

  void _showSubmitLinkDialog(RoadmapStepDto task) {
    final linkCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Вставьте ссылку"),
        content: TextField(controller: linkCtrl, decoration: const InputDecoration(hintText: "https://...")),
        actions: [
          ElevatedButton(onPressed: () async {
            if (linkCtrl.text.isNotEmpty) {
              await context.read<GroupProvider>().submitStepResult(task.id, linkCtrl.text, "Сдано через главное меню", task.groupId);
              context.read<NotificationProvider>().removeOverdueNotification(task.id, "roadmap");
              Navigator.pop(ctx);
              _refreshData();
            }
          }, child: const Text("ОТПРАВИТЬ"))
        ],
      ),
    );
  }

  Future<void> _submitFile(RoadmapStepDto task) async {
    await context.read<GroupProvider>().uploadArtifact(task.id, task.groupId);
    context.read<NotificationProvider>().removeOverdueNotification(task.id, "roadmap");
    _refreshData();
  }

  Future<void> _markPartnerTaskAsDone(RoadmapStepDto task) async {
    await context.read<GroupProvider>().submitStepResult(task.id, "", "Завершено", task.groupId);
    context.read<NotificationProvider>().removeOverdueNotification(task.id, "roadmap");
    _refreshData();
  }

  void _navigateToChat(RoadmapStepDto task) {
    final groupProv = context.read<GroupProvider>();
    final group = groupProv.groups.firstWhere((g) => g.id == task.groupId, orElse: () => groupProv.groups.first);
    Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(group: group))).then((_) => _refreshData());
  }

  void _openCreateEvent({EventResponse? event}) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => CreateEventScreen(initialDate: _selectedDay, event: event))).then((_) => _refreshData());
  }

  // --- ВЕРСТКА ---

  @override
  Widget build(BuildContext context) {
    final eventProv = context.watch<EventProvider>();
    final taskProv = context.watch<TaskProvider>();
    final groupProv = context.watch<GroupProvider>();
    final auth = context.read<AuthProvider>();
    
    final myName = auth.user?.username ?? "";
    final myId = auth.user?.id ?? 0;
    final myAvatar = auth.user?.avatarUrl;

    final dailyEvents = eventProv.events.where((e) => isSameDay(e.eventDate.toLocal(), _selectedDay)).toList();
    final dailyTasks = taskProv.tasks.where((t) => isSameDay(t.dueDate.toLocal(), _selectedDay)).toList();
    final partnerTasks = groupProv.allRoadmapSteps.where((s) => isSameDay(s.dueDate.toLocal(), _selectedDay) && s.creatorId != myId).toList();

    bool isWeb = MediaQuery.of(context).size.width > 1000;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          _buildCalendarHeader(),
          _buildCalendarSection(eventProv.events, taskProv.tasks, groupProv.allRoadmapSteps),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: ListView(
                    padding: EdgeInsets.symmetric(horizontal: isWeb ? 40 : 20, vertical: 25),
                    children: [
                      if (dailyEvents.isNotEmpty) ...[
                        _buildBlockHeader(Icons.calendar_month, "СОБЫТИЯ ДНЯ"),
                        ...dailyEvents.map((e) => _buildEventCard(e)),
                      ],
                      if (dailyTasks.isNotEmpty) ...[
                        _buildBlockHeader(Icons.rocket_launch, "ШАГИ К ЦЕЛЯМ"),
                        ...dailyTasks.map((t) => _buildEnhancedTaskCard(t, myName, myAvatar, myId)),
                      ],
                      if (partnerTasks.isNotEmpty) ...[
                        _buildBlockHeader(Icons.people_alt, "ЗАДАНИЯ ИЗ ЧАТОВ", color: Colors.purple),
                        ...partnerTasks.map((s) => _buildEnhancedPartnerCard(s)),
                      ],
                      if (dailyEvents.isEmpty && dailyTasks.isEmpty && partnerTasks.isEmpty) _buildEmptyState(),
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
                if (isWeb) _buildWebSidebar(taskProv.tasks, eventProv.events, myName),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openCreateEvent(),
        backgroundColor: AppColors.navy,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text("СОБЫТИЕ", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  // --- КАРТОЧКИ ---

  Widget _buildEnhancedTaskCard(TaskResponse t, String myName, String? myAvatar, int myId) {
    bool isDone = t.status == "Done" || t.completions.any((c) => c.username == myName);
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    bool isOverdue = t.dueDate.toLocal().isBefore(today) && !isDone;

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: isOverdue ? Colors.redAccent.withOpacity(0.4) : const Color(0xFFF1F5F9), width: isOverdue ? 2 : 1),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
          ),
          child: Column(
            children: [
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                leading: Checkbox(
                  value: isDone, activeColor: Colors.green,
                  onChanged: (v) => _handleTaskCheckbox(t, myName, myAvatar, isDone),
                ),
                title: Text(t.title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, decoration: isDone ? TextDecoration.lineThrough : null, color: isDone ? Colors.grey : AppColors.navy)),
                subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text("ЦЕЛЬ: ${t.goalTitle.toUpperCase()}", style: const TextStyle(fontSize: 9, color: AppColors.primary, fontWeight: FontWeight.w900)),
                  if (isOverdue) 
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: InkWell(
                        onTap: () => _rescheduleGeneral(t.id, 'task'),
                        child: const Text("ПРОПУЩЕНО. ПЕРЕНЕСТИ?", style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  _buildCompletionRow(t),
                ]),
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
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    bool isOverdue = s.dueDate.toLocal().isBefore(today) && !isDone && !isReview;

    Color cardColor = s.isTest ? Colors.purple : AppColors.primary;

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: isOverdue ? Colors.red.withOpacity(0.3) : cardColor.withOpacity(0.1), width: 1.5),
        boxShadow: [BoxShadow(color: cardColor.withOpacity(0.03), blurRadius: 10)],
      ),
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.all(15),
            leading: isReview 
              ? const Icon(Icons.hourglass_bottom, color: Colors.orange)
              : IconButton(
                  icon: Icon(isDone ? Icons.check_circle : Icons.circle_outlined, color: isDone ? Colors.green : Colors.grey),
                  onPressed: () => _handlePartnerTaskAction(s),
                ),
            title: Text(s.content, style: TextStyle(fontWeight: FontWeight.w800, decoration: isDone ? TextDecoration.lineThrough : null, color: isDone ? Colors.grey : AppColors.navy)),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("НАЗНАЧИЛ: ${s.creatorName ?? 'Учитель'}", style: TextStyle(fontSize: 10, color: cardColor, fontWeight: FontWeight.bold)),
                  if (isReview) const Text("Ждет проверки учителем", style: TextStyle(color: Colors.orange, fontSize: 10, fontWeight: FontWeight.bold)),
                  if (isOverdue) const Text("ЗАДАНИЕ ПРОСРОЧЕНО", style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            trailing: !isDone ? _buildTinyActionButton(s) : const Icon(Icons.verified, color: Colors.green),
          ),
          _buildTinyResources(s),
        ],
      ),
    );
  }

  Widget _buildTinyActionButton(RoadmapStepDto s) {
    if (s.isTest) return const Icon(Icons.quiz, color: Colors.purple, size: 20);
    if (s.isRequired) return const Icon(Icons.upload_file, color: Colors.blue, size: 20);
    return const SizedBox.shrink();
  }

  Widget _buildTinyResources(RoadmapStepDto s) {
    if (s.instructionUrl == null && s.artifactUrl == null) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: const BorderRadius.vertical(bottom: Radius.circular(22))),
      child: Row(
        children: [
          if (s.instructionUrl != null) const Row(children: [Icon(Icons.menu_book, size: 12, color: Colors.blue), SizedBox(width: 4), Text("Материал", style: TextStyle(fontSize: 10))]),
          const SizedBox(width: 15),
          if (s.artifactUrl != null) const Row(children: [Icon(Icons.description, size: 12, color: Colors.green), SizedBox(width: 4), Text("Отчет сдан", style: TextStyle(fontSize: 10))]),
        ],
      ),
    );
  }

  Widget _buildEventCard(EventResponse e) {
    DateTime localTime = e.eventDate.toLocal();
    bool isOverdue = localTime.isBefore(DateTime.now()) && !e.isCompleted;

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: isOverdue ? Colors.redAccent.withOpacity(0.3) : Colors.transparent, width: 2),
          ),
          child: Row(
            children: [
              Container(
                width: 75, height: 80,
                decoration: BoxDecoration(color: isOverdue ? Colors.red.withOpacity(0.05) : const Color(0xFFF8FAFC), borderRadius: const BorderRadius.horizontal(left: Radius.circular(18))),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(DateFormat('HH:mm').format(localTime), style: TextStyle(fontWeight: FontWeight.bold, color: isOverdue ? Colors.red : AppColors.navy)),
                  Checkbox(value: e.isCompleted, activeColor: Colors.green, onChanged: (v) => context.read<EventProvider>().toggleEvent(e.id)),
                ]),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(15),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(e.title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, decoration: e.isCompleted ? TextDecoration.lineThrough : null)),
                  ]),
                ),
              ),
              if (e.imageUrl != null) 
                ClipRRect(
                  borderRadius: const BorderRadius.only(topRight: Radius.circular(18), bottomRight: Radius.circular(18)),
                  child: Image.memory(base64Decode(e.imageUrl!), width: 90, height: 80, fit: BoxFit.cover)
                ),
              _buildActionsMenu(e.id, 'event', e),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildComments(TaskResponse t, int myId) {
    final ctrl = TextEditingController();
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 15),
      child: Column(children: [
        if (t.comments.isNotEmpty) ...[
          const Divider(),
          ...t.comments.map((c) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(children: [
              Expanded(child: Text.rich(TextSpan(children: [
                TextSpan(text: "${c.userName}: ", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppColors.navy)),
                TextSpan(text: c.text, style: const TextStyle(fontSize: 11)),
              ]))),
              if (c.userId == myId) 
                IconButton(onPressed: () => context.read<TaskProvider>().deleteComment(t.id, c.id), icon: const Icon(Icons.close, size: 12, color: Colors.grey), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
            ]),
          )),
        ],
        const SizedBox(height: 8),
        TextField(
          controller: ctrl,
          style: const TextStyle(fontSize: 12),
          decoration: InputDecoration(
            hintText: "Комментировать...", border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
            fillColor: const Color(0xFFF8FAFC), filled: true, isDense: true,
            suffixIcon: IconButton(icon: const Icon(Icons.send, size: 16), onPressed: () {
              if (ctrl.text.trim().isNotEmpty) { context.read<TaskProvider>().addComment(t.id, ctrl.text.trim()); ctrl.clear(); }
            }),
          ),
        )
      ]),
    );
  }

  // --- КАЛЕНДАРЬ И ХЕЛПЕРЫ ---

  Widget _buildCalendarHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(25, 20, 20, 10), color: Colors.white,
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(DateFormat('EEEE, d MMMM', 'ru').format(_selectedDay).toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.navy, fontSize: 14)),
        Row(children: [
          TextButton(onPressed: () => jumpToDate(DateTime.now()), child: const Text("СЕГОДНЯ")),
          _buildViewSwitcher(),
        ]),
      ]),
    );
  }

  Widget _buildViewSwitcher() => Container(
    padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: const Color(0xFFF1F4F8), borderRadius: BorderRadius.circular(10)),
    child: Row(children: [ _viewItem("НЕД", CalendarFormat.week), _viewItem("МЕС", CalendarFormat.month) ]),
  );

  Widget _viewItem(String label, CalendarFormat format) => GestureDetector(
    onTap: () => setState(() => _calendarFormat = format),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: _calendarFormat == format ? Colors.white : Colors.transparent, borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _calendarFormat == format ? AppColors.navy : Colors.grey)),
    ),
  );

  Widget _buildCalendarSection(List<EventResponse> evs, List<TaskResponse> ts, List<RoadmapStepDto> rs) {
    return Container(
      color: Colors.white,
      child: TableCalendar(
        locale: 'ru_RU', firstDay: DateTime.now().subtract(const Duration(days: 365)), lastDay: DateTime.now().add(const Duration(days: 365)),
        focusedDay: _focusedDay, calendarFormat: _calendarFormat, headerVisible: false, startingDayOfWeek: StartingDayOfWeek.monday,
        selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
        onDaySelected: (sel, foc) => setState(() { _selectedDay = sel; _focusedDay = foc; }),
        eventLoader: (day) {
          bool hasEvent = evs.any((e) => isSameDay(e.eventDate.toLocal(), day));
          bool hasTask = ts.any((t) => isSameDay(t.dueDate.toLocal(), day));
          bool hasRoadmap = rs.any((s) => isSameDay(s.dueDate.toLocal(), day));
          return (hasEvent || hasTask || hasRoadmap) ? ['dot'] : [];
        },
        calendarStyle: const CalendarStyle(selectedDecoration: BoxDecoration(color: AppColors.primary, shape: BoxShape.circle), markerDecoration: BoxDecoration(color: Colors.orange, shape: BoxShape.circle)),
      ),
    );
  }

  Widget _buildWebSidebar(List<TaskResponse> tasks, List<EventResponse> events, String myName) {
    int done = tasks.where((t) => t.completions.any((c) => c.username == myName)).length;
    double progress = tasks.isEmpty ? 0 : (done / tasks.length);
    return Container(
      width: 300, margin: const EdgeInsets.all(25), padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 20)]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text("ПРОГРЕСС", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
        const SizedBox(height: 20),
        _statTile("Задач", done.toString(), Colors.green),
        _statTile("Событий", events.length.toString(), Colors.blue),
        const SizedBox(height: 20),
        LinearProgressIndicator(value: progress, color: AppColors.primary, backgroundColor: Colors.grey.shade100),
      ]),
    );
  }

  Widget _statTile(String l, String v, Color c) => Padding(padding: const EdgeInsets.only(bottom: 10), child: Row(children: [Icon(Icons.circle, size: 8, color: c), const SizedBox(width: 10), Text(l), const Spacer(), Text(v, style: const TextStyle(fontWeight: FontWeight.bold))]));

  Widget _buildBlockHeader(IconData i, String t, {Color color = AppColors.navy}) => Padding(padding: const EdgeInsets.only(top: 25, bottom: 15), child: Row(children: [Icon(i, size: 16, color: color), const SizedBox(width: 10), Text(t, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: color, letterSpacing: 1.2))]));

  Widget _buildEmptyState() => const Center(child: Padding(padding: EdgeInsets.only(top: 60), child: Text("На сегодня ничего нет", style: TextStyle(color: Colors.grey))));

  bool isSameDay(DateTime? a, DateTime? b) => a?.year == b?.year && a?.month == b?.month && a?.day == b?.day;

  Widget _buildCompletionRow(TaskResponse t) {
    if (t.completions.isEmpty) return const SizedBox.shrink();
    return Padding(padding: const EdgeInsets.only(top: 8), child: Wrap(spacing: -8, children: t.completions.map((c) => Container(decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)), child: CircleAvatar(radius: 12, backgroundImage: c.avatarUrl != null ? MemoryImage(base64Decode(c.avatarUrl!)) : null, child: c.avatarUrl == null ? Text(c.username[0], style: const TextStyle(fontSize: 10)) : null))).toList()));
  }

  Widget _buildActionsMenu(int id, String type, dynamic obj) => PopupMenuButton<String>(
    icon: const Icon(Icons.more_vert, size: 20, color: Colors.grey),
    onSelected: (v) {
      if (v == 'del') { type == 'task' ? context.read<TaskProvider>().deleteTask(id, obj.goalId) : context.read<EventProvider>().deleteEvent(id); }
      if (v == 'edit') { _rescheduleGeneral(id, type); }
    },
    itemBuilder: (ctx) => [ const PopupMenuItem(value: 'edit', child: Text("Перенести")), const PopupMenuItem(value: 'del', child: Text("Удалить", style: TextStyle(color: Colors.red))) ],
  );

  void _rescheduleGeneral(int id, String type) async {
    final DateTime? d = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
    if (d != null) {
      if (type == 'task') {
        await context.read<TaskProvider>().updateTaskDate(id, d, context.read<GoalProvider>());
      } else {
        final ev = context.read<EventProvider>().events.firstWhere((e) => e.id == id);
        await context.read<EventProvider>().updateEvent(id, ev.title, ev.description, d, ev.linkUrl, ev.location, ev.imageUrl);
      }
      _refreshData();
    }
  }
}