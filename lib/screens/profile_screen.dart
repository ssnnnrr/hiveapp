import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/user_provider.dart';
import '../theme/app_theme.dart';
import '../models/all_models.dart';
import 'edit_profile_screen.dart';
import 'skill_catalog_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    final user = context.read<AuthProvider>().user;
    if (user != null) {
      context.read<UserProvider>().loadMyProfile(user.id);
      context.read<UserProvider>().loadFriends();
    }
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<UserProvider>();
    final profile = prov.myProfile;
    double width = MediaQuery.of(context).size.width;
    bool isWide = width > 800;

    return Scaffold(
      backgroundColor: isWide ? Colors.transparent : const Color(0xFFF0F2F5),
      body: (prov.isLoading || profile == null)
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async => _refresh(),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.symmetric(horizontal: isWide ? 0 : 20, vertical: 30),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 800),
                    child: Column(
                      children: [
                        _buildMainInfoCard(profile),
                        const SizedBox(height: 25),
                        
                        Row(
                          children: [
                            Expanded(child: _buildStatCard("ПАРТНЕРЫ", prov.friends.length.toString(), Icons.people_outline, Colors.blue)),
                            const SizedBox(width: 15),
                            Expanded(child: _buildStatCard("ОТЗЫВЫ", profile.reviews.length.toString(), Icons.star_outline, Colors.orange)),
                          ],
                        ),

                        const SizedBox(height: 25),
                        _buildSkillsSection("Я МОГУ НАУЧИТЬ", "Teaching", profile.skills, AppColors.navy),
                        const SizedBox(height: 15),
                        _buildSkillsSection("Я ХОЧУ ВЫУЧИТЬ", "Learning", profile.skills, Colors.green),
                        
                        const SizedBox(height: 35),
                        SizedBox(
                          width: double.infinity,
                          height: 60,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: AppColors.navy, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                            icon: const Icon(Icons.settings, color: Colors.white),
                            label: const Text("РЕДАКТИРОВАТЬ ПРОФИЛЬ", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfileScreen())).then((_) => _refresh()),
                          ),
                        ),
                        const SizedBox(height: 50),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildMainInfoCard(UserProfileDto p) {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 20)],
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 60,
            backgroundColor: Colors.grey.shade100,
            backgroundImage: p.avatarUrl != null ? MemoryImage(base64Decode(p.avatarUrl!)) : null,
            child: p.avatarUrl == null ? const Icon(Icons.person, size: 50, color: Colors.grey) : null,
          ),
          const SizedBox(height: 20),
          Text(p.username, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.navy)),
          Text(p.email, style: const TextStyle(color: Colors.grey, fontSize: 14)),
          const SizedBox(height: 25),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(width: 15),
              _buildBalanceBadge("⭐ ${p.rating.toStringAsFixed(1)} РЕЙТИНГ"),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildBalanceBadge(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(color: const Color(0xFFF8F9FB), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade100)),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: AppColors.navy)),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color col) {
    return Container(
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
      child: Column(
        children: [
          Icon(icon, color: col),
          const SizedBox(height: 10),
          Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
          Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1)),
        ],
      ),
    );
  }

  Widget _buildSkillsSection(String title, String type, List<UserSkillDto> skills, Color color) {
    final filtered = skills.where((s) => s.type == type).toList();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: color, letterSpacing: 1)),
              IconButton(
                icon: const Icon(Icons.add_circle_outline, size: 20),
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SkillCatalogScreen(type: type))).then((_) => _refresh()),
              )
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: filtered.isEmpty 
              ? [const Text("Навыки не добавлены", style: TextStyle(color: Colors.grey, fontSize: 13))]
              : filtered.map((s) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(10), border: Border.all(color: color.withValues(alpha: 0.1))),
                  child: Text(s.skillName, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
                )).toList(),
          ),
        ],
      ),
    );
  }
}