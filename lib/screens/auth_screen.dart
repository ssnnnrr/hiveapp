import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../providers/auth_provider.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool isLogin = true;
  bool _obscurePassword = true;

  // Контроллеры для полей ввода
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

  // Метод отправки данных
  void _submit() async {
    final auth = context.read<AuthProvider>();

    // Валидация полей
    if (_emailCtrl.text.trim().isEmpty || _passCtrl.text.trim().isEmpty) {
      _showSnackBar("Пожалуйста, заполните все обязательные поля");
      return;
    }

    if (!isLogin) {
      if (_userCtrl.text.trim().isEmpty) {
        _showSnackBar("Введите имя пользователя");
        return;
      }
      if (_passCtrl.text != _confirmPassCtrl.text) {
        _showSnackBar("Пароли не совпадают");
        return;
      }
    }

    // Вызов методов провайдера
    bool success;
    if (isLogin) {
      success = await auth.login(
        _emailCtrl.text.trim(), 
        _passCtrl.text.trim()
      );
    } else {
      success = await auth.register(
        _userCtrl.text.trim(),
        _emailCtrl.text.trim(),
        _passCtrl.text.trim(),
      );
    }

    if (!mounted) return;

    if (success) {
      if (isLogin) {
        auth.completeAuth(); // Вход в приложение
      } else {
        setState(() => isLogin = true); // Переключение на вход после регистрации
        _showSnackBar("Регистрация успешна! Теперь войдите в аккаунт", isError: false);
      }
    } else {
      _showSnackBar("Произошла ошибка. Проверьте данные и попробуйте снова");
    }
  }

  void _showSnackBar(String message, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(20),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = context.watch<AuthProvider>().isLoading;
    final size = MediaQuery.of(context).size;
    final bool isWide = size.width > 900; // Проверка для Web/Desktop

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Row(
        children: [
          // Левая часть для широких экранов (Декор)
          if (isWide)
            Expanded(
              flex: 1,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.navy, AppColors.secondary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.hive_rounded, size: 120, color: Colors.white),
                    const SizedBox(height: 20),
                    Text(
                      "HIVE",
                      style: GoogleFonts.orbitron(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 10,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      "Платформа совместного роста",
                      style: GoogleFonts.manrope(
                        fontSize: 18,
                        color: Colors.white.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Правая часть (Форма)
          Expanded(
            flex: 1,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 450),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Логотип для мобильной версии
                      if (!isWide) ...[
                        const Center(
                          child: Icon(Icons.hive_rounded, size: 80, color: AppColors.primary),
                        ),
                        const SizedBox(height: 40),
                      ],

                      Text(
                        isLogin ? "С возвращением!" : "Создать аккаунт",
                        style: GoogleFonts.manrope(
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        isLogin 
                          ? "Войдите, чтобы продолжить работу" 
                          : "Зарегистрируйтесь, чтобы начать планирование",
                        style: AppTextStyles.caption,
                      ),
                      const SizedBox(height: 40),

                      // Поля ввода
                      if (!isLogin) ...[
                        _buildLabel("ИМЯ ПОЛЬЗОВАТЕЛЯ"),
                        TextField(
                          controller: _userCtrl,
                          decoration: AppDecorations.smartInput("Ваш никнейм", Icons.person_outline),
                        ),
                        const SizedBox(height: 20),
                      ],

                      _buildLabel("EMAIL"),
                      TextField(
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        decoration: AppDecorations.smartInput("example@mail.com", Icons.alternate_email_rounded),
                      ),
                      const SizedBox(height: 20),

                      _buildLabel("ПАРОЛЬ"),
                      TextField(
                        controller: _passCtrl,
                        obscureText: _obscurePassword,
                        decoration: AppDecorations.smartInput("••••••••", Icons.lock_outline_rounded).copyWith(
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword ? Icons.visibility_off : Icons.visibility,
                              color: Colors.grey,
                              size: 20,
                            ),
                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          ),
                        ),
                      ),

                      if (!isLogin) ...[
                        const SizedBox(height: 20),
                        _buildLabel("ПОДТВЕРЖДЕНИЕ ПАРОЛЯ"),
                        TextField(
                          controller: _confirmPassCtrl,
                          obscureText: _obscurePassword,
                          decoration: AppDecorations.smartInput("Повторите пароль", Icons.lock_reset_rounded),
                        ),
                      ],

                      const SizedBox(height: 40),

                      // Кнопка входа
                      SizedBox(
                        width: double.infinity,
                        height: 60,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.navy,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                            elevation: 0,
                          ),
                          onPressed: isLoading ? null : _submit,
                          child: isLoading
                              ? const SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                                )
                              : Text(
                                  isLogin ? "ВОЙТИ" : "ЗАРЕГИСТРИРОВАТЬСЯ",
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Переключатель режима
                      Center(
                        child: TextButton(
                          onPressed: () => setState(() => isLogin = !isLogin),
                          child: RichText(
                            text: TextSpan(
                              style: GoogleFonts.manrope(fontSize: 14, color: AppColors.textGrey),
                              children: [
                                TextSpan(text: isLogin ? "Впервые у нас? " : "Уже есть аккаунт? "),
                                TextSpan(
                                  text: isLogin ? "Создать профиль" : "Войти здесь",
                                  style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
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

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w900,
          color: AppColors.textGrey,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}