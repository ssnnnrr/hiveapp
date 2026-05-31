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
  String _filterType = "All";

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  void _refreshData() {
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

    // --- ЛОГИКА ФИЛЬТРАЦИИ ---
    List<GoalResponse> visibleGoals = provider.goals.where((g) {
      // Если я создатель — вижу всегда
      if (g.userId == myId) return true;
      
      // Если я партнер — вижу ТОЛЬКО если я подтвердил приглашение
      bool confirmed = g.collaborators.any((c) => c.id == myId && c.isConfirmed);
      return confirmed;
    }).toList();

    // *** ИСПРАВЛЕННАЯ ФИЛЬТРАЦИЯ ПО ТИПУ ***
    List<GoalResponse> filteredGoals = visibleGoals.where((g) {
      if (_filterType == "All") return true;
      
      // Проверяем разные возможные значения типов
      if (_filterType == "Personal") {
        // Личные цели - isSolo = true
        return g.isSolo == true;
      }
      
      if (_filterType == "Group") {
        // Групповые цели - isSolo = false
        return g.isSolo == false;
      }
      
      // Точное совпадение по goalType
      return g.goalType == _filterType;
    }).toList();

    // Отладка
    debugPrint('Total goals: ${provider.goals.length}');
    debugPrint('Visible goals: ${visibleGoals.length}');
    debugPrint('Filtered goals (${_filterType}): ${filteredGoals.length}');
    debugPrint('Goal types: ${visibleGoals.map((g) => g.goalType).toSet()}');
    debugPrint('IsSolo values: ${visibleGoals.map((g) => g.isSolo).toSet()}');

    return Scaffold(
      backgroundColor: isWide ? Colors.transparent : AppColors.background,
      body: Padding(
        padding: EdgeInsets.all(isWide ? 40 : 15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isWide) _buildWebHeader(context),
            const SizedBox(height: 25),
            _buildFilterBar(),
            const SizedBox(height: 25),
            Expanded(
              child: filteredGoals.isEmpty && !provider.isLoading
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

  Widget _buildFilterBar() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _filterChip("Все маршруты", "All"),
          const SizedBox(width: 10),
          _filterChip("Личные", "Personal"),      // Фильтр по isSolo
          const SizedBox(width: 10),
          _filterChip("Групповые", "Group"),       // Фильтр по isSolo
        ],
      ),
    );
  }

  Widget _buildWebHeader(BuildContext context) {
    return Row(
      children: [
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Мои маршруты", style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: AppColors.navy)),
            Text("Личное обучение и подтвержденные групповые цели", style: TextStyle(color: Colors.grey, fontSize: 14)),
          ],
        ),
        const Spacer(),
        ElevatedButton.icon(
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateGoalScreen())),
          icon: const Icon(Icons.add, color: Colors.white),
          label: const Text("СОЗДАТЬ ПУТЬ", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.secondary,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }

  Widget _filterChip(String label, String type) {
    bool isSelected = _filterType == type;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (val) {
        if (val) {
          setState(() => _filterType = type);
          debugPrint('Filter changed to: $type');
        }
      },
      selectedColor: AppColors.navy,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : AppColors.navy, 
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      showCheckmark: false,
    );
  }

  Widget _buildGoalCard(BuildContext context, GoalResponse g, int myId, bool isWide) {
    Color color = g.isSolo ? AppColors.primary : Colors.purple;
    
    // Ищем информацию о текущем пользователе в коллабораторах
    final myInfo = g.collaborators.firstWhere(
      (c) => c.id == myId,
      orElse: () => GoalPartnerDto(
        id: myId, 
        name: "", 
        progress: g.progress,
        isConfirmed: true, 
        isAdmin: false,
        avatarUrl: null
      ),
    );

    // Если пользователь - создатель, используем общий прогресс цели
    // Если партнер - используем его персональный прогресс
    double displayProgress = g.userId == myId ? g.progress : myInfo.progress;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white, 
        borderRadius: BorderRadius.circular(24), 
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04), 
            blurRadius: 15, 
            offset: const Offset(0, 8)
          )
        ]
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context, 
              MaterialPageRoute(builder: (_) => GoalDetailsScreen(goal: g))
            ).then((_) => _refreshData());
          },
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
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1), 
                        borderRadius: BorderRadius.circular(12)
                      ),
                      child: Icon(
                        g.isSolo ? Icons.person_outline : Icons.groups_rounded, 
                        color: color, 
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            g.title, 
                            style: const TextStyle(
                              fontWeight: FontWeight.bold, 
                              fontSize: 17, 
                              color: AppColors.navy
                            ), 
                            maxLines: 1, 
                            overflow: TextOverflow.ellipsis
                          ),
                          const SizedBox(height: 2),
                          Text(
                            g.isSolo ? "Личный маршрут" : "Групповой маршрут",
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey.shade500,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "${displayProgress.toInt()}% пройдено", 
                      style: const TextStyle(
                        fontSize: 12, 
                        color: Colors.grey, 
                        fontWeight: FontWeight.bold
                      )
                    ),
                    Icon(Icons.chevron_right, size: 16, color: Colors.grey.shade400),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: displayProgress / 100,
                    minHeight: 8,
                    backgroundColor: Colors.grey.shade100,
                    color: color,
                  ),
                ),
                const Spacer(),
                if (isWide) 
                  const Text(
                    "ОТКРЫТЬ ПОДРОБНО", 
                    style: TextStyle(
                      fontWeight: FontWeight.w900, 
                      fontSize: 11, 
                      color: AppColors.primary, 
                      letterSpacing: 0.5
                    ),
                  ),
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
          Icon(Icons.flag_outlined, size: 60, color: Colors.grey.shade300),
          const SizedBox(height: 15),
          const Text("Маршруты не найдены", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}