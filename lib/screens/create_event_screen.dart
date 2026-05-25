import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/event_provider.dart';
import '../theme/app_theme.dart';
import '../models/all_models.dart';

class CreateEventScreen extends StatefulWidget {
  final EventResponse? event;
  final DateTime? initialDate;

  const CreateEventScreen({super.key, this.event, this.initialDate});

  @override
  State<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends State<CreateEventScreen> {
  final _titleCtrl = TextEditingController();
  late DateTime _selectedDate;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // Инициализация даты: либо из редактируемого события, либо начальная (с учетом МСК)
    if (widget.event != null) {
      _titleCtrl.text = widget.event!.title;
      _selectedDate = widget.event!.eventDate;
    } else {
      _selectedDate = widget.initialDate ?? DateTime.now().toUtc().add(const Duration(hours: 3));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Делаем фон слегка затемненным, чтобы окно выделялось
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: BackButton(color: AppColors.navy, onPressed: () => Navigator.pop(context)),
        title: Text(
          widget.event != null ? "Редактировать событие" : "Новое событие",
          style: const TextStyle(color: AppColors.navy, fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500), // ОГРАНИЧЕНИЕ ШИРИНЫ ДЛЯ ВЕБА
            child: Container(
              margin: const EdgeInsets.all(25),
              padding: const EdgeInsets.all(30),
              decoration: AppDecorations.glassCard, // Фирменный стиль
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("ЧТО ПЛАНИРУЕМ?", 
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: Colors.grey, letterSpacing: 1.2)),
                  const SizedBox(height: 15),
                  TextField(
                    controller: _titleCtrl,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    decoration: AppDecorations.smartInput("Название события", Icons.edit_calendar_rounded),
                  ),
                  const SizedBox(height: 30),
                  const Text("КОГДА?", 
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: Colors.grey, letterSpacing: 1.2)),
                  const SizedBox(height: 15),
                  
                  // Кнопка выбора даты и времени
                  _buildPickerTile(),

                  const SizedBox(height: 40),
                  
                  // КНОПКИ ДЕЙСТВИЯ
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text("ОТМЕНА", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.navy,
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                            elevation: 0,
                          ),
                          onPressed: _isSaving ? null : _submit,
                          child: _isSaving 
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text("СОХРАНИТЬ", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPickerTile() {
    return InkWell(
      onTap: _pickDateTime,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.blue.shade50),
        ),
        child: Row(
          children: [
            const Icon(Icons.access_time_filled_rounded, color: AppColors.primary),
            const SizedBox(width: 15),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(DateFormat('dd MMMM yyyy', 'ru').format(_selectedDate), 
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                Text("Начало в ${DateFormat('HH:mm').format(_selectedDate)}", 
                  style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
            const Spacer(),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDateTime() async {
    final now = DateTime.now().toUtc().add(const Duration(hours: 3));

    // 1. Выбор даты (с ограничениями)
    final DateTime? d = await showDatePicker(
      context: context,
      initialDate: _selectedDate.isBefore(now) ? now : _selectedDate,
      firstDate: DateTime(now.year, now.month, now.day), // ЗАПРЕТ ПРОШЛОГО
      lastDate: now.add(const Duration(days: 365 * 5)), // ЗАПРЕТ ДАЛЕКОГО БУДУЩЕГО (+5 лет)
      locale: const Locale("ru"),
    );

    if (d != null) {
      // 2. Выбор времени
      final TimeOfDay? t = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_selectedDate),
      );

      if (t != null) {
        setState(() {
          _selectedDate = DateTime(d.year, d.month, d.day, t.hour, t.minute);
        });
      }
    }
  }

  void _submit() async {
    if (_titleCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Введите название")));
      return;
    }

    setState(() => _isSaving = true);
    
    bool ok;
    if (widget.event != null) {
      ok = await context.read<EventProvider>().updateEvent(widget.event!.id, _titleCtrl.text.trim(), _selectedDate);
    } else {
      ok = await context.read<EventProvider>().addEvent(_titleCtrl.text.trim(), null, _selectedDate, null);
    }

    if (mounted) {
      if (ok) {
        Navigator.pop(context); // Возвращаемся и обновляем список
      } else {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Ошибка сохранения")));
      }
    }
  }
}