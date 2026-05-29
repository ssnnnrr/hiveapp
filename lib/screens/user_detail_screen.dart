import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../providers/group_provider.dart';
import '../theme/app_theme.dart';
import '../models/all_models.dart';
import '../widgets/main_dashboard_layout.dart'; // ИМПОРТ
import 'chat_screen.dart';

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

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<UserProvider>();
    final profile = prov.targetFullProfile;
    final myProfile = prov.myProfile;
    
    double width = MediaQuery.of(context).size.width;
    bool isWide = width > 1000;

    Widget body = (prov.isLoading || profile == null)
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: Padding(
                  padding: EdgeInsets.all(isWide ? 40 : 20),
                  child: Column(
                    children: [
                      _buildMainHeader(profile),
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
                      _buildReviewsSection(profile),
                      const SizedBox(height: 120),
                    ],
                  ),
                ),
              ),
            ),
          );

    Widget content = Scaffold(
      backgroundColor: Colors.transparent,
      appBar: isWide ? null : AppBar(
        backgroundColor: Colors.white, elevation: 0.5,
        leading: const BackButton(color: AppColors.navy),
        title: Text(profile?.username ?? "Загрузка...", style: const TextStyle(color: AppColors.navy, fontWeight: FontWeight.bold, fontSize: 16)),
      ),
      body: body,
      bottomSheet: profile != null ? _buildActionDock(profile, isWide) : null,
    );

    return MainDashboardLayout(
      selectedIndex: 2, // Подсвечиваем "Биржа"
      child: content,
    );
  }

  // --- Вспомогательные виджеты ---
  
  Widget _buildActionDock(UserProfileDto p, bool isWide) {
    return Container(
      constraints: isWide ? const BoxConstraints(maxWidth: 900) : null,
      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white, 
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))]
      ),
      child: SafeArea(
        child: p.relationshipStatus == "Accepted"
          ? ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.navy, minimumSize: const Size(double.infinity, 60), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
              onPressed: () async {
                int? gId = await context.read<GroupProvider>().startDirectChat(p.id);
                if (gId != null && mounted) {
                   Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(group: GroupResponse(id: gId, name: p.username, ownerName: p.username, membersCount: 2, isSolo: true, otherUserId: p.id))));
                }
              },
              icon: const Icon(Icons.chat_bubble_rounded, color: Colors.white),
              label: const Text("ОТКРЫТЬ ОБСУЖДЕНИЕ", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            )
          : ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, minimumSize: const Size(double.infinity, 60), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
              onPressed: p.relationshipStatus == "Pending" ? null : () => context.read<UserProvider>().sendChatRequest(p.id),
              icon: Icon(p.relationshipStatus == "Pending" ? Icons.hourglass_top : Icons.bolt_rounded, color: Colors.white),
              label: Text(p.relationshipStatus == "Pending" ? "ЗАПРОС ОТПРАВЛЕН" : "ПРЕДЛОЖИТЬ ОБМЕН НАВЫКАМИ", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
      ),
    );
  }

  Widget _buildMainHeader(UserProfileDto p) {
    return Container(
      padding: const EdgeInsets.all(35),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30)),
      child: Column(
        children: [
          CircleAvatar(
            radius: 55,
            backgroundColor: Colors.grey.shade100,
            backgroundImage: p.avatarUrl != null ? MemoryImage(base64Decode(p.avatarUrl!)) : null,
            child: p.avatarUrl == null ? const Icon(Icons.person, size: 50, color: Colors.grey) : null,
          ),
          const SizedBox(height: 20),
          Text(p.username, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.navy)),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.star_rounded, color: Colors.orange, size: 24),
              const SizedBox(width: 5),
              Text(p.rating.toStringAsFixed(1), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMatchBanner() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Colors.amber.shade400, Colors.orange.shade400]),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Row(
        children: [
          Icon(Icons.bolt_rounded, color: Colors.white, size: 30),
          SizedBox(width: 15),
          Expanded(child: Text("ИДЕАЛЬНЫЙ МЭТЧ ДЛЯ ОБМЕНА!", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13))),
        ],
      ),
    );
  }

  Widget _buildSkillBlock(String title, List<UserSkillDto> skills, String type, Color col) {
    final filtered = skills.where((s) => s.type == type).toList();
    return Container(
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(25)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: col, letterSpacing: 1.5)),
          const SizedBox(height: 15),
          if (filtered.isEmpty) const Text("Не указано", style: TextStyle(color: Colors.grey, fontSize: 13))
          else Wrap(
            spacing: 8, runSpacing: 8,
            children: filtered.map((s) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: col.withOpacity(0.05), borderRadius: BorderRadius.circular(10)),
              child: Text(s.skillName, style: TextStyle(color: col, fontWeight: FontWeight.bold, fontSize: 11)),
            )).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewsSection(UserProfileDto p) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("ОТЗЫВЫ ПАРТНЕРОВ", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: Colors.grey, letterSpacing: 1.5)),
        const SizedBox(height: 15),
        if (p.reviews.isEmpty) const Center(child: Text("Отзывов пока нет"))
        else ...p.reviews.map((r) => Container(
          margin: const EdgeInsets.only(bottom: 15),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(r.reviewerName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  Row(children: List.generate(5, (i) => Icon(Icons.star_rounded, size: 14, color: i < r.rating ? Colors.orange : Colors.grey.shade200))),
                ],
              ),
              const SizedBox(height: 10),
              Text(r.comment ?? "", style: const TextStyle(fontSize: 13, height: 1.4, color: Colors.black87)),
            ],
          ),
        )),
      ],
    );
  }

  bool _isIdealMatch(UserProfileDto? me, UserProfileDto target) {
    if (me == null) return false;
    final myTeaching = me.skills.where((s) => s.type == "Teaching").map((s) => s.skillId).toSet();
    final targetLearning = target.skills.where((s) => s.type == "Learning").map((s) => s.skillId).toSet();
    return myTeaching.intersection(targetLearning).isNotEmpty;
  }
}