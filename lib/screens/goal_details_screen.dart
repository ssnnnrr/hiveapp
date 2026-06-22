import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_app/screens/main_screen.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:fl_chart/fl_chart.dart';

// Импорты внутренних ресурсов
import '../models/all_models.dart';
import '../providers/task_provider.dart';
import '../providers/goal_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/user_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/main_dashboard_layout.dart';

/// ЭКРАН ДЕТАЛЕЙ МАРШРУТА (GOAL DETAILS)
/// Содержит Дашборд, Базу знаний, Управление командой и Метрики
class GoalDetailsScreen extends StatefulWidget {
  final GoalResponse goal;
  const GoalDetailsScreen({super.key, required this.goal});

  @override
  State<GoalDetailsScreen> createState() => _GoalDetailsScreenState();
}

class _GoalDetailsScreenState extends State<GoalDetailsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // Синхронизация данных с сервером при входе
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TaskProvider>().loadTasks(widget.goal.id);
      context.read<UserProvider>().loadFriends();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // --- ЛОГИКА РАСЧЕТОВ (МЕТРИКИ И ПРОГРЕСС) ---
  // ---------------------------------------------------------------------------

  /// Считает прогресс конкретного пользователя по списку completions
  double _calcUserProgress(List<TaskResponse> tasks, String username) {
    if (tasks.isEmpty) return 0.0;
    int done = tasks
        .where((t) => t.completions.any((c) => c.username == username))
        .length;
    return (done / tasks.length) * 100;
  }

  Map<String, double> _getMetrics(
    List<TaskResponse> tasks,
    String myName,
    GoalResponse goal,
  ) {
    if (tasks.isEmpty) return {"completed": 0, "total": 0, "percent": 0};

    int totalTasks = tasks.length;
    int completedCount = tasks
        .where((t) => t.completions.any((c) => c.username == myName))
        .length;

    return {
      "completed": completedCount.toDouble(),
      "total": totalTasks.toDouble(),
      "percent": totalTasks > 0 ? (completedCount / totalTasks * 100) : 0,
    };
  }


  // ---------------------------------------------------------------------------
  // --- ВСПОМОГАТЕЛЬНЫЕ UI ЭЛЕМЕНТЫ ---
  // ---------------------------------------------------------------------------

  /// Адаптивное модальное окно (центровка для Web/Desktop)
  void _showHiveModal(Widget content) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Material(
            color: Colors.transparent,
            child: Container(
              margin: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 25,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: content,
            ),
          ),
        ),
      ),
    );
  }

  /// Стандартизированный аватар пользователя
  Widget _userAvatar(String? url, String name, {double radius = 12}) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.navy.withValues(alpha:0.1),
      backgroundImage: (url != null && url.isNotEmpty)
          ? MemoryImage(base64Decode(url))
          : null,
      child: (url == null || url.isEmpty)
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

  // ---------------------------------------------------------------------------
  // --- ГЛАВНЫЙ ЭКРАН BUILD ---
  // ---------------------------------------------------------------------------
 void _handleGlobalNavigation(int index) {
    if (index == 1) {
      // Если нажали на "Цели" (индекс 1), просто закрываем детали и возвращаемся к списку
      Navigator.pop(context);
    } else {
      // Если на любой другой пункт - сбрасываем всё и идем в MainScreen на нужную вкладку
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => MainScreen(initialIndex: index)),
        (route) => false,
      );
    }
  }

@override
  Widget build(BuildContext context) {
    final goalProv = context.watch<GoalProvider>();
    final taskProv = context.watch<TaskProvider>();
    final authProv = context.read<AuthProvider>();

    final goal = goalProv.goals.firstWhere(
      (g) => g.id == widget.goal.id,
      orElse: () => widget.goal,
    );

    final myUser = authProv.user;
    final myName = myUser?.username ?? "";
    bool isCreator = goal.userId == myUser?.id;

    final goalTasks = taskProv.getTasksByGoal(goal.id); 
    final double myLiveProg = taskProv.getProgress(myName, goalId: goal.id);
    final metrics = _getMetrics(goalTasks, myName, goal);

    double screenWidth = MediaQuery.of(context).size.width;
    bool isWide = screenWidth > 1150;

    // ИСПРАВЛЕННЫЙ ВЫЗОВ ЛЕЙАУТА
    return MainDashboardLayout(
      selectedIndex: 1, // Индекс вкладки "Цели"
      onTabSelected: _handleGlobalNavigation, // Передаем функцию навигации
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: _buildAppBar(goal, isCreator, isWide),
        body: TabBarView(
          controller: _tabController,
          children: [
            RefreshIndicator(
              onRefresh: () => taskProv.loadTasks(goal.id),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(26),
                child: isWide
                    ? _buildWideDashboard(goal, taskProv, myName, myUser, isCreator, metrics, myLiveProg, goalTasks)
                    : _buildMobileDashboard(goal, taskProv, myName, myUser, isCreator, metrics, myLiveProg, goalTasks),
              ),
            ),
            _buildMaterialsTab(goal, isCreator),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // --- РАЗДЕЛ ДАШБОРДА (МАКЕТЫ) ---
  // ---------------------------------------------------------------------------

// ШИРОКИЙ ЭКРАН (8 аргументов)
Widget _buildWideDashboard(
  GoalResponse g,
  TaskProvider prov,
  String name,
  UserDto? u,
  bool creator,
  Map<String, double> m,
  double prog,
  List<TaskResponse> goalTasks, // Добавлен 8-й аргумент
) {
  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        flex: 2,
        child: Column(
          children: [
            _dashCard(_buildMainProgressCircle(prog)),
            const SizedBox(height: 24),
            _dashCard(_buildMetricsList(m, g.isSolo, g)),
          ],
        ),
      ),
      const SizedBox(width: 24),
      Expanded(
        flex: 4,
        child: _dashCard(_buildTaskListSection(g, prov, name, u, creator, goalTasks)),
      ),
      const SizedBox(width: 24),
      Expanded(
        flex: 2,
        child: Column(
          children: [
            if (!g.isSolo) ...[
              _dashCard(_buildTeamManagementSection(g, goalTasks, creator, u?.id)),
              const SizedBox(height: 24),
            ],
            _dashCard(_buildProductivityChart(goalTasks, name)),
          ],
        ),
      ),
    ],
  );
}

// МОБИЛЬНЫЙ ЭКРАН (8 аргументов)
Widget _buildMobileDashboard(
  GoalResponse g,
  TaskProvider prov,
  String name,
  UserDto? u,
  bool creator,
  Map<String, double> m,
  double prog,
  List<TaskResponse> goalTasks, // Добавлен 8-й аргумент
) {
  return Column(
    children: [
      _dashCard(_buildMainProgressCircle(prog)),
      const SizedBox(height: 24),
      _dashCard(_buildMetricsList(m, g.isSolo, g)),
      const SizedBox(height: 32),
      _buildTaskListSection(g, prov, name, u, creator, goalTasks),
      const SizedBox(height: 32),
      if (!g.isSolo) ...[
        _dashCard(_buildTeamManagementSection(g, goalTasks, creator, u?.id)),
        const SizedBox(height: 32),
      ],
      _dashCard(_buildProductivityChart(goalTasks, name)),
      const SizedBox(height: 120),
    ],
  );
}

  // ---------------------------------------------------------------------------
  // --- КОМПОНЕНТЫ ИНТЕРФЕЙСА (CARDS) ---
  // ---------------------------------------------------------------------------

  Widget _dashCard(Widget child) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(24),
    decoration: AppDecorations.glassCard,
    child: child,
  );

  /// Большой круглый индикатор личного прогресса
  Widget _buildMainProgressCircle(double prog) {
    return Column(
      children: [
        const Text(
          "ВАШ ПРОГРЕСС",
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 11,
            color: Colors.grey,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 30),
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              height: 150,
              width: 150,
              child: CircularProgressIndicator(
                value: prog / 100,
                strokeWidth: 14,
                backgroundColor: AppColors.primary.withValues(alpha:0.05),
                color: const Color(0xFF32D74B), // Насыщенный зеленый
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "${prog.toInt()}%",
                  style: const TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.w900,
                    color: AppColors.navy,
                  ),
                ),
                const Text(
                  "ВЫПОЛНЕНО",
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

Widget _buildMetricsList(Map<String, double> metrics, bool isSolo, GoalResponse goal) {
  final completed = metrics['completed']!.toInt();
  final total = metrics['total']!.toInt();
  final materialsCount = goal.materials.length;

  // Расчет дней до дедлайна
  final now = DateTime.now();
  final daysLeft = goal.targetDate.difference(now).inDays;
  final dateFormatted = DateFormat('dd MMMM yyyy', 'ru').format(goal.targetDate);

  // Цвет для дедлайна (меняется если осталось мало времени)
  Color deadlineColor = AppColors.primary;
  if (daysLeft <= 3) deadlineColor = Colors.redAccent;
  else if (daysLeft <= 7) deadlineColor = Colors.orangeAccent;

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        "ОСНОВНЫЕ ПОКАЗАТЕЛИ",
        style: TextStyle(
          fontWeight: FontWeight.w900,
          fontSize: 11,
          color: Colors.grey,
          letterSpacing: 1.2,
        ),
      ),
      const SizedBox(height: 20),
      
      // 1. ДЕДЛАЙН
      _statTile(
        icon: Icons.calendar_today_rounded,
        color: deadlineColor,
        title: "Срок завершения",
        subtitle: "Цель до $dateFormatted",
        value: daysLeft > 0 ? "$daysLeft" : "0",
        suffix: "дн.",
      ),
      
      const SizedBox(height: 12),

      // 2. ЗАДАЧИ
      _statTile(
        icon: Icons.checklist_rounded,
        color: Colors.green,
        title: "Прогресс этапов",
        subtitle: "Выполнено $completed из $total шагов",
        value: "$completed",
        suffix: "/$total",
      ),

      const SizedBox(height: 12),

      // 3. БАЗА ЗНАНИЙ
      _statTile(
        icon: Icons.auto_stories_rounded,
        color: Colors.orange,
        title: "База знаний",
        subtitle: materialsCount == 0 
            ? "Материалы еще не добавлены" 
            : "Прикреплено ресурсов: $materialsCount",
        value: "$materialsCount",
        suffix: materialsCount % 10 == 1 && materialsCount % 100 != 11 ? "файл" : "рес.",
      ),
    ],
  );
}

// Новый вспомогательный виджет для горизонтальной карточки
Widget _statTile({
  required IconData icon,
  required Color color,
  required String title,
  required String subtitle,
  required String value,
  required String suffix,
}) {
  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: color.withValues(alpha:0.1), width: 1.5),
      boxShadow: [
        BoxShadow(
          color: color.withValues(alpha:0.04),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Row(
      children: [
        // Левая часть: Иконка в мягком круге
        Container(
          height: 48,
          width: 48,
          decoration: BoxDecoration(
            color: color.withValues(alpha:0.1),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(width: 16),
        
        // Средняя часть: Текстовое описание
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.navy,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        
        // Правая часть: Числовой показатель
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: color,
                height: 1,
              ),
            ),
            Text(
              suffix,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: color.withValues(alpha:0.5),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}
  // ---------------------------------------------------------------------------
  // --- СПИСОК ЭТАПОВ (ШАГОВ К ЦЕЛИ) ---
  // ---------------------------------------------------------------------------

// СПИСОК ЗАДАЧ (6 аргументов)
Widget _buildTaskListSection(
  GoalResponse goal,
  TaskProvider prov,
  String name,
  UserDto? u,
  bool creator,
  List<TaskResponse> goalTasks, // Добавлен 6-й аргумент
) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text("ЭТАПЫ МАРШРУТА (${goalTasks.length})", 
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: AppColors.navy)),
          if (creator)
            IconButton(
              onPressed: () => _showAddTaskModal(goal.id),
              icon: const Icon(Icons.add_circle_rounded, color: AppColors.primary, size: 30),
            ),
        ],
      ),
      const SizedBox(height: 20),
      if (prov.isLoading)
        const Center(child: CircularProgressIndicator())
      else if (goalTasks.isEmpty)
        const Center(child: Padding(padding: EdgeInsets.all(40), child: Text("Задачи еще не добавлены")))
      else
       ListView.builder(
  shrinkWrap: true,
  physics: const NeverScrollableScrollPhysics(),
  itemCount: goalTasks.length, // Используем отфильтрованный список
  itemBuilder: (ctx, i) {
    final t = goalTasks[i];
    bool isDone = t.completions.any((c) => c.username == name);
    
    // ПЕРЕДАЕМ КЛЮЧ ЗДЕСЬ
    return _buildStepCard(
      t, 
      isDone, 
      name, 
      u, 
      creator, 
      goal.isSolo,
      key: ValueKey(t.id), // <-- Теперь это сработает
    );
  },
),
    ],
  );
}


Widget _buildStepCard(
  TaskResponse t, 
  bool isDone, 
  String name, 
  UserDto? u, 
  bool creator, 
  bool isSolo, 
  {Key? key} // <-- Мы добавили этот именованный параметр в фигурных скобках
) {
  return Container(
    key: key, // <-- ПРИСВАИВАЕМ КЛЮЧ КОНТЕЙНЕРУ
    margin: const EdgeInsets.only(bottom: 15),
    decoration: BoxDecoration(
      color: isDone ? const Color(0xFFF9FBFF) : Colors.white,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(
        color: isDone ? Colors.green.withValues(alpha:0.25) : const Color(0xFFE8ECF1), 
        width: 1.5
      ),
    ),
    child: Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Transform.scale(
          scale: 1.4,
          child: Checkbox(
            value: isDone,
            activeColor: Colors.green,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
            onChanged: (v) {
              context.read<TaskProvider>().updateTaskStatus(
                taskId: t.id,
                newStatus: isDone ? "ToDo" : "Done",
                comment: null,
                userName: name,
                userAvatar: u?.avatarUrl,
                goalProvider: context.read<GoalProvider>(),
              );
            },
          ),
        ),
        title: Text(
          t.title, 
          style: TextStyle(
            fontWeight: FontWeight.w700, 
            fontSize: 15, 
            decoration: isDone ? TextDecoration.lineThrough : null, 
            color: isDone ? Colors.grey : AppColors.navy
          )
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.calendar_today_rounded, size: 12, color: AppColors.primary),
                const SizedBox(width: 6),
                Text(
                  DateFormat('dd MMMM yyyy', 'ru').format(t.dueDate), 
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.primary)
                ),
              ],
            ),
            _buildCompletionsAvatarsRow(t.completions, isSolo),
          ],
        ),
        children: [_buildTaskExpandedDetails(t, creator)],
      ),
    ),
  );
}


Widget _buildCompletionsAvatarsRow(List<UserMinimalDto> completions, bool isSolo) {
  // Если цель личная — иконки других людей (или вообще иконки) не нужны
  if (isSolo || completions.isEmpty) {
    return const SizedBox.shrink();
  }
  
  return Padding(
    padding: const EdgeInsets.only(top: 10),
    child: Wrap(
      spacing: 6,
      children: completions.map((c) => Tooltip(
        message: c.username,
        child: _userAvatar(c.avatarUrl, c.username, radius: 10),
      )).toList(),
    ),
  );
}

Widget _buildTaskExpandedDetails(TaskResponse t, bool creator) {
  final myId = context.read<AuthProvider>().user?.id;
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: const Color(0xFFF9FAFF), 
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(22)), 
      border: Border(top: BorderSide(color: Colors.grey.withValues(alpha: 0.1)))
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (creator) ...[
          Row(
            children: [
              const Text("УПРАВЛЕНИЕ ЭТАПОМ:", 
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 0.5)),
              const Spacer(),
              TextButton.icon(
                onPressed: () => _showEditTaskModal(t), 
                icon: const Icon(Icons.edit_rounded, size: 16), 
                label: const Text("Изменить", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))
              ),
              const SizedBox(width: 10),
              IconButton(
                onPressed: () => _confirmDeleteTask(t), 
                icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                tooltip: "Удалить шаг",
              ),
            ],
          ),
          const Divider(height: 30),
        ],

        const Text("ОБСУЖДЕНИЕ ЭТОГО ШАГА", 
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey)),
        const SizedBox(height: 15),

        // Список комментариев
        ...t.comments.map((c) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _userAvatar(c.avatarUrl, c.userName, radius: 15),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(c.userName, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: AppColors.navy)),
                        const SizedBox(width: 8),
                        Text(DateFormat('HH:mm').format(c.createdAt), style: const TextStyle(fontSize: 10, color: Colors.grey)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(c.text, style: const TextStyle(fontSize: 13, height: 1.4, color: Colors.black87)),
                  ],
                ),
              ),
              if (c.userId == myId)
                IconButton(
                  onPressed: () => context.read<TaskProvider>().deleteComment(t.id, c.id), 
                  icon: const Icon(Icons.close_rounded, size: 14, color: Colors.grey)
                ),
            ],
          ),
        )),

        _buildTaskCommentInputField(t.id),
      ],
    ),
  );
}

  Widget _buildTaskCommentInputField(int taskId) {
    final TextEditingController ctrl = TextEditingController();
    return Container(
      margin: const EdgeInsets.only(top: 15),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.blue.shade50),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: ctrl,
              style: const TextStyle(fontSize: 13),
              decoration: const InputDecoration(
                hintText: "Добавить ответ...",
                border: InputBorder.none,
                hintStyle: TextStyle(fontSize: 12),
              ),
            ),
          ),
          IconButton(
            onPressed: () {
              if (ctrl.text.trim().isNotEmpty) {
                context.read<TaskProvider>().addComment(
                  taskId,
                  ctrl.text.trim(),
                );
                ctrl.clear();
              }
            },
            icon: const Icon(
              Icons.send_rounded,
              color: AppColors.primary,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }




  // ---------------------------------------------------------------------------
  // --- КОМАНДА: ЛОГИКА УДАЛЕНИЯ И ОЖИДАНИЯ ---
  // ---------------------------------------------------------------------------

  Widget _buildTeamManagementSection(
    GoalResponse g,
    List<TaskResponse> tasks,
    bool isCreator,
    int? myId,
  ) {
    // Не показываем себя в списке партнеров
    final partners = g.collaborators.where((c) => c.id != myId).toList();
    if (partners.isEmpty) {
      return const Column(
        children: [
          Icon(Icons.person_outline, color: Colors.grey, size: 40),
          SizedBox(height: 10),
          Text(
            "Вы работаете один",
            style: TextStyle(color: Colors.grey, fontSize: 11),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "КОМАНДА МАРШРУТА",
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 11,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 20),
        ...partners.map((p) {
          double pProg = _calcUserProgress(tasks, p.name);
          return Padding(
            padding: const EdgeInsets.only(bottom: 15),
            child: Row(
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    if (p.isConfirmed)
                      SizedBox(
                        height: 48,
                        width: 48,
                        child: CircularProgressIndicator(
                          value: pProg / 100,
                          strokeWidth: 3,
                          color: Colors.amber,
                        ),
                      )
                    else
                      const SizedBox(
                        height: 48,
                        width: 48,
                        child: Icon(
                          Icons.hourglass_empty_rounded,
                          color: Colors.orange,
                          size: 20,
                        ),
                      ),
                    _userAvatar(p.avatarUrl, p.name, radius: 20),
                  ],
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        p.isConfirmed
                            ? "${pProg.toInt()}% завершено"
                            : "Ожидает подтверждения",
                        style: TextStyle(
                          fontSize: 10,
                          color: p.isConfirmed ? Colors.grey : Colors.orange,
                          fontWeight: p.isConfirmed
                              ? FontWeight.normal
                              : FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                // УДАЛЕНИЕ КОНКРЕТНОГО УЧАСТНИКА (ФОРК)
                if (isCreator)
                  IconButton(
                    onPressed: () => _confirmSingleMemberRemoval(
                      g.id,
                      p,
                    ), // Теперь вызываем диалог
                    icon: const Icon(
                      Icons.person_remove_rounded,
                      color: Colors.redAccent,
                      size: 18,
                    ),
                    tooltip: "Удалить из группы",
                  ),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }

Future<void> _fullRefresh() async {
  if (!mounted) return;
  // Загружаем задачи и обновляем данные о целях
  await context.read<TaskProvider>().loadTasks(widget.goal.id);
  final myId = context.read<AuthProvider>().user?.id;
  if (myId != null) {
    await context.read<GoalProvider>().loadGoals(myId);
  }
}

  // ---------------------------------------------------------------------------
  // --- ВКЛАДКА БАЗЫ ЗНАНИЙ (МАТЕРИАЛЫ) ---
  // ---------------------------------------------------------------------------

Widget _buildMaterialsTab(GoalResponse g, bool isCreator) {
    final myId = context.read<AuthProvider>().user?.id;
    bool canAdd = isCreator || g.collaborators.any((c) => c.id == myId && c.isConfirmed);

    return Column(
      children: [
        if (canAdd)
          Padding(
            padding: const EdgeInsets.all(24),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.navy,
                minimumSize: const Size(double.infinity, 55),
              ),
              icon: const Icon(Icons.add_link_rounded, color: Colors.white),
              label: const Text("ДОБАВИТЬ НОВЫЕ ЗНАНИЯ", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              onPressed: () => _showAddMaterialModal(g.id),
            ),
          ),
        Expanded(
          child: g.materials.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.folder_open_rounded, size: 60, color: Color(0xFFE0E0E0)),
                      SizedBox(height: 15),
                      Text("Материалов в этом пути пока нет", style: TextStyle(color: Colors.grey, fontSize: 15, fontWeight: FontWeight.w500)),
                      SizedBox(height: 8),
                      Text("Добавьте ссылки или файлы для обучения", style: TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  itemCount: g.materials.length,
                  itemBuilder: (ctx, i) {
                    final m = g.materials[i];
                    bool canManageMaterial = m.creatorId == myId || isCreator;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha:0.04), blurRadius: 12, offset: const Offset(0, 4)),
                        ],
                        border: Border.all(
                          color: m.type == "File" ? Colors.green.withValues(alpha:0.2) : Colors.blue.withValues(alpha:0.2),
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Заголовок и тип
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: m.type == "File" ? Colors.green.withValues(alpha:0.1) : Colors.blue.withValues(alpha:0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(
                                        m.type == "File" ? Icons.insert_drive_file_rounded : Icons.link_rounded,
                                        color: m.type == "File" ? Colors.green : Colors.blue,
                                        size: 22,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(m.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.navy), maxLines: 2, overflow: TextOverflow.ellipsis),
                                          const SizedBox(height: 4),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: m.type == "File" ? Colors.green.withValues(alpha:0.1) : Colors.blue.withValues(alpha:0.1),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              m.type == "File" ? "ФАЙЛ" : "ССЫЛКА",
                                              style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: m.type == "File" ? Colors.green : Colors.blue, letterSpacing: 1),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                
                                const SizedBox(height: 15),
                                
                                // *** ПРИВЯЗКА К ШАГУ - ИСПОЛЬЗУЕМ taskTitle ИЗ МОДЕЛИ ***
                                if (m.taskTitle != null && m.taskTitle!.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.withValues(alpha:0.05),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.orange.withValues(alpha:0.15)),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.flag_rounded, color: Colors.orange, size: 16),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Text("ПРИВЯЗАН К ЭТАПУ:", style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 0.5)),
                                              const SizedBox(height: 2),
                                              Text(
                                                m.taskTitle!,
                                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.orange),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                
                                const SizedBox(height: 12),
                                
                                // Автор и дата
                                Row(
                                  children: [
                                    _userAvatar(m.creatorAvatarUrl, m.creatorName, radius: 12),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text("Загрузил: ${m.creatorName}", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.navy)),
                                          Text(DateFormat('dd.MM.yyyy HH:mm', 'ru').format(m.createdAt), style: const TextStyle(fontSize: 9, color: Colors.grey)),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: () {
                                        if (m.type == "File") {
                                          final downloadUrl = 'http://localhost:5254${m.content}';
                                          launchUrl(Uri.parse(downloadUrl), mode: LaunchMode.externalApplication);
                                        } else {
                                          launchUrl(Uri.parse(m.content), mode: LaunchMode.externalApplication);
                                        }
                                      },
                                      icon: Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(color: AppColors.primary.withValues(alpha:0.1), borderRadius: BorderRadius.circular(10)),
                                        child: const Icon(Icons.open_in_new_rounded, color: AppColors.primary, size: 18),
                                      ),
                                      tooltip: m.type == "File" ? "Скачать файл" : "Открыть ссылку",
                                    ),
                                    if (canManageMaterial)
                                      IconButton(
                                        onPressed: () => _confirmDeleteMaterial(g.id, m),
                                        icon: Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(color: Colors.red.withValues(alpha:0.1), borderRadius: BorderRadius.circular(10)),
                                          child: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 18),
                                        ),
                                        tooltip: "Удалить материал",
                                      ),

                                      if (canManageMaterial)
                                      IconButton(
                                        onPressed: () => _showEditMaterialModal(g.id, m), // Вызываем модалку редактирования
                                        icon: Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(color: AppColors.navy.withValues(alpha:0.1), borderRadius: BorderRadius.circular(10)),
                                          child: const Icon(Icons.edit_rounded, color: AppColors.navy, size: 18),
                                        ),
                                        tooltip: "Редактировать",
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // Диалог подтверждения удаления материала
  void _confirmDeleteMaterial(int goalId, MaterialDto material) {
    _showHiveModal(
      Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.delete_forever_rounded,
              color: Colors.redAccent,
              size: 50,
            ),
            const SizedBox(height: 20),
            const Text(
              "УДАЛИТЬ МАТЕРИАЛ?",
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 18,
                color: AppColors.navy,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              "'${material.title}' будет удален безвозвратно",
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 30),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      "ОТМЕНА",
                      style: TextStyle(
                        color: Colors.grey,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
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
                      context
                          .read<GoalProvider>()
                          .deleteMaterial(goalId, material.id);
                      Navigator.pop(context);
                    },
                    child: const Text(
                      "УДАЛИТЬ",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
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

  // ---------------------------------------------------------------------------
  // --- ГРАФИК ПРОДУКТИВНОСТИ ---
  // ---------------------------------------------------------------------------

 Widget _buildProductivityChart(List<TaskResponse> goalTasks, String myName) {
    if (goalTasks.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text("ДИНАМИКА ВЫПОЛНЕНИЯ", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: Colors.grey)),
          SizedBox(height: 20),
          Center(child: Text("Добавьте задачи", style: TextStyle(color: Colors.grey, fontSize: 12))),
        ],
      );
    }

    int totalTasks = goalTasks.length;
    final sortedTasks = List<TaskResponse>.from(goalTasks)..sort((a, b) => a.dueDate.compareTo(b.dueDate));
    
    List<FlSpot> spots = [const FlSpot(0, 0)];
    double currentSum = 0;
    for (int i = 0; i < sortedTasks.length; i++) {
      if (sortedTasks[i].completions.any((c) => c.username == myName)) {
        currentSum++;
      }
      spots.add(FlSpot((i + 1).toDouble(), currentSum));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "ДИНАМИКА ВЫПОЛНЕНИЯ",
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: Colors.grey, letterSpacing: 1.2),
        ),
        const SizedBox(height: 25),
        SizedBox(
          height: 200,
          child: LineChart(
            LineChartData(
              gridData: FlGridData(
                show: true,
                drawVerticalLine: true,
                horizontalInterval: totalTasks > 5 ? (totalTasks / 5) : 1,
                getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey.withValues(alpha:0.1), strokeWidth: 1),
                getDrawingVerticalLine: (value) => FlLine(color: Colors.grey.withValues(alpha:0.1), strokeWidth: 1),
              ),
              titlesData: FlTitlesData(
                show: true,
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30,
                    getTitlesWidget: (value, meta) => Text(value.toInt().toString(), style: const TextStyle(color: Colors.grey, fontSize: 10)),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30,
                    getTitlesWidget: (value, meta) {
                      if (value == 0) return const Text('0', style: TextStyle(color: Colors.grey, fontSize: 10));
                      if (value == totalTasks) return const Text('Цель', style: TextStyle(color: Colors.grey, fontSize: 10));
                      return Text(value.toInt().toString(), style: const TextStyle(color: Colors.grey, fontSize: 10));
                    },
                  ),
                ),
              ),
              borderData: FlBorderData(show: false),
              minX: 0,
              maxX: totalTasks.toDouble(),
              minY: 0,
              maxY: totalTasks.toDouble(),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  curveSmoothness: 0.35,
                  gradient: const LinearGradient(colors: [AppColors.primary, Color(0xFF00BCD4)]),
                  barWidth: 4,
                  dotData: FlDotData(
                    show: true,
                    getDotPainter: (spot, percent, barData, index) {
                      if (index == spots.length - 1 || index == 0) {
                        return FlDotCirclePainter(radius: 4, color: Colors.white, strokeWidth: 2, strokeColor: AppColors.primary);
                      }
                      return FlDotCirclePainter(radius: 0);
                    },
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      colors: [AppColors.primary.withValues(alpha:0.2), AppColors.primary.withValues(alpha:0)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // --- APPBAR И КНОПКИ УПРАВЛЕНИЯ ---
  // ---------------------------------------------------------------------------

  PreferredSizeWidget _buildAppBar(GoalResponse g, bool isCreator, bool isWide) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0.5,
      // В Вебе (isWide) скрываем кнопку Назад, на Мобильных оставляем
      leading: isWide 
        ? const SizedBox.shrink() 
        : IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.navy, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            g.title,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: AppColors.navy),
          ),
          Text(
            g.isSolo ? "Личное обучение" : "Командная работа",
            style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold),
          ),
        ],
      ),
      actions: [
        if (isCreator && !g.isSolo)
          IconButton(
            onPressed: () => _showInvitePartnerModal(g),
            icon: const Icon(Icons.person_add_alt_1_rounded, color: AppColors.primary),
          ),
        IconButton(
          onPressed: () => _showGoalSettingsModal(g, isCreator),
          icon: const Icon(Icons.settings_suggest_rounded, color: AppColors.navy),
        ),
        const SizedBox(width: 15),
      ],
      bottom: TabBar(
        controller: _tabController,
        indicatorColor: AppColors.primary,
        tabs: const [
          Tab(text: "ДАШБОРД"),
          Tab(text: "МАТЕРИАЛЫ"),
        ],
      ),
    );
  }
  // ---------------------------------------------------------------------------
  // --- МОДАЛЬНЫЕ ОКНА И ДИАЛОГИ ПОДТВЕРЖДЕНИЯ ---
  // ---------------------------------------------------------------------------

void _showGoalSettingsModal(GoalResponse goal, bool isCreator) {
    MainDashboardLayout.showHiveDialog(
      context,
      Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isCreator ? "Управление маршрутом" : "Настройки участия",
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 19, color: AppColors.navy),
            ),
            const SizedBox(height: 35),
            if (isCreator) ...[
              Row(
                children: [
                  _modeIconButton(
                    icon: Icons.person_outline_rounded,
                    label: "ЛИЧНЫЙ",
                    isSelected: goal.isSolo,
                    color: Colors.blueAccent,
                    onTap: () {
                      if (goal.isSolo) return;
                      Navigator.pop(context);
                      _confirmTotalModeChangeToSolo(goal.id);
                    },
                  ),
                  const SizedBox(width: 20),
                  _modeIconButton(
                    icon: Icons.groups_rounded,
                    label: "ГРУППОВОЙ",
                    isSelected: !goal.isSolo,
                    color: Colors.orangeAccent,
                    onTap: () async {
                      if (!goal.isSolo) return;
                      await context.read<GoalProvider>().updateGoalMode(goal.id, false);
                      if (mounted) {
                        Navigator.pop(context);
                        _fullRefresh();
                      }
                    },
                  ),
                ],
              ),
              const Divider(height: 60),
              ListTile(
                leading: const Icon(Icons.delete_forever_rounded, color: Colors.redAccent),
                title: const Text("Удалить маршрут", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                onTap: () async {
                  Navigator.pop(context);
                  _confirmDeleteGoal(goal);
                },
              ),
            ] else ...[
              ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                tileColor: Colors.orange.withValues(alpha:0.05),
                leading: const Icon(Icons.exit_to_app_rounded, color: Colors.orange),
                title: const Text("Покинуть маршрут", style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
                onTap: () async {
                  Navigator.pop(context);
                  _confirmLeaveGoal(goal.id);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }


  void _confirmDeleteGoal(GoalResponse goal) {
    MainDashboardLayout.showHiveDialog(
      context,
      Padding(
        padding: const EdgeInsets.all(35),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.delete_forever_rounded, color: Colors.redAccent, size: 60),
            const SizedBox(height: 20),
            const Text("УДАЛИТЬ ВЕСЬ ПУТЬ?", 
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: AppColors.navy)),
            const SizedBox(height: 15),
            Text("Маршрут '${goal.title}' и все связанные с ним материалы и задачи будут удалены навсегда.",
              textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey, height: 1.4)),
            const SizedBox(height: 35),
            Row(
              children: [
                Expanded(child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("ОТМЕНА"),
                )),
                const SizedBox(width: 15),
                Expanded(child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                  onPressed: () async {
                    await context.read<GoalProvider>().removeGoal(goal.id, goal.userId);
                    if (mounted) {
                      Navigator.pop(context); // Закрыть диалог
                      Navigator.pop(context); // Вернуться на экран списка целей
                    }
                  },
                  child: const Text("УДАЛИТЬ", style: TextStyle(color: Colors.white)),
                )),
              ],
            )
          ],
        ),
      ),
    );
  }

  void _confirmLeaveGoal(int goalId) {
    MainDashboardLayout.showHiveDialog(
      context,
      Padding(
        padding: const EdgeInsets.all(35),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.exit_to_app_rounded, color: Colors.orange, size: 60),
            const SizedBox(height: 20),
            const Text("ПОКИНУТЬ ГРУППУ?", 
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: AppColors.navy)),
            const SizedBox(height: 15),
            const Text("Вы больше не сможете участвовать в обсуждении и видеть общий прогресс. Ваша личная копия маршрута не будет создана.",
              textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, height: 1.4)),
            const SizedBox(height: 35),
            Row(
              children: [
                Expanded(child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("ОТМЕНА"),
                )),
                const SizedBox(width: 15),
                Expanded(child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                  onPressed: () async {
                    bool ok = await context.read<GoalProvider>().leaveGoal(goalId);
                    if (ok && mounted) {
                      Navigator.pop(context);
                      Navigator.pop(context);
                    }
                  },
                  child: const Text("ВЫЙТИ", style: TextStyle(color: Colors.white)),
                )),
              ],
            )
          ],
        ),
      ),
    );
  }




  Widget _modeIconButton({
    required IconData icon,
    required String label,
    required bool isSelected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(vertical: 25),
          decoration: BoxDecoration(
            color: isSelected ? color : Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: color.withValues(alpha:isSelected ? 1 : 0.2),
              width: 2,
            ),
            boxShadow: [
              if (isSelected)
                BoxShadow(
                  color: color.withValues(alpha:0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
            ],
          ),
          child: Column(
            children: [
              Icon(icon, color: isSelected ? Colors.white : color, size: 35),
              const SizedBox(height: 12),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 11,
                  color: isSelected ? Colors.white : color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

   void _confirmTotalModeChangeToSolo(int id) {
    MainDashboardLayout.showHiveDialog(
      context,
      Padding(
        padding: const EdgeInsets.all(35),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.warning_amber_rounded, size: 50, color: Colors.orange),
            const SizedBox(height: 20),
            const Text("СДЕЛАТЬ ПУТЬ ЛИЧНЫМ?", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
            const SizedBox(height: 15),
            const Text(
              "Групповая работа будет прекращена. Все участники получат личную копию, а ваша цель станет приватной. Продолжить?",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey, height: 1.4),
            ),
            const SizedBox(height: 35),
            Row(
              children: [
                Expanded(child: TextButton(onPressed: () => Navigator.pop(context), child: const Text("ОТМЕНА"))),
                const SizedBox(width: 15),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                    onPressed: () async {
                      await context.read<GoalProvider>().makeGoalPersonal(id);
                      if (mounted) Navigator.pop(context);
                    },
                    child: const Text("ДА, РАЗДЕЛИТЬ", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }


void _confirmSingleMemberRemoval(int goalId, GoalPartnerDto p) {
  // Если участник не подтвержден - показываем другое сообщение
  String message = p.isConfirmed 
    ? "У пользователя останется его личная копия этого маршрута со всеми текущими материалами и его галочками, но он больше не будет частью вашей группы. Продолжить?"
    : "Пользователь еще не принял приглашение. Он будет просто удален из списка приглашенных без создания копии цели. Продолжить?";

  _showHiveModal(
    Padding(
      padding: const EdgeInsets.all(35),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            p.isConfirmed ? Icons.person_remove_rounded : Icons.person_off_rounded,
            size: 50,
            color: Colors.redAccent,
          ),
          const SizedBox(height: 20),
          Text(
            "УДАЛИТЬ ${p.name.toUpperCase()}?",
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
          ),
          const SizedBox(height: 15),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade600,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 35),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    "ОТМЕНА",
                    style: TextStyle(color: Colors.grey),
                  ),
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
                  onPressed: () async {
                    final ok = await context
                        .read<GoalProvider>()
                        .removeMember(goalId, p.id);
                    if (!mounted) return;
                    Navigator.pop(context);
                    if (ok) _fullRefresh();
                  },
                  child: const Text(
                    "ДА, УДАЛИТЬ",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
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
  // ---------------------------------------------------------------------------
  // --- ДИАЛОГИ СОЗДАНИЯ / РЕДАКТИРОВАНИЯ ЭЛЕМЕНТОВ ---
  // ---------------------------------------------------------------------------

void _showAddTaskModal(int gid) {
    final titleCtrl = TextEditingController();
    DateTime date = DateTime.now().add(const Duration(days: 1));

    MainDashboardLayout.showHiveDialog(
      context,
      StatefulBuilder(
        builder: (ctx, setSt) => Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.add_task_rounded, size: 48, color: AppColors.primary),
              const SizedBox(height: 20),
              const Text(
                "НОВЫЙ ЭТАП ПУТИ",
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: AppColors.navy),
              ),
              const SizedBox(height: 25),
              
              // Поле ввода с автоматическим переносом текста
              TextField(
                controller: titleCtrl,
                maxLines: null, // Позволяет тексту переноситься на новую строку
                minLines: 1,    // Начальная высота в одну строку
                keyboardType: TextInputType.multiline,
                style: const TextStyle(fontSize: 15),
                decoration: AppDecorations.smartInput(
                  "Что необходимо выполнить?", 
                  Icons.edit_note_rounded
                ),
              ),
              
              const SizedBox(height: 20),
              
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: ListTile(
                  onTap: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: date,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 730)),
                    );
                    if (d != null) setSt(() => date = d);
                  },
                  leading: const Icon(Icons.calendar_today_rounded, color: AppColors.primary, size: 20),
                  title: Text(
                    DateFormat('dd MMMM yyyy', 'ru').format(date),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  subtitle: const Text("Срок выполнения", style: TextStyle(fontSize: 10)),
                  trailing: const Icon(Icons.edit_calendar_rounded, size: 18),
                ),
              ),
              
              const SizedBox(height: 35),
              
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () {
                    if (titleCtrl.text.trim().isNotEmpty) {
                      context.read<TaskProvider>().createTask(
                        gid,
                        titleCtrl.text.trim(),
                        date,
                      );
                      Navigator.pop(context);
                    }
                  },
                  child: const Text(
                    "ДОБАВИТЬ В МАРШРУТ",
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

void _showEditTaskModal(TaskResponse t) {
    final tc = TextEditingController(text: t.title);
    DateTime d = t.dueDate;
    
    // Сегодняшнее число без времени для точного сравнения дат
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    MainDashboardLayout.showHiveDialog(
      context,
      StatefulBuilder(
        builder: (ctx, st) => Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "РЕДАКТИРОВАНИЕ ШАГА",
                style: GoogleFonts.manrope(
                  fontWeight: FontWeight.w900, 
                  fontSize: 18, 
                  color: AppColors.navy
                ),
              ),
              const SizedBox(height: 25),
              
              // Поле ввода текста
              TextField(
                controller: tc,
                maxLines: null,
                minLines: 1,
                keyboardType: TextInputType.multiline,
                style: const TextStyle(fontSize: 15),
                decoration: AppDecorations.smartInput(
                  "Что нужно сделать?",
                  Icons.edit_calendar_rounded,
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Поле выбора даты
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: ListTile(
                  onTap: () async {
                    final sel = await showDatePicker(
                      context: context,
                      // Если текущая дата задачи уже в прошлом, позволяем календарю открыться на ней
                      initialDate: d,
                      // Позволяем выбрать дату в диапазоне +/- 2 года
                      firstDate: DateTime.now().subtract(const Duration(days: 365 * 2)),
                      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
                      locale: const Locale('ru'),
                    );
                    if (sel != null) st(() => d = sel);
                  },
                  leading: const Icon(Icons.calendar_month, color: AppColors.primary),
                  title: Text(
                    DateFormat('dd MMMM yyyy', 'ru').format(d),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text("Нажмите, чтобы изменить дату", style: TextStyle(fontSize: 10)),
                ),
              ),
              
              const SizedBox(height: 35),
              
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.navy,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                  onPressed: () async {
                    if (tc.text.trim().isNotEmpty) {
                      
                      // ИСПРАВЛЕННАЯ ЛОГИКА ВАЛИДАЦИИ:
                      // Сравниваем только год, месяц и день
                      bool isDateChanged = d.year != t.dueDate.year || 
                                         d.month != t.dueDate.month || 
                                         d.day != t.dueDate.day;

                      // Если дату ИЗМЕНИЛИ и новая дата раньше сегодняшнего дня — ругаемся
                      if (isDateChanged && d.isBefore(today)) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Нельзя перенести задачу на прошедшее время"),
                            backgroundColor: Colors.redAccent,
                          ),
                        );
                        return;
                      }

                      // Если дату не меняли ИЛИ дата корректная — сохраняем
                      await context.read<TaskProvider>().updateTask(
                        taskId: t.id,
                        goalId: t.goalId,
                        newTitle: tc.text.trim(),
                        newDate: d,
                        goalProv: context.read<GoalProvider>(),
                      );
                      
                      if (mounted) Navigator.pop(context);
                    }
                  },
                  child: const Text(
                    "СОХРАНИТЬ ИЗМЕНЕНИЯ",
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

void _confirmDeleteTask(TaskResponse t) {
  MainDashboardLayout.showHiveDialog(
    context,
    Padding(
      padding: const EdgeInsets.all(35),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.delete_sweep_rounded, color: Colors.redAccent, size: 50),
          const SizedBox(height: 20),
          const Text("УДАЛИТЬ ЭТОТ ШАГ?", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: AppColors.navy)),
          const SizedBox(height: 10),
          Text("'${t.title}' будет удален из вашего маршрута.", textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 35),
          Row(
            children: [
              Expanded(child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("ОТМЕНА"),
              )),
              const SizedBox(width: 15),
              Expanded(child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                onPressed: () {
                  context.read<TaskProvider>().deleteTask(t.id, t.goalId, context.read<GoalProvider>());
                  Navigator.pop(context);
                },
                child: const Text("УДАЛИТЬ", style: TextStyle(color: Colors.white)),
              )),
            ],
          ),
        ],
      ),
    ),
  );
}

void _showAddMaterialModal(int goalId) {
    final tCtrl = TextEditingController();
    final lCtrl = TextEditingController();
    int? selectedTaskId;
    bool isFileMode = false;
    PlatformFile? selectedFile;
    bool isUploading = false;

    MainDashboardLayout.showHiveDialog(
      context,
      StatefulBuilder(
        builder: (ctx, setSt) => Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("НОВЫЙ МАТЕРИАЛ", 
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: AppColors.navy)),
              const SizedBox(height: 25),
              
              // Переключатель Ссылка/Файл
              Row(
                children: [
                  Expanded(child: _modeToggleButton(
                    label: "ССЫЛКА", icon: Icons.link_rounded, active: !isFileMode, color: Colors.blue,
                    onTap: () => setSt(() => isFileMode = false),
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: _modeToggleButton(
                    label: "ФАЙЛ", icon: Icons.upload_file_rounded, active: isFileMode, color: Colors.green,
                    onTap: () => setSt(() => isFileMode = true),
                  )),
                ],
              ),
              const SizedBox(height: 25),

              TextField(
                controller: tCtrl, 
                decoration: AppDecorations.smartInput("Заголовок (напр. Конспект)", Icons.title_rounded)
              ),
              const SizedBox(height: 15),

              if (!isFileMode)
                TextField(
                  controller: lCtrl, 
                  decoration: AppDecorations.smartInput("URL-адрес (http/https)", Icons.link_rounded),
                  keyboardType: TextInputType.url,
                )
              else
                _buildFilePickerArea(selectedFile, (file) => setSt(() => selectedFile = file)),

              const SizedBox(height: 20),

              DropdownButtonFormField<int>(
                isExpanded: true,
                decoration: AppDecorations.smartInput("Привязать к этапу", Icons.flag_rounded),
                items: [
                  const DropdownMenuItem<int>(value: null, child: Text("Без привязки к этапу")),
                  ...context.read<TaskProvider>().tasks.map((t) => DropdownMenuItem(
                    value: t.id, 
                    child: Text(t.title, overflow: TextOverflow.ellipsis)
                  )).toList(),
                ],
                onChanged: (v) => selectedTaskId = v,
              ),

              const SizedBox(height: 35),
              
              SizedBox(
                width: double.infinity, height: 60,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.navy),
                  onPressed: isUploading ? null : () async {
                    if (tCtrl.text.isEmpty) return;
                    
                    // ВАЛИДАЦИЯ ССЫЛКИ
                    if (!isFileMode) {
                      String url = lCtrl.text.trim();
                      if (!url.startsWith('http://') && !url.startsWith('https://')) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text("Ссылка должна начинаться с http:// или https://"),
                          backgroundColor: Colors.redAccent,
                        ));
                        return;
                      }
                    } else if (selectedFile == null) {
                      return;
                    }

                    setSt(() => isUploading = true);
                    bool ok = await context.read<GoalProvider>().addMaterialWithTask(
                      goalId, tCtrl.text.trim(), isFileMode ? (selectedFile?.name ?? "") : lCtrl.text.trim(), 
                      isFileMode ? "File" : "Link", selectedTaskId, file: selectedFile
                    );
                    
                    if (ok && mounted) Navigator.pop(context);
                    else setSt(() => isUploading = false);
                  },
                  child: isUploading 
                    ? const CircularProgressIndicator(color: Colors.white) 
                    : const Text("ДОБАВИТЬ В ПУТЬ", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }


 void _showEditMaterialModal(int goalId, MaterialDto material) {
    final tCtrl = TextEditingController(text: material.title);
    final lCtrl = TextEditingController(text: material.type == "Link" ? material.content : "");
    int? selectedTaskId = material.taskId;
    bool isFileMode = material.type == "File";
    PlatformFile? newFile;
    bool isProcessing = false;

    MainDashboardLayout.showHiveDialog(
      context,
      StatefulBuilder(
        builder: (ctx, setSt) => Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("РЕДАКТИРОВАНИЕ", 
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: AppColors.navy)),
                  IconButton(
                    onPressed: () { Navigator.pop(context); _confirmDeleteMaterial(goalId, material); },
                    icon: const Icon(Icons.delete_sweep_rounded, color: Colors.redAccent),
                  ),
                ],
              ),
              const SizedBox(height: 25),

              TextField(
                controller: tCtrl, 
                decoration: AppDecorations.smartInput("Заголовок материала", Icons.title_rounded)
              ),
              const SizedBox(height: 15),

              if (!isFileMode)
                TextField(
                  controller: lCtrl, 
                  decoration: AppDecorations.smartInput("URL-адрес (http/https)", Icons.link_rounded),
                )
              else
                _buildFilePickerArea(newFile, (file) => setSt(() => newFile = file)),

              const SizedBox(height: 20),

              DropdownButtonFormField<int>(
                value: selectedTaskId,
                isExpanded: true,
                decoration: AppDecorations.smartInput("Сменить привязку к этапу", Icons.flag_rounded),
                items: [
                  const DropdownMenuItem<int>(value: null, child: Text("Без привязки к этапу")),
                  ...context.read<TaskProvider>().tasks.map((t) => DropdownMenuItem(
                    value: t.id, 
                    child: Text(t.title, overflow: TextOverflow.ellipsis)
                  )).toList(),
                ],
                onChanged: (v) => selectedTaskId = v,
              ),

              const SizedBox(height: 35),

              SizedBox(
                width: double.infinity, height: 60,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.navy),
                  onPressed: isProcessing ? null : () async {
                    if (tCtrl.text.isEmpty) return;

                    // ВАЛИДАЦИЯ ПРИ ИЗМЕНЕНИИ
                    if (!isFileMode) {
                      String url = lCtrl.text.trim();
                      if (!url.startsWith('http://') && !url.startsWith('https://')) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text("Введите корректную ссылку (http/https)"),
                          backgroundColor: Colors.redAccent,
                        ));
                        return;
                      }
                    }

                    setSt(() => isProcessing = true);
                    // Удаляем старый и добавляем новый (логика обновления через перезапись)
                    await context.read<GoalProvider>().deleteMaterial(goalId, material.id);
                    
                    bool ok = await context.read<GoalProvider>().addMaterialWithTask(
                      goalId, 
                      tCtrl.text.trim(), 
                      isFileMode ? (newFile?.name ?? material.content) : lCtrl.text.trim(), 
                      material.type, 
                      selectedTaskId,
                      file: newFile
                    );
                    
                    if (mounted) Navigator.pop(context);
                  },
                  child: isProcessing 
                    ? const CircularProgressIndicator(color: Colors.white) 
                    : const Text("СОХРАНИТЬ ИЗМЕНЕНИЯ", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }


   Widget _buildFilePickerArea(PlatformFile? selectedFile, Function(PlatformFile?) onFilePicked) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5),
      child: selectedFile == null
          ? OutlinedButton.icon(
              onPressed: () async {
                final result = await FilePicker.platform.pickFiles(withData: true);
                if (result != null && result.files.isNotEmpty) {
                  onFilePicked(result.files.first);
                }
              },
              icon: const Icon(Icons.upload_file),
              label: const Text("Выбрать файл"),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 55),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              ),
            )
          : Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha:0.05),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.green.withValues(alpha:0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.insert_drive_file, color: Colors.green),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(selectedFile.name, 
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13), 
                          overflow: TextOverflow.ellipsis),
                        Text("${(selectedFile.size / 1024).toStringAsFixed(1)} KB", 
                          style: const TextStyle(fontSize: 11, color: Colors.grey)),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => onFilePicked(null),
                    icon: const Icon(Icons.close, color: Colors.red),
                  ),
                ],
              ),
            ),
    );
  }


  Widget _modeToggleButton({
    required String label,
    required IconData icon,
    required bool active,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          color: active ? color.withValues(alpha:0.1) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: active ? color : Colors.grey.shade300,
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: active ? color : Colors.grey, size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 11,
                color: active ? color : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }



void _showInvitePartnerModal(GoalResponse initialGoal) {
    // Принудительно подгружаем список друзей перед открытием
    context.read<UserProvider>().loadFriends();
    
    MainDashboardLayout.showHiveDialog(
      context,
      Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("ПРИГЛАСИТЬ ПАРТНЕРА", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: AppColors.navy)),
            const SizedBox(height: 20),
            const Text("Выберите друга из списка ниже, чтобы пригласить его в совместный маршрут обучения.", 
              textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 20),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 350),
              child: Consumer2<UserProvider, GoalProvider>( // Используем Consumer2 для реактивности обоих провайдеров
                builder: (ctx, uProv, gProv, _) {
                  // Ищем актуальное состояние цели в общем списке провайдера
                  final currentGoal = gProv.goals.firstWhere((g) => g.id == initialGoal.id, orElse: () => initialGoal);
                  
                  if (uProv.friends.isEmpty) return const Center(child: Text("У вас пока нет друзей"));
                  
                  return ListView.builder(
                    shrinkWrap: true,
                    itemCount: uProv.friends.length,
                    itemBuilder: (c, i) {
                      final f = uProv.friends[i];
                      
                      // ПРОВЕРКА: пользователь уже в команде (по ID или по имени без учета регистра)
                      bool alreadyIn = currentGoal.collaborators.any((member) => 
                        member.id == f.id || member.name.toLowerCase().trim() == f.username.toLowerCase().trim()
                      );

                      return ListTile(
                        leading: _userAvatar(f.avatarUrl, f.username, radius: 18),
                        title: Text(f.username, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        trailing: alreadyIn 
                          ? Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(10)),
                              child: const Text("В КОМАНДЕ", style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
                            )
                          : ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                              onPressed: () {
                                context.read<GoalProvider>().invitePartner(initialGoal.id, f.id, initialGoal.userId);
                                Navigator.pop(context);
                              },
                              child: const Text("ПОЗВАТЬ", style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                            ),
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("ЗАКРЫТЬ")),
          ],
        ),
      ),
    );
  }
}