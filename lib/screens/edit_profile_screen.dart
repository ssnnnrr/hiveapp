import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/main_dashboard_layout.dart';
import 'main_screen.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});
  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _nameCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  
  String? _base64Image;
  bool _isPrivate = false;
  bool _isSaving = false;

  // Состояния валидации пароля
  double _passwordStrength = 0;
  String _passwordStrengthText = '';
  Color _passwordStrengthColor = Colors.transparent;
  String? _passwordError;
  String? _confirmPasswordError;

  @override
  void initState() {
    super.initState();
    final p = context.read<UserProvider>().myProfile;
    if (p != null) {
      _nameCtrl.text = p.username;
      _base64Image = p.avatarUrl;
    }
    // Слушатели для живой проверки
    _passCtrl.addListener(_checkPasswordStrength);
    _confirmPassCtrl.addListener(_validateConfirmPassword);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _passCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  void _checkPasswordStrength() {
    final password = _passCtrl.text;
    if (password.isEmpty) {
      setState(() {
        _passwordStrength = 0;
        _passwordStrengthText = '';
        _passwordStrengthColor = Colors.transparent;
        _passwordError = null;
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

  void _validateConfirmPassword() {
    if (_confirmPassCtrl.text.isEmpty && _passCtrl.text.isEmpty) {
      setState(() => _confirmPasswordError = null);
      return;
    }
    if (_confirmPassCtrl.text != _passCtrl.text) {
      setState(() => _confirmPasswordError = 'Пароли не совпадают');
    } else {
      setState(() => _confirmPasswordError = null);
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 500,
      maxHeight: 500,
      imageQuality: 50,
    );
    if (image != null) {
      final bytes = await image.readAsBytes();
      setState(() => _base64Image = base64Encode(bytes));
    }
  }

  void _save() async {
    if (_nameCtrl.text.trim().isEmpty) return;

    // Если поле пароля не пустое, проверяем его на валидность
    if (_passCtrl.text.isNotEmpty) {
      if (_passwordStrength < 0.6) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Придумайте более надежный пароль"), backgroundColor: Colors.orange)
        );
        return;
      }
      if (_confirmPassCtrl.text != _passCtrl.text) {
        setState(() => _confirmPasswordError = 'Пароли не совпадают');
        return;
      }
    }

    setState(() => _isSaving = true);

    await context.read<UserProvider>().updateSelfProfile(
      name: _nameCtrl.text.trim(),
      isPrivate: _isPrivate,
      pass: _passCtrl.text.isEmpty ? null : _passCtrl.text,
      confirm: _confirmPassCtrl.text.isEmpty ? null : _confirmPassCtrl.text,
      avatarUrl: _base64Image,
    );

    if (mounted) {
      setState(() => _isSaving = false);
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Профиль успешно обновлен"), backgroundColor: Colors.green)
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    double width = MediaQuery.of(context).size.width;
    bool isWide = width > 1000;

    return MainDashboardLayout(
      selectedIndex: 4,
      onTabSelected: (idx) => Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => MainScreen(initialIndex: idx)), (route) => false,
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0.5,
          leading: isWide ? const SizedBox.shrink() : const BackButton(color: AppColors.navy),
          title: const Text("Настройки аккаунта", 
            style: TextStyle(color: AppColors.navy, fontWeight: FontWeight.bold, fontSize: 16)),
        ),
        body: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: isWide ? 0 : 20, vertical: 30),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Column(
                children: [
                  _buildAvatarSection(),
                  const SizedBox(height: 30),
                  
                  _buildCard([
                    _buildLabel("ПУБЛИЧНОЕ ИМЯ"),
                    TextField(
                      controller: _nameCtrl, 
                      decoration: AppDecorations.smartInput("Как вас называть?", Icons.person_outline)
                    )
        
                  ]),

                  const SizedBox(height: 30),

                  // БЛОК ПАРОЛЯ С ПРОВЕРКАМИ
                  _buildCard([
                    _buildLabel("ИЗМЕНИТЬ ПАРОЛЬ"),
                    const Text("Оставьте поля пустыми, если не хотите менять пароль", 
                      style: TextStyle(fontSize: 11, color: Colors.grey)),
                    const SizedBox(height: 20),
                    
                    TextField(
                      controller: _passCtrl, 
                      obscureText: true, 
                      decoration: AppDecorations.smartInput("Новый пароль", Icons.lock_outline_rounded).copyWith(
                        errorText: _passwordError,
                      ),
                    ),
                    
                    if (_passCtrl.text.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _buildPasswordStrengthIndicator(),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          _requirementChip("7+ символов", _passCtrl.text.length >= 7),
                          _requirementChip("Цифра", RegExp(r'\d').hasMatch(_passCtrl.text)),
                          _requirementChip("Заглавная", RegExp(r'[A-ZА-ЯЁ]').hasMatch(_passCtrl.text)),
                          _requirementChip("Спец. символ", RegExp(r'[!@#\$%^&*(),.?":{}|<>]').hasMatch(_passCtrl.text)),
                        ],
                      ),
                    ],

                    const SizedBox(height: 20),
                    
                    TextField(
                      controller: _confirmPassCtrl, 
                      obscureText: true, 
                      decoration: AppDecorations.smartInput("Повторите новый пароль", Icons.lock_reset_rounded).copyWith(
                        errorText: _confirmPasswordError,
                      ),
                    ),
                  ]),

                  const SizedBox(height: 40),

                  SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.navy,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      ),
                      onPressed: _isSaving ? null : _save,
                      child: _isSaving 
                        ? const CircularProgressIndicator(color: Colors.white) 
                        : const Text("СОХРАНИТЬ ИЗМЕНЕНИЯ", 
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1)),
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
            Icon(Icons.shield_outlined, size: 14, color: _passwordStrengthColor),
            const SizedBox(width: 6),
            Text(_passwordStrengthText, 
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _passwordStrengthColor)),
          ],
        ),
      ],
    );
  }

  Widget _requirementChip(String label, bool isMet) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isMet ? Colors.green.withValues(alpha:0.1) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isMet ? Colors.green.withValues(alpha:0.3) : Colors.grey.shade300),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isMet ? Icons.check : Icons.close, size: 12, color: isMet ? Colors.green : Colors.grey),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 10, color: isMet ? Colors.green.shade700 : Colors.grey.shade600)),
        ],
      ),
    );
  }

  Widget _buildAvatarSection() {
    return Column(
      children: [
        Stack(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.primary.withValues(alpha:0.2), width: 3),
              ),
              child: CircleAvatar(
                radius: 60,
                backgroundColor: Colors.white,
                backgroundImage: _base64Image != null ? MemoryImage(base64Decode(_base64Image!)) : null,
                child: _base64Image == null ? const Icon(Icons.person, size: 50, color: Colors.grey) : null,
              ),
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: GestureDetector(
                onTap: _pickImage,
                child: const CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.navy,
                  child: Icon(Icons.camera_alt, size: 16, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        TextButton(
          onPressed: _pickImage,
          child: const Text("Изменить фото", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.amber)),
        ),
      ],
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha:0.03), blurRadius: 20)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(text, 
        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: Colors.grey, letterSpacing: 1.2)),
    );
  }
}