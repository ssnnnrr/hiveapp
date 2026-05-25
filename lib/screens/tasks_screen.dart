import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../models/all_models.dart';
import '../providers/task_provider.dart';
import '../providers/goal_provider.dart';
import '../theme/app_theme.dart';

class TasksScreen extends StatefulWidget {
  final int? goalId;
  
  const TasksScreen({super.key, this.goalId});

  @override
  State<TasksScreen> createState() => TasksScreenState();
}

class TasksScreenState extends State<TasksScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _selectedDay = DateTime.now();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadTasks();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

    void jumpToDate(DateTime date) {
    setState(() {
      _selectedDay = date;
      _focusedDay = date;
    });
  }

  Future<void> _loadTasks() async {
    final taskProvider = context.read<TaskProvider>();
    if (widget.goalId != null) {
      await taskProvider.loadTasks(widget.goalId!);
    } else {
      // Загружаем все задачи пользователя
      final goalProvider = context.read<GoalProvider>();
      final goals = goalProvider.goals;
      for (var goal in goals) {
        await taskProvider.loadTasks(goal.id);
      }
    }
  }


    List<TaskResponse> _getFilteredTasks(List<TaskResponse> tasks) {
    return tasks.where((t) => isSameDay(t.dueDate, _selectedDay)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final taskProvider = context.watch<TaskProvider>();
    final tasks = _getFilteredTasks(taskProvider.tasks);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Задачи"),
        actions: [
          // Кнопка "Сегодня"
          IconButton(
            icon: const Icon(Icons.today),
            onPressed: () => setState(() {
              _selectedDay = DateTime.now();
              _focusedDay = DateTime.now();
            }),
          )
        ],
      ),
      body: Column(
        children: [
          TableCalendar(
            locale: 'ru_RU',
            firstDay: DateTime.utc(2023, 1),
            lastDay: DateTime.utc(2030, 12),
            focusedDay: _focusedDay,
            calendarFormat: CalendarFormat.week, // Компактный вид
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
            },
          ),
          Expanded(
            child: ListView.builder(
              itemCount: tasks.length,
              itemBuilder: (ctx, i) => _buildTaskCard(tasks[i]),
            ),
          ),
        ],
      ),
      // Кнопка создания задачи теперь привязана к выбранному дню
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddTaskDialog(_selectedDay ?? DateTime.now()),
        child: const Icon(Icons.add),
      ),
    );
  }




  Widget _buildTaskCard(TaskResponse task) {
    bool isOverdue = task.dueDate.isBefore(DateTime.now()) && task.status != "Done";
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => _showTaskDetails(task),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Чекбокс для выполнения
                  GestureDetector(
                    onTap: () => _toggleTaskStatus(task),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: task.status == "Done" ? Colors.green : Colors.grey.shade400,
                          width: 2,
                        ),
                        color: task.status == "Done" ? Colors.green : Colors.transparent,
                      ),
                      child: task.status == "Done"
                        ? const Icon(Icons.check, color: Colors.white, size: 18)
                        : null,
                    ),
                  ),
                   if (isOverdue)
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ElevatedButton.icon(
              icon: const Icon(Icons.date_range, size: 14),
              label: const Text("Перенести"),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade50, foregroundColor: Colors.red),
              onPressed: () => _rescheduleTask(task),
            ),
          ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task.title,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            decoration: task.status == "Done" ? TextDecoration.lineThrough : null,
                            color: task.status == "Done" ? Colors.grey : AppColors.navy,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          task.goalTitle,
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  ),
                  // Кнопка дополнительных действий
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert, color: Colors.grey.shade600),
                    onSelected: (value) {
                      switch (value) {
                        case 'edit':
                          _showEditTaskDialog(task);
                          break;
                        case 'delete':
                          _deleteTask(task);
                          break;
                        case 'reschedule':
                          _rescheduleTask(task);
                          break;
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'edit', child: Row(
                        children: [
                          Icon(Icons.edit, size: 18),
                          SizedBox(width: 8),
                          Text('Редактировать'),
                        ],
                      )),
                      const PopupMenuItem(value: 'reschedule', child: Row(
                        children: [
                          Icon(Icons.schedule, size: 18),
                          SizedBox(width: 8),
                          Text('Перенести'),
                        ],
                      )),
                      const PopupMenuItem(value: 'delete', child: Row(
                        children: [
                          Icon(Icons.delete, size: 18, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Удалить', style: TextStyle(color: Colors.red)),
                        ],
                      )),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  // Дата выполнения
                  Icon(Icons.calendar_today, size: 14, color: Colors.grey.shade500),
                  const SizedBox(width: 4),
                  Text(
                    DateFormat('dd.MM.yyyy').format(task.dueDate),
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                  const Spacer(),
                  // Статус
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: task.status == "Done" 
                        ? Colors.green.withOpacity(0.1) 
                        : Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      task.status == "Done" ? "Выполнено" : "В процессе",
                      style: TextStyle(
                        fontSize: 11,
                        color: task.status == "Done" ? Colors.green : Colors.orange,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              // Комментарии и инициалы пользователей
              if (task.completions.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.people, size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    ...task.completions.map((initial) => Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: CircleAvatar(
                        radius: 10,
                        backgroundColor: AppColors.primary.withOpacity(0.1),
                        child: Text(
                          initial,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    )),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _toggleTaskStatus(TaskResponse task) async {
    final newStatus = task.status == "Done" ? "ToDo" : "Done";
    await context.read<TaskProvider>().updateTaskStatus(
      task.id, 
      newStatus, 
      task.studentComment
    );
  }

  void _rescheduleTask(TaskResponse task) async {
    DateTime selectedDate = task.dueDate;
    
    final date = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: AppColors.navy),
          ),
          child: child!,
        );
      },
    );
    
    if (date != null) {
      await context.read<TaskProvider>().updateTask(
        taskId: task.id,
        goalId: task.goalId,
        newTitle: task.title,
        newDate: date,
      );
    }
  }

  void _showEditTaskDialog(TaskResponse task) {
    final titleCtrl = TextEditingController(text: task.title);
    DateTime dueDate = task.dueDate;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("Редактировать задачу", style: TextStyle(fontWeight: FontWeight.w700)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                decoration: InputDecoration(
                  labelText: "Название",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 15),
              ListTile(
                contentPadding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                tileColor: Colors.grey.shade50,
                title: Text(
                  "Дата: ${DateFormat('dd.MM.yyyy').format(dueDate)}",
                  style: const TextStyle(fontSize: 14),
                ),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: dueDate,
                    firstDate: DateTime.now(),
                    lastDate: DateTime(2030),
                    builder: (context, child) {
                      return Theme(
                        data: Theme.of(context).copyWith(
                          colorScheme: const ColorScheme.light(primary: AppColors.navy),
                        ),
                        child: child!,
                      );
                    },
                  );
                  if (d != null) {
                    setDialogState(() {
                      dueDate = d;
                    });
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Отмена"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.navy,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                context.read<TaskProvider>().updateTask(
                  taskId: task.id,
                  goalId: task.goalId,
                  newTitle: titleCtrl.text,
                  newDate: dueDate,
                );
                Navigator.pop(ctx);
              },
              child: const Text("Сохранить"),
            ),
          ],
        ),
      ),
    );
  }

  void _deleteTask(TaskResponse task) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Удалить задачу?"),
        content: Text("Вы уверены, что хотите удалить \"${task.title}\"?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Отмена"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Удалить"),
          ),
        ],
      ),
    );
    
    if (confirm == true) {
      await context.read<TaskProvider>().deleteTask(task.id, task.goalId);
    }
  }

  void _showTaskDetails(TaskResponse task) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              task.title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildDetailRow(Icons.flag, "Цель", task.goalTitle),
            _buildDetailRow(Icons.calendar_today, "Срок", DateFormat('dd.MM.yyyy').format(task.dueDate)),
            _buildDetailRow(
              Icons.check_circle,
              "Статус",
              task.status == "Done" ? "Выполнено" : "В процессе",
            ),
            if (task.studentComment != null && task.studentComment!.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text("Комментарий:", style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(task.studentComment!),
              ),
            ],
            if (task.completions.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text("Выполнили:", style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: task.completions.map((initial) => Chip(
                  avatar: CircleAvatar(
                    backgroundColor: AppColors.primary.withOpacity(0.1),
                    child: Text(initial, style: const TextStyle(color: AppColors.primary)),
                  ),
                  label: Text(initial),
                )).toList(),
              ),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          Text("$label: ", style: TextStyle(color: Colors.grey.shade600)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  void _showAddTaskDialog(DateTime date) {
    // Используем дату из календаря
    final titleCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("Задача на ${DateFormat('dd.MM').format(date)}"),
        content: TextField(controller: titleCtrl),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text("Отмена")),
          ElevatedButton(
            onPressed: () {
              context.read<TaskProvider>().createTask(widget.goalId!, titleCtrl.text, date, (p){});
              Navigator.pop(context);
            },
            child: Text("Создать"),
          )
        ],
      ),
    );
  }
}