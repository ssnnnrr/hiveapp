import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:hive_app/providers/auth_provider.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';

import '../models/all_models.dart';
import '../providers/group_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/main_dashboard_layout.dart';

class TestTakingScreen extends StatefulWidget {
  final RoadmapStepDto step;
  const TestTakingScreen({super.key, required this.step});

  @override
  State<TestTakingScreen> createState() => _TestTakingScreenState();
}

class _TestTakingScreenState extends State<TestTakingScreen> {
  // --- СОСТОЯНИЕ ПРОХОЖДЕНИЯ ---
  int _currentQuestionIndex = 0;
  List<dynamic> _questions = [];

  
  // Храним ответы: Map<ИндексВопроса, dynamic (String или List<String>)>
  final Map<int, dynamic> _userAnswers = {};
  
  bool _isSubmitting = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _parseTestData();
  }
  void _parseTestData() {
    try {
      setState(() {
        _questions = jsonDecode(widget.step.testData ?? "[]");
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Ошибка парсинга теста: $e");
      setState(() => _isLoading = false);
    }
  }

  // --- ЛОГИКА ВЫБОРА ОТВЕТОВ ---

  void _toggleSingleAnswer(String val) {
    setState(() => _userAnswers[_currentQuestionIndex] = val);
  }

  void _toggleMultipleAnswer(String val) {
    setState(() {
      List<String> current = List<String>.from(_userAnswers[_currentQuestionIndex] ?? []);
      if (current.contains(val)) {
        current.remove(val);
      } else {
        current.add(val);
      }
      _userAnswers[_currentQuestionIndex] = current;
    });
  }

  // --- ОТПРАВКА РЕЗУЛЬТАТОВ ---

  Future<void> _finishTest() async {
    if (_userAnswers.length < _questions.length) {
      _showToast("Пожалуйста, ответьте на все вопросы");
      return;
    }

    setState(() => _isSubmitting = true);

    int correctCount = 0;
    Map<String, dynamic> resultReport = {};

    for (int i = 0; i < _questions.length; i++) {
      var q = _questions[i];
      var userAns = _userAnswers[i];
      var correctAns = q['correctAnswer'];

      bool isCorrect = false;
      if (q['type'] == 'multiple') {
        // Сравнение списков для множественного выбора
        List<String> uList = List<String>.from(userAns)..sort();
        List<String> cList = List<String>.from(correctAns)..sort();
        isCorrect = uList.join() == cList.join();
      } else {
        isCorrect = userAns.toString() == correctAns.toString();
      }

      if (isCorrect) correctCount++;
      
      // Формируем отчет для сохранения в studentComment
      resultReport["Вопрос ${i + 1}"] = userAns;
    }

    double finalScore = correctCount / _questions.length;

    try {
      await context.read<GroupProvider>().submitTestResult(
        widget.step.id,
        finalScore,
        widget.step.groupId,
        jsonEncode(resultReport),
      );
      
      if (mounted) {
        _showSuccessDialog(finalScore);
      }
    } catch (e) {
      _showToast("Ошибка сохранения: $e");
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  // --- UI BUILDER: ГЛАВНЫЙ ЭКРАН ---

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    // ПОЛУЧАЕМ ID ПРЯМО ТУТ - это безопасно и быстро
    final myId = context.read<AuthProvider>().user?.id ?? 0;
    
    // ИСПРАВЛЕННАЯ ЛОГИКА:
    bool isTeacher = widget.step.creatorId == myId;
    
    // Тест пройден окончательно, только если статус Done И попыток больше нет
    bool noMoreAttempts = widget.step.usedAttempts >= widget.step.maxAttempts;
    bool isFinished = widget.step.status == "Done" && noMoreAttempts;

    // Показываем разбор, только если это учитель ИЛИ если тест реально закончен (нет попыток)
    bool showReview = isTeacher || isFinished;

    return MainDashboardLayout(
      selectedIndex: 3,
      child: Scaffold(
        backgroundColor: const Color(0xFFF2F5F9),
        appBar: _buildAppBar(showReview),
        body: showReview ? _buildReviewContent() : _buildTakeTestContent(),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(bool isReview) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0.5,
      leading: const BackButton(color: AppColors.navy),
      title: Text(
        isReview ? "РАЗБОР РЕЗУЛЬТАТОВ" : "ТЕСТИРОВАНИЕ",
        style: GoogleFonts.manrope(fontWeight: FontWeight.w900, fontSize: 15, color: AppColors.navy),
      ),
      centerTitle: true,
    );
  }

  // --- КРАСИВЫЙ РАЗБОР ОТВЕТОВ (REVIEW MODE) ---

  Widget _buildReviewContent() {
    Map<String, dynamic> studentAnswers = {};
    try {
      studentAnswers = jsonDecode(widget.step.studentComment ?? "{}");
    } catch (e) {}

    return ListView(
      padding: const EdgeInsets.all(25),
      children: [
        _buildSummaryHeader(),
        const SizedBox(height: 30),
        const Text("ДЕТАЛЬНЫЙ РЕЗУЛЬТАТ ПО КАЖДОМУ ВОПРОСУ:", 
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 10, color: Colors.grey, letterSpacing: 1.2)),
        const SizedBox(height: 15),
        ..._questions.asMap().entries.map((e) => _buildReviewCard(e.key, e.value, studentAnswers)).toList(),
        const SizedBox(height: 50),
      ],
    );
  }

  Widget _buildSummaryHeader() {
    final double score = (widget.step.testScore ?? 0) * 100;
    final bool isPassed = score >= 80;

    return FadeInDown(
      child: Container(
        padding: const EdgeInsets.all(30),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: isPassed 
              ? [const Color(0xFF1DB954), const Color(0xFF191414)] 
              : [const Color(0xFFE53935), const Color(0xFF8E24AA)]),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 20, offset: const Offset(0, 10))],
        ),
        child: Column(
          children: [
            Text(isPassed ? "ТЕСТ ПРОЙДЕН!" : "ТРЕБУЕТСЯ ПОВТОР", 
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
            const SizedBox(height: 15),
            Text("${score.toInt()}%", style: const TextStyle(color: Colors.white, fontSize: 56, fontWeight: FontWeight.w900)),
            const Divider(color: Colors.white24, height: 40),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _headerStat("ПОПЫТОК", "${widget.step.usedAttempts}/${widget.step.maxAttempts}"),
                _headerStat("СТАТУС", widget.step.status.toUpperCase()),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _headerStat(String l, String v) => Column(
    children: [
      Text(l, style: const TextStyle(color: Colors.white60, fontSize: 10, fontWeight: FontWeight.bold)),
      Text(v, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900)),
    ],
  );

  Widget _buildReviewCard(int idx, dynamic q, Map<String, dynamic> studentAnswers) {
    // Извлекаем ответ ученика из JSON-мапы
    var studentAns = studentAnswers.values.length > idx ? studentAnswers.values.elementAt(idx) : "Нет ответа";
    var correctAns = q['correctAnswer'];

    // Логика проверки правильности для визуализации
    bool isCorrect = false;
    if (q['type'] == 'multiple') {
      List<String> sList = List<String>.from(studentAns is List ? studentAns : [])..sort();
      List<String> cList = List<String>.from(correctAns is List ? correctAns : [])..sort();
      isCorrect = sList.join() == cList.join();
    } else {
      isCorrect = studentAns.toString() == correctAns.toString();
    }

    return FadeInUp(
      delay: Duration(milliseconds: 100 * idx),
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        padding: const EdgeInsets.all(25),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: isCorrect ? Colors.green.withOpacity(0.3) : Colors.red.withOpacity(0.3), width: 2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("ВОПРОС ${idx + 1}", style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.grey, fontSize: 10)),
                Icon(isCorrect ? Icons.check_circle_rounded : Icons.cancel_rounded, 
                    color: isCorrect ? Colors.green : Colors.red, size: 20),
              ],
            ),
            const SizedBox(height: 10),
            Text(q['question'], style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.navy)),
            const Divider(height: 40),
            
            _answerBlock("ОТВЕТ УЧЕНИКА", studentAns.toString(), isCorrect ? Colors.green : Colors.red),
            const SizedBox(height: 15),
            if (!isCorrect)
              _answerBlock("ПРАВИЛЬНЫЙ ОТВЕТ", correctAns.toString(), Colors.green),
          ],
        ),
      ),
    );
  }

  Widget _answerBlock(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey)),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
          decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(12)),
          child: Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 14)),
        ),
      ],
    );
  }

  // --- ИНТЕРФЕЙС ПРОХОЖДЕНИЯ (TAKE MODE) ---

  Widget _buildTakeTestContent() {
    final q = _questions[_currentQuestionIndex];
    final double progress = (_currentQuestionIndex + 1) / _questions.length;

    return Column(
      children: [
        LinearProgressIndicator(value: progress, backgroundColor: Colors.white, color: AppColors.primary, minHeight: 6),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildAttemptBadge(),
                const SizedBox(height: 20),
                Text("Вопрос ${_currentQuestionIndex + 1} из ${_questions.length}", 
                    style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.grey, fontSize: 11)),
                const SizedBox(height: 10),
                Text(q['question'], 
                    style: GoogleFonts.manrope(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.navy, height: 1.3)),
                const SizedBox(height: 40),
                
                // Рендер вариантов в зависимости от типа
                ..._buildOptions(q),
              ],
            ),
          ),
        ),
        _buildNavigationPanel(),
      ],
    );
  }

  Widget _buildAttemptBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: Colors.amber.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.refresh, size: 14, color: Colors.orange),
          const SizedBox(width: 6),
          Text("Попытка: ${widget.step.usedAttempts + 1} из ${widget.step.maxAttempts}", 
              style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 10)),
        ],
      ),
    );
  }

  List<Widget> _buildOptions(dynamic q) {
    final List<String> options = List<String>.from(q['options']);
    final String type = q['type'] ?? 'single';

    return options.map((opt) {
      bool isSelected = false;
      if (type == 'multiple') {
        isSelected = (_userAnswers[_currentQuestionIndex] as List<String>?)?.contains(opt) ?? false;
      } else {
        isSelected = _userAnswers[_currentQuestionIndex] == opt;
      }

      return Padding(
        padding: const EdgeInsets.only(bottom: 15),
        child: InkWell(
          onTap: () => type == 'multiple' ? _toggleMultipleAnswer(opt) : _toggleSingleAnswer(opt),
          borderRadius: BorderRadius.circular(20),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.navy : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: isSelected ? AppColors.navy : Colors.grey.shade200, width: 2),
              boxShadow: [if (isSelected) BoxShadow(color: AppColors.navy.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))],
            ),
            child: Row(
              children: [
                Icon(isSelected ? Icons.check_circle : Icons.circle_outlined, 
                    color: isSelected ? Colors.white : Colors.grey, size: 22),
                const SizedBox(width: 15),
                Expanded(child: Text(opt, style: TextStyle(
                  color: isSelected ? Colors.white : AppColors.navy,
                  fontWeight: FontWeight.bold, fontSize: 15
                ))),
              ],
            ),
          ),
        ),
      );
    }).toList();
  }

  Widget _buildNavigationPanel() {
    bool isLast = _currentQuestionIndex == _questions.length - 1;

    return Container(
      padding: const EdgeInsets.fromLTRB(25, 20, 25, 40),
      decoration: const BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)]),
      child: Row(
        children: [
          if (_currentQuestionIndex > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: () => setState(() => _currentQuestionIndex--),
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 55), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                child: const Text("НАЗАД", style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          if (_currentQuestionIndex > 0) const SizedBox(width: 15),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : (isLast ? _finishTest : () => setState(() => _currentQuestionIndex++)),
              style: ElevatedButton.styleFrom(
                backgroundColor: isLast ? Colors.green : AppColors.navy,
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 55),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
              ),
              child: _isSubmitting 
                ? const CircularProgressIndicator(color: Colors.white)
                : Text(isLast ? "ЗАВЕРШИТЬ ТЕСТ" : "ДАЛЕЕ", style: const TextStyle(fontWeight: FontWeight.w900)),
            ),
          ),
        ],
      ),
    );
  }

  // --- ВСПОМОГАТЕЛЬНЫЕ ОКНА ---

  void _showSuccessDialog(double score) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.stars_rounded, size: 80, color: Colors.amber),
            const SizedBox(height: 20),
            const Text("ТЕСТ ОКОНЧЕН", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20)),
            Text("Ваш результат: ${(score * 100).toInt()}%", style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pop(context, true);
                },
                child: const Text("ПОСМОТРЕТЬ РАЗБОР"),
              ),
            )
          ],
        ),
      ),
    );
  }

  void _showToast(String m) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), behavior: SnackBarBehavior.floating));
  }
}