import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/all_models.dart';
import '../providers/goal_provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/main_dashboard_layout.dart'; // ИМПОРТ

class GoalPreviewScreen extends StatefulWidget {
  final String title, why, result;
  final DateTime targetDate;
  final bool isSolo;
  final List<TaskDraftResponse> initialSteps;

  const GoalPreviewScreen({
    super.key, required this.title, required this.why, required this.result, 
    required this.targetDate, required this.isSolo, required this.initialSteps,
  });

  @override
  State<GoalPreviewScreen> createState() => _GoalPreviewScreenState();
}

class _GoalPreviewScreenState extends State<GoalPreviewScreen> {
  late List<TaskDraftResponse> _steps;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _steps = List.from(widget.initialSteps);
  }

  @override
  Widget build(BuildContext context) {
    double width = MediaQuery.of(context).size.width;
    bool isWide = width > 1000;

    // Внутренний контент страницы
    Widget content = Scaffold(
      backgroundColor: Colors.transparent, // Важно для Layout
      appBar: isWide ? null : AppBar(
        backgroundColor: Colors.white, elevation: 0,
        leading: const BackButton(color: AppColors.navy),
        title: const Text("Редактирование плана", style: TextStyle(color: AppColors.navy, fontWeight: FontWeight.bold, fontSize: 16)),
      ),
      body: Column(
        children: [
          if (isWide) 
            Padding(
              padding: const EdgeInsets.all(25),
              child: Row(
                children: [
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back_ios_new, size: 20)),
                  const Text("Просмотр и правка маршрута", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.navy)),
                ],
              ),
            ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: _steps.length,
              itemBuilder: (ctx, i) => _buildStepCard(i),
            ),
          ),
          _buildBottomAction(),
        ],
      ),
    );

    // Оборачиваем в Layout
    return MainDashboardLayout(
      selectedIndex: 1, // Секция "Цели"
      child: content,
    );
  }

  Widget _buildStepCard(int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(backgroundColor: AppColors.navy, radius: 12, child: Text("${index + 1}", style: const TextStyle(fontSize: 10, color: Colors.white))),
              const SizedBox(width: 15),
              Expanded(
                child: TextFormField(
                  initialValue: _steps[index].title,
                  decoration: const InputDecoration(border: InputBorder.none),
                  onChanged: (v) => _steps[index] = TaskDraftResponse(title: v, dueDate: _steps[index].dueDate),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_sweep, color: Colors.redAccent),
                onPressed: () => setState(() => _steps.removeAt(index)),
              ),
            ],
          ),
          const Divider(),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.calendar_today, size: 16),
            title: Text(DateFormat('dd.MM.yyyy').format(_steps[index].dueDate), style: const TextStyle(fontSize: 13)),
            trailing: const Text("ИЗМЕНИТЬ ДАТУ", style: TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.bold)),
            onTap: () async {
              final d = await showDatePicker(
                context: context, 
                initialDate: _steps[index].dueDate, 
                firstDate: DateTime.now(), 
                lastDate: widget.targetDate
              );
              if (d != null) setState(() => _steps[index] = TaskDraftResponse(title: _steps[index].title, dueDate: d));
            },
          )
        ],
      ),
    );
  }

  Widget _buildBottomAction() {
    return Container(
      padding: const EdgeInsets.all(25),
      decoration: const BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)]),
      child: SizedBox(
        width: double.infinity, height: 60,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
          onPressed: _isSaving ? null : _save,
          child: _isSaving 
            ? const CircularProgressIndicator(color: Colors.white)
            : const Text("ЗАПУСТИТЬ МАРШРУТ", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  void _save() async {
    if (_steps.isEmpty) return;
    setState(() => _isSaving = true);
    
    final uid = context.read<AuthProvider>().user!.id;
    bool ok = await context.read<GoalProvider>().addGoalWithSteps(
      title: widget.title, why: widget.why, result: widget.result, 
      date: widget.targetDate, goalType: widget.isSolo ? "Social" : "Group", 
      uid: uid, steps: _steps, isSolo: widget.isSolo
    );

    if (mounted) {
      setState(() => _isSaving = false);
      if (ok) Navigator.popUntil(context, (route) => route.isFirst);
    }
  }
}