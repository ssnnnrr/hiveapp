import 'package:flutter/material.dart';
import 'package:hive_app/models/all_models.dart';
import 'package:intl/intl.dart';
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
  final TextEditingController _searchCtrl = TextEditingController();
  String _filter = "";

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    final user = context.read<AuthProvider>().user;
    if (user != null) context.read<GroupProvider>().loadGroups();
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<GroupProvider>();
    final auth = context.read<AuthProvider>();
    double width = MediaQuery.of(context).size.width;
    bool isWide = width > 800;

    // Фильтрация
    final filteredGroups = prov.groups.where((g) => 
      g.name.toLowerCase().contains(_filter.toLowerCase())).toList();

    return Scaffold(
      backgroundColor: isWide ? Colors.transparent : const Color(0xFFF8FAFD),
      body: prov.isLoading 
        ? const Center(child: CircularProgressIndicator())
        : Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isWide ? 60 : 20, 
              vertical: 30
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Заголовок
                _buildHeader(isWide),
                const SizedBox(height: 25),
                
                // Поиск
                _buildSearchBar(),
                const SizedBox(height: 25),
                
                // Список
                Expanded(
                  child: filteredGroups.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemCount: filteredGroups.length,
                        itemBuilder: (ctx, i) => _buildGroupCard(filteredGroups[i], auth.user?.id ?? 0),
                      ),
                ),
              ],
            ),
          ),
    );
  }

  Widget _buildHeader(bool isWide) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Обсуждения", 
          style: TextStyle(
            fontSize: isWide ? 32 : 26, 
            fontWeight: FontWeight.w900, 
            color: AppColors.navy,
            letterSpacing: -0.5
          )
        ),
        const SizedBox(height: 4),
        Text(
          "Ваши чаты и активные планы обучения", 
          style: TextStyle(fontSize: 14, color: Colors.grey.shade600, fontWeight: FontWeight.w500)
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha:0.03), blurRadius: 15, offset: const Offset(0, 5))],
      ),
      child: TextField(
        controller: _searchCtrl,
        onChanged: (v) => setState(() => _filter = v),
        decoration: InputDecoration(
          hintText: "Поиск по именам и чатам...",
          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
          prefixIcon: const Icon(Icons.search_rounded, color: Colors.grey),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 15),
        ),
      ),
    );
  }

  Widget _buildGroupCard(GroupResponse g, int myId) {
    bool hasUnread = g.unreadCount > 0;
    String time = g.lastMessageAt != null ? DateFormat('HH:mm').format(g.lastMessageAt!) : "";

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha:0.02), blurRadius: 10, offset: const Offset(0, 4))],
        border: Border.all(color: hasUnread ? AppColors.primary.withValues(alpha:0.1) : Colors.transparent),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () {
            
            Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(group: g)));
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Техно-аватар
                Stack(
                  children: [
                    Container(
                      width: 58, height: 58,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppColors.navy, AppColors.navy.withValues(alpha:0.7)],
                          begin: Alignment.topLeft, end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Center(
                        child: Text(
                          g.name[0].toUpperCase(), 
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 22)
                        ),
                      ),
                    ),
                    if (hasUnread)
                      Positioned(
                        right: -2, top: -2,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.redAccent, 
                            shape: BoxShape.circle, 
                            border: Border.all(color: Colors.white, width: 3)
                          ),
                          child: Text(
                            g.unreadCount.toString(), 
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 18),
                
                // Контент
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            g.name, 
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: AppColors.navy)
                          ),
                          Text(time, style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        g.lastMessage ?? (g.isSolo ? "Начните диалог" : "Группа: ${g.membersCount} участников"),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13, 
                          color: hasUnread ? AppColors.navy : Colors.grey.shade500,
                          fontWeight: hasUnread ? FontWeight.w700 : FontWeight.normal
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFFE2E8F0)),
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
          Icon(Icons.forum_outlined, size: 70, color: Colors.grey.withValues(alpha:0.2)),
          const SizedBox(height: 20),
          const Text("Пока нет обсуждений", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 5),
          const Text("Договоритесь обмене на бирже и чат появится здесь", style: TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }
}