import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../theme/app_theme.dart';
import '../models/all_models.dart';

class EditSkillsScreen extends StatelessWidget {
  const EditSkillsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<UserProvider>();
    double width = MediaQuery.of(context).size.width;
    bool isWide = width > 800;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: const Text("Компетенции и навыки", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        leading: const BackButton(),
        centerTitle: true,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: isWide ? 900 : double.infinity),
          child: Column(
            children: [
              // ИНФОРМАЦИОННЫЙ БЛОК
              Container(
                width: double.infinity,
                margin: const EdgeInsets.all(20),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.blue.withValues(alpha: 0.1)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: AppColors.primary),
                    SizedBox(width: 15),
                    Expanded(
                      child: Text(
                        "Выберите навыки, которыми вы владеете или которые хотите освоить. Это поможет системе найти идеальных партнеров для обмена.",
                        style: TextStyle(fontSize: 13, color: AppColors.navy, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),

              // СПИСОК НАВЫКОВ
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: prov.allSkills.length,
                  itemBuilder: (context, i) {
                    final skill = prov.allSkills[i];
                    return _buildSkillTile(context, skill, prov);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSkillTile(BuildContext context, SkillDto skill, UserProvider prov) {
    // Проверяем, есть ли уже этот навык у пользователя
    bool isLearning = prov.myProfile?.skills.any((s) => s.skillId == skill.id && s.type == "Learning") ?? false;
    bool isTeaching = prov.myProfile?.skills.any((s) => s.skillId == skill.id && s.type == "Teaching") ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10)],
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(skill.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.navy)),
          ),
          _skillActionBtn(
            context: context,
            label: "ХОЧУ ВЫУЧИТЬ",
            icon: Icons.school_outlined,
            color: AppColors.primary,
            isActive: isLearning,
            onTap: () => prov.addSkillToMe(skill.id, "Learning"),
          ),
          const SizedBox(width: 10),
          _skillActionBtn(
            context: context,
            label: "МОГУ НАУЧИТЬ",
            icon: Icons.psychology_outlined,
            color: Colors.green,
            isActive: isTeaching,
            onTap: () => prov.addSkillToMe(skill.id, "Teaching"),
          ),
        ],
      ),
    );
  }

  Widget _skillActionBtn({
    required BuildContext context,
    required String label,
    required IconData icon,
    required Color color,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? color : color.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isActive ? color : color.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: isActive ? Colors.white : color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 10, 
                fontWeight: FontWeight.w900, 
                color: isActive ? Colors.white : color
              ),
            ),
          ],
        ),
      ),
    );
  }
}