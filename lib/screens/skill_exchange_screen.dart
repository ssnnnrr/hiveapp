import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../theme/app_theme.dart';
import '../models/all_models.dart';
import 'user_detail_screen.dart';

class SkillExchangeScreen extends StatefulWidget {
  const SkillExchangeScreen({super.key});

  @override
  State<SkillExchangeScreen> createState() => _SkillExchangeScreenState();
}

class _SkillExchangeScreenState extends State<SkillExchangeScreen> {
  String _searchType =
      "Teaching"; // Тип поиска: Teaching (учителя) или Learning (ученики)
  int _selectedSkillId = 0;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Инициализация данных
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final prov = context.read<UserProvider>();
      prov.loadAllSkills();
      _onSearch();
    });
  }

  void _onSearch() {
    context.read<UserProvider>().searchPartners(
      _selectedSkillId == 0 ? null : _selectedSkillId,
      _searchType,
      query: _searchCtrl.text.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<UserProvider>();

    return Scaffold(
      backgroundColor: Colors.transparent, // Фон берется из MainScreen
      body: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ВЕРХНЯЯ ПАНЕЛЬ: Поиск и фильтры
            _buildSearchHeader(prov),
            const SizedBox(height: 30),

            // СЕТКА КАРТОЧЕК ПОЛЬЗОВАТЕЛЕЙ
            Expanded(
              child: prov.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : prov.searchResults.isEmpty
                  ? _buildEmptyState()
                  : GridView.builder(
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 380, // Ширина карточки в Вебе
                            mainAxisExtent: 320, // Высота карточки
                            crossAxisSpacing: 25,
                            mainAxisSpacing: 25,
                          ),
                      itemCount: prov.searchResults.length,
                      itemBuilder: (ctx, i) {
                        return _buildUserWebCard(prov.searchResults[i]);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // Метод для отображения состояния, когда ничего не найдено
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.person_search_rounded,
            size: 80,
            color: Colors.grey.withValues(alpha:0.2),
          ),
          const SizedBox(height: 20),
          const Text(
            "Партнеры не найдены",
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "Попробуйте изменить параметры поиска или тип навыка",
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
        ],
      ),
    );
  }

  // --- ПАНЕЛЬ ПОИСКА (WEB СТИЛЬ) ---
  Widget _buildSearchHeader(UserProvider prov) {
    return Container(
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 20,
          ),
        ],
      ),
      child: Row(
        children: [
          // Поле ввода имени
          Expanded(
            flex: 3,
            child: TextField(
              controller: _searchCtrl,
              onChanged: (_) => _onSearch(),
              decoration: AppDecorations.smartInput(
                "Поиск по имени или почте...",
                Icons.search_rounded,
              ),
            ),
          ),
          const SizedBox(width: 20),
          // Выбор навыка (Dropdown)
          Expanded(
            flex: 2,
            child: DropdownButtonFormField<int>(
              value: _selectedSkillId,
              decoration: AppDecorations.smartInput(
                "Категория навыка",
                Icons.psychology_rounded,
              ),
              items: [
                const DropdownMenuItem(
                  value: 0,
                  child: Text(
                    "Все компетенции",
                    style: TextStyle(fontSize: 14),
                  ),
                ),
                ...prov.allSkills.map(
                  (s) => DropdownMenuItem(
                    value: s.id,
                    child: Text(s.name, style: const TextStyle(fontSize: 14)),
                  ),
                ),
              ],
              onChanged: (val) {
                setState(() => _selectedSkillId = val ?? 0);
                _onSearch();
              },
            ),
          ),
          const SizedBox(width: 20),
          // Переключатель Учитель/Ученик
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                _buildToggleButton("Учителя", "Teaching"),
                _buildToggleButton("Ученики", "Learning"),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleButton(String label, String type) {
    bool isSelected = _searchType == type;
    return GestureDetector(
      onTap: () {
        setState(() => _searchType = type);
        _onSearch();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 5,
                  ),
                ]
              : [],
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? AppColors.navy : Colors.grey,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

Widget _buildUserWebCard(UserDto user) {
  bool isMatch = user.synergyLevel == "Ideal";
  
  return Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(
        color: isMatch ? Colors.amber.shade300 : Colors.transparent,
        width: 2,
      ),
      boxShadow: [
        BoxShadow(
          color: isMatch ? Colors.amber.withValues(alpha:0.1) : Colors.black.withValues(alpha:0.04),
          blurRadius: 20,
          offset: const Offset(0, 10),
        ),
      ],
    ),
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => UserDetailScreen(userId: user.id)),
        ),
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(25),
          child: Column(
            children: [
              // Метод отрисовки аватара и имени с галочкой
              _buildAvatarAndName(user), 
              
              const SizedBox(height: 15),

              // Блок реального рейтинга на основе отзывов
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _analyticChip(
                    Icons.star_rounded, 
                    user.rating > 0 ? user.rating.toStringAsFixed(1) : "0.0", 
                    Colors.amber
                  ),
                ],
              ),
              
              const Spacer(),
              if (isMatch) 
                _buildStatusBadge(
                  title: "ИДЕАЛЬНЫЙ МЭТЧ",
                  color: Colors.orange,
                  bgColor: Colors.amber.shade50,
                ) 
              else 
                const Text("", style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w500)),
              const Spacer(),

              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isMatch ? Colors.amber : AppColors.primary,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => UserDetailScreen(userId: user.id)),
                ),
                child: const Text("ПРОФИЛЬ", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

Widget _buildAvatarAndName(UserDto user) {
  return Column(
    children: [
      CircleAvatar(
        radius: 45,
        backgroundColor: Colors.grey.shade100,
        backgroundImage: user.avatarUrl != null
            ? MemoryImage(base64Decode(user.avatarUrl!))
            : null,
        child: user.avatarUrl == null
            ? const Icon(Icons.person, size: 40, color: Colors.grey)
            : null,
      ),
      const SizedBox(height: 15),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: Text(
              user.username,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: AppColors.navy),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // СИНЯЯ ГАЛОЧКА, если пройдена верификация навыка Teaching
          if (user.isVerified) 
            const Padding(
              padding: EdgeInsets.only(left: 6),
              child: Icon(Icons.verified, color: Colors.blue, size: 20),
            ),
        ],
      ),
    ],
  );
}

Widget _analyticChip(IconData icon, String label, Color col) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: col.withValues(alpha:0.1),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      children: [
        Icon(icon, size: 14, color: col),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: col)),
      ],
    ),
  );
}



Widget _buildStatusBadge({required String title, required Color color, required Color bgColor}) {
  return Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: bgColor, 
          borderRadius: BorderRadius.circular(12)
        ),
        child: Text(
          title,
          style: TextStyle(
            color: color, 
            fontSize: 10, 
            fontWeight: FontWeight.w900, 
            letterSpacing: 0.5
          ),
        ),
      ),
    ],
  );
}
}
