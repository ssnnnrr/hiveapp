import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/goal_provider.dart';
import '../theme/app_theme.dart';
import 'goal_preview_screen.dart';

class CreateGoalScreen extends StatefulWidget {
  const CreateGoalScreen({super.key});

  @override
  State<CreateGoalScreen> createState() => _CreateGoalScreenState();
}

class _CreateGoalScreenState extends State<CreateGoalScreen> {
  final _titleCtrl = TextEditingController();
  final _whyCtrl = TextEditingController();
  final _resultCtrl = TextEditingController();
  
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 30));
  bool _isSolo = true; // Только этот флаг управляет типом
  bool _isGenerating = false;

  void _onGenerate() async {
    if (_titleCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Укажите название вашей цели")));
      return;
    }
    setState(() => _isGenerating = true);
    
    final draft = await context.read<GoalProvider>().getDraftSteps(
      _titleCtrl.text.trim(), _whyCtrl.text.trim(), _resultCtrl.text.trim(), _selectedDate
    );
    
    setState(() => _isGenerating = false);

    if (mounted) {
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => GoalPreviewScreen(
          title: _titleCtrl.text.trim(), 
          why: _whyCtrl.text.trim(), 
          result: _resultCtrl.text.trim(),
          targetDate: _selectedDate, 
          isSolo: _isSolo, // Передаем только выбор из плашек
          initialSteps: draft,
        )
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: 0,
        leading: const BackButton(color: AppColors.navy),
        title: const Text("Новый маршрут", style: TextStyle(color: AppColors.navy, fontWeight: FontWeight.bold, fontSize: 16)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(25),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionLabel("1. ОСНОВНАЯ ИНФОРМАЦИЯ"),
                _buildInput("Название цели", _titleCtrl, Icons.flag_rounded),
                const SizedBox(height: 15),
                _buildInput("Ожидаемый результат", _resultCtrl, Icons.emoji_events_rounded),
                
                const SizedBox(height: 30),
                _sectionLabel("2. ФОРМАТ ЦЕЛИ"),
                Row(
                  children: [
                    _typeCard(true, "ЛИЧНАЯ", "Только для меня", Icons.person_outline),
                    const SizedBox(width: 15),
                    _typeCard(false, "ГРУППОВАЯ", "Общая работа", Icons.groups_outlined),
                  ],
                ),
                
                const SizedBox(height: 30),
                _sectionLabel("3. ДЕДЛАЙН"),
                _buildDatePicker(),
                
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity, height: 60,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.navy, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                    onPressed: _isGenerating ? null : _onGenerate,
                    child: _isGenerating 
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("СФОРМИРОВАТЬ ПЛАН С AI", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _typeCard(bool solo, String title, String sub, IconData icon) {
    bool isSelected = _isSolo == solo;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _isSolo = solo),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.navy : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: isSelected ? AppColors.navy : Colors.grey.shade200, width: 2),
          ),
          child: Column(
            children: [
              Icon(icon, color: isSelected ? Colors.white : Colors.grey, size: 30),
              const SizedBox(height: 10),
              Text(title, style: TextStyle(color: isSelected ? Colors.white : AppColors.navy, fontWeight: FontWeight.bold, fontSize: 12)),
              Text(sub, style: TextStyle(color: isSelected ? Colors.white70 : Colors.grey, fontSize: 10)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDatePicker() {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)),
      child: ListTile(
        leading: const Icon(Icons.calendar_today, color: AppColors.primary),
        title: Text(DateFormat('dd MMMM yyyy', 'ru').format(_selectedDate)),
        trailing: const Icon(Icons.chevron_right),
        onTap: () async {
          final d = await showDatePicker(
            context: context, 
            initialDate: _selectedDate, 
            firstDate: DateTime.now(), // НЕЛЬЗЯ В ПРОШЛОЕ
            lastDate: DateTime.now().add(const Duration(days: 365 * 5)), // МАКСИМУМ 5 ЛЕТ
          );
          if (d != null) setState(() => _selectedDate = d);
        },
      ),
    );
  }

  Widget _buildInput(String hint, TextEditingController ctrl, IconData icon) {
    return TextField(
      controller: ctrl,
      decoration: AppDecorations.smartInput(hint, icon),
    );
  }

  Widget _sectionLabel(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 10, left: 5),
    child: Text(t, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 10, color: Colors.grey, letterSpacing: 1.2)),
  );
}