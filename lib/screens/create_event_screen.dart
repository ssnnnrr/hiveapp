import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/event_provider.dart';
import '../theme/app_theme.dart';
import '../models/all_models.dart';

class CreateEventScreen extends StatefulWidget {
  final DateTime initialDate;
  final EventResponse? event;
  final bool isOverlay;

  const CreateEventScreen({
    super.key, 
    required this.initialDate, 
    this.event,
    this.isOverlay = false,
  });

  @override
  State<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends State<CreateEventScreen> {
  final _titleCtrl = TextEditingController();
  final _locCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _linkCtrl = TextEditingController();
  String? _base64Image;
  
  late DateTime _selectedDate;
  TimeOfDay _selectedTime = TimeOfDay.now();

  @override
  void initState() {
    super.initState();
    if (widget.event != null) {
      _titleCtrl.text = widget.event!.title;
      _locCtrl.text = widget.event!.location ?? "";
      _descCtrl.text = widget.event!.description ?? "";
      _linkCtrl.text = widget.event!.linkUrl ?? "";
      final localDateTime = widget.event!.eventDate.toLocal();
      _selectedDate = localDateTime;
      _selectedTime = TimeOfDay.fromDateTime(localDateTime);
      _base64Image = widget.event!.imageUrl;
    } else {
      _selectedDate = widget.initialDate;
      _selectedTime = TimeOfDay.fromDateTime(
        DateTime.now().add(const Duration(hours: 1))
      );
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _locCtrl.dispose();
    _descCtrl.dispose();
    _linkCtrl.dispose();
    super.dispose();
  }

void _onSave() async {
    if (_titleCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Введите название события"),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }
    
    final now = DateTime.now();
    final localFinal = DateTime(
      _selectedDate.year, 
      _selectedDate.month, 
      _selectedDate.day, 
      _selectedTime.hour, 
      _selectedTime.minute
    );
    
    // ЛОГИКА ВАЛИДАЦИИ:
    // 1. Если это новое событие (event == null), оно обязано быть в будущем.
    // 2. Если это редактирование, и вы ИЗМЕНИЛИ время, то новое время обязано быть в будущем.
    bool isTimeChanged = widget.event == null || 
        localFinal.millisecondsSinceEpoch != widget.event!.eventDate.toLocal().millisecondsSinceEpoch;

    if (isTimeChanged && localFinal.isBefore(now)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Ошибка: Нельзя назначить событие на прошедшее время"), 
          backgroundColor: Colors.redAccent
        ),
      );
      return;
    }

    final prov = context.read<EventProvider>();
    bool success;
    
    try {
      if (widget.event == null) {
        success = await prov.addEvent(
          _titleCtrl.text.trim(), 
          _descCtrl.text.trim(), 
          localFinal, 
          _linkCtrl.text.trim(), 
          _locCtrl.text.trim(), 
          _base64Image
        );
      } else {
        success = await prov.updateEvent(
          widget.event!.id, 
          _titleCtrl.text.trim(), 
          _descCtrl.text.trim(), 
          localFinal, 
          _linkCtrl.text.trim(), 
          _locCtrl.text.trim(), 
          _base64Image
        );
      }

      if (success && mounted) {
        Navigator.pop(context);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Не удалось сохранить изменения на сервере"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Ошибка: $e"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Если это оверлей - показываем диалоговое окно
    if (widget.isOverlay) {
      return _buildOverlayContent();
    }

    // Мобильная версия - полный экран
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          widget.event == null ? "Новое событие" : "Редактирование", 
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            color: AppColors.navy,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, 
            color: AppColors.navy, 
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: _onSave,
            child: const Text(
              "Сохранить",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: _buildForm(),
      ),
    );
  }

  Widget _buildOverlayContent() {
    return Container(
      constraints: const BoxConstraints(
        maxWidth: 600, 
        maxHeight: 800,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha:0.15), 
            blurRadius: 40, 
            offset: const Offset(0, 20),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Заголовок модального окна
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: Color(0xFFF1F5F9), 
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.event == null ? "Новое событие" : "Редактирование", 
                    style: const TextStyle(
                      fontSize: 22, 
                      fontWeight: FontWeight.w900, 
                      color: AppColors.navy,
                    ),
                  ),
                  Row(
                    children: [
                      TextButton(
                        onPressed: _onSave,
                        child: const Text(
                          "Сохранить",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          onPressed: () => Navigator.pop(context), 
                          icon: const Icon(Icons.close_rounded, size: 20),
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: _buildForm(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Заголовок события
        _buildLabel("НАЗВАНИЕ СОБЫТИЯ"),
        const SizedBox(height: 8),
        TextField(
          controller: _titleCtrl, 
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: AppColors.navy,
          ),
          decoration: AppDecorations.smartInput(
            "Что вы планируете?", 
            Icons.edit_note_rounded,
          ),
          autofocus: true,
        ),
        const SizedBox(height: 24),
        
        // Дата и время
        _buildLabel("ДАТА И ВРЕМЯ"),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildDateTimeTile(
                DateFormat('dd.MM.yyyy', 'ru').format(_selectedDate),
                Icons.calendar_month_rounded,
                _pickDate,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildDateTimeTile(
                _selectedTime.format(context),
                Icons.access_time_rounded,
                _pickTime,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        
        // Местоположение
        _buildLabel("МЕСТО ПРОВЕДЕНИЯ"),
        const SizedBox(height: 8),
        TextField(
          controller: _locCtrl, 
          decoration: AppDecorations.smartInput(
            "Адрес или место встречи", 
            Icons.location_on_outlined,
          ),
        ),
        const SizedBox(height: 24),
        
        // Ссылка
        _buildLabel("ССЫЛКА (ZOOM / GOOGLE MEET)"),
        const SizedBox(height: 8),
        TextField(
          controller: _linkCtrl, 
          decoration: AppDecorations.smartInput(
            "URL для подключения", 
            Icons.video_call_outlined,
          ),
          keyboardType: TextInputType.url,
        ),
        const SizedBox(height: 24),
        
        // Описание
        _buildLabel("ОПИСАНИЕ"),
        const SizedBox(height: 8),
        TextField(
          controller: _descCtrl, 
          maxLines: 3,
          decoration: AppDecorations.smartInput(
            "Детали события", 
            Icons.description_outlined,
          ),
        ),
        const SizedBox(height: 24),
        
        // Фотография
        _buildLabel("ОБЛОЖКА СОБЫТИЯ"),
        const SizedBox(height: 8),
        _buildPhotoPicker(),
        const SizedBox(height: 32),
        
        // Кнопка сохранения (только для мобильной версии)
        if (!widget.isOverlay)
          ElevatedButton(
            onPressed: _onSave,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.navy,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 60),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              elevation: 0,
            ),
            child: const Text(
              "СОХРАНИТЬ СОБЫТИЕ", 
              style: TextStyle(
                fontSize: 16, 
                fontWeight: FontWeight.bold, 
                letterSpacing: 1.2,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPhotoPicker() {
    return GestureDetector(
      onTap: _pickImage,
      child: Container(
        height: 200,
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFFE2E8F0), 
            width: 2,
          ),
        ),
        child: _base64Image != null 
          ? ClipRRect(
              borderRadius: BorderRadius.circular(18), 
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.memory(
                    base64Decode(_base64Image!), 
                    fit: BoxFit.cover,
                  ),
                  Positioned(
                    top: 12,
                    right: 12,
                    child: GestureDetector(
                      onTap: () => setState(() => _base64Image = null),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha:0.6),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close, 
                          color: Colors.white, 
                          size: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            )
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.add_photo_alternate_outlined, 
                    color: Colors.grey.shade400, 
                    size: 32,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  "Добавить обложку",
                  style: TextStyle(
                    color: Colors.grey.shade500, 
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "JPG или PNG, не более 10MB",
                  style: TextStyle(
                    color: Colors.grey.shade400, 
                    fontSize: 11,
                  ),
                ),
              ],
            ),
      ),
    );
  }

  Widget _buildDateTimeTile(String text, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha:0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text, 
                style: const TextStyle(
                  fontWeight: FontWeight.w600, 
                  fontSize: 14,
                  color: AppColors.navy,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await ImagePicker().pickImage(
        source: ImageSource.gallery, 
        maxWidth: 1200, 
        imageQuality: 85,
      );
      if (image != null) {
        final bytes = await image.readAsBytes();
        if (bytes.length > 10 * 1024 * 1024) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Файл слишком большой. Максимум 10MB"),
                backgroundColor: Colors.redAccent,
              ),
            );
          }
          return;
        }
        setState(() => _base64Image = base64Encode(bytes));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Ошибка загрузки: $e"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context, 
      initialDate: _selectedDate, 
      firstDate: DateTime.now().subtract(const Duration(days: 30)), 
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.navy,
            ),
          ),
          child: child!,
        );
      },
    );
    if (d != null) setState(() => _selectedDate = d);
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(
      context: context, 
      initialTime: _selectedTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.navy,
            ),
          ),
          child: child!,
        );
      },
    );
    if (t != null) setState(() => _selectedTime = t);
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 11, 
        fontWeight: FontWeight.w900, 
        color: Color(0xFF94A3B8), 
        letterSpacing: 1.5,
      ),
    );
  }
}