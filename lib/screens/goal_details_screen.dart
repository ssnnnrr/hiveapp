import 'dart:convert';
import 'package:flutter/material.dart';
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

class _GoalDetailsScreenState extends State<GoalDetailsScreen> with SingleTickerProviderStateMixin {
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
    int done = tasks.where((t) => t.completions.any((c) => c.username == username)).length;
    return (done / tasks.length) * 100;
  }

  /// Собирает карту метрик для дашборда
  Map<String, double> _getMetrics(List<TaskResponse> tasks, String myName, GoalResponse goal) {
    if (tasks.isEmpty) return {"eff": 0, "sync": 0, "vel": 100};

    // Личная эффективность (процент выполнения моих задач)
    double efficiency = _calcUserProgress(tasks, myName);
    
    // Командная синхронизация (среднее арифметическое всех подтвержденных участников)
    double teamSync = efficiency; 
    if (!goal.isSolo) {
      double totalSum = efficiency;
      var activePartners = goal.collaborators.where((c) => c.isConfirmed).toList();
      if (activePartners.isNotEmpty) {
        for (var p in activePartners) {
          totalSum += _calcUserProgress(tasks, p.name);
        }
        teamSync = totalSum / (activePartners.length + 1);
      }
    }

    // Скорость прохождения (отношение выполненных в срок задач к общему числу просроченных)
    final now = DateTime.now();
    final pastTasks = tasks.where((t) => t.dueDate.isBefore(now)).toList();
    double velocity = 100.0;
    if (pastTasks.isNotEmpty) {
      int onTimeCount = pastTasks.where((t) => t.completions.any((c) => c.username == myName)).length;
      velocity = (onTimeCount / pastTasks.length) * 100;
    }

    return {"eff": efficiency, "sync": teamSync, "vel": velocity};
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
                  BoxShadow(color: Colors.black26, blurRadius: 25, offset: const Offset(0, 10))
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
      backgroundColor: AppColors.navy.withOpacity(0.1),
      backgroundImage: (url != null && url.isNotEmpty) ? MemoryImage(base64Decode(url)) : null,
      child: (url == null || url.isEmpty)
          ? Text(name.isNotEmpty ? name[0].toUpperCase() : "?", 
              style: TextStyle(fontSize: radius * 0.8, fontWeight: FontWeight.bold, color: AppColors.navy)) 
          : null,
    );
  }

  // ---------------------------------------------------------------------------
  // --- ГЛАВНЫЙ ЭКРАН BUILD ---
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final goalProv = context.watch<GoalProvider>();
    final taskProv = context.watch<TaskProvider>();
    final authProv = context.read<AuthProvider>();

    // Поиск актуального объекта цели в кеше провайдера
    final goal = goalProv.goals.firstWhere((g) => g.id == widget.goal.id, orElse: () => widget.goal);
    
    final myUser = authProv.user;
    final myName = myUser?.username ?? "";
    bool isCreator = goal.userId == myUser?.id;

    final metrics = _getMetrics(taskProv.tasks, myName, goal);
    final double myLiveProg = taskProv.getProgress(myName);

    double screenWidth = MediaQuery.of(context).size.width;
    bool isWide = screenWidth > 1150;

    return MainDashboardLayout(
      selectedIndex: 1,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: _buildAppBar(goal, isCreator),
        body: TabBarView(
          controller: _tabController,
          children: [
            // ВКЛАДКА 1: ДАШБОРД
            RefreshIndicator(
              onRefresh: () => taskProv.loadTasks(goal.id),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(26),
                child: isWide 
                  ? _buildWideDashboard(goal, taskProv, myName, myUser, isCreator, metrics, myLiveProg)
                  : _buildMobileDashboard(goal, taskProv, myName, myUser, isCreator, metrics, myLiveProg),
              ),
            ),
            // ВКЛАДКА 2: МАТЕРИАЛЫ
            _buildMaterialsTab(goal, isCreator),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // --- РАЗДЕЛ ДАШБОРДА (МАКЕТЫ) ---
  // ---------------------------------------------------------------------------

  /// Макет для больших экранов (Desktop / Web)
  Widget _buildWideDashboard(GoalResponse g, TaskProvider prov, String name, UserDto? u, bool creator, Map<String, double> m, double prog) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Левая колонка: Круговой прогресс и Метрики
        Expanded(
          flex: 2,
          child: Column(
            children: [
              _dashCard(_buildMainProgressCircle(prog)),
              const SizedBox(height: 24),
              _dashCard(_buildMetricsList(m, g.isSolo)),
            ],
          ),
        ),
        const SizedBox(width: 24),
        // Центральная колонка: Основной список этапов
        Expanded(
          flex: 4,
          child: _dashCard(_buildTaskListSection(g, prov, name, u, creator)),
        ),
        const SizedBox(width: 24),
        // Правая колонка: Состав команды и График динамики
        Expanded(
          flex: 2,
          child: Column(
            children: [
              if (!g.isSolo) ...[
                _dashCard(_buildTeamManagementSection(g, prov.tasks, creator, u?.id)),
                const SizedBox(height: 24),
              ],
              _dashCard(_buildProductivityChart(prov, name)),
            ],
          ),
        ),
      ],
    );
  }

  /// Макет для мобильных устройств (одна колонка)
  Widget _buildMobileDashboard(GoalResponse g, TaskProvider prov, String name, UserDto? u, bool creator, Map<String, double> m, double prog) {
    return Column(
      children: [
        _dashCard(_buildMainProgressCircle(prog)),
        const SizedBox(height: 24),
        _dashCard(_buildMetricsList(m, g.isSolo)),
        const SizedBox(height: 32),
        _buildTaskListSection(g, prov, name, u, creator),
        const SizedBox(height: 32),
        if (!g.isSolo) ...[
          _dashCard(_buildTeamManagementSection(g, prov.tasks, creator, u?.id)),
          const SizedBox(height: 32),
        ],
        _dashCard(_buildProductivityChart(prov, name)),
        const SizedBox(height: 120), // Отступ для FAB
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // --- КОМПОНЕНТЫ ИНТЕРФЕЙСА (CARDS) ---
  // ---------------------------------------------------------------------------

  Widget _dashCard(Widget child) => Container(
    width: double.infinity, padding: const EdgeInsets.all(24),
    decoration: AppDecorations.glassCard, child: child,
  );

  /// Большой круглый индикатор личного прогресса
  Widget _buildMainProgressCircle(double prog) {
    return Column(
      children: [
        const Text("ВАШ ПРОГРЕСС", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: Colors.grey, letterSpacing: 1.2)),
        const SizedBox(height: 30),
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              height: 150, width: 150,
              child: CircularProgressIndicator(
                value: prog / 100,
                strokeWidth: 14,
                backgroundColor: AppColors.primary.withOpacity(0.05),
                color: const Color(0xFF32D74B), // Насыщенный зеленый
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("${prog.toInt()}%", style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: AppColors.navy)),
                const Text("ВЫПОЛНЕНО", style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey)),
              ],
            ),
          ],
        ),
      ],
    );
  }

  /// Линейные метрики (Эффективность, Синхрон, Темп)
  Widget _buildMetricsList(Map<String, double> metrics, bool isSolo) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("АНАЛИТИКА ПУТИ", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: Colors.grey)),
        const SizedBox(height: 25),
        _metricItem("Личная эффективность", metrics['eff']!, Colors.blue),
        if (!isSolo) _metricItem("Командный резонанс", metrics['sync']!, Colors.purple),
        _metricItem("Темп прохождения", metrics['vel']!, Colors.orange),
      ],
    );
  }

  Widget _metricItem(String label, double val, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.navy)),
              Text("${val.toInt()}%", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: val / 100, 
              minHeight: 7, 
              color: color, 
              backgroundColor: color.withOpacity(0.08)
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // --- СПИСОК ЭТАПОВ (ШАГОВ К ЦЕЛИ) ---
  // ---------------------------------------------------------------------------

  Widget _buildTaskListSection(GoalResponse goal, TaskProvider prov, String name, UserDto? u, bool creator) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text("ЭТАПЫ МАРШРУТА", style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: AppColors.navy)),
            if (creator) 
              IconButton(
                onPressed: () => _showAddTaskModal(goal.id), 
                icon: const Icon(Icons.add_circle_rounded, color: AppColors.primary, size: 30)
              ),
          ],
        ),
        const SizedBox(height: 20),
        if (prov.isLoading) const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()))
        else if (prov.tasks.isEmpty)
          const Center(child: Padding(padding: EdgeInsets.all(50), child: Text("Задачи еще не добавлены", style: TextStyle(color: Colors.grey))))
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: prov.tasks.length,
            itemBuilder: (ctx, i) {
              final t = prov.tasks[i];
              bool isDone = t.completions.any((c) => c.username == name);
              return _buildStepCard(t, isDone, name, u, creator);
            },
          ),
      ],
    );
  }

  Widget _buildStepCard(TaskResponse t, bool isDone, String name, UserDto? u, bool creator) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
        color: isDone ? const Color(0xFFF9FBFF) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: isDone ? Colors.green.withOpacity(0.25) : const Color(0xFFE8ECF1), width: 1.5),
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
                  goalProvider: context.read<GoalProvider>()
                );
              },
            ),
          ),
          title: Text(t.title, style: TextStyle(
            fontWeight: FontWeight.w700, 
            fontSize: 15, 
            decoration: isDone ? TextDecoration.lineThrough : null, 
            color: isDone ? Colors.grey : AppColors.navy
          )),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 6),
              // ОТОБРАЖЕНИЕ ДАТЫ ШАГА (с возможностью клика для автора)
              InkWell(
                onTap: creator ? () => _showEditTaskModal(t) : null,
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_rounded, size: 12, color: AppColors.primary),
                    const SizedBox(width: 6),
                    Text(DateFormat('dd MMMM yyyy', 'ru').format(t.dueDate), 
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.primary)),
                  ],
                ),
              ),
              _buildCompletionsAvatarsRow(t.completions),
            ],
          ),
          children: [_buildTaskExpandedDetails(t, creator)],
        ),
      ),
    );
  }

  /// Список аватарок тех, кто выполнил шаг
  Widget _buildCompletionsAvatarsRow(List<UserMinimalDto> completions) {
    if (completions.isEmpty) return const SizedBox.shrink();
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

  /// Развернутое содержимое карточки шага (Боковые комментарии и управление)
  Widget _buildTaskExpandedDetails(TaskResponse t, bool creator) {
    final myId = context.read<AuthProvider>().user?.id;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFF),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(22)),
        border: Border(top: BorderSide(color: Colors.grey.withOpacity(0.1))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ПАНЕЛЬ УПРАВЛЕНИЯ ЭТАПОМ ДЛЯ АВТОРА
          if (creator) ...[
            Row(
              children: [
                const Text("УПРАВЛЕНИЕ ЭТАПОМ:", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 0.5)),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => _showEditTaskModal(t), 
                  icon: const Icon(Icons.edit_rounded, size: 16),
                  label: const Text("Изменить", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
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

          const Text("ОБСУЖДЕНИЕ ЭТОГО ШАГА", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey)),
          const SizedBox(height: 15),

          // СПИСОК КОММЕНТАРИЕВ (БОКОВОЙ СТИЛЬ)
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
        border: Border.all(color: Colors.blue.shade50)
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: ctrl,
              style: const TextStyle(fontSize: 13),
              decoration: const InputDecoration(hintText: "Добавить ответ...", border: InputBorder.none, hintStyle: TextStyle(fontSize: 12)),
            ),
          ),
          IconButton(
            onPressed: () {
              if (ctrl.text.trim().isNotEmpty) {
                context.read<TaskProvider>().addComment(taskId, ctrl.text.trim());
                ctrl.clear();
              }
            }, 
            icon: const Icon(Icons.send_rounded, color: AppColors.primary, size: 20)
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // --- КОМАНДА: ЛОГИКА УДАЛЕНИЯ И ОЖИДАНИЯ ---
  // ---------------------------------------------------------------------------

  Widget _buildTeamManagementSection(GoalResponse g, List<TaskResponse> tasks, bool isCreator, int? myId) {
    // Не показываем себя в списке партнеров
    final partners = g.collaborators.where((c) => c.id != myId).toList();
    if (partners.isEmpty) {
      return const Column(
        children: [
          Icon(Icons.person_outline, color: Colors.grey, size: 40),
          SizedBox(height: 10),
          Text("Вы работаете один", style: TextStyle(color: Colors.grey, fontSize: 11)),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("КОМАНДА МАРШРУТА", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: Colors.grey)),
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
                      SizedBox(height: 48, width: 48, child: CircularProgressIndicator(value: pProg/100, strokeWidth: 3, color: Colors.amber))
                    else 
                      const SizedBox(height: 48, width: 48, child: Icon(Icons.hourglass_empty_rounded, color: Colors.orange, size: 20)),
                    _userAvatar(p.avatarUrl, p.name, radius: 20),
                  ],
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, overflow: TextOverflow.ellipsis)),
                      Text(
                        p.isConfirmed ? "${pProg.toInt()}% завершено" : "Ожидает подтверждения", 
                        style: TextStyle(fontSize: 10, color: p.isConfirmed ? Colors.grey : Colors.orange, fontWeight: p.isConfirmed ? FontWeight.normal : FontWeight.bold)
                      ),
                    ],
                  ),
                ),
                // УДАЛЕНИЕ КОНКРЕТНОГО УЧАСТНИКА (ФОРК)
                if (isCreator)
                  IconButton(
                    onPressed: () => _confirmSingleMemberRemoval(g.id, p), 
                    icon: const Icon(Icons.person_remove_rounded, color: Colors.redAccent, size: 18),
                    tooltip: "Удалить из группы",
                  ),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // --- ВКЛАДКА БАЗЫ ЗНАНИЙ (МАТЕРИАЛЫ) ---
  // ---------------------------------------------------------------------------

Widget _buildMaterialsTab(GoalResponse g, bool isCreator) {
  final myId = context.read<AuthProvider>().user?.id;
  // Партнер может добавлять, если он подтвержден
  bool canAdd = isCreator || g.collaborators.any((c) => c.id == myId && c.isConfirmed);

  return Column(
    children: [
      if (canAdd) 
        Padding(
          padding: const EdgeInsets.all(24),
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.navy, minimumSize: const Size(double.infinity, 55)),
            icon: const Icon(Icons.add_link_rounded, color: Colors.white),
            label: const Text("ДОБАВИТЬ НОВЫЕ ЗНАНИЯ", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            onPressed: () => _showAddMaterialModal(g.id),
          ),
        ),
      Expanded(
        child: g.materials.isEmpty 
          ? const Center(child: Text("Материалов в этом пути пока нет"))
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              itemCount: g.materials.length,
              itemBuilder: (ctx, i) {
                final m = g.materials[i];
                // ИСПРАВЛЕНИЕ: Удалять/редактировать может только АВТОР материала или создатель ЦЕЛИ
                bool canManageMaterial = m.creatorId == myId || isCreator;

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: AppDecorations.glassCard,
                  child: ListTile(
                    title: Text(m.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (m.taskTitle != null && m.taskTitle!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Text("📌 ЭТАП: ${m.taskTitle}", style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 10)),
                          ),
                        Text("Загрузил: ${m.creatorName}", style: const TextStyle(fontSize: 10)),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(icon: const Icon(Icons.open_in_new), onPressed: () => launchUrl(Uri.parse(m.content))),
                        if (canManageMaterial)
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                            onPressed: () => context.read<GoalProvider>().deleteMaterial(g.id, m.id),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
      ),
    ],
  );
}

  // ---------------------------------------------------------------------------
  // --- ГРАФИК ПРОДУКТИВНОСТИ ---
  // ---------------------------------------------------------------------------

  Widget _buildProductivityChart(TaskProvider prov, String myName) {
    // Формируем точки на основе времени выполнения
    List<FlSpot> spots = [const FlSpot(0, 0)];
    int count = 0;
    for (int i = 0; i < prov.tasks.length; i++) {
      if (prov.tasks[i].completions.any((c) => c.username == myName)) {
        count++;
      }
      spots.add(FlSpot((i + 1).toDouble(), count.toDouble()));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("ДИНАМИКА ПУТИ", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: Colors.grey)),
        const SizedBox(height: 25),
        SizedBox(
          height: 150,
          child: spots.length < 2 
          ? const Center(child: Text("Недостаточно данных для графика", style: TextStyle(fontSize: 10, color: Colors.grey)))
          : LineChart(
              LineChartData(
                gridData: const FlGridData(show: false),
                titlesData: const FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: AppColors.primary,
                    barWidth: 4,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(show: true, color: AppColors.primary.withOpacity(0.08)),
                  )
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

  PreferredSizeWidget _buildAppBar(GoalResponse g, bool isCreator) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0.5,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.navy, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(g.title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: AppColors.navy)),
          Text(g.isSolo ? "Личное обучение" : "Командная работа", style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
        ],
      ),
      actions: [
        if (isCreator && !g.isSolo) 
          IconButton(onPressed: () => _showInvitePartnerModal(g), icon: const Icon(Icons.person_add_alt_1_rounded, color: AppColors.primary)),
        IconButton(onPressed: () => _showGoalSettingsModal(g, isCreator), icon: const Icon(Icons.settings_suggest_rounded, color: AppColors.navy)),
        const SizedBox(width: 15),
      ],
      bottom: TabBar(
        controller: _tabController,
        labelColor: AppColors.primary,
        unselectedLabelColor: Colors.grey,
        indicatorColor: AppColors.primary,
        indicatorWeight: 3,
        tabs: const [Tab(text: "ДАШБОРД"), Tab(text: "МАТЕРИАЛЫ")],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // --- МОДАЛЬНЫЕ ОКНА И ДИАЛОГИ ПОДТВЕРЖДЕНИЯ ---
  // ---------------------------------------------------------------------------

  /// Настройки цели с кнопками-иконками режима (как при создании)
  void _showGoalSettingsModal(GoalResponse goal, bool isCreator) {
    _showHiveModal(Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text("Управление маршрутом", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 19, color: AppColors.navy)),
          const SizedBox(height: 10),
          const Text("Измените режим или удалите цель", style: TextStyle(fontSize: 11, color: Colors.grey)),
          const SizedBox(height: 35),
          
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
                onTap: () {
                  if (!goal.isSolo) return;
                  context.read<GoalProvider>().toggleGoalSoloStatus(goal.id, false);
                  Navigator.pop(context);
                },
              ),
            ],
          ),
          
          const Divider(height: 60),
          
          ListTile(
            onTap: () {
              Navigator.pop(context);
              context.read<GoalProvider>().removeGoal(goal.id, goal.userId);
              Navigator.pop(context);
            },
            leading: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.delete_forever_rounded, color: Colors.redAccent)),
            title: const Text("Удалить этот маршрут", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w900, fontSize: 14)),
            subtitle: const Text("Действие необратимо", style: TextStyle(fontSize: 11)),
          )
        ],
      ),
    ));
  }

  Widget _modeIconButton({required IconData icon, required String label, required bool isSelected, required Color color, required VoidCallback onTap}) {
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
            border: Border.all(color: color.withOpacity(isSelected ? 1 : 0.2), width: 2),
            boxShadow: [if (isSelected) BoxShadow(color: color.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 6))],
          ),
          child: Column(
            children: [
              Icon(icon, color: isSelected ? Colors.white : color, size: 35),
              const SizedBox(height: 12),
              Text(label, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: isSelected ? Colors.white : color)),
            ],
          ),
        ),
      ),
    );
  }

  /// Диалог: перевод всей цели в Личный режим (Кикаем всех с Форком)
  void _confirmTotalModeChangeToSolo(int id) {
    _showHiveModal(Padding(
      padding: const EdgeInsets.all(35),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.warning_amber_rounded, size: 50, color: Colors.orange),
          const SizedBox(height: 20),
          const Text("СДЕЛАТЬ ПУТЬ ЛИЧНЫМ?", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
          const SizedBox(height: 15),
          const Text(
            "Внимание! Групповая работа будет прекращена. Все участники получат свою личную независимую копию со своим прогрессом, а ваша цель станет приватной. Продолжить?",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.grey, height: 1.4),
          ),
          const SizedBox(height: 35),
          Row(
            children: [
              Expanded(child: TextButton(onPressed: () => Navigator.pop(context), child: const Text("ОТМЕНА", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)))),
              const SizedBox(width: 15),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                  onPressed: () {
                    context.read<GoalProvider>().makeGoalPersonal(id);
                    Navigator.pop(context);
                  }, 
                  child: const Text("ДА, РАЗДЕЛИТЬ", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                ),
              ),
            ],
          )
        ],
      ),
    ));
  }

  /// Диалог: Удаление одного конкретного человека (с Форком для него)
  void _confirmSingleMemberRemoval(int goalId, GoalPartnerDto p) {
    _showHiveModal(Padding(
      padding: const EdgeInsets.all(35),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.person_remove_rounded, size: 50, color: Colors.redAccent),
          const SizedBox(height: 20),
          Text("УДАЛИТЬ ${p.name.toUpperCase()}?", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
          const SizedBox(height: 15),
          Text(
            "У пользователя останется его личная копия этого маршрута со всеми текущими материалами и его галочками, но он больше не будет частью вашей группы. Продолжить?",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600, height: 1.4),
          ),
          const SizedBox(height: 35),
          Row(
            children: [
              Expanded(child: TextButton(onPressed: () => Navigator.pop(context), child: const Text("ОТМЕНА", style: TextStyle(color: Colors.grey)))),
              const SizedBox(width: 15),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                  onPressed: () {
                    // Здесь вызываем удаление из GoalProvider, которое на бэкенде делает Fork
                    Navigator.pop(context);
                  }, 
                  child: const Text("ДА, УДАЛИТЬ", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                ),
              ),
            ],
          )
        ],
      ),
    ));
  }

  // ---------------------------------------------------------------------------
  // --- ДИАЛОГИ СОЗДАНИЯ / РЕДАКТИРОВАНИЯ ЭЛЕМЕНТОВ ---
  // ---------------------------------------------------------------------------

  void _showAddTaskModal(int gid) {
    final titleCtrl = TextEditingController();
    DateTime date = DateTime.now().add(const Duration(days: 1));
    _showHiveModal(StatefulBuilder(builder: (ctx, setSt) => Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text("НОВЫЙ ЭТАП ПУТИ", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: AppColors.navy)),
          const SizedBox(height: 25),
          TextField(controller: titleCtrl, decoration: AppDecorations.smartInput("Что необходимо выполнить?", Icons.add_task_rounded)),
          const SizedBox(height: 15),
          ListTile(
            onTap: () async {
              final d = await showDatePicker(context: context, initialDate: date, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 730)));
              if (d != null) setSt(() => date = d);
            },
            leading: const Icon(Icons.calendar_today_rounded, color: AppColors.primary, size: 20),
            title: Text(DateFormat('dd MMMM yyyy', 'ru').format(date), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            subtitle: const Text("Срок выполнения", style: TextStyle(fontSize: 10)),
            trailing: const Icon(Icons.edit_calendar_rounded, size: 18),
          ),
          const SizedBox(height: 35),
          SizedBox(
            width: double.infinity, height: 55,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
              onPressed: () {
                if (titleCtrl.text.isNotEmpty) {
                  context.read<TaskProvider>().createTask(gid, titleCtrl.text.trim(), date);
                  Navigator.pop(context);
                }
              }, 
              child: const Text("ДОБАВИТЬ В МАРШРУТ", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900))
            ),
          )
        ],
      ),
    )));
  }

// Метод внутри _GoalDetailsScreenState

// Внутри класса _GoalDetailsScreenState в файле goal_details_screen.dart

// Найти в GoalDetailsScreen метод _showEditTaskModal:

void _showEditTaskModal(TaskResponse t) {
  final tc = TextEditingController(text: t.title);
  DateTime d = t.dueDate;
  final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);

  _showHiveModal(StatefulBuilder(builder: (ctx, st) => Padding(
    padding: const EdgeInsets.all(32),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text("РЕДАКТИРОВАНИЕ ШАГА", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
        const SizedBox(height: 25),
        TextField(controller: tc, decoration: AppDecorations.smartInput("Что нужно сделать?", Icons.edit_note_rounded)),
        const SizedBox(height: 15),
        ListTile(
          contentPadding: EdgeInsets.zero,
          onTap: () async {
            final sel = await showDatePicker(
              context: context, 
              initialDate: d.isBefore(today) ? today : d, 
              firstDate: today, // ЗАПРЕТ ВЫБОРА ПРОШЛОГО
              lastDate: DateTime.now().add(const Duration(days: 730)),
              locale: const Locale('ru'),
            );
            if (sel != null) st(() => d = sel);
          },
          leading: const Icon(Icons.calendar_month, color: AppColors.primary),
          title: Text(DateFormat('dd MMMM yyyy', 'ru').format(d), style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: const Text("Нажмите, чтобы изменить дату"),
        ),
        const SizedBox(height: 35),
        SizedBox(
          width: double.infinity,
          height: 55,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.navy, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
            onPressed: () async {
              if (tc.text.isNotEmpty) {
                // Если пользователь каким-то образом выбрал старую дату, блокируем тут
                if (d.isBefore(today)) {
                   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Выберите будущую дату")));
                   return;
                }

                await context.read<TaskProvider>().updateTask(
                  taskId: t.id, 
                  goalId: t.goalId, 
                  newTitle: tc.text.trim(), 
                  newDate: d,
                  goalProv: context.read<GoalProvider>(),
                );
                Navigator.pop(context);
              }
            }, 
            child: const Text("СОХРАНИТЬ", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
          ),
        )
      ],
    ),
  )));
}

  void _confirmDeleteTask(TaskResponse t) {
    _showHiveModal(Padding(
      padding: const EdgeInsets.all(35),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.delete_sweep_rounded, color: Colors.redAccent, size: 45),
          const SizedBox(height: 15),
          const Text("УДАЛИТЬ ЭТОТ ШАГ?", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
          const Text("Все связанные с ним комментарии также будут стерты.", textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 30),
          Row(
            children: [
              Expanded(child: TextButton(onPressed: () => Navigator.pop(context), child: const Text("ОТМЕНА"))),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                  onPressed: () {
                    context.read<TaskProvider>().deleteTask(t.id, t.goalId);
                    Navigator.pop(context);
                  }, 
                  child: const Text("УДАЛИТЬ", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
                ),
              ),
            ],
          )
        ],
      ),
    ));
  }

  void _showAddMaterialModal(int goalId) {
    final tCtrl = TextEditingController();
    final lCtrl = TextEditingController();
    int? selectedTaskId;

    _showHiveModal(StatefulBuilder(builder: (ctx, setSt) => Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text("НОВЫЙ МАТЕРИАЛ", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: AppColors.navy)),
          const SizedBox(height: 25),
          TextField(controller: tCtrl, decoration: AppDecorations.smartInput("Заголовок ссылки или файла", Icons.title_rounded)),
          const SizedBox(height: 15),
          TextField(controller: lCtrl, decoration: AppDecorations.smartInput("URL-адрес ресурса", Icons.link_rounded)),
          const SizedBox(height: 20),
          const Align(alignment: Alignment.centerLeft, child: Text("ПРИВЯЗАТЬ К КОНКРЕТНОМУ ШАГУ:", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.grey))),
          const SizedBox(height: 10),
          DropdownButtonFormField<int>(
            decoration: AppDecorations.smartInput("Выберите этап маршрута", Icons.layers_rounded),
            items: context.read<TaskProvider>().tasks.map((t) => DropdownMenuItem(value: t.id, child: Text(t.title, style: const TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis))).toList(),
            onChanged: (v) => setSt(() => selectedTaskId = v),
          ),
          const SizedBox(height: 35),
          SizedBox(
            width: double.infinity, height: 55,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
              onPressed: () {
                if (tCtrl.text.isNotEmpty && lCtrl.text.isNotEmpty) {
                  context.read<GoalProvider>().addMaterialWithTask(goalId, tCtrl.text.trim(), lCtrl.text.trim(), "Link", selectedTaskId);
                  Navigator.pop(context);
                }
              }, 
              child: const Text("СОХРАНИТЬ В БАЗУ", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900))
            ),
          )
        ],
      ),
    )));
  }

  void _showInvitePartnerModal(GoalResponse goal) {
    final userProv = context.read<UserProvider>();
    userProv.loadFriends();
    _showHiveModal(Padding(
      padding: const EdgeInsets.all(30),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text("ПРИГЛАСИТЬ В КОМАНДУ", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
          const SizedBox(height: 20),
          SizedBox(
            height: 300,
            child: Consumer<UserProvider>(
              builder: (ctx, prov, _) => prov.friends.isEmpty 
              ? const Center(child: Text("Сначала добавьте друзей в профиле"))
              : ListView.builder(
                  itemCount: prov.friends.length,
                  itemBuilder: (c, i) {
                    final f = prov.friends[i];
                    bool isAlreadyMember = goal.collaborators.any((c) => c.id == f.id);
                    return ListTile(
                      leading: _userAvatar(f.avatarUrl, f.username, radius: 18),
                      title: Text(f.username, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      trailing: TextButton(
                        onPressed: isAlreadyMember ? null : () {
                          context.read<GoalProvider>().invitePartner(goal.id, f.id, goal.userId);
                          Navigator.pop(context);
                        }, 
                        child: Text(isAlreadyMember ? "В ПУТИ" : "ПОЗВАТЬ", style: TextStyle(color: isAlreadyMember ? Colors.grey : AppColors.primary, fontWeight: FontWeight.bold))
                      ),
                    );
                  },
                ),
            ),
          ),
        ],
      ),
    ));
  }
}