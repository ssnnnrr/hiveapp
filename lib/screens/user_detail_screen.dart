import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../providers/group_provider.dart';
import '../theme/app_theme.dart';
import '../models/all_models.dart';
import '../widgets/main_dashboard_layout.dart';
import 'chat_screen.dart';
import 'main_screen.dart';

class UserDetailScreen extends StatefulWidget {
  final int userId;
  const UserDetailScreen({super.key, required this.userId});

  @override
  State<UserDetailScreen> createState() => _UserDetailScreenState();
}

class _UserDetailScreenState extends State<UserDetailScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      context.read<UserProvider>().loadTargetProfile(widget.userId);
    });
  }

  // Навигация из верхнего меню (сброс стека до нужной вкладки)
  void _handleNavigation(int index) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => MainScreen(initialIndex: index)),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<UserProvider>();
    final profile = prov.targetFullProfile;
    final myProfile = prov.myProfile;
    
    double width = MediaQuery.of(context).size.width;
    bool isWide = width > 1000;

    if (prov.isLoading || profile == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return MainDashboardLayout(
      selectedIndex: 2, 
      onTabSelected: _handleNavigation,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: isWide ? null : AppBar(
          backgroundColor: Colors.white,
          leading: const BackButton(color: AppColors.navy),
          title: Text(profile.username),
        ),
        body: SingleChildScrollView(
          padding: EdgeInsets.all(isWide ? 40 : 20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: Column(
                children: [
                  _buildMainHeader(profile),
                  const SizedBox(height: 25),
                  
                  _buildInfoTile(
                    icon: Icons.verified_user_rounded,
                    title: "Статус аккаунта",
                    subtitle: "Пользователь подтвержден и готов к обмену навыками",
                  ),
                  const SizedBox(height: 25),
                  
                  if (_isIdealMatch(myProfile, profile)) _buildMatchBanner(),
                  
                  const SizedBox(height: 25),
                  
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _buildSkillBlock("ОБУЧАЕТ", profile.skills, "Teaching", AppColors.navy)),
                      const SizedBox(width: 20),
                      Expanded(child: _buildSkillBlock("ИЗУЧАЕТ", profile.skills, "Learning", Colors.green)),
                    ],
                  ),

                  const SizedBox(height: 30),

                  // ВСТАВЬТЕ ЭТО ЗДЕСЬ (решает проблему unused_element):
                  _buildTeacherPortfolio(profile), 

                  const SizedBox(height: 120),
                ],
              ),
            ),
          ),
        ),
        bottomSheet: _buildActionDock(profile, isWide),
      ),
    );
  }


 Widget _buildTeacherPortfolio(UserProfileDto profile) {
  // Показываем портфолио только если пользователь обучает чему-то (есть навыки типа Teaching)
  final teachingSkills = profile.skills.where((s) => s.type == "Teaching").toList();

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        "ПОРТФОЛИО МАТЕРИАЛОВ", 
        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: AppColors.navy, letterSpacing: 1.5)
      ),
      const SizedBox(height: 15),
      teachingSkills.isEmpty 
        ? const Text("Портфолио формируется после первых завершенных обменов", 
            style: TextStyle(color: Colors.grey, fontSize: 12))
        : SizedBox(
            height: 130,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: teachingSkills.length,
              itemBuilder: (ctx, i) => _portfolioCard(teachingSkills[i].skillName),
            ),
          ),
    ],
  );
}

Widget _portfolioCard(String title) {
  return Container(
    width: 220,
    margin: const EdgeInsets.only(right: 15, bottom: 5),
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: AppColors.primary.withValues(alpha:0.1)),
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha:0.02), blurRadius: 10)],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.menu_book_rounded, color: AppColors.primary, size: 22),
        const Spacer(),
        Text(
          title, 
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.navy), 
          maxLines: 2, 
          overflow: TextOverflow.ellipsis
        ),
        const SizedBox(height: 4),
        const Text("Авторский курс обучения", style: TextStyle(color: Colors.grey, fontSize: 10)),
      ],
    ),
  );
}

  // Вспомогательная карточка информации
  Widget _buildInfoTile({required IconData icon, required String title, required String subtitle}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha:0.02), blurRadius: 10)]
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: const Color(0xFFF1F5F9),
            child: Icon(icon, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Широкий метод хедера (Возвращен по просьбе)
  Widget _buildMainHeader(UserProfileDto p) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white, 
        borderRadius: BorderRadius.circular(30),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha:0.03), blurRadius: 20)]
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 65,
            backgroundColor: Colors.grey.shade100,
            backgroundImage: p.avatarUrl != null 
                ? MemoryImage(base64Decode(p.avatarUrl!)) 
                : null,
            child: p.avatarUrl == null 
                ? const Icon(Icons.person, size: 60, color: Colors.grey) 
                : null,
          ),
          const SizedBox(height: 25),
          Text(
            p.username, 
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: AppColors.navy)
          ),
          const SizedBox(height: 12),
        
        ],
      ),
    );
  }

  Widget _buildMatchBanner() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Colors.amber.shade400, Colors.orange.shade400]),
        borderRadius: BorderRadius.circular(20)
      ),
      child: const Row(
        children: [
          Icon(Icons.bolt_rounded, color: Colors.white, size: 30),
          SizedBox(width: 15),
          Expanded(child: Text("ИДЕАЛЬНЫЙ МЭТЧ ДЛЯ ОБМЕНА!", 
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13))),
        ],
      ),
    );
  }

Widget _buildSkillBlock(String title, List<UserSkillDto> skills, String type, Color col) {
  final filtered = skills.where((s) => s.type == type).toList();
  
  return Container(
    padding: const EdgeInsets.all(25),
    decoration: BoxDecoration(
      color: Colors.white, 
      borderRadius: BorderRadius.circular(25),
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha:0.02), blurRadius: 10)]
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title, 
          style: TextStyle(
            fontWeight: FontWeight.w900, 
            fontSize: 11, 
            color: col, 
            letterSpacing: 1.5
          )
        ),
        const SizedBox(height: 15),
        if (filtered.isEmpty) 
          const Text("Не указано", style: TextStyle(color: Colors.grey, fontSize: 13))
        else 
          Wrap(
            spacing: 8, 
            runSpacing: 8,
            children: filtered.map((s) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: col.withValues(alpha:0.05), 
                borderRadius: BorderRadius.circular(10),
                // Если навык верифицирован ИИ, подсвечиваем рамку синим
                border: Border.all(
                  color: s.isAiVerified ? Colors.blue.shade200 : Colors.transparent,
                  width: 1
                )
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    s.skillName, 
                    style: TextStyle(color: col, fontWeight: FontWeight.bold, fontSize: 11)
                  ),
                  // ГАЛОЧКА ВЕРИФИКАЦИИ (Этап 3)
                  if (s.isAiVerified) ...[
                    const SizedBox(width: 4),
                    const Icon(Icons.verified, color: Colors.blue, size: 14),
                  ],
                ],
              ),
            )).toList(),
          ),
      ],
    ),
  );
}

  Widget _buildActionDock(UserProfileDto p, bool isWide) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white, 
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha:0.05), blurRadius: 10, offset: const Offset(0, -5))]
      ),
      child: SafeArea(
        child: p.relationshipStatus == "Accepted"
          ? ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.navy, 
                minimumSize: const Size(double.infinity, 60), 
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
              ),
              onPressed: () async {
                int? gId = await context.read<GroupProvider>().startDirectChat(p.id);
                if (gId != null && mounted) {
// ИСПРАВЛЕННЫЙ БЛОК НАВИГАЦИИ:
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (_) => ChatScreen(
      group: GroupResponse(
        id: gId,
        name: p.username,
        ownerName: p.username,
        ownerId: p.id, // ДОБАВЛЕНО: теперь аргумент присутствует
        membersCount: 2,
        isSolo: true,
        otherUserId: p.id,
      ),
    ),
  ),
);                }
              },
              icon: const Icon(Icons.chat_bubble_rounded, color: Colors.white),
              label: const Text("ОТКРЫТЬ ОБСУЖДЕНИЕ", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            )
          : ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary, 
                minimumSize: const Size(double.infinity, 60), 
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
              ),
              onPressed: p.relationshipStatus == "Pending" ? null : () => context.read<UserProvider>().sendChatRequest(p.id),
              icon: Icon(p.relationshipStatus == "Pending" ? Icons.hourglass_top : Icons.bolt_rounded, color: Colors.white),
              label: Text(p.relationshipStatus == "Pending" ? "ЗАПРОС ОТПРАВЛЕН" : "ПРЕДЛОЖИТЬ ОБМЕН НАВЫКАМИ", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
      ),
    );
  }

  bool _isIdealMatch(UserProfileDto? me, UserProfileDto target) {
    if (me == null) return false;
    final myTeaching = me.skills.where((s) => s.type == "Teaching").map((s) => s.skillId).toSet();
    final targetLearning = target.skills.where((s) => s.type == "Learning").map((s) => s.skillId).toSet();
    return myTeaching.intersection(targetLearning).isNotEmpty;
  }
}