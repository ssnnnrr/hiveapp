import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/group_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/main_dashboard_layout.dart';

class TestCreationScreen extends StatefulWidget {
  final int groupId;
  const TestCreationScreen({super.key, required this.groupId});

  @override
  State<TestCreationScreen> createState() => _TestCreationScreenState();
}

class _TestCreationScreenState extends State<TestCreationScreen> {
  // --- КОНТРОЛЛЕРЫ ТЕСТА ---
  final _testTitleCtrl = TextEditingController();
  final _aiTopicCtrl = TextEditingController();
  
  // --- ПАРАМЕТРЫ ---
  DateTime _dueDate = DateTime.now().add(const Duration(days: 7));
  int _maxAttempts = 3;
  int _aiQuestionsCount = 5;
  String _creationMode = 'manual';
  
  // --- ПАРАМЕТРЫ AI ---
  int _aiMaxAttempts = 3;
  String _aiTestTitle = '';
  String _aiFormat = 'single'; // single, multiple, boolean
  
  // --- СПИСОК ВОПРОСОВ ---
  List<Map<String, dynamic>> _questions = [];

  // --- СОСТОЯНИЕ РЕДАКТОРА ВОПРОСА ---
  bool _isAddingQuestion = false;
  bool _isEditingQuestion = false;
  int? _editingQuestionIndex;
  String _currentQuestionType = 'single';
  final _questionTextCtrl = TextEditingController();
  List<TextEditingController> _optionCtrls = [];
  
  // Правильные ответы
  String? _singleCorrectAnswer;
  List<String> _multipleCorrectAnswers = [];
  bool? _booleanCorrectAnswer;

  @override
  void initState() {
    super.initState();
    _initOptionControllers();
  }

  void _initOptionControllers() {
    for (var c in _optionCtrls) {
      c.dispose();
    }
    
    if (_currentQuestionType == 'boolean') {
      _optionCtrls = [
        TextEditingController(text: 'Верно'),
        TextEditingController(text: 'Неверно'),
      ];
    } else {
      _optionCtrls = [
        TextEditingController(text: 'Вариант 1'),
        TextEditingController(text: 'Вариант 2'),
      ];
    }
  }

  void _resetQuestionEditor() {
    _questionTextCtrl.clear();
    _initOptionControllers();
    _singleCorrectAnswer = null;
    _multipleCorrectAnswers = [];
    _booleanCorrectAnswer = null;
    _editingQuestionIndex = null;
    _isEditingQuestion = false;
  }

  void _editQuestion(int index) {
    final question = _questions[index];
    _questionTextCtrl.text = question['question'];
    _currentQuestionType = question['type'];
    
    for (var c in _optionCtrls) {
      c.dispose();
    }
    _optionCtrls = (question['options'] as List)
        .map((opt) => TextEditingController(text: opt))
        .toList();
    
    switch (_currentQuestionType) {
      case 'single':
        _singleCorrectAnswer = question['correctAnswer'];
        break;
      case 'multiple':
        _multipleCorrectAnswers = List<String>.from(question['correctAnswer']);
        break;
      case 'boolean':
        _booleanCorrectAnswer = question['correctAnswer'] == 'Верно';
        break;
    }
    
    setState(() {
      _isAddingQuestion = true;
      _isEditingQuestion = true;
      _editingQuestionIndex = index;
    });
  }

  void _addQuestionToList() {
    if (_questionTextCtrl.text.trim().isEmpty) {
      _showError("Введите текст вопроса");
      return;
    }

    dynamic correctAnswer;
    
    switch (_currentQuestionType) {
      case 'single':
        if (_singleCorrectAnswer == null) {
          _showError("Выберите правильный вариант ответа");
          return;
        }
        correctAnswer = _singleCorrectAnswer;
        break;
        
      case 'multiple':
        if (_multipleCorrectAnswers.isEmpty) {
          _showError("Выберите хотя бы один правильный ответ");
          return;
        }
        correctAnswer = List<String>.from(_multipleCorrectAnswers);
        break;
        
      case 'boolean':
        if (_booleanCorrectAnswer == null) {
          _showError("Выберите правильный ответ");
          return;
        }
        correctAnswer = _booleanCorrectAnswer! ? 'Верно' : 'Неверно';
        break;
    }

    final options = _optionCtrls.map((c) => c.text.trim()).toList();

    final questionData = {
      'question': _questionTextCtrl.text.trim(),
      'type': _currentQuestionType,
      'options': options,
      'correctAnswer': correctAnswer,
    };

    setState(() {
      if (_isEditingQuestion && _editingQuestionIndex != null) {
        _questions[_editingQuestionIndex!] = questionData;
      } else {
        _questions.add(questionData);
      }
      _isAddingQuestion = false;
      _resetQuestionEditor();
    });
  }

  void _moveQuestion(int oldIndex, int newIndex) {
    if (newIndex < 0 || newIndex >= _questions.length) return;
    setState(() {
      final item = _questions.removeAt(oldIndex);
      _questions.insert(newIndex, item);
    });
  }

  Future<void> _handleAIGeneration() async {
    // Валидация
    if (_aiTestTitle.isEmpty) {
      _showError("Введите название теста");
      return;
    }
    if (_aiTopicCtrl.text.isEmpty) {
      _showError("Введите тему для генерации");
      return;
    }
    if (_aiQuestionsCount < 1) {
      _showError("Количество вопросов должно быть больше 0");
      return;
    }
    
    showDialog(
      context: context, 
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: Colors.amber)
      )
    );
    
    try {
      final result = await context.read<GroupProvider>().generateTest(
        _aiTopicCtrl.text.trim(), 
        _aiFormat, // Передаем формат вопросов
        _aiQuestionsCount
      );
      
      if (mounted) Navigator.pop(context);

      if (result != null) {
        setState(() {
          _questions = List<Map<String, dynamic>>.from(jsonDecode(result));
          _testTitleCtrl.text = _aiTestTitle;
          _maxAttempts = _aiMaxAttempts;
          _creationMode = 'manual'; // Переключаем на ручной режим для просмотра
        });
      } else {
        _showError("Не удалось сгенерировать вопросы");
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      _showError("Ошибка генерации: $e");
    }
  }

  Future<void> _publishTest() async {
    if (_testTitleCtrl.text.isEmpty) {
      _showError("Введите название теста");
      return;
    }
    if (_questions.isEmpty) {
      _showError("Добавьте хотя бы один вопрос");
      return;
    }

    for (int i = 0; i < _questions.length; i++) {
      final q = _questions[i];
      if (q['question'] == null || q['question'].toString().isEmpty) {
        _showError("Вопрос ${i + 1}: отсутствует текст вопроса");
        return;
      }
      if (q['options'] == null || (q['options'] as List).isEmpty) {
        _showError("Вопрос ${i + 1}: отсутствуют варианты ответов");
        return;
      }
      if (q['correctAnswer'] == null) {
        _showError("Вопрос ${i + 1}: не указан правильный ответ");
        return;
      }
    }

    for (var q in _questions) {
      if (q['question'].toString().isEmpty || q['correctAnswer'] == null) {
        _showError("Проверьте, что во всех вопросах заполнен текст и правильный ответ");
        return;
      }
    }

    try {
      await context.read<GroupProvider>().createRoadmapStepWithTest(
        groupId: widget.groupId,
        content: _testTitleCtrl.text.trim(),
        dueDate: _dueDate,
        testData: jsonEncode(_questions),
        maxAttempts: _maxAttempts,
        isRequired: true,
      );
      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Тест успешно опубликован и доступен ученику!"),
            backgroundColor: Colors.green,
          )
        );
      }
    } catch (e) {
      _showError("Ошибка при публикации: $e");
    }
  }

  void _showError(String m) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(m),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isWeb = MediaQuery.of(context).size.width > 950;
    return MainDashboardLayout(
      selectedIndex: 3,
      child: Scaffold(
        backgroundColor: const Color(0xFFF2F5F9),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          title: Text(
            "КОНСТРУКТОР ТЕСТА",
            style: GoogleFonts.manrope(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: AppColors.navy
            )
          ),
          leading: const BackButton(color: AppColors.navy),
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: isWeb ? 800 : double.infinity),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _buildGlobalSettings(),
                const SizedBox(height: 20),
                _buildModeToggle(),
                const SizedBox(height: 20),
                if (_creationMode == 'ai') _buildAISection()
                else ...[
                  _buildQuestionList(),
                  const SizedBox(height: 10),
                  if (_isAddingQuestion) _buildManualQuestionEditor()
                  else _buildAddQuestionButton(),
                ],
                const SizedBox(height: 30),
                if (_questions.isNotEmpty) _buildPublishButton(),
                const SizedBox(height: 50),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGlobalSettings() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha:0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label("НАЗВАНИЕ ТЕСТА"),
          TextField(
            controller: _testTitleCtrl,
            decoration: InputDecoration(
              hintText: "Введите название теста",
              prefixIcon: const Icon(Icons.edit_note, color: AppColors.navy),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.navy, width: 2),
              ),
              filled: true,
              fillColor: Colors.grey.shade50,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label("КОЛИЧЕСТВО ПОПЫТОК"),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.grey.shade50,
                      ),
                      child: DropdownButtonFormField<int>(
                        value: _maxAttempts,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          prefixIcon: Icon(Icons.refresh, color: AppColors.navy),
                        ),
                        items: [1, 2, 3, 5, 10]
                            .map((e) => DropdownMenuItem(
                                  value: e,
                                  child: Text(
                                    "$e ${e == 1 ? 'попытка' : e < 5 ? 'попытки' : 'попыток'}",
                                  ),
                                ))
                            .toList(),
                        onChanged: (v) => setState(() => _maxAttempts = v!),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label("ДЕДЛАЙН"),
                    InkWell(
                      onTap: () async {
                        final d = await showDatePicker(
                          context: context,
                          initialDate: _dueDate,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (d != null) setState(() => _dueDate = d);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(12),
                          color: Colors.grey.shade50,
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today, color: AppColors.navy, size: 18),
                            const SizedBox(width: 10),
                            Text(
                              DateFormat('dd.MM.yyyy').format(_dueDate),
                              style: const TextStyle(fontSize: 16),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildModeToggle() {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha:0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          _toggleBtn("РУЧНОЕ СОЗДАНИЕ", 'manual', Icons.create),
          const SizedBox(width: 5),
          _toggleBtn("AI ГЕНЕРАЦИЯ", 'ai', Icons.auto_awesome),
        ],
      ),
    );
  }

  Widget _toggleBtn(String label, String mode, IconData icon) {
    bool active = _creationMode == mode;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _creationMode = mode),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
          decoration: BoxDecoration(
            color: active ? AppColors.navy : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: active ? Colors.white : Colors.grey, size: 18),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    color: active ? Colors.white : Colors.grey,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAISection() {
    return Container(
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.purple.shade600, AppColors.navy],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.withValues(alpha:0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.auto_awesome, color: Colors.amber, size: 24),
              SizedBox(width: 10),
              Text(
                "AI ГЕНЕРАЦИЯ ТЕСТА",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          // НАЗВАНИЕ ТЕСТА
          _buildAIInputField(
            label: "Название теста",
            hint: "Например: Итоговый тест по географии",
            icon: Icons.edit,
            onChanged: (v) => _aiTestTitle = v,
          ),
          const SizedBox(height: 12),
          
          // ТЕМА
          _buildAIInputField(
            label: "Тема теста",
            hint: "Например: География России",
            icon: Icons.topic,
            controller: _aiTopicCtrl,
          ),
          const SizedBox(height: 12),
          
          // ФОРМАТ ВОПРОСОВ
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha:0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: DropdownButtonFormField<String>(
              value: _aiFormat,
              dropdownColor: Colors.purple.shade800,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: "Формат вопросов",
                labelStyle: TextStyle(color: Colors.white70),
                border: InputBorder.none,
              ),
              items: const [
                DropdownMenuItem(value: 'single', child: Text("Один правильный ответ", style: TextStyle(color: Colors.white))),
                DropdownMenuItem(value: 'multiple', child: Text("Несколько правильных", style: TextStyle(color: Colors.white))),
                DropdownMenuItem(value: 'boolean', child: Text("Верно/Неверно", style: TextStyle(color: Colors.white))),
              ],
              onChanged: (v) => setState(() => _aiFormat = v!),
            ),
          ),
          const SizedBox(height: 20),
          
          // КОЛИЧЕСТВО ВОПРОСОВ И ПОПЫТОК
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Количество вопросов:", style: TextStyle(color: Colors.white70, fontSize: 12)),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha:0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            onPressed: () {
                              if (_aiQuestionsCount > 1) setState(() => _aiQuestionsCount--);
                            },
                            icon: const Icon(Icons.remove_circle_outline, color: Colors.white),
                          ),
                          Text(
                            "$_aiQuestionsCount",
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
                          ),
                          IconButton(
                            onPressed: () {
                              if (_aiQuestionsCount < 20) setState(() => _aiQuestionsCount++);
                            },
                            icon: const Icon(Icons.add_circle_outline, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Макс. попыток:", style: TextStyle(color: Colors.white70, fontSize: 12)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha:0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: DropdownButtonFormField<int>(
                        value: _aiMaxAttempts,
                        dropdownColor: Colors.purple.shade800,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(border: InputBorder.none),
                        items: [1, 2, 3, 5, 10]
                            .map((e) => DropdownMenuItem(
                                  value: e,
                                  child: Text("$e", style: const TextStyle(color: Colors.white)),
                                ))
                            .toList(),
                        onChanged: (v) => setState(() => _aiMaxAttempts = v!),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 25),
          
          // КНОПКА ГЕНЕРАЦИИ
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _handleAIGeneration,
              icon: const Icon(Icons.auto_awesome),
              label: const Text("СГЕНЕРИРОВАТЬ ВОПРОСЫ", style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                foregroundColor: Colors.purple.shade900,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAIInputField({
    required String label,
    required String hint,
    required IconData icon,
    TextEditingController? controller,
    Function(String)? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          onChanged: onChanged,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.white70),
            prefixIcon: Icon(icon, color: Colors.white60),
            filled: true,
            fillColor: Colors.white.withValues(alpha:0.1),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuestionList() {
    if (_questions.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(30),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            Icon(Icons.quiz_outlined, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 10),
            Text("Нет добавленных вопросов", style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 5, bottom: 10),
          child: Text("ВОПРОСЫ (${_questions.length})", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
        ),
        ..._questions.asMap().entries.map((e) => _buildQuestionCard(e.key, e.value)),
      ],
    );
  }

  Widget _buildQuestionCard(int idx, Map q) {
    String typeLabel = '';
    IconData typeIcon = Icons.radio_button_checked;
    
    switch (q['type']) {
      case 'single':
        typeLabel = 'Один ответ';
        typeIcon = Icons.radio_button_checked;
        break;
      case 'multiple':
        typeLabel = 'Несколько ответов';
        typeIcon = Icons.check_box;
        break;
      case 'boolean':
        typeLabel = 'Верно/Неверно';
        typeIcon = Icons.toggle_on;
        break;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Кнопки перемещения
                Column(
                  children: [
                    if (idx > 0)
                      InkWell(
                        onTap: () => _moveQuestion(idx, idx - 1),
                        child: const Icon(Icons.keyboard_arrow_up, size: 20, color: Colors.grey),
                      ),
                    if (idx < _questions.length - 1)
                      InkWell(
                        onTap: () => _moveQuestion(idx, idx + 1),
                        child: const Icon(Icons.keyboard_arrow_down, size: 20, color: Colors.grey),
                      ),
                  ],
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.navy.withValues(alpha:0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(typeIcon, size: 14, color: AppColors.navy),
                      const SizedBox(width: 4),
                      Text(typeLabel, style: const TextStyle(fontSize: 10, color: AppColors.navy, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.edit, size: 18, color: Colors.blue),
                  onPressed: () => _editQuestion(idx),
                  constraints: const BoxConstraints(),
                  padding: EdgeInsets.zero,
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                  onPressed: () => setState(() => _questions.removeAt(idx)),
                  constraints: const BoxConstraints(),
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(q['question'], style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
            const SizedBox(height: 8),
            ...((q['options'] as List).map((opt) {
              bool isCorrect = false;
              if (q['type'] == 'multiple') {
                isCorrect = (q['correctAnswer'] as List).contains(opt);
              } else {
                isCorrect = q['correctAnswer'] == opt;
              }
              return Padding(
                padding: const EdgeInsets.only(left: 8, top: 2),
                child: Row(
                  children: [
                    Icon(
                      isCorrect ? Icons.check_circle : Icons.circle_outlined,
                      size: 16,
                      color: isCorrect ? Colors.green : Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      opt,
                      style: TextStyle(
                        color: isCorrect ? Colors.green.shade700 : Colors.grey.shade700,
                        fontWeight: isCorrect ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              );
            }).toList()),
          ],
        ),
      ),
    );
  }

  Widget _buildManualQuestionEditor() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.navy, width: 2),
        boxShadow: [
          BoxShadow(
            color: AppColors.navy.withValues(alpha:0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.quiz, color: AppColors.navy),
              const SizedBox(width: 8),
              Text(
                _isEditingQuestion ? "РЕДАКТИРОВАНИЕ ВОПРОСА" : "НОВЫЙ ВОПРОС",
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.navy),
              ),
            ],
          ),
          const SizedBox(height: 15),
          
          // Тип вопроса
          DropdownButtonFormField<String>(
            value: _currentQuestionType,
            decoration: InputDecoration(
              labelText: "Тип ответа",
              prefixIcon: Icon(
                _currentQuestionType == 'single' ? Icons.radio_button_checked : _currentQuestionType == 'multiple' ? Icons.check_box : Icons.toggle_on,
                color: AppColors.navy,
              ),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: Colors.grey.shade50,
            ),
            items: const [
              DropdownMenuItem(value: 'single', child: Text("Один правильный ответ")),
              DropdownMenuItem(value: 'multiple', child: Text("Несколько правильных ответов")),
              DropdownMenuItem(value: 'boolean', child: Text("Верно/Неверно")),
            ],
            onChanged: (v) {
              setState(() {
                _currentQuestionType = v!;
                _singleCorrectAnswer = null;
                _multipleCorrectAnswers = [];
                _booleanCorrectAnswer = null;
                _initOptionControllers();
              });
            },
          ),
          const SizedBox(height: 15),
          
          // Текст вопроса
          TextField(
            controller: _questionTextCtrl,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: "Введите текст вопроса",
              prefixIcon: const Icon(Icons.question_answer, color: AppColors.navy),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: Colors.grey.shade50,
            ),
          ),
          const SizedBox(height: 20),
          
          // Варианты ответов
          if (_currentQuestionType == 'boolean')
            _buildBooleanOptions()
          else
            _buildMultipleOptions(),
          
          const SizedBox(height: 20),
          
          // Кнопки
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _isAddingQuestion = false;
                      _resetQuestionEditor();
                    });
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text("ОТМЕНА"),
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: ElevatedButton(
                  onPressed: _addQuestionToList,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.navy,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    _isEditingQuestion ? "СОХРАНИТЬ ИЗМЕНЕНИЯ" : "ДОБАВИТЬ ВОПРОС",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildBooleanOptions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Правильный ответ:", style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.navy)),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: ChoiceChip(
                label: const Text("ВЕРНО"),
                selected: _booleanCorrectAnswer == true,
                selectedColor: Colors.green,
                labelStyle: TextStyle(
                  color: _booleanCorrectAnswer == true ? Colors.white : Colors.black,
                  fontWeight: FontWeight.bold,
                ),
                onSelected: (selected) => setState(() => _booleanCorrectAnswer = true),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ChoiceChip(
                label: const Text("НЕВЕРНО"),
                selected: _booleanCorrectAnswer == false,
                selectedColor: Colors.red,
                labelStyle: TextStyle(
                  color: _booleanCorrectAnswer == false ? Colors.white : Colors.black,
                  fontWeight: FontWeight.bold,
                ),
                onSelected: (selected) => setState(() => _booleanCorrectAnswer = false),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMultipleOptions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text("Варианты ответов:", style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.navy)),
            const Spacer(),
            if (_currentQuestionType == 'single')
              const Text("Выберите один правильный", style: TextStyle(fontSize: 11, color: Colors.grey))
            else
              const Text("Выберите правильные", style: TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
        const SizedBox(height: 10),
        ..._optionCtrls.asMap().entries.map((e) => _optionRow(e.key, e.value)),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: () {
            setState(() {
              _optionCtrls.add(TextEditingController(text: 'Вариант ${_optionCtrls.length + 1}'));
            });
          },
          icon: const Icon(Icons.add_circle_outline),
          label: const Text("Добавить вариант"),
        ),
      ],
    );
  }

  Widget _optionRow(int idx, TextEditingController ctrl) {
    bool isCorrect;
    
    if (_currentQuestionType == 'multiple') {
      isCorrect = _multipleCorrectAnswers.contains(ctrl.text);
    } else {
      isCorrect = _singleCorrectAnswer == ctrl.text;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          // Кнопка выбора правильного ответа
          IconButton(
            icon: Icon(
              _currentQuestionType == 'multiple'
                  ? (isCorrect ? Icons.check_box : Icons.check_box_outline_blank)
                  : (isCorrect ? Icons.radio_button_checked : Icons.radio_button_unchecked),
              color: isCorrect ? Colors.green : Colors.grey,
            ),
            onPressed: () {
              setState(() {
                if (_currentQuestionType == 'multiple') {
                  if (isCorrect) {
                    _multipleCorrectAnswers.remove(ctrl.text);
                  } else {
                    _multipleCorrectAnswers.add(ctrl.text);
                  }
                } else {
                  _singleCorrectAnswer = ctrl.text;
                }
              });
            },
          ),
          // Поле ввода варианта
          Expanded(
            child: TextField(
              controller: ctrl,
              onChanged: (v) {
                setState(() {
                  if (_currentQuestionType == 'single' && _singleCorrectAnswer != null) {
                    // Обновляем правильный ответ если он был выбран
                    final oldCorrect = _optionCtrls.firstWhere(
                      (c) => c.text == _singleCorrectAnswer,
                      orElse: () => ctrl,
                    );
                    if (oldCorrect == ctrl) {
                      _singleCorrectAnswer = v;
                    }
                  }
                });
              },
              decoration: InputDecoration(
                hintText: "Вариант ответа ${idx + 1}",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                filled: true,
                fillColor: isCorrect ? Colors.green.shade50 : Colors.grey.shade50,
              ),
            ),
          ),
          // Кнопка удаления варианта (минимум 2)
          if (_optionCtrls.length > 2)
            IconButton(
              icon: const Icon(Icons.close, size: 18, color: Colors.red),
              onPressed: () {
                setState(() {
                  final removedText = ctrl.text;
                  _optionCtrls.removeAt(idx);
                  ctrl.dispose();
                  if (_currentQuestionType == 'single' && _singleCorrectAnswer == removedText) {
                    _singleCorrectAnswer = null;
                  }
                  if (_currentQuestionType == 'multiple') {
                    _multipleCorrectAnswers.remove(removedText);
                  }
                });
              },
            ),
        ],
      ),
    );
  }

  Widget _buildAddQuestionButton() {
    return OutlinedButton.icon(
      onPressed: () {
        setState(() {
          _isAddingQuestion = true;
          _resetQuestionEditor();
        });
      },
      icon: const Icon(Icons.add_circle_outline, size: 20),
      label: const Text("ДОБАВИТЬ ВОПРОС"),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(double.infinity, 55),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: BorderSide(color: AppColors.navy.withValues(alpha:0.5), width: 2),
      ),
    );
  }

  Widget _buildPublishButton() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppColors.navy.withValues(alpha:0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton.icon(
        onPressed: _publishTest,
        icon: const Icon(Icons.publish),
        label: const Text("ОПУБЛИКОВАТЬ ТЕСТ", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.navy,
          minimumSize: const Size(double.infinity, 60),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _label(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(t, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.2)),
  );

  @override
  void dispose() {
    _testTitleCtrl.dispose();
    _aiTopicCtrl.dispose();
    _questionTextCtrl.dispose();
    for (var c in _optionCtrls) {
      c.dispose();
    }
    super.dispose();
  }
}