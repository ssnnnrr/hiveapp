import 'package:flutter/material.dart';
import 'package:hive_app/providers/event_provider.dart';
import 'package:hive_app/providers/goal_provider.dart';
import 'package:hive_app/providers/group_provider.dart';
import 'package:hive_app/providers/task_provider.dart';
import 'package:hive_app/providers/user_provider.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../providers/auth_provider.dart';
import 'main_screen.dart'; // ВАЖНЫЙ ИМПОРТ

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool isLogin = true;
  bool _obscurePassword = true;

  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _userCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _userCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

// В AuthScreen.dart измените метод _submit:

void _submit() async {
  final auth = context.read<AuthProvider>();

  if (_emailCtrl.text.trim().isEmpty || _passCtrl.text.trim().isEmpty) {
    _showSnackBar("Заполните все поля");
    return;
  }

  if (!isLogin && _passCtrl.text != _confirmPassCtrl.text) {
    _showSnackBar("Пароли не совпадают");
    return;
  }

  bool success;
  if (isLogin) {
    success = await auth.login(_emailCtrl.text.trim(), _passCtrl.text.trim());
  } else {
    success = await auth.register(_userCtrl.text.trim(), _emailCtrl.text.trim(), _passCtrl.text.trim());
  }

  if (!mounted) return;

  if (success) {
    if (isLogin) {
      // --- НОВАЯ ЛОГИКА: ФОНОВАЯ ПРЕДЗАГРУЗКА ДАННЫХ ---
      _prepareAppData(context);
      
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MainScreen()),
        (route) => false,
      );
    } else {
      setState(() => isLogin = true);
      _showSnackBar("Успех! Теперь войдите", isError: false);
    }
  } else {
    _showSnackBar("Ошибка входа. Проверьте почту/пароль");
  }
}

// Добавьте этот метод в _AuthScreenState:
Future<void> _prepareAppData(BuildContext context) async {
  final auth = context.read<AuthProvider>();
  final myId = auth.user?.id; // Получаем ID вошедшего пользователя
  
  if (myId == null) return;

  await Future.wait([
    context.read<TaskProvider>().loadAllTasks(),
    context.read<EventProvider>().loadEvents(),
    context.read<GroupProvider>().loadAllRoadmaps(),
    // ИСПРАВЛЕНИЕ: Передаем myId внутрь метода
    context.read<UserProvider>().loadMyProfile(myId), 
    context.read<GoalProvider>().loadGoals(myId),
  ]);
}

  void _showSnackBar(String m, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(m), backgroundColor: isError ? Colors.redAccent : Colors.green,
      behavior: SnackBarBehavior.floating, margin: const EdgeInsets.all(20),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = context.watch<AuthProvider>().isLoading;
    final bool isWide = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Row(
        children: [
          if (isWide)
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: [AppColors.navy, Color(0xFF0055BB)]),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.hive_rounded, size: 100, color: Colors.white),
                    const SizedBox(height: 20),
                    Text("HIVE", style: GoogleFonts.orbitron(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 8)),
                    const Text("Твой путь к целям", style: TextStyle(color: Colors.white70, fontSize: 18)),
                  ],
                ),
              ),
            ),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(40),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!isWide) const Center(child: Icon(Icons.hive_rounded, size: 60, color: AppColors.primary)),
                      const SizedBox(height: 30),
                      Text(isLogin ? "Вход" : "Регистрация", style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 30),
                      
                      if (!isLogin) ...[
                        _label("НИКНЕЙМ"),
                        TextField(controller: _userCtrl, decoration: const InputDecoration(hintText: "Username")),
                        const SizedBox(height: 20),
                      ],
                      
                      _label("EMAIL"),
                      TextField(controller: _emailCtrl, decoration: const InputDecoration(hintText: "mail@example.com")),
                      const SizedBox(height: 20),
                      
                      _label("ПАРОЛЬ"),
                      TextField(
                        controller: _passCtrl, 
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          hintText: "********",
                          suffixIcon: IconButton(
                            icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          )
                        ),
                      ),

                      if (!isLogin) ...[
                        const SizedBox(height: 20),
                        _label("ПОВТОР ПАРОЛЯ"),
                        TextField(controller: _confirmPassCtrl, obscureText: _obscurePassword),
                      ],
                      
                      const SizedBox(height: 40),
                      
                      SizedBox(
                        width: double.infinity, height: 60,
                        child: ElevatedButton(
                          onPressed: isLoading ? null : _submit,
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.navy, foregroundColor: Colors.white),
                          child: isLoading ? const CircularProgressIndicator(color: Colors.white) : Text(isLogin ? "ВОЙТИ" : "СОЗДАТЬ АККАУНТ"),
                        ),
                      ),
                      
                      const SizedBox(height: 20),
                      Center(child: TextButton(onPressed: () => setState(() => isLogin = !isLogin), child: Text(isLogin ? "Еще нет аккаунта? Зарегистрироваться" : "Уже есть профиль? Войти"))),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String t) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(t, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)));
}