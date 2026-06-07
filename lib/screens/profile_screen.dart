import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_app/screens/verification_test_screen.dart';
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
                        // 1. Основная информация (Имя, Почта, Аватар)
                        _buildMainInfoCard(profile),
                        const SizedBox(height: 25),

                        // 2. БЛОК АНАЛИТИКИ (ВЫЗОВ ДОБАВЛЕН ТУТ - Исправляет ошибку)
                        _buildAnalyticsSection(profile),
                        const SizedBox(height: 25),
                        
                        // 3. Статистика партнеров
                        _buildStatCard(
                          "ВАШИ АКТИВНЫЕ ПАРТНЕРЫ", 
                          prov.friends.length.toString(), 
                          Icons.people_outline, 
                          Colors.blue,
                          onTap: () => _showMyPartnersModal(prov),
                        ),

                        const SizedBox(height: 25),

                        // 4. Секции навыков
                        _buildSkillsSection("Я МОГУ НАУЧИТЬ", "Teaching", profile.skills, AppColors.navy),
                        const SizedBox(height: 15),
                        _buildSkillsSection("Я ХОЧУ ВЫУЧИТЬ", "Learning", profile.skills, Colors.green),
                        
                        const SizedBox(height: 35),

                        // 5. Кнопка настроек
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
            color: Colors.black.withValues(alpha:0.04), 
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


  Widget _buildSkillChip(UserSkillDto s, bool isMyProfile) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: s.isAiVerified ? Colors.blue.shade200 : Colors.grey.shade200),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(s.skillName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
        if (s.isAiVerified) ...[
          const SizedBox(width: 4),
          const Icon(Icons.verified, color: Colors.blue, size: 16), // СИНЯЯ ГАЛОЧКА
        ] else if (isMyProfile && s.type == "Teaching") ...[
          const SizedBox(width: 8),
          InkWell(
            onTap: () => _startVerification(s),
            child: const Icon(Icons.security_rounded, color: Colors.orange, size: 16), // Кнопка аттестации
          ),
        ],
      ],
    ),
  );
}


Widget _buildAnalyticsSection(UserProfileDto profile) {
  return InkWell(
    onTap: () => _showAllReviews(profile.reviews),
    borderRadius: BorderRadius.circular(24),
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: Colors.white, 
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha:0.02), blurRadius: 10)],
      ),
      child: Column(
        children: [
          const Text("ВАШ РЕЙТИНГ", 
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: Colors.grey, letterSpacing: 1.2)),
          const SizedBox(height: 15),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.star_rounded, color: Colors.amber, size: 40),
              const SizedBox(width: 10),
              Text(
                profile.rating.toStringAsFixed(1), 
                style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: AppColors.navy)
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            "На основе ${profile.reviews.length} отзывов",
            style: const TextStyle(color: Colors.grey, fontSize: 13),
          ),
          const SizedBox(height: 5),
          const Text(
            "Нажмите, чтобы прочитать отзывы", 
            style: TextStyle(color: Colors.blue, fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    ),
  );
}

// 1. Исправленный метод показа отзывов (исправлена опечатка в Colors.grey[50])
void _showAllReviews(List<ReviewDto> reviews) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
    ),
    builder: (ctx) => Column(
      children: [
        const SizedBox(height: 15),
        // Полоска вверху модального окна
        Container(
          width: 40, 
          height: 4, 
          decoration: BoxDecoration(
            color: Colors.grey[300], 
            borderRadius: BorderRadius.circular(10)
          )
        ),
        const Padding(
          padding: EdgeInsets.all(20),
          child: Text("ОТЗЫВЫ ПАРТНЕРОВ", 
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: AppColors.navy)),
        ),
        Expanded(
          child: reviews.isEmpty 
            ? const Center(child: Text("У вас пока нет отзывов"))
            : ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: reviews.length,
                itemBuilder: (ctx, i) => Container(
                  margin: const EdgeInsets.only(bottom: 15),
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: Colors.grey[50], // ОШИБКА ИСПРАВЛЕНА: удалено лишнее слово Nord
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.grey.shade100)
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const CircleAvatar(
                            radius: 15, 
                            backgroundColor: AppColors.accent,
                            child: Icon(Icons.person, size: 15, color: AppColors.navy)
                          ),
                          const SizedBox(width: 10),
                          Text(
                            reviews[i].reviewerName, 
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)
                          ),
                          const Spacer(),
                          Text(
                            reviews[i].rating.toString(),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const Icon(Icons.star_rounded, color: Colors.amber, size: 18),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        reviews[i].comment, 
                        style: const TextStyle(fontSize: 13, height: 1.4, color: Colors.black87)
                      ),
                    ],
                  ),
                ),
              ),
        ),
        const SizedBox(height: 20),
      ],
    ),
  );
}


void _startVerification(UserSkillDto s) async {
  // 1. Показываем модальное окно загрузки
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => Center(
      child: Container(
        padding: const EdgeInsets.all(30),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(25),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: AppColors.navy),
            const SizedBox(height: 20),
            Text(
              "Генерация теста...",
              style: GoogleFonts.manrope(
                fontWeight: FontWeight.bold,
                color: AppColors.navy,
                decoration: TextDecoration.none,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    ),
  );

  final prov = context.read<UserProvider>();
  
  // 2. Запрашиваем данные у сервера
  final testDataRaw = await prov.getVerificationTest(s.skillId);

  if (!mounted) return;
  
  // 3. Закрываем окно загрузки (обязательно перед навигацией или показом ошибки)
  Navigator.of(context, rootNavigator: true).pop();

  // 4. Проверяем, что сервер прислал данные
  if (testDataRaw != null && testDataRaw.isNotEmpty) {
    try {
      // Декодируем строку JSON в список
      final List<dynamic> questions = jsonDecode(testDataRaw);
      
      // КРИТИЧЕСКОЕ ИСПРАВЛЕНИЕ: Проверяем, не пустой ли список
      if (questions.isEmpty) {
        _showErrorSnackBar("ИИ вернул пустой список вопросов. Попробуйте еще раз.");
        return;
      }
      
      // 5. Если всё хорошо, переходим на экран теста
      Navigator.push(
        context, 
        MaterialPageRoute(
          builder: (_) => VerificationTestScreen(
            skillId: s.skillId, 
            skillName: s.skillName, 
            questions: questions,
          ),
        ),
      );
    } catch (e) {
      // Если JSON пришел «битый» или произошла ошибка парсинга
      debugPrint("Parsing Error: $e");
      _showErrorSnackBar("Ошибка в структуре теста. Попробуйте снова через минуту.");
    }
  } else {
    // Если сервер вообще ничего не прислал
    _showErrorSnackBar("Не удалось связаться с ИИ. Проверьте интернет-соединение.");
  }
}

// Вспомогательный метод для показа ошибок (если у вас его нет, добавьте ниже)
void _showErrorSnackBar(String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: Colors.redAccent,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.all(20),
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
            border: onTap != null ? Border.all(color: col.withValues(alpha:0.1), width: 2) : null,
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha:0.02), blurRadius: 10)],
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
  final auth = context.read<AuthProvider>();
  final isMyProfile = auth.user?.id == context.read<UserProvider>().myProfile?.id;

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
            if (isMyProfile)
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
            // ИСПРАВЛЕНО: Теперь вызываем _buildSkillChip
            : filtered.map((s) => _buildSkillChip(s, isMyProfile)).toList(),
        ),
      ],
    ),
  );
}
}