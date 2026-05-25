import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/group_provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import 'chat_screen.dart';

class GroupsScreen extends StatefulWidget {
  const GroupsScreen({super.key});
  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = context.read<AuthProvider>().user;
      if (user != null && mounted) context.read<GroupProvider>().loadGroups();
    });
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<GroupProvider>();
    double width = MediaQuery.of(context).size.width;
    bool isWide = width > 800;

    return Scaffold(
      backgroundColor: isWide ? Colors.transparent : const Color(0xFFF0F2F5),
      body: prov.isLoading 
        ? const Center(child: CircularProgressIndicator())
        : Padding(
            padding: EdgeInsets.all(isWide ? 40 : 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isWide) const Text("Ваши обсуждения", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.navy)),
                if (isWide) const SizedBox(height: 30),
                
                Expanded(
                  child: prov.groups.isEmpty
                    ? _buildEmptyState()
                    : GridView.builder(
                        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: isWide ? 400 : width,
                          mainAxisExtent: 100,
                          crossAxisSpacing: 15,
                          mainAxisSpacing: 15,
                        ),
                        itemCount: prov.groups.length,
                        itemBuilder: (context, i) {
                          final g = prov.groups[i];
                          return _buildGroupTile(context, g);
                        },
                      ),
                ),
              ],
            ),
          ),
    );
  }

  Widget _buildGroupTile(BuildContext context, g) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10)],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
        leading: CircleAvatar(
          radius: 25,
          backgroundColor: AppColors.primary.withValues(alpha: 0.1),
          child: Text(g.name[0].toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.navy)),
        ),
        title: Text(g.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        subtitle: Text(g.isSolo ? "Личный чат" : "Группа: ${g.membersCount} участников", style: const TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(group: g))),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline_rounded, size: 60, color: Colors.grey.withValues(alpha: 0.2)),
          const SizedBox(height: 15),
          const Text("У вас пока нет активных чатов", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}