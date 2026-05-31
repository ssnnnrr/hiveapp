import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/user_provider.dart';
import '../theme/app_theme.dart';
import '../models/all_models.dart';
import '../widgets/main_dashboard_layout.dart';
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
      backgroundColor: Colors.transparent,
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
                        
                        // ТЕПЕРЬ ТОЛЬКО ПАРТНЕРЫ (НА ВСЮ ШИРИНУ)
                        _buildStatCard(
                          "ВАШИ АКТИВНЫЕ ПАРТНЕРЫ", 
                          prov.friends.length.toString(), 
                          Icons.people_outline, 
                          Colors.blue,
                          onTap: () => _showMyPartnersModal(prov),
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
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.navy, 
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
                            ),
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

  // Широкий белый блок профиля
  Widget _buildMainInfoCard(UserProfileDto p) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04), 
            blurRadius: 20,
            offset: const Offset(0, 10)
          )
        ],
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
            style: const TextStyle(
              fontSize: 28, 
              fontWeight: FontWeight.w900, 
              color: AppColors.navy,
              letterSpacing: 0.5
            )
          ),
          const SizedBox(height: 5),
          Text(
            p.email, 
            style: const TextStyle(color: Colors.grey, fontSize: 15)
          ),
          const SizedBox(height: 25),
          
        ],
      ),
    );
  }

  // Широкая карточка статистики
  Widget _buildStatCard(String label, String value, IconData icon, Color col, {VoidCallback? onTap}) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(30),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: onTap != null ? Border.all(color: col.withOpacity(0.1), width: 2) : null,
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
          ),
          child: Row(
            children: [
              Icon(icon, color: col, size: 30),
              const SizedBox(width: 20),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
                  Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1)),
                ],
              ),
              const Spacer(),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  void _showMyPartnersModal(UserProvider prov) {
    MainDashboardLayout.showHiveDialog(
      context,
      Padding(
        padding: const EdgeInsets.all(25),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("МОИ ПАРТНЕРЫ", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: AppColors.navy)),
            const SizedBox(height: 15),
            if (prov.friends.isEmpty)
              const Center(child: Padding(padding: EdgeInsets.all(20), child: Text("У вас пока нет активных партнеров")))
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 400),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: prov.friends.length,
                  itemBuilder: (ctx, i) {
                    final friend = prov.friends[i];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundImage: friend.avatarUrl != null ? MemoryImage(base64Decode(friend.avatarUrl!)) : null,
                        child: friend.avatarUrl == null ? const Icon(Icons.person) : null,
                      ),
                      title: Text(friend.username, style: const TextStyle(fontWeight: FontWeight.bold)),
                      trailing: IconButton(
                        icon: const Icon(Icons.person_remove_rounded, color: Colors.redAccent),
                        onPressed: () => _confirmUnfriend(friend.id, friend.username),
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 20),
            SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text("ЗАКРЫТЬ"))),
          ],
        ),
      ),
    );
  }

  void _confirmUnfriend(int friendId, String name) {
    MainDashboardLayout.showHiveDialog(
      context,
      Padding(
        padding: const EdgeInsets.all(35),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 70),
            const SizedBox(height: 20),
            Text("УДАЛИТЬ СВЯЗЬ С $name?", textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
            const SizedBox(height: 15),
            const Text("Это действие удалит чат и все совместные задания. Это необратимо.", 
              textAlign: TextAlign.center, style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 35),
            Row(
              children: [
                Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text("ОТМЕНА"))),
                const SizedBox(width: 15),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                    onPressed: () async {
                      await context.read<UserProvider>().terminatePartnership(friendId, context);
                      if (mounted) {
                        Navigator.pop(context); // Закрыть предупреждение
                        Navigator.pop(context); // Закрыть список друзей
                      }
                    },
                    child: const Text("УДАЛИТЬ ВСЁ", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            )
          ],
        ),
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
                  decoration: BoxDecoration(color: color.withOpacity(0.05), borderRadius: BorderRadius.circular(10), border: Border.all(color: color.withOpacity(0.1))),
                  child: Text(s.skillName, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
                )).toList(),
          ),
        ],
      ),
    );
  }
}