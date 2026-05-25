import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/goal_provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import '../models/all_models.dart';
import 'create_goal_screen.dart';
import 'goal_details_screen.dart';

class GoalsScreen extends StatefulWidget {
  const GoalsScreen({super.key});

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  String _filterType = "All"; // Фильтр: All, Social, Exchange, Group

  @override
  void initState() {
    super.initState();
    // Загружаем данные при входе
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = context.read<AuthProvider>().user;
      if (user != null) {
        context.read<GoalProvider>().loadGoals(user.id);
      }
    });
  }

@override
  Widget build(BuildContext context) {
    final provider = context.watch<GoalProvider>();
    final myId = context.read<AuthProvider>().user?.id;
    double screenWidth = MediaQuery.of(context).size.width;
    bool isWide = screenWidth > 800;

    List<GoalResponse> filteredGoals = provider.goals.where((g) {
      if (_filterType == "All") return true;
      return g.goalType == _filterType;
    }).toList();

    return Scaffold(
      backgroundColor: isWide ? Colors.transparent : AppColors.background,
      body: Padding(
        padding: EdgeInsets.all(isWide ? 40 : 15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isWide) _buildWebHeader(context),
            const SizedBox(height: 25),
            _buildFilterBar(), // ИСПРАВЛЕНО: Теперь без аргумента
            const SizedBox(height: 25),
            Expanded(
              child: filteredGoals.isEmpty
                  ? _buildEmptyState()
                  : GridView.builder(
                      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: isWide ? 450 : screenWidth,
                        mainAxisExtent: 220,
                        crossAxisSpacing: 20,
                        mainAxisSpacing: 20,
                      ),
                      itemCount: filteredGoals.length,
                      itemBuilder: (context, i) => _buildGoalCard(context, filteredGoals[i], myId!, isWide),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // Обновленный фильтр: только Все, Мои и Групповые
  Widget _buildFilterBar() {
    return Row(
      children: [
        _filterChip("Все маршруты", "All"),
        const SizedBox(width: 10),
        _filterChip("Мои цели", "Social"),
        const SizedBox(width: 10),
        _filterChip("Групповые", "Group"),
      ],
    );
  }

  // --- ХЕДЕР ДЛЯ WEB ---
  Widget _buildWebHeader(BuildContext context) {
    return Row(
      children: [
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Мои маршруты", style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: AppColors.navy)),
            Text("Управляйте личным обучением и командными целями", style: TextStyle(color: Colors.grey, fontSize: 14)),
          ],
        ),
        const Spacer(),
        ElevatedButton.icon(
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateGoalScreen())),
          icon: const Icon(Icons.add, color: Colors.white, size: 18),
          label: const Text("СОЗДАТЬ ПУТЬ", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.secondary,
            padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 20),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          ),
        ),
      ],
    );
  }

  Widget _filterChip(String label, String type) {
    bool isSelected = _filterType == type;
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (val) => setState(() => _filterType = type),
        selectedColor: AppColors.navy,
        labelStyle: TextStyle(color: isSelected ? Colors.white : AppColors.navy, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, fontSize: 12),
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: isSelected ? AppColors.navy : Colors.grey.shade200)),
        showCheckmark: false,
      ),
    );
  }

  // --- АДАПТИВНАЯ КАРТОЧКА ЦЕЛИ ---
  Widget _buildGoalCard(BuildContext context, GoalResponse g, int myId, bool isWide) {
    Color color = g.goalType == "Exchange" ? Colors.orange : g.goalType == "Group" ? Colors.purple : AppColors.primary;
    IconData icon = g.goalType == "Exchange" ? Icons.sync_alt : g.goalType == "Group" ? Icons.school : Icons.flag_rounded;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 15, offset: const Offset(0, 8))],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => GoalDetailsScreen(goal: g))),
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(25),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                      child: Icon(icon, color: color, size: 20),
                    ),
                    const SizedBox(width: 15),
                    Expanded(child: Text(g.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: AppColors.navy), maxLines: 1, overflow: TextOverflow.ellipsis)),
                    if (g.userId == myId) 
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 20, color: Colors.grey),
                        onPressed: () => _confirmDelete(context, g, myId),
                      )
                  ],
                ),
                const Spacer(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("${g.progress.toInt()}% пройдено", style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: color.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(8)),
                      child: Text(
                        g.goalType == "Exchange" ? "БАРТЕР" : g.goalType == "Group" ? "ГРУППА" : "ЛИЧНАЯ",
                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: color, letterSpacing: 0.5),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: g.progress / 100,
                    minHeight: 8,
                    backgroundColor: Colors.grey.shade50,
                    color: color,
                  ),
                ),
                const Spacer(),
                if (isWide) 
                  ElevatedButton(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => GoalDetailsScreen(goal: g))),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: color.withValues(alpha: 0.1),
                      foregroundColor: color,
                      elevation: 0,
                      minimumSize: const Size(double.infinity, 45),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text("ОТКРЫТЬ МАРШРУТ", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11)),
                  )
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.flag_outlined, size: 70, color: Colors.grey.withValues(alpha: 0.2)),
          const SizedBox(height: 20),
          const Text("Маршруты не найдены", style: TextStyle(fontSize: 16, color: Colors.grey, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text("Попробуйте сменить фильтр или создайте новую цель", style: TextStyle(color: Colors.grey, fontSize: 13)),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, GoalResponse goal, int myId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Удалить маршрут?", style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text("Вы действительно хотите удалить '${goal.title}'?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("ОТМЕНА")),
          TextButton(
            onPressed: () {
              context.read<GoalProvider>().removeGoal(goal.id, myId);
              Navigator.pop(ctx);
            },
            child: const Text("УДАЛИТЬ", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}