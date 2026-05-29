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
  final bool isOverlay; // Новый параметр

  const CreateEventScreen({
    super.key, 
    required this.initialDate, 
    this.event,
    this.isOverlay = false, // По умолчанию полный экран
  });

  @override
  State<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends State<CreateEventScreen> {
  final _titleCtrl = TextEditingController();
  final _locCtrl = TextEditingController();
  String? _base64Image;
  
  late DateTime _selectedDate;
  TimeOfDay _selectedTime = TimeOfDay.now();

  @override
  void initState() {
    super.initState();
    if (widget.event != null) {
      _titleCtrl.text = widget.event!.title;
      _locCtrl.text = widget.event!.location ?? "";
      final localDateTime = widget.event!.eventDate.toLocal();
      _selectedDate = localDateTime;
      _selectedTime = TimeOfDay.fromDateTime(localDateTime);
      _base64Image = widget.event!.imageUrl;
    } else {
      _selectedDate = widget.initialDate;
    }
  }

  void _onSave() async {
    if (_titleCtrl.text.isEmpty) return;
    final localFinal = DateTime(
      _selectedDate.year, _selectedDate.month, _selectedDate.day, 
      _selectedTime.hour, _selectedTime.minute
    );
    
    if (localFinal.isBefore(DateTime.now()) && widget.event == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Нельзя выбрать время в прошлом"), backgroundColor: Colors.redAccent)
      );
      return;
    }

    final prov = context.read<EventProvider>();
    bool success;
    if (widget.event == null) {
      success = await prov.addEvent(_titleCtrl.text.trim(), null, localFinal, "", _locCtrl.text.trim(), _base64Image);
    } else {
      success = await prov.updateEvent(widget.event!.id, _titleCtrl.text.trim(), null, localFinal, "", _locCtrl.text.trim(), _base64Image);
    }

    if (success && mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Если это оверлей - показываем просто контейнер без Scaffold
    if (widget.isOverlay) {
      return Container(
        constraints: const BoxConstraints(maxWidth: 550, maxHeight: 750),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black26, 
              blurRadius: 40, 
              offset: const Offset(0, 20)
            )
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Заголовок для оверлея
              Container(
                padding: const EdgeInsets.all(20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      widget.event == null ? "Новое событие" : "Редактирование", 
                      style: const TextStyle(
                        fontSize: 20, 
                        fontWeight: FontWeight.w900, 
                        color: AppColors.navy
                      )
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context), 
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(25),
                  child: _buildForm(),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Мобильная версия - полный экран
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          widget.event == null ? "Новое событие" : "Редактирование", 
          style: const TextStyle(fontWeight: FontWeight.bold)
        ),
        leading: const BackButton(color: AppColors.navy),
        elevation: 0,
        backgroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: _buildForm(),
      ),
    );
  }

  Widget _buildForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label("ЧТО ВЫ ПЛАНИРУЕТЕ?"),
        TextField(
          controller: _titleCtrl, 
          style: const TextStyle(fontWeight: FontWeight.bold),
          decoration: AppDecorations.smartInput("Название события", Icons.edit_note_rounded),
        ),
        const SizedBox(height: 25),
        _label("ФОТОГРАФИЯ"),
        _buildPhotoPicker(),
        const SizedBox(height: 25),
        _label("ГДЕ И КОГДА"),
        TextField(
          controller: _locCtrl, 
          decoration: AppDecorations.smartInput("Место встречи или ссылка", Icons.place_outlined),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _dateTile(DateFormat('dd.MM.yyyy').format(_selectedDate), Icons.calendar_month, _pickDate)),
            const SizedBox(width: 12),
            Expanded(child: _dateTile(_selectedTime.format(context), Icons.access_time_rounded, _pickTime)),
          ],
        ),
        const SizedBox(height: 40),
        ElevatedButton(
          onPressed: _onSave,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.navy,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 60),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            elevation: 0,
          ),
          child: const Text("СОХРАНИТЬ", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        ),
      ],
    );
  }

  Widget _buildPhotoPicker() {
    return GestureDetector(
      onTap: _pickImage,
      child: Container(
        height: 180,
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE2E8F0), width: 2),
        ),
        child: _base64Image != null 
          ? ClipRRect(
              borderRadius: BorderRadius.circular(18), 
              child: Image.memory(base64Decode(_base64Image!), fit: BoxFit.cover))
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_photo_alternate_outlined, color: Colors.blueGrey.shade300, size: 40),
                const SizedBox(height: 8),
                Text("Нажмите, чтобы загрузить фото", style: TextStyle(color: Colors.blueGrey.shade400, fontSize: 13)),
              ],
            ),
      ),
    );
  }

  Widget _dateTile(String text, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppColors.primary),
            const SizedBox(width: 10),
            Flexible(child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage() async {
    final XFile? image = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1000, imageQuality: 80);
    if (image != null) {
      final bytes = await image.readAsBytes();
      setState(() => _base64Image = base64Encode(bytes));
    }
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context, 
      initialDate: _selectedDate, 
      firstDate: DateTime.now().subtract(const Duration(days: 30)), 
      lastDate: DateTime.now().add(const Duration(days: 365))
    );
    if (d != null) setState(() => _selectedDate = d);
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(context: context, initialTime: _selectedTime);
    if (t != null) setState(() => _selectedTime = t);
  }

  Widget _label(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 10, left: 4),
    child: Text(t, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.blueGrey.shade400, letterSpacing: 1.2)),
  );
}