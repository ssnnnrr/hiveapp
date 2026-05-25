import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../theme/app_theme.dart';
import '../models/all_models.dart';

class SkillCatalogScreen extends StatefulWidget {
  final String type; // "Teaching" или "Learning"
  const SkillCatalogScreen({super.key, required this.type});

  @override
  State<SkillCatalogScreen> createState() => _SkillCatalogScreenState();
}

class _SkillCatalogScreenState extends State<SkillCatalogScreen> {
  List<int> _tempSelectedIds = [];
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final prov = context.read<UserProvider>();
    // Предварительно заполняем список уже выбранными навыками пользователя
    _tempSelectedIds = prov.myProfile?.skills
            .where((s) => s.type == widget.type)
            .map((s) => s.skillId)
            .toList() ?? [];
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<UserProvider>();
    double width = MediaQuery.of(context).size.width;
    bool isWide = width > 800;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          widget.type == "Teaching" ? "Я могу научить" : "Я хочу изучить",
          style: const TextStyle(color: AppColors.navy, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        centerTitle: true,
        leading: const BackButton(color: AppColors.navy),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: isWide ? 1000 : double.infinity),
          child: Column(
            children: [
              _buildHeaderInfo(),
              Expanded(
                child: prov.allSkills.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : GridView.builder(
                        padding: const EdgeInsets.all(20),
                        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: isWide ? 300 : width,
                          mainAxisExtent: 80,
                          crossAxisSpacing: 15,
                          mainAxisSpacing: 15,
                        ),
                        itemCount: prov.allSkills.length,
                        itemBuilder: (context, i) {
                          final skill = prov.allSkills[i];
                          bool isSelected = _tempSelectedIds.contains(skill.id);
                          return _buildSkillCard(skill, isSelected);
                        },
                      ),
              ),
              _buildFooterButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderInfo() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      color: AppColors.primary.withValues(alpha: 0.05),
      child: Text(
        "Выберите навыки из списка ниже. Мы будем использовать их для поиска партнеров с противоположными интересами.",
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 12, color: AppColors.navy.withValues(alpha: 0.7), fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildSkillCard(SkillDto skill, bool isSelected) {
    return InkWell(
      onTap: () {
        setState(() {
          if (isSelected) _tempSelectedIds.remove(skill.id);
          else _tempSelectedIds.add(skill.id);
        });
      },
      borderRadius: BorderRadius.circular(15),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.navy : Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: isSelected ? AppColors.navy : Colors.grey.shade200),
          boxShadow: [if (!isSelected) BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 5)],
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                skill.name,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: isSelected ? Colors.white : AppColors.navy,
                ),
              ),
            ),
            Icon(
              isSelected ? Icons.check_circle_rounded : Icons.add_circle_outline_rounded,
              color: isSelected ? Colors.white : Colors.grey.shade300,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooterButton() {
    return Container(
      padding: const EdgeInsets.all(30),
      decoration: const BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)]),
      child: SizedBox(
        width: double.infinity,
        height: 60,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.navy, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
          onPressed: _isSaving ? null : _save,
          child: _isSaving 
            ? const CircularProgressIndicator(color: Colors.white)
            : const Text("СОХРАНИТЬ ВЫБОР", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        ),
      ),
    );
  }

  void _save() async {
    setState(() => _isSaving = true);
    await context.read<UserProvider>().saveSkills(_tempSelectedIds, widget.type);
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Навыки успешно обновлены!")));
    }
  }
}