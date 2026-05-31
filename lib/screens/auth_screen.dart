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
import 'main_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with SingleTickerProviderStateMixin {
  bool isLogin = true;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  
  // Состояния ошибок (только для регистрации)
  String? _emailError;
  String? _passwordError;
  String? _usernameError;
  String? _confirmPasswordError;
  
  // Сила пароля (только для регистрации)
  double _passwordStrength = 0;
  String _passwordStrengthText = '';
  Color _passwordStrengthColor = Colors.transparent;
  
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _userCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  
  final _emailFocus = FocusNode();
  final _passFocus = FocusNode();
  final _userFocus = FocusNode();
  final _confirmPassFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));
    
    _animationController.forward();
    
    // Слушатели для валидации (только при регистрации)
    _passCtrl.addListener(_checkPasswordStrength);
    _emailCtrl.addListener(_validateEmail);
    _userCtrl.addListener(_validateUsername);
    _confirmPassCtrl.addListener(_validateConfirmPassword);
  }

  @override
  void dispose() {
    _passCtrl.removeListener(_checkPasswordStrength);
    _emailCtrl.removeListener(_validateEmail);
    _userCtrl.removeListener(_validateUsername);
    _confirmPassCtrl.removeListener(_validateConfirmPassword);
    
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _userCtrl.dispose();
    _confirmPassCtrl.dispose();
    _emailFocus.dispose();
    _passFocus.dispose();
    _userFocus.dispose();
    _confirmPassFocus.dispose();
    _animationController.dispose();
    super.dispose();
  }

  // Валидация email (только для регистрации)
  void _validateEmail() {
    if (isLogin) return;
    
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      setState(() => _emailError = 'Логин обязателен');
      return;
    }
    
    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    if (!emailRegex.hasMatch(email)) {
      setState(() => _emailError = 'Введите корректный логин');
      return;
    }
    
    setState(() => _emailError = null);
  }

  // Валидация username (только для регистрации)
  void _validateUsername() {
    if (isLogin) return;
    
    final username = _userCtrl.text.trim();
    
    if (username.isEmpty) {
      setState(() => _usernameError = 'Никнейм обязателен');
      return;
    }
    
    if (username.length < 3) {
      setState(() => _usernameError = 'Минимум 3 символа');
      return;
    }
    
    if (username.length > 20) {
      setState(() => _usernameError = 'Максимум 20 символов');
      return;
    }
    
    // Разрешаем буквы (включая русские), цифры, пробелы и _
    final usernameRegex = RegExp(r'^[a-zA-Zа-яА-ЯёЁ0-9_\s]+$');
    if (!usernameRegex.hasMatch(username)) {
      setState(() => _usernameError = 'Только буквы, цифры, пробелы и _');
      return;
    }
    
    setState(() => _usernameError = null);
  }

  // Проверка силы пароля (только для регистрации)
  void _checkPasswordStrength() {
    if (isLogin) return;
    
    final password = _passCtrl.text;
    if (password.isEmpty) {
      setState(() {
        _passwordStrength = 0;
        _passwordStrengthText = '';
        _passwordStrengthColor = Colors.transparent;
        _passwordError = 'Пароль обязателен';
      });
      return;
    }
    
    if (password.length < 7) {
      setState(() {
        _passwordStrength = 0.2;
        _passwordStrengthText = 'Слишком короткий';
        _passwordStrengthColor = Colors.red;
        _passwordError = 'Минимум 7 символов';
      });
      return;
    }
    
    double strength = 0;
    
    if (password.length >= 7) strength += 0.2;
    if (password.length >= 10) strength += 0.1;
    if (RegExp(r'\d').hasMatch(password)) strength += 0.2;
    if (RegExp(r'[A-ZА-ЯЁ]').hasMatch(password)) strength += 0.2;
    if (RegExp(r'[a-zа-яё]').hasMatch(password)) strength += 0.15;
    if (RegExp(r'[!@#\$%^&*(),.?":{}|<>]').hasMatch(password)) strength += 0.15;
    
    String text;
    Color color;
    
    if (strength <= 0.3) {
      text = 'Слабый';
      color = Colors.red;
    } else if (strength <= 0.6) {
      text = 'Средний';
      color = Colors.orange;
    } else if (strength <= 0.8) {
      text = 'Хороший';
      color = Colors.lightGreen;
    } else {
      text = 'Надежный';
      color = Colors.green;
    }
    
    setState(() {
      _passwordStrength = strength.clamp(0.0, 1.0);
      _passwordStrengthText = text;
      _passwordStrengthColor = color;
      _passwordError = null;
    });
  }

  // Проверка подтверждения пароля (только для регистрации)
  void _validateConfirmPassword() {
    if (isLogin) return;
    
    final confirmPass = _confirmPassCtrl.text;
    if (confirmPass.isEmpty) {
      setState(() => _confirmPasswordError = 'Подтвердите пароль');
      return;
    }
    
    if (confirmPass != _passCtrl.text) {
      setState(() => _confirmPasswordError = 'Пароли не совпадают');
      return;
    }
    
    setState(() => _confirmPasswordError = null);
  }

  // Валидация формы
  bool _validateForm() {
    // Для авторизации - минимальная проверка
    if (isLogin) {
      if (_emailCtrl.text.trim().isEmpty || _passCtrl.text.trim().isEmpty) {
        _showSnackBar("Заполните все поля");
        return false;
      }
      return true;
    }
    
    // Для регистрации - полная проверка
    bool isValid = true;
    
    _validateEmail();
    if (_emailError != null) isValid = false;
    
    _checkPasswordStrength();
    if (_passwordError != null) isValid = false;
    
    _validateUsername();
    if (_usernameError != null) isValid = false;
    
    _validateConfirmPassword();
    if (_confirmPasswordError != null) isValid = false;
    
    return isValid;
  }

  void _submit() async {
    FocusScope.of(context).unfocus();
    
    if (!_validateForm()) {
      if (!isLogin) {
        _showSnackBar("Исправьте ошибки в форме");
      }
      return;
    }

    final auth = context.read<AuthProvider>();
    setState(() => _isLoading = true);

    try {
      bool success;
      if (isLogin) {
        success = await auth.login(
          _emailCtrl.text.trim(), 
          _passCtrl.text.trim(),
        );
        
        if (success && mounted) {
          await _prepareAppData(context);
          
          if (!mounted) return;
          
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const MainScreen()),
            (route) => false,
          );
        } else if (mounted) {
          setState(() => _isLoading = false);
          _showSnackBar("Неверный логин или пароль");
        }
      } else {
        success = await auth.register(
          _userCtrl.text.trim(), 
          _emailCtrl.text.trim(), 
          _passCtrl.text.trim(),
        );
        
        if (success && mounted) {
          setState(() {
            isLogin = true;
            _isLoading = false;
            _emailError = null;
            _passwordError = null;
            _usernameError = null;
            _confirmPasswordError = null;
            _passwordStrength = 0;
            _passwordStrengthText = '';
            _passwordStrengthColor = Colors.transparent;
          });
          _showSnackBar("🎉 Аккаунт создан! Теперь войдите", isError: false);
          _animationController.reset();
          _animationController.forward();
        } else if (mounted) {
          setState(() => _isLoading = false);
          _showSnackBar("Ошибка регистрации. Возможно, логин уже используется");
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnackBar("Произошла ошибка. Попробуйте позже");
      }
    }
  }

  Future<void> _prepareAppData(BuildContext context) async {
    final auth = context.read<AuthProvider>();
    final myId = auth.user?.id;
    
    if (myId == null) return;

    try {
      await Future.wait([
        context.read<TaskProvider>().loadAllTasks(),
        context.read<EventProvider>().loadEvents(),
        context.read<GroupProvider>().loadAllRoadmaps(),
        context.read<UserProvider>().loadMyProfile(myId),
        context.read<GoalProvider>().loadGoals(myId),
      ]);
    } catch (e) {
      debugPrint('Error loading data: $e');
    }
  }

  void _showSnackBar(String m, {bool isError = true}) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(m, style: const TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authLoading = context.watch<AuthProvider>().isLoading;
    final bool isWide = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Row(
        children: [
          if (isWide)
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF0A0E21),
                      Color(0xFF1A237E),
                      Color(0xFF0D47A1),
                    ],
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      top: -100,
                      right: -100,
                      child: Container(
                        width: 300,
                        height: 300,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withOpacity(0.1),
                            width: 30,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: -50,
                      left: -50,
                      child: Container(
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withOpacity(0.05),
                            width: 20,
                          ),
                        ),
                      ),
                    ),
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0.0, end: 1.0),
                            duration: const Duration(milliseconds: 1500),
                            builder: (context, value, child) {
                              return Transform.scale(scale: value, child: child);
                            },
                            child: Container(
                              padding: const EdgeInsets.all(30),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withOpacity(0.1),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.2),
                                  width: 2,
                                ),
                              ),
                              child: const Icon(
                                Icons.hive_rounded,
                                size: 80,
                                color: Colors.amber,
                              ),
                            ),
                          ),
                          const SizedBox(height: 40),
                          Text(
                            "HIVE",
                            style: GoogleFonts.orbitron(
                              fontSize: 56,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 12,
                            ),
                          ),
                          const SizedBox(height: 15),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: Colors.white.withOpacity(0.2),
                              ),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              "ТВОЙ ПУТЬ К ЦЕЛЯМ",
                              style: GoogleFonts.orbitron(
                                fontSize: 12,
                                color: Colors.white70,
                                letterSpacing: 3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Expanded(
            child: Container(
              color: Colors.white,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 450),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(40),
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: SlideTransition(
                        position: _slideAnimation,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (!isWide) ...[
                              Center(
                                child: Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppColors.primary.withOpacity(0.1),
                                  ),
                                  child: const Icon(
                                    Icons.hive_rounded,
                                    size: 50,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 30),
                            ],
                            
                            Text(
                              isLogin ? "С возвращением!" : "Присоединяйся!",
                              style: GoogleFonts.orbitron(
                                fontSize: 32,
                                fontWeight: FontWeight.w900,
                                color: AppColors.navy,
                                letterSpacing: 2,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              isLogin 
                                ? "Войди, чтобы продолжить свой путь" 
                                : "Создай аккаунт и начни достигать цели",
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade500,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 40),
                            
                            // Поля ввода
                            if (!isLogin) ...[
                              _buildInputField(
                                controller: _userCtrl,
                                focusNode: _userFocus,
                                label: "НИКНЕЙМ",
                                hint: "Придумайте username",
                                icon: Icons.person_outline_rounded,
                                errorText: _usernameError,
                                showValidation: !isLogin,
                              ),
                              const SizedBox(height: 20),
                            ],
                            
                            _buildInputField(
                              controller: _emailCtrl,
                              focusNode: _emailFocus,
                              label: "ЛОГИН",
                              hint: "mail@example.com",
                              icon: Icons.email_outlined,
                              keyboardType: TextInputType.emailAddress,
                              errorText: !isLogin ? _emailError : null,
                              showValidation: !isLogin,
                            ),
                            const SizedBox(height: 20),
                            
                            _buildInputField(
                              controller: _passCtrl,
                              focusNode: _passFocus,
                              label: "ПАРОЛЬ",
                              hint: isLogin ? "Введите пароль" : "Минимум 7 символов",
                              icon: Icons.lock_outline_rounded,
                              isPassword: true,
                              obscureText: _obscurePassword,
                              onToggleVisibility: () => setState(() => _obscurePassword = !_obscurePassword),
                              errorText: !isLogin ? _passwordError : null,
                              showValidation: !isLogin,
                            ),
                            
                            // Индикатор силы пароля (только при регистрации)
                            if (!isLogin && _passCtrl.text.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              _buildPasswordStrengthIndicator(),
                            ],
                            
                            if (!isLogin) ...[
                              const SizedBox(height: 20),
                              _buildInputField(
                                controller: _confirmPassCtrl,
                                focusNode: _confirmPassFocus,
                                label: "ПОВТОР ПАРОЛЯ",
                                hint: "Повторите пароль",
                                icon: Icons.lock_outline_rounded,
                                isPassword: true,
                                obscureText: _obscureConfirmPassword,
                                onToggleVisibility: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                                errorText: _confirmPasswordError,
                                showValidation: true,
                              ),
                            ],
                            
                            const SizedBox(height: 40),
                            
                            // Кнопка
                            SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: ElevatedButton(
                                onPressed: (_isLoading || authLoading) ? null : _submit,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.navy,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  disabledBackgroundColor: Colors.grey.shade300,
                                ),
                                child: (_isLoading || authLoading)
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Row(
  mainAxisAlignment: MainAxisAlignment.center,
  children: [
    Text(
      isLogin ? "ВОЙТИ" : "СОЗДАТЬ АККАУНТ",
      style: GoogleFonts.orbitron(
        fontSize: 14,
        fontWeight: FontWeight.bold,
        letterSpacing: 2,
      ),
    ),
    // Иконка показывается ТОЛЬКО при регистрации
    if (!isLogin) ...[
      const SizedBox(width: 10),
      const Icon(Icons.person_add_rounded, size: 20),
    ],
  ],
),
                              ),
                            ),
                            
                            const SizedBox(height: 30),
                            
                            Center(
                              child: TextButton(
                                onPressed: () {
                                  setState(() {
                                    isLogin = !isLogin;
                                    _emailError = null;
                                    _passwordError = null;
                                    _usernameError = null;
                                    _confirmPasswordError = null;
                                    _passwordStrength = 0;
                                    _passwordStrengthText = '';
                                    _passwordStrengthColor = Colors.transparent;
                                    _emailCtrl.clear();
                                    _passCtrl.clear();
                                    _userCtrl.clear();
                                    _confirmPassCtrl.clear();
                                    _animationController.reset();
                                    _animationController.forward();
                                  });
                                },
                                child: RichText(
  text: TextSpan(
    style: TextStyle(
      fontSize: 14,
      color: Colors.grey.shade600,
    ),
    children: [
      TextSpan(
        text: isLogin 
          ? "Ещё нет аккаунта? " 
          : "Уже есть профиль? ",
      ),
      TextSpan(
        text: isLogin ? "Зарегистрироваться" : "Войти",
        style: const TextStyle(
          color: Colors.amber, // Изменено на желтый (как иконка улья)
          fontWeight: FontWeight.bold,
        ),
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
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Индикатор силы пароля (только для регистрации)
  Widget _buildPasswordStrengthIndicator() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: _passwordStrength,
            minHeight: 6,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation<Color>(_passwordStrengthColor),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(
              _passwordStrength <= 0.3 
                ? Icons.warning_amber_rounded 
                : _passwordStrength >= 0.8 
                  ? Icons.shield_rounded 
                  : Icons.check_circle_outline,
              size: 14,
              color: _passwordStrengthColor,
            ),
            const SizedBox(width: 6),
            Text(
              _passwordStrengthText,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: _passwordStrengthColor,
              ),
            ),
            const Spacer(),
            if (_passCtrl.text.isNotEmpty && _passwordStrength < 0.8)
              Text(
                _getPasswordHint(),
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey.shade500,
                ),
              ),
          ],
        ),
        if (_passCtrl.text.isNotEmpty && _passwordStrength < 0.8) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              _buildRequirementChip("7+ символов", _passCtrl.text.length >= 7),
              _buildRequirementChip("Цифра", RegExp(r'\d').hasMatch(_passCtrl.text)),
              _buildRequirementChip("A-Z", RegExp(r'[A-Z]').hasMatch(_passCtrl.text)),
              _buildRequirementChip("a-z", RegExp(r'[a-z]').hasMatch(_passCtrl.text)),
              _buildRequirementChip("!@#\$", RegExp(r'[!@#\$%^&*(),.?":{}|<>]').hasMatch(_passCtrl.text)),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildRequirementChip(String label, bool isMet) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isMet ? Colors.green.withOpacity(0.1) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isMet ? Colors.green.withOpacity(0.3) : Colors.grey.shade300,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isMet ? Icons.check : Icons.close,
            size: 12,
            color: isMet ? Colors.green : Colors.grey,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: isMet ? Colors.green.shade700 : Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  String _getPasswordHint() {
    final password = _passCtrl.text;
    if (password.length < 7) return "Добавьте символы";
    if (!RegExp(r'[A-Z]').hasMatch(password)) return "Добавьте заглавные буквы";
    if (!RegExp(r'\d').hasMatch(password)) return "Добавьте цифры";
    if (!RegExp(r'[!@#\$%^&*(),.?":{}|<>]').hasMatch(password)) return "Добавьте спецсимволы";
    return "";
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String label,
    required String hint,
    required IconData icon,
    bool isPassword = false,
    bool obscureText = false,
    VoidCallback? onToggleVisibility,
    TextInputType keyboardType = TextInputType.text,
    String? errorText,
    bool showValidation = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8, left: 4),
              child: Text(
                label,
                style: GoogleFonts.orbitron(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: showValidation && errorText != null 
                    ? Colors.red.shade400 
                    : Colors.grey.shade500,
                  letterSpacing: 1.5,
                ),
              ),
            ),
            if (showValidation && errorText != null) ...[
              const Spacer(),
              Padding(
                padding: const EdgeInsets.only(bottom: 8, right: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline, size: 12, color: Colors.red.shade400),
                    const SizedBox(width: 4),
                    Text(
                      errorText,
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.red.shade400,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        Container(
          decoration: BoxDecoration(
            color: showValidation && errorText != null 
              ? Colors.red.shade50 
              : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: showValidation && errorText != null 
                ? Colors.red.shade300 
                : focusNode.hasFocus 
                  ? AppColors.primary.withOpacity(0.5) 
                  : Colors.grey.shade200,
              width: (showValidation && errorText != null) || focusNode.hasFocus ? 2 : 1,
            ),
            boxShadow: focusNode.hasFocus
              ? [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
          ),
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            obscureText: isPassword ? obscureText : false,
            keyboardType: keyboardType,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: AppColors.navy,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                color: Colors.grey.shade400,
                fontSize: 14,
              ),
              prefixIcon: Icon(
                icon,
                color: showValidation && errorText != null 
                  ? Colors.red.shade400 
                  : focusNode.hasFocus 
                    ? AppColors.primary 
                    : Colors.grey.shade400,
                size: 20,
              ),
              suffixIcon: isPassword && onToggleVisibility != null
                ? IconButton(
                    onPressed: onToggleVisibility,
                    icon: Icon(
                      obscureText ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                      color: Colors.grey.shade400,
                      size: 20,
                    ),
                  )
                : showValidation && controller.text.isNotEmpty && errorText == null
                  ? Icon(
                      Icons.check_circle,
                      color: Colors.green.shade400,
                      size: 18,
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 16,
              ),
            ),
            onSubmitted: (_) {
              if (!isLogin && focusNode == _userFocus) {
                _emailFocus.requestFocus();
              } else if (focusNode == _emailFocus) {
                _passFocus.requestFocus();
              } else if (!isLogin && focusNode == _passFocus) {
                _confirmPassFocus.requestFocus();
              } else if (focusNode == _confirmPassFocus || (isLogin && focusNode == _passFocus)) {
                _submit();
              }
            },
            onChanged: (_) {
              if (showValidation) setState(() {});
            },
          ),
        ),
      ],
    );
  }
}