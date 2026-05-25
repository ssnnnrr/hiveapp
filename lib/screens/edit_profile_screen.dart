import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../theme/app_theme.dart';

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

  @override
  void initState() {
    super.initState();
    final p = context.read<UserProvider>().myProfile;
    if (p != null) {
      _nameCtrl.text = p.username;
      _isPrivate = p.isPrivate;
      _base64Image = p.avatarUrl;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _passCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
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
      // Читаем байты (работает и на Web, и на Mobile)
      final Uint8List bytes = await image.readAsBytes();
      setState(() {
        _base64Image = base64Encode(bytes);
      });
    }
  }

  void _save() async {
    if (_nameCtrl.text.trim().isEmpty) return;
    
    if (_passCtrl.text.isNotEmpty && _passCtrl.text != _confirmPassCtrl.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Пароли не совпадают"), backgroundColor: Colors.redAccent)
      );
      return;
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
  }@override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    bool isWide = screenWidth > 800;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: AppColors.navy),
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
                // БЛОК АВАТАРА
                _buildAvatarSection(),
                const SizedBox(height: 30),

                // ОСНОВНЫЕ НАСТРОЙКИ
                _buildCard([
                  _buildLabel("ПУБЛИЧНОЕ ИМЯ"),
                  TextField(
                    controller: _nameCtrl, 
                    decoration: AppDecorations.smartInput("Как вас называть?", Icons.person_outline)
                  ),
                  const SizedBox(height: 20),
                  _buildLabel("ПРИВАТНОСТЬ"),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text("Скрытый профиль", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                    subtitle: const Text("Ваши цели будут видеть только партнеры", style: TextStyle(fontSize: 11)),
                    value: _isPrivate,
                    activeColor: AppColors.primary,
                    onChanged: (v) => setState(() => _isPrivate = v),
                  ),
                ]),

                const SizedBox(height: 30),

                // БЛОК БЕЗОПАСНОСТИ
                _buildCard([
                  _buildLabel("ИЗМЕНИТЬ ПАРОЛЬ"),
                  const Text("Оставьте поля пустыми, если не хотите менять пароль", 
                    style: TextStyle(fontSize: 11, color: Colors.grey)),
                  const SizedBox(height: 15),
                  TextField(
                    controller: _passCtrl, 
                    obscureText: true, 
                    decoration: AppDecorations.smartInput("Новый пароль", Icons.lock_outline)
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    controller: _confirmPassCtrl, 
                    obscureText: true, 
                    decoration: AppDecorations.smartInput("Повторите паро_ль", Icons.lock_reset)
                  ),
                ]),

                const SizedBox(height: 40),

                // КНОПКА СОХРАНЕНИЯ
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.navy,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      elevation: 0,
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
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.2), width: 3),
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
                child: CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.navy,
                  child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        TextButton(
          onPressed: _pickImage,
          child: const Text("Изменить фото", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
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
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 20)],
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