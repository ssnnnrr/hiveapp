import 'dart:convert';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:hive_app/services/task_service.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/all_models.dart';
import '../providers/task_provider.dart';
import '../providers/goal_provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';

class GoalDetailsScreen extends StatefulWidget {
  final GoalResponse goal;
  const GoalDetailsScreen({super.key, required this.goal});

  @override
  State<GoalDetailsScreen> createState() => _GoalDetailsScreenState();
}

class _GoalDetailsScreenState extends State<GoalDetailsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TaskProvider>().loadTasks(widget.goal.id);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

Future<void> _toggleTask(TaskResponse t, GoalResponse goal) async {
  final newStatus = t.status == "Done" ? "ToDo" : "Done";
  // Используем TaskProvider вместо TaskService напрямую
  await context.read<TaskProvider>().updateTaskStatus(t.id, newStatus, t.studentComment);
}

  @override
  Widget build(BuildContext context) {
    final goalProv = context.watch<GoalProvider>();
    final currentGoal = goalProv.goals.firstWhere((g) => g.id == widget.goal.id, orElse: () => widget.goal);
    final tasks = context.watch<TaskProvider>().tasks;
    final progress = tasks.isEmpty ? 0.0 : (tasks.where((t) => t.status == "Done").length / tasks.length) * 100;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(currentGoal.title, style: AppTextStyles.h2),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: AppColors.navy),
            onPressed: () => _showGoalSettings(currentGoal)
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.navy,
          unselectedLabelColor: Colors.grey,
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(text: "ЗАДАЧИ"),
            Tab(text: "БАЗА ЗНАНИЙ")
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          Column(
            children: [
              _buildProgressHeader(progress),
              Expanded(
                child: tasks.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.task_alt, size: 64, color: Colors.grey.shade300),
                          const SizedBox(height: 16),
                          Text("Нет задач", style: TextStyle(color: Colors.grey.shade500, fontSize: 16)),
                          const SizedBox(height: 8),
                          Text("Нажмите + чтобы добавить шаг", style: TextStyle(color: Colors.grey.shade400, fontSize: 14)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: tasks.length,
                      itemBuilder: (ctx, i) => _buildTaskCard(tasks[i], currentGoal),
                    ),
              ),
            ],
          ),
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: ElevatedButton.icon(
                  onPressed: () => _showAddMaterialSheet(currentGoal.id),
                  icon: const Icon(Icons.add),
                  label: const Text("Добавить материал"),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    backgroundColor: AppColors.navy,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
              Expanded(
                child: currentGoal.materials.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.library_books, size: 64, color: Colors.grey.shade300),
                          const SizedBox(height: 16),
                          Text("Нет материалов", style: TextStyle(color: Colors.grey.shade500, fontSize: 16)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: currentGoal.materials.length,
                      itemBuilder: (ctx, i) => _buildMaterialCard(currentGoal.materials[i], currentGoal),
                    ),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddStepSheet(currentGoal.id),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildProgressHeader(double progress) {
    return Container(
      padding: const EdgeInsets.all(24),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.navy, AppColors.navy.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.navy.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Прогресс",
                style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500),
              ),
              Text(
                "${progress.toInt()}%",
                style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress / 100,
              backgroundColor: Colors.white24,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
              minHeight: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskCard(TaskResponse t, GoalResponse goal) {
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Радио-кнопка с анимацией
                GestureDetector(
                  onTap: () => _toggleTask(t, goal),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: t.status == "Done" ? Colors.green : Colors.grey.shade400,
                        width: 2,
                      ),
                      color: t.status == "Done" ? Colors.green : Colors.transparent,
                    ),
                    child: t.status == "Done"
                      ? const Icon(Icons.check, color: Colors.white, size: 18)
                      : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t.title,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          decoration: t.status == "Done" ? TextDecoration.lineThrough : null,
                          color: t.status == "Done" ? Colors.grey : AppColors.navy,
                        ),
                      ),
                      if (t.dueDate != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.calendar_today, size: 12, color: Colors.grey.shade500),
                            const SizedBox(width: 4),
                            Text(
                              DateFormat('dd.MM.yyyy').format(t.dueDate),
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                // Кнопки действий
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(Icons.edit_outlined, size: 20, color: Colors.grey.shade600),
                      onPressed: () => _showEditTaskDialog(t),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    ),
                    IconButton(
                      icon: Icon(Icons.delete_outline, size: 20, color: Colors.red.shade400),
                      onPressed: () => _deleteTask(t, goal),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Комментарии
          if (t.studentComment != null && t.studentComment!.isNotEmpty || 
              t.teacherComment != null && t.teacherComment!.isNotEmpty)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  // Комментарии пользователей
                  ..._buildComments(t),
                  const SizedBox(height: 8),
                  // Кнопка добавления комментария
                  InkWell(
                    onTap: () => _showCommentDialog(t),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.add_comment_outlined, size: 16, color: Colors.grey.shade500),
                          const SizedBox(width: 8),
                          Text(
                            "Добавить комментарий...",
                            style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: InkWell(
                onTap: () => _showCommentDialog(t),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.add_comment_outlined, size: 16, color: Colors.grey.shade500),
                      const SizedBox(width: 8),
                      Text(
                        "Добавить комментарий...",
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ЕДИНСТВЕННЫЙ метод _buildComments
// Замените метод _buildComments на этот:
List<Widget> _buildComments(TaskResponse t) {
  List<Widget> comments = [];
  
  // Показываем комментарий студента с правильным аватаром
  if (t.studentComment != null && t.studentComment!.isNotEmpty) {
    comments.add(
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Используем аватар из completions или первую букву имени
            CircleAvatar(
              radius: 14,
              backgroundColor: AppColors.primary.withOpacity(0.1),
              backgroundImage: t.studentAvatarUrl != null 
                ? MemoryImage(base64Decode(t.studentAvatarUrl!)) 
                : null,
              child: t.studentAvatarUrl == null
                ? Text(
                    t.completions.isNotEmpty 
                      ? t.completions.first 
                      : (t.studentName?.substring(0, 1).toUpperCase() ?? "У"),
                    style: const TextStyle(
                      fontSize: 12, 
                      fontWeight: FontWeight.bold, 
                      color: AppColors.primary
                    ),
                  )
                : null,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Имя пользователя
                  Text(
                    t.studentName ?? "Пользователь",
                    style: const TextStyle(
                      fontSize: 12, 
                      fontWeight: FontWeight.w600,
                      color: AppColors.navy,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      t.studentComment!,
                      style: const TextStyle(fontSize: 13, color: AppColors.navy),
                    ),
                  ),
                ],
              ),
            ),
            // Кнопки редактирования и удаления комментария
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, size: 16, color: Colors.grey.shade500),
              onSelected: (value) {
                if (value == 'edit') {
                  _showCommentDialog(t);
                } else if (value == 'delete') {
                  _deleteComment(t);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit, size: 16),
                      SizedBox(width: 8),
                      Text('Редактировать'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, size: 16, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Удалить', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  // Показываем комментарий учителя
  if (t.teacherComment != null && t.teacherComment!.isNotEmpty) {
    comments.add(
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: Colors.orange.withOpacity(0.1),
            child: const Text(
              "П",
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.orange),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Преподаватель",
                  style: TextStyle(
                    fontSize: 12, 
                    fontWeight: FontWeight.w600,
                    color: AppColors.navy,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    t.teacherComment!,
                    style: const TextStyle(fontSize: 13, color: AppColors.navy),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  return comments;
}

// Добавьте метод для удаления комментария
void _deleteComment(TaskResponse t) async {
  final confirm = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text("Удалить комментарий?"),
      content: const Text("Вы уверены, что хотите удалить этот комментарий?"),
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
    await context.read<TaskProvider>().updateTaskStatus(t.id, t.status, null);
  }
}



  // Замените метод _buildMaterialCard:
Widget _buildMaterialCard(MaterialDto material, GoalResponse goal) {
  final authProv = context.watch<AuthProvider>();
  final tasks = context.watch<TaskProvider>().tasks;
  
  // Находим связанную задачу
  final linkedTask = material.taskId != null 
    ? tasks.firstWhereOrNull((t) => t.id == material.taskId)
    : null;
  
  return Container(
    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: AppColors.navy.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          material.type == "Link" ? Icons.link : Icons.description,
          color: AppColors.navy,
        ),
      ),
      title: Text(
        material.title,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          // Показываем привязку к шагу
          if (linkedTask != null) ...[
            Row(
              children: [
                Icon(Icons.link, size: 12, color: AppColors.primary),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    "Привязан к: ${linkedTask.title}",
                    style: TextStyle(fontSize: 12, color: AppColors.primary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
          ],
          // Информация о создателе
          Row(
            children: [
              CircleAvatar(
                radius: 10,
                backgroundColor: AppColors.primary.withOpacity(0.1),
                backgroundImage: authProv.user?.avatarUrl != null 
                  ? MemoryImage(base64Decode(authProv.user!.avatarUrl!)) 
                  : null,
                child: authProv.user?.avatarUrl == null
                  ? Text(
                      authProv.user?.username?.substring(0, 1).toUpperCase() ?? "?",
                      style: const TextStyle(
                        fontSize: 10, 
                        fontWeight: FontWeight.bold, 
                        color: AppColors.primary
                      ),
                    )
                  : null,
              ),
              const SizedBox(width: 4),
              Text(
                DateFormat('dd.MM.yyyy').format(material.createdAt),
                style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
              ),
            ],
          ),
        ],
      ),
      trailing: IconButton(
        icon: Icon(Icons.delete_outline, size: 20, color: Colors.red.shade400),
        onPressed: () => context.read<GoalProvider>().deleteMaterial(goal.id, material.id),
      ),
      onTap: () {
        // Открыть материал
        if (material.type == "Link" && material.content.isNotEmpty) {
          // Используйте url_launcher для открытия ссылки
        }
      },
    ),
  );
}


  // --- 1. НАСТРОЙКИ ЦЕЛИ ---
  void _showGoalSettings(GoalResponse goal) {
  final titleCtrl = TextEditingController(text: goal.title);
  bool isSolo = goal.isSolo;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
    ),
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSt) => Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          top: 20,
          left: 20,
          right: 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              "РЕДАКТИРОВАНИЕ ЦЕЛИ",
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: titleCtrl,
              decoration: InputDecoration(
                labelText: "Название цели",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              title: const Text("Личная цель"),
              subtitle: Text(isSolo ? "Только вы работаете над целью" : "Групповая цель"),
              value: isSolo,
              onChanged: (v) => setSt(() => isSolo = v),
              activeColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 55),
                backgroundColor: AppColors.navy,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: () async {
                // Сохраняем изменения
                await context.read<GoalProvider>().updateGoal(
                  goalId: goal.id,
                  title: titleCtrl.text,
                  isSolo: isSolo,
                );
                Navigator.pop(ctx);
              },
              child: const Text("СОХРАНИТЬ", style: TextStyle(fontWeight: FontWeight.w600)),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    ),
  );
}


  // --- 2. ДОБАВЛЕНИЕ МАТЕРИАЛА С ПРИВЯЗКОЙ К ШАГУ ---
  void _showAddMaterialSheet(int goalId) {
    final titleCtrl = TextEditingController();
    final urlCtrl = TextEditingController();
    int? selectedTaskId;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            top: 20,
            left: 20,
            right: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                "ПРИКРЕПИТЬ МАТЕРИАЛ",
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: titleCtrl,
                decoration: InputDecoration(
                  labelText: "Название",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: urlCtrl,
                decoration: InputDecoration(
                  labelText: "Ссылка",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
              ),
              const SizedBox(height: 15),
               DropdownButtonFormField<int>(
              isExpanded: true, // 👈 ДОБАВЬТЕ ЭТУ СТРОКУ
              decoration: InputDecoration(
                labelText: "Привязать к шагу",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.grey.shade50,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), // 👈 ДОБАВЬТЕ ЭТУ СТРОКУ
              ),
              items: [
                const DropdownMenuItem<int>(
                  value: null,
                  child: Text("Без привязки", overflow: TextOverflow.ellipsis), // 👈 Добавьте overflow
                ),
                ...context.read<TaskProvider>().tasks.map(
                  (t) => DropdownMenuItem(
                    value: t.id,
                    child: Text(t.title, overflow: TextOverflow.ellipsis), // 👈 Добавьте overflow
                  ),
                ),
              ],
              onChanged: (v) => setSt(() => selectedTaskId = v),
            ),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 55),
                  backgroundColor: AppColors.navy,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: () async {
                  await context.read<GoalProvider>().addMaterialWithTask(
                    goalId,
                    titleCtrl.text,
                    urlCtrl.text,
                    "Link",
                    selectedTaskId,
                  );
                  Navigator.pop(ctx);
                },
                child: const Text("СОХРАНИТЬ", style: TextStyle(fontWeight: FontWeight.w600)),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  // --- 3. РЕДАКТИРОВАНИЕ ШАГА К ЦЕЛИ ---
  void _showEditTaskDialog(TaskResponse t) {
    final titleCtrl = TextEditingController(text: t.title);
    DateTime dueDate = t.dueDate;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("Редактировать шаг", style: TextStyle(fontWeight: FontWeight.w700)),
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
                          colorScheme: const ColorScheme.light(
                            primary: AppColors.navy,
                          ),
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
                  taskId: t.id,
                  goalId: t.goalId,
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

Future<void> _deleteTask(TaskResponse t, GoalResponse goal) async {
  final confirm = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text("Удалить шаг?"),
      content: Text("Вы уверены, что хотите удалить \"${t.title}\"?"),
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
    // Используем TaskProvider вместо TaskService напрямую
    await context.read<TaskProvider>().deleteTask(t.id, t.goalId);
  }
}

  // --- 1. ДИАЛОГ ДОБАВЛЕНИЯ ШАГА ---
  void _showAddStepSheet(int goalId) {
    final stepCtrl = TextEditingController();
    DateTime selectedDate = DateTime.now().add(const Duration(days: 1));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            top: 20,
            left: 20,
            right: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                "НОВЫЙ ШАГ ПЛАНА",
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: stepCtrl,
                decoration: InputDecoration(
                  labelText: "Что нужно сделать?",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                tileColor: Colors.grey.shade50,
                title: Text(
                  "Дедлайн: ${DateFormat('dd.MM.yyyy').format(selectedDate)}",
                  style: const TextStyle(fontSize: 14),
                ),
                trailing: const Icon(Icons.calendar_month),
                onTap: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: selectedDate,
                    firstDate: DateTime.now(),
                    lastDate: DateTime(2030),
                    builder: (context, child) {
                      return Theme(
                        data: Theme.of(context).copyWith(
                          colorScheme: const ColorScheme.light(
                            primary: AppColors.navy,
                          ),
                        ),
                        child: child!,
                      );
                    },
                  );
                  if (d != null) setSt(() => selectedDate = d);
                },
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 55),
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: () async {
                  if (stepCtrl.text.isEmpty) return;
                  await context.read<TaskProvider>().createTask(
                    goalId,
                    stepCtrl.text,
                    selectedDate,
                    (p) => context.read<GoalProvider>().syncProgress(goalId, p),
                  );
                  Navigator.pop(ctx);
                },
                child: const Text("СОЗДАТЬ ШАГ", style: TextStyle(fontWeight: FontWeight.w600)),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  // --- 2. ОКНО КОММЕНТАРИЯ К ЗАДАЧЕ (ДЕТАЛИЗАЦИЯ) ---
  void _showCommentDialog(TaskResponse t) {
    final ctrl = TextEditingController(text: t.studentComment ?? "");
    
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "РЕЗУЛЬТАТ ВЫПОЛНЕНИЯ",
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: ctrl,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: "Добавьте комментарий к задаче...",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text("ОТМЕНА"),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.navy,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () async {
                      await context.read<TaskProvider>().submitTask(
                        taskId: t.id,
                        goalId: t.goalId,
                        resultComment: ctrl.text,
                      );
                      Navigator.pop(ctx);
                    },
                    child: const Text("СОХРАНИТЬ"),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}