import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hive_app/theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/user_provider.dart';

class VerificationTestScreen extends StatefulWidget {
  final int skillId;
  final String skillName;
  final List<dynamic> questions;

  const VerificationTestScreen({
    super.key, 
    required this.skillId, 
    required this.skillName, 
    required this.questions
  });

  @override
  State<VerificationTestScreen> createState() => _VerificationTestScreenState();
}

class _VerificationTestScreenState extends State<VerificationTestScreen> {
  int _currentIndex = 0;
  final Map<int, String> _userAnswers = {};
  bool _isSubmitting = false;
  
  // --- ЛОГИКА ТАЙМЕРА ---
  late Timer _timer;
  int _secondsRemaining = 300; 

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_secondsRemaining > 0) {
          _secondsRemaining--;
        } else {
          _timer.cancel();
          _autoSubmit(); // Автосдача при выходе времени
        }
      });
    });
  }

  String _formatTime(int seconds) {
    int mins = seconds ~/ 60;
    int secs = seconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  // --- ЛОГИКА ЗАВЕРШЕНИЯ ---

  void _autoSubmit() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Время вышло! Тест отправлен автоматически."))
    );
    _finishTest();
  }


void _finishTest() async {
  _timer.cancel();
  setState(() => _isSubmitting = true);

  int correctCount = 0;
  List<Map<String, dynamic>> errorLog = [];

  for (int i = 0; i < widget.questions.length; i++) {
    // 1. Извлекаем сырые данные
    String userAns = (_userAnswers[i] ?? "Нет ответа").toString().trim();
    String rawCorrectAns = widget.questions[i]['correctAnswer'].toString().trim();
    
    // 2. Функция глубокой очистки для сравнения и отображения
    String cleanString(String input) {
      return input
          .replaceAll("'", "")
          .replaceAll('"', "")
          .replaceAll("[", "")
          .replaceAll("]", "")
          .trim();
    }

    String cleanCorrect = cleanString(rawCorrectAns);
    String cleanUser = cleanString(userAns);

    // 3. Логика сравнения (игнорируем регистр и мелкие артефакты)
    if (cleanUser.toLowerCase() == cleanCorrect.toLowerCase()) {
      correctCount++;
    } else {
      // Записываем в лог именно ЧИСТЫЙ правильный ответ для UI
      errorLog.add({
        "question": widget.questions[i]['question'],
        "userAnswer": userAns, // Оставляем как ответил пользователь
        "correctAnswer": cleanCorrect, // А здесь показываем эталон без кавычек
      });
    }
  }

  double score = correctCount / widget.questions.length;
  
  // Отправка на бэкенд
  bool isVerified = await context.read<UserProvider>().submitVerificationResult(widget.skillId, score);

  if (mounted) {
    setState(() => _isSubmitting = false);
    _showResultDialog(isVerified, score, errorLog);
  }
}

  // --- ИНТЕРФЕЙС РЕЗУЛЬТАТОВ ---

  void _showResultDialog(bool success, double score, List<Map<String, dynamic>> errors) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
        title: Center(
          child: Text(success ? "АТТЕСТАЦИЯ ПРОЙДЕНА!" : "АТТЕСТАЦИЯ НЕ СДАНА", 
            style: TextStyle(color: success ? Colors.green : Colors.red, fontWeight: FontWeight.bold)),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Ваш результат: ${(score * 100).toInt()}%", 
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            Text(success 
              ? "Поздравляем! Теперь ваш навык подтвержден синей галочкой." 
              : "Для верификации нужно набрать минимум 80%. Попробуйте позже."),
            if (errors.isNotEmpty) ...[
              const Divider(height: 30),
              const Text("Хотите посмотреть свои ошибки?", style: TextStyle(fontWeight: FontWeight.bold)),
            ]
          ],
        ),
        actions: [
          if (errors.isNotEmpty)
            TextButton(
              onPressed: () => _showErrorReport(errors), 
              child: const Text("РАЗБОР ОШИБОК", style: TextStyle(color: Colors.orange))
            ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            }, 
            child: const Text("В ПРОФИЛЬ")
          )
        ],
      ),
    );
  }

  void _showErrorReport(List<Map<String, dynamic>> errors) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.all(25),
          children: [
            const Text("АНАЛИЗ ОШИБОК", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: 20),
            ...errors.map((e) => Container(
              margin: const EdgeInsets.only(bottom: 20),
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha:0.05),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.red.withValues(alpha:0.1)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(e['question'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 10),
                  Text("Ваш ответ: ${e['userAnswer']}", style: const TextStyle(color: Colors.red, fontSize: 12)),
                  Text("Правильный: ${e['correctAnswer']}", style: const TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              ),
            )).toList(),
          ],
        ),
      ),
    );
  }

  // --- ГЛАВНЫЙ ЭКРАН ТЕСТА ---

  @override
  Widget build(BuildContext context) {
    final q = widget.questions[_currentIndex];
    bool isLast = _currentIndex == widget.questions.length - 1;

    return Scaffold(
      backgroundColor: Colors.white, // ИЗМЕНЕНО: СВЕТЛЫЙ ТОН
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        centerTitle: true,
        title: Text(
          "ТАЙМЕР: ${_formatTime(_secondsRemaining)}",
          style: GoogleFonts.manrope(
            color: _secondsRemaining < 60 ? Colors.red : AppColors.navy,
            fontWeight: FontWeight.bold,
            fontSize: 16
          ),
        ),
      ),
      body: Column(
        children: [
          LinearProgressIndicator(
            value: (_currentIndex + 1) / widget.questions.length,
            backgroundColor: Colors.grey.shade100,
            color: AppColors.primary,
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("ЭКЗАМЕН: ${widget.skillName.toUpperCase()}", 
                    style: const TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 20),
                  Text(q['question'], 
                    style: const TextStyle(color: AppColors.navy, fontSize: 20, fontWeight: FontWeight.bold, height: 1.4)),
                  const SizedBox(height: 30),
                  
                  ...List.generate(q['options'].length, (i) {
                    String opt = q['options'][i];
                    bool isSelected = _userAnswers[_currentIndex] == opt;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 15),
                      child: InkWell(
                        onTap: () => setState(() => _userAnswers[_currentIndex] = opt),
                        borderRadius: BorderRadius.circular(15),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.primary.withValues(alpha:0.1) : Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(color: isSelected ? AppColors.primary : Colors.grey.shade200, width: 2),
                          ),
                          child: Row(
                            children: [
                              Icon(isSelected ? Icons.check_circle : Icons.circle_outlined, 
                                color: isSelected ? AppColors.primary : Colors.grey),
                              const SizedBox(width: 15),
                              Expanded(child: Text(opt, 
                                style: TextStyle(color: isSelected ? AppColors.navy : Colors.black87, fontSize: 15))),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
          
          Container(
            padding: const EdgeInsets.fromLTRB(30, 20, 30, 40),
            decoration: BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Colors.grey.shade100))),
            child: Row(
              children: [
                if (_currentIndex > 0)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => setState(() => _currentIndex--), 
                      child: const Text("НАЗАД"),
                    ),
                  ),
                if (_currentIndex > 0) const SizedBox(width: 15),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.navy),
                    // ИСПРАВЛЕНИЕ: Убираем дублирующую загрузку
                    onPressed: _isSubmitting ? null : (isLast ? _finishTest : () => setState(() => _currentIndex++)),
                    child: _isSubmitting 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text(isLast ? "ЗАВЕРШИТЬ" : "ДАЛЕЕ", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}