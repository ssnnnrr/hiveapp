import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:hive_app/providers/user_provider.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/all_models.dart';
import '../providers/group_provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/main_dashboard_layout.dart';
import 'test_run_screen.dart';
import 'test_creation_screen.dart'; // ДОБАВЛЯЕМ ИМПОРТ

// --- ОСНОВНОЙ ЭКРАН ЧАТА И ПЛАНА ОБУЧЕНИЯ ---

class ChatScreen extends StatefulWidget {
  final GroupResponse group;
  const ChatScreen({super.key, required this.group});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}



class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  // Контроллеры
  bool _isRatingDialogShowing = false;
  late TabController _tabController;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();
  final FocusNode _messageFocusNode = FocusNode();

  // Состояние Roadmap
  int _roadmapFilterIndex = 0;
  bool _isInitialized = false;
  bool _isMentioningTask = false;
  List<RoadmapStepDto> _filteredMentionTasks = [];
  bool _hasSubmittedReviewInThisSession = false;
  bool _isSystemActionLoading = false;

@override
void initState() {
  super.initState();
  _tabController = TabController(length: 2, vsync: this);
  _initializeChat();
  _messageController.addListener(_onChatInputChanged);
}

Future<void> _initializeChat() async {
  await Future.delayed(Duration.zero);
  if (!mounted) return;

  final groupProv = context.read<GroupProvider>();
  final authProv = context.read<AuthProvider>();
  final myId = authProv.user?.id ?? 0;

  await groupProv.openChat(
    widget.group.id, 
    myId,
    context,
    onBothFinished: () {
      if (mounted) _checkAndShowRating();
    },
  );

  if (mounted) {
    setState(() => _isInitialized = true);
    // Проверка при открытии чата: если уже всё завершено, а мы еще не оценили
    _checkAndShowRating();
  }
}

// Новый метод проверки условий для показа рейтинга
void _checkAndShowRating() async {
  if (_isRatingDialogShowing || _hasSubmittedReviewInThisSession) return;

  final groupProv = context.read<GroupProvider>();
  try {
    final group = groupProv.groups.firstWhere((g) => g.id == widget.group.id);
    // Если оба завершили обучение
    if (group.ownerFinished && group.partnerFinished) {
      _showRatingDialog();
    }
  } catch (e) {
    debugPrint("Check rating error: $e");
  }
}


  Widget _buildPinnedHeader(MessageDto pinned) {
    return FadeInDown(
      // Анимация появления
      duration: const Duration(milliseconds: 200),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha:0.95),
          border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
        ),
        child: InkWell(
          onTap: () => _scrollToMessage(pinned.id), // Прыжок при нажатии
          child: Row(
            children: [
              Container(width: 3, height: 32, color: AppColors.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "Закреплённое сообщение",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    Text(
                      pinned.content,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 20, color: Colors.grey),
                onPressed: () => context.read<GroupProvider>().togglePinMessage(
                  pinned.id,
                  false,
                  widget.group.id,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _scrollToMessage(int messageId) {
    final prov = context.read<GroupProvider>();
    // Находим индекс сообщения в оригинальном списке
    final index = prov.messages.reversed.toList().indexWhere(
      (m) => m.id == messageId,
    );

    if (index != -1) {
      _chatScrollController.animateTo(
        index * 80.0,
        duration: const Duration(milliseconds: 500),
        curve: Curves.fastOutSlowIn,
      );
    }
  }

  // Вспомогательное окно подтверждения удаления
  void _confirmDeleteMessage(int messageId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Удалить?"),
        content: const Text("Это сообщение исчезнет у всех участников чата."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("ОТМЕНА"),
          ),
          TextButton(
            onPressed: () {
              context.read<GroupProvider>().deleteMessage(messageId);
              Navigator.pop(ctx);
            },
            child: const Text("УДАЛИТЬ", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _onChatInputChanged() {
    final text = _messageController.text;
    if (text.contains('@')) {
      final lastPart = text.split('@').last;
      if (!lastPart.contains(' ')) {
        setState(() {
          _isMentioningTask = true;
          _filteredMentionTasks = context.read<GroupProvider>().roadmapSteps;
        });
      } else {
        setState(() => _isMentioningTask = false);
      }
    } else if (_isMentioningTask) {
      setState(() => _isMentioningTask = false);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _messageController.dispose();
    _chatScrollController.dispose();
    _messageFocusNode.dispose();
    super.dispose();
  }

  void _jumpToChatWithTask(RoadmapStepDto step, String prefix) {
    _tabController.animateTo(0);
    setState(() {
      _messageController.text = "$prefix @\"${step.content}\": ";
    });
    _messageFocusNode.requestFocus();
    _messageController.selection = TextSelection.fromPosition(
      TextPosition(offset: _messageController.text.length),
    );
  }

  // МЕТОД ДЛЯ ОТКРЫТИЯ ПОЛНОЦЕННОЙ СТРАНИЦЫ СОЗДАНИЯ ТЕСТА
  void _openTestCreationScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TestCreationScreen(groupId: widget.group.id),
      ),
    ).then((_) {
      // Обновляем roadmap после возврата
      context.read<GroupProvider>().loadRoadmap(widget.group.id);
    });
  }

  Future<void> _handleResourceOpen(String? path) async {
    if (path == null || path.isEmpty) return;

    // Если это внешняя ссылка
    if (path.startsWith('http')) {
      final uri = Uri.parse(path);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      return;
    }

    // Если это файл на сервере
    String fileName = path.contains('/') ? path.split('/').last : path;
    final downloadUrl =
        'http://localhost:5254/api/Chat/download/${Uri.encodeComponent(fileName)}';

    try {
      final uri = Uri.parse(downloadUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw "Не удалось открыть $downloadUrl";
      }
    } catch (e) {
      debugPrint("Ошибка открытия файла: $e");
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Ошибка открытия файла: $e")));
      }
    }
  }

 void _showAddStepDialog() {
    final titleCtrl = TextEditingController();
    final theoryCtrl = TextEditingController();
    bool needArtifact = false;
    bool useFileInsteadOfLink = false;
    DateTime deadline = DateTime.now().add(const Duration(days: 3));
    PlatformFile? selectedFile;
    bool isUploading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
          title: const Text("НОВОЕ ЗАДАНИЕ / МАТЕРИАЛ", style: TextStyle(fontWeight: FontWeight.w900)),
          content: ConstrainedBox(
            // ОГРАНИЧЕНИЕ: Карточка не будет расти шире 500 пикселей
            constraints: const BoxConstraints(maxWidth: 500),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleCtrl,
                    // ПЕРЕНОС ТЕКСТА: Разрешаем до 5 строк, далее скролл. 
                    // Текст будет уходить вниз, а не вбок.
                    maxLines: 5,
                    minLines: 1,
                    keyboardType: TextInputType.multiline,
                    style: const TextStyle(fontSize: 15),
                    decoration: AppDecorations.smartInput(
                      "Текст задания *",
                      Icons.edit_note,
                    ).copyWith(
                      // Чтобы длинная строка без пробелов тоже пыталась перенестись
                      hintStyle: const TextStyle(fontSize: 13),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.calendar_month, color: AppColors.primary),
                    title: const Text("Дедлайн:", style: TextStyle(fontSize: 13)),
                    subtitle: Text(
                      DateFormat('dd MMMM yyyy', 'ru').format(deadline),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: deadline,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) setSt(() => deadline = picked);
                    },
                  ),
                  const Divider(),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text("Использовать файл", style: TextStyle(fontSize: 14)),
                    value: useFileInsteadOfLink,
                    onChanged: (v) => setSt(() => useFileInsteadOfLink = v),
                  ),
                  if (!useFileInsteadOfLink)
                    TextField(
                      controller: theoryCtrl,
                      maxLines: 1, // Ссылку обычно не нужно многострочно
                      decoration: AppDecorations.smartInput("Ссылка на теорию (URL)", Icons.link),
                    )
                  else
                    // Блок выбора файла
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 10),
                      width: double.infinity,
                      child: selectedFile == null
                          ? OutlinedButton.icon(
                              onPressed: () async {
                                final result = await FilePicker.platform.pickFiles(withData: true);
                                if (result != null) setSt(() => selectedFile = result.files.first);
                              },
                              icon: const Icon(Icons.upload_file),
                              label: const Text("Выбрать файл"),
                            )
                          : Row(
                              children: [
                                const Icon(Icons.description, color: Colors.green),
                                const SizedBox(width: 8),
                                Expanded(child: Text(selectedFile!.name, overflow: TextOverflow.ellipsis)),
                                IconButton(onPressed: () => setSt(() => selectedFile = null), icon: const Icon(Icons.close, color: Colors.red)),
                              ],
                            ),
                    ),
                  const SizedBox(height: 10),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text("Требовать отчет от ученика", style: TextStyle(fontSize: 13)),
                    value: needArtifact,
                    onChanged: (v) => setSt(() => needArtifact = v!),
                  ),
                  if (isUploading) const Padding(padding: EdgeInsets.all(10), child: LinearProgressIndicator()),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("ОТМЕНА")),
            ElevatedButton(
              onPressed: isUploading ? null : () async {
                if (titleCtrl.text.trim().isEmpty) return;
                setSt(() => isUploading = true);
                String? finalPath;
                try {
                  if (useFileInsteadOfLink && selectedFile != null) {
                    finalPath = await context.read<GroupProvider>().uploadFileToServer(selectedFile!);
                  } else {
                    finalPath = theoryCtrl.text.isNotEmpty ? theoryCtrl.text.trim() : null;
                  }
                  await context.read<GroupProvider>().addRoadmapStep(
                    groupId: widget.group.id,
                    content: titleCtrl.text.trim(),
                    date: deadline,
                    isRequired: needArtifact,
                    instructionUrl: finalPath,
                  );
                  if (mounted) Navigator.pop(ctx);
                } catch (e) {
                  setSt(() => isUploading = false);
                }
              },
              child: const Text("СОХРАНИТЬ"),
            ),
          ],
        ),
      ),
    );
}

  void _showDetailedTestResults(RoadmapStepDto s) {
    if (s.testData == null) return;
    final List<dynamic> questions = jsonDecode(s.testData!);
    Map<String, dynamic> studentAnswers = {};
    try {
      studentAnswers = jsonDecode(s.studentComment ?? "{}");
    } catch (e) {
      debugPrint("Error parsing answers: $e");
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (_, scroll) => Column(
          children: [
            Container(
              padding: const EdgeInsets.all(25),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(30),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "РАЗБОР ТЕСТА",
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 20,
                          color: AppColors.navy,
                        ),
                      ),
                      Text(
                        "Лучший результат: ${((s.testScore ?? 0) * 100).toInt()}%",
                        style: const TextStyle(
                          color: Colors.grey,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close_rounded, size: 28),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: scroll,
                padding: const EdgeInsets.all(20),
                itemCount: questions.length,
                itemBuilder: (context, i) {
                  final q = questions[i];
                  final String correct = q['correctAnswer'].toString();
                  String studentAns = "Нет ответа";
                  if (studentAnswers.containsKey("Вопрос ${i + 1}")) {
                    studentAns = studentAnswers["Вопрос ${i + 1}"].toString();
                  } else if (studentAnswers.values.length > i) {
                    studentAns = studentAnswers.values.elementAt(i).toString();
                  }

                  final bool isCorrect =
                      studentAns.toLowerCase().trim() ==
                      correct.toLowerCase().trim();

                  return FadeInUp(
                    delay: Duration(milliseconds: 50 * i),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 15),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: isCorrect
                            ? Colors.green.withValues(alpha:0.03)
                            : Colors.red.withValues(alpha:0.03),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isCorrect
                              ? Colors.green.withValues(alpha:0.2)
                              : Colors.red.withValues(alpha:0.2),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 12,
                                backgroundColor: isCorrect
                                    ? Colors.green
                                    : Colors.red,
                                child: Text(
                                  "${i + 1}",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  q['question'],
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                    color: AppColors.navy,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 15),
                            child: Divider(height: 1),
                          ),
                          _resultValue(
                            "ВАШ ОТВЕТ:",
                            studentAns,
                            isCorrect ? Colors.green : Colors.red,
                          ),
                          if (!isCorrect) ...[
                            const SizedBox(height: 12),
                            _resultValue(
                              "ПРАВИЛЬНЫЙ ОТВЕТ:",
                              correct,
                              Colors.green,
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _resultValue(String label, String val, Color col) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w900,
            color: Colors.grey,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          val,
          style: TextStyle(
            color: col,
            fontWeight: FontWeight.w900,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final auth = context.read<AuthProvider>();
    final myId = auth.user?.id ?? 0;

    return MainDashboardLayout(
      selectedIndex: 3,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: _buildChatHeader(),
        body: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [_buildMessagesTab(myId), _buildRoadmapTab(myId)],
                  ),
                ),
              ],
            ),
            if (_isMentioningTask) _buildMentionOverlay(),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildChatHeader() {
    double width = MediaQuery.of(context).size.width;
    bool isWide = width > 1000;

    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0.5,
      toolbarHeight: 70,
      // Кнопка назад (скрыта в веб-версии)
      leading: isWide
          ? const SizedBox.shrink()
          : IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: AppColors.navy,
                size: 20,
              ),
              onPressed: () => Navigator.pop(context),
            ),
      title: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppColors.navy.withValues(alpha:0.1),
            child: Text(
              widget.group.name.isNotEmpty
                  ? widget.group.name[0].toUpperCase()
                  : "?",
              style: const TextStyle(
                color: AppColors.navy,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.group.name,
                  style: GoogleFonts.manrope(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: AppColors.navy,
                  ),
                ),
                Text(
                  widget.group.isSolo ? "Личный диалог" : "Учебная группа",
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
      
      bottom: TabBar(
        controller: _tabController,
        indicatorColor: AppColors.primary,
        indicatorWeight: 4,
        labelColor: AppColors.navy,
        unselectedLabelColor: Colors.grey,
        labelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
        tabs: const [
          Tab(text: "ОБСУЖДЕНИЕ"),
          Tab(text: "ПЛАН ОБУЧЕНИЯ"),
        ],
      ),
    );
  }



  void _showArtifactStatusDialog(RoadmapStepDto s) {
    MainDashboardLayout.showHiveDialog(
      context,
      StatefulBuilder(
        builder: (ctx, setSt) {
          // Логика состояний
          bool isRejected = s.teacherComment != null && s.status == "ToDo";
          bool hasArtifact = s.artifactUrl != null;
          bool isUnderReview = s.status == "UnderReview";
          bool isDone = s.status == "Done";

          return Padding(
            padding: const EdgeInsets.all(32),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Иконка в зависимости от статуса
                  Icon(
                    isDone
                        ? Icons.check_circle_rounded
                        : (isRejected
                              ? Icons.edit_notifications_rounded
                              : (isUnderReview
                                    ? Icons.hourglass_top_rounded
                                    : Icons.cloud_upload_outlined)),
                    size: 54,
                    color: isDone
                        ? Colors.green
                        : (isRejected
                              ? Colors.orange
                              : (isUnderReview
                                    ? Colors.blue
                                    : AppColors.primary)),
                  ),
                  const SizedBox(height: 16),

                  // Заголовок
                  Text(
                    isDone
                        ? "ЗАДАНИЕ ПРИНЯТО"
                        : (isRejected
                              ? "НУЖНЫ ПРАВКИ"
                              : (isUnderReview
                                    ? "НА ПРОВЕРКЕ"
                                    : "СДАТЬ РАБОТУ")),
                    style: GoogleFonts.manrope(
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                      color: AppColors.navy,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Текст задания (с переносом)
                  Flexible(
                    child: Text(
                      s.content,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ),

                  // Блок правок учителя
                  if (isRejected)
                    Container(
                      margin: const EdgeInsets.only(top: 20),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha:0.08),
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                          color: Colors.orange.withValues(alpha:0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "КОММЕНТАРИЙ УЧИТЕЛЯ:",
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 10,
                              color: Colors.orange,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            s.teacherComment!,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.navy,
                              fontWeight: FontWeight.w600,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 25),

                  // Отображение сданного ранее ответа
                  if (hasArtifact)
                    InkWell(
                      onTap: () => _handleResourceOpen(s.artifactUrl),
                      borderRadius: BorderRadius.circular(15),
                      child: Container(
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F4F9),
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(
                            color: isUnderReview
                                ? Colors.blue.withValues(alpha:0.2)
                                : Colors.transparent,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              s.artifactUrl!.startsWith('http')
                                  ? Icons.link_rounded
                                  : Icons.description_rounded,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "ВАШ ПОСЛЕДНИЙ ОТВЕТ (НАЖМИТЕ):",
                                    style: TextStyle(
                                      fontSize: 8,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  Text(
                                    s.artifactUrl!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: AppColors.navy,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Кнопка удаления для пересдачи
                            if (!isDone)
                              IconButton(
                                onPressed: () =>
                                    setSt(() => s.artifactUrl = null),
                                icon: const Icon(
                                  Icons.delete_sweep_rounded,
                                  color: Colors.redAccent,
                                ),
                                tooltip: "Сбросить и прикрепить заново",
                              ),
                          ],
                        ),
                      ),
                    ),

                  const SizedBox(height: 30),

                  // Кнопки действий
                  if (!hasArtifact && !isDone)
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              _showAddLinkDialog(s.id, s.groupId);
                            },
                            icon: const Icon(Icons.link, size: 18),
                            label: const Text(
                              "ССЫЛКА",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              // Вызов метода загрузки файла из GroupProvider
                              await context
                                  .read<GroupProvider>()
                                  .uploadArtifact(s.id, s.groupId);
                              Navigator.pop(context);
                              _refreshData();
                            },
                            icon: const Icon(
                              Icons.upload_file,
                              color: Colors.white,
                              size: 18,
                            ),
                            label: const Text(
                              "ФАЙЛ",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.navy,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  else
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text(
                          "ЗАКРЫТЬ",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

Widget _buildMessagesTab(int myId) {
    return Consumer<GroupProvider>(
      builder: (context, prov, _) {
        final pinned = prov.pinnedMessage;
        // ВАЖНО: Больше не делаем .reversed.toList() здесь! 
        // Провайдер уже отдает список в нужном для reverse:true порядке.
        final displayMessages = prov.messages; 

        return Column(
          children: [
            if (pinned != null) _buildPinnedHeader(pinned),

            Expanded(
              child: prov.messages.isEmpty
                  ? const Center(child: Text("Сообщений нет"))
                  : ListView.builder(
                      controller: _chatScrollController,
                      reverse: true, // НОВЫЕ СООБЩЕНИЯ СНИЗУ (ИНДЕКС 0)
                      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 20),
                      itemCount: displayMessages.length,
                      itemBuilder: (ctx, i) {
                        final m = displayMessages[i];
                        final bool isMe = m.senderId == myId;

                        if (m.content.startsWith("[COMPLETION_REQUEST]")) {
                          return _buildCompletionRequestBubble(m, isMe);
                        }
                        if (m.content.startsWith("[RESTART_PROPOSAL]")) {
                          return _buildRestartProposalBubble(m, isMe);
                        }
                        return _buildMessageBubble(m, isMe);
                      },
                    ),
            ),
            _buildChatInputArea(),
          ],
        );
      },
    );
  }


Future<void> _confirmRestart() async {
  if (_isSystemActionLoading) return;
  setState(() => _isSystemActionLoading = true);
  
  try {
    // Просто шлем запрос на сервер. 
    // Весь UI обновится сам, когда придет сигнал RoadmapUpdated в GroupProvider
    await context.read<GroupProvider>().confirmRestart(widget.group.id);
  } catch (e) {
    debugPrint("Restart error: $e");
  } finally {
    if (mounted) setState(() => _isSystemActionLoading = false);
  }
}

// Метод подтверждения окончания (для учителя)
Future<void> _confirmFinish() async {
  if (_isSystemActionLoading) return;
  setState(() => _isSystemActionLoading = true);

  try {
    // Шлем подтверждение
    await context.read<GroupProvider>().confirmPartnerCompletion(widget.group.id);
    // Окно рейтинга и скрытие кнопок произойдет через SignalR
  } catch (e) {
    debugPrint("Confirm error: $e");
  } finally {
    if (mounted) setState(() => _isSystemActionLoading = false);
  }
}

Widget _buildMessageBubble(MessageDto m, bool isMe) {
  // Следим за изменениями в GroupProvider для обновления состояния закладок
  final prov = context.watch<GroupProvider>();

  // Проверяем, закреплено ли сообщение локально (в закладках пользователя)
  final isLocallyPinned = prov.myPinnedMessages.contains(m.id);
  // Общее состояние: закреплено либо глобально для всех, либо локально
  final isAnyPinned = m.isPinned || isLocallyPinned;

  return Align(
    alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
    child: Container(
      // Ограничиваем ширину сообщения до 75% экрана
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.75,
      ),
      margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        // Темно-синий для "меня", белый для партнера
        color: isMe ? const Color(0xFF0D47A1) : Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(18),
          topRight: const Radius.circular(18),
          bottomLeft: isMe ? const Radius.circular(18) : Radius.zero,
          bottomRight: isMe ? Radius.zero : const Radius.circular(18),
        ),
        // Подсветка рамки при закрепе (оранжевый для всех, синий для личного)
        border: isAnyPinned
            ? Border.all(
                color: m.isPinned 
                    ? Colors.orange.withValues(alpha: 0.5) 
                    : Colors.blue.withValues(alpha: 0.5),
                width: 2,
              )
            : Border.all(color: Colors.grey.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // --- ХЕДЕР СООБЩЕНИЯ ---
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: isAnyPinned
                    ? Row(
                        children: [
                          Icon(
                            m.isPinned ? Icons.push_pin : Icons.bookmark,
                            size: 12,
                            color: isMe 
                                ? Colors.white70 
                                : (m.isPinned ? Colors.orange : Colors.blue),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            m.isPinned ? "ЗАКРЕПЛЕНО" : "В ЗАКЛАДКАХ",
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: isMe ? Colors.white70 : Colors.grey[600],
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      )
                    : (!isMe
                        ? Text(
                            m.senderName,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          )
                        : const SizedBox()),
              ),
              // Кнопка меню (три точки)
              _buildMessageMenu(m, isMe),
            ],
          ),

          const SizedBox(height: 4),

          // --- ТЕКСТ СООБЩЕНИЯ ---
          Text(
            m.content,
            style: TextStyle(
              color: isMe ? Colors.white : Colors.black87,
              fontSize: 14,
              height: 1.4,
            ),
          ),

          const SizedBox(height: 6),

          // --- ФУТЕР СООБЩЕНИЯ ---
          Align(
            alignment: Alignment.bottomRight,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  DateFormat('HH:mm').format(m.sentAt),
                  style: TextStyle(
                    fontSize: 10,
                    color: isMe ? Colors.white60 : Colors.grey[500],
                  ),
                ),
                if (isMe) ...[
                  const SizedBox(width: 4),
                  Icon(
                    Icons.done_all,
                    size: 14,
                    // Галочки голубые, если прочитано, и серые, если просто доставлено
                    color: m.isRead ? Colors.lightBlueAccent : Colors.white54,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    ),
  );
}


  Widget _buildRestartProposalBubble(MessageDto m, bool isMe) {
  final prov = context.read<GroupProvider>();

  return FadeInUp(
    child: Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.purple.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: Colors.purple.withValues(alpha: 0.2), width: 2),
      ),
      child: Column(
        children: [
          const Icon(Icons.refresh_rounded, color: Colors.purple, size: 30),
          const SizedBox(height: 10),
          Text(m.content.split('|').last, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 15),
          if (!isMe)
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
                    // ВОТ ЗДЕСЬ МЫ ИСПОЛЬЗУЕМ МЕТОД, ЧТОБЫ ОШИБКА ИСЧЕЗЛА:
                    onPressed: _isSystemActionLoading ? null : _confirmRestart, 
                    child: _isSystemActionLoading
                        ? const SizedBox(
                            width: 20, 
                            height: 20, 
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)
                          )
                        : const Text("СОГЛАСЕН", style: TextStyle(color: Colors.white)),
                  ),
                ),
          ],
            )
          else
            const Text(
              "Ожидание согласия партнера...",
              style: TextStyle(color: Colors.grey, fontSize: 12, fontStyle: FontStyle.italic),
            ),
        ],
      ),
    ),
  );
}


Widget _buildNormalInput() {
  return Container(
    padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
    ),
    child: Row(
      children: [
        Expanded(
          child: TextField(
            controller: _messageController,
            focusNode: _messageFocusNode,
            maxLines: null,
            decoration: InputDecoration(
              hintText: "Напишите сообщение...",
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(25),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
          ),
        ),
        const SizedBox(width: 10),
        CircleAvatar(
          backgroundColor: const Color(0xFF023E8A),
          radius: 24,
          child: IconButton(
            icon: const Icon(Icons.send, color: Colors.white, size: 20),
            onPressed: () {
              if (_messageController.text.trim().isNotEmpty) {
                context.read<GroupProvider>().sendMessage(
                  widget.group.id,
                  _messageController.text.trim(),
                );
                _messageController.clear();
              }
            },
          ),
        ),
      ],
    ),
  );
}


  Widget _buildMessageMenu(MessageDto m, bool isMe) {
  final prov = context.read<GroupProvider>();
  // ИСПОЛЬЗУЕМ ПЕРЕМЕННУЮ ТУТ:
  final isLocallyPinned = prov.myPinnedMessages.contains(m.id);

  return SizedBox(
    height: 20,
    width: 20,
    child: PopupMenuButton<String>(
      padding: EdgeInsets.zero,
      icon: Icon(Icons.more_horiz, size: 16, color: isMe ? Colors.white70 : Colors.grey),
      onSelected: (value) {
        switch (value) {
          case 'local_pin':
            prov.toggleLocalPin(m.id); // Метод в провайдере
            break;
          case 'global_pin':
            prov.togglePinMessage(m.id, !m.isPinned, widget.group.id);
            break;
          case 'delete':
            _confirmDeleteMessage(m.id);
            break;
        }
      },
      itemBuilder: (context) => [
        // Опция "Закладка" (Локальный закреп)
        PopupMenuItem(
          value: 'local_pin',
          child: Row(
            children: [
              // ТЕПЕРЬ ПЕРЕМЕННАЯ ИСПОЛЬЗУЕТСЯ ДЛЯ ВИЗУАЛИЗАЦИИ
              Icon(
                isLocallyPinned ? Icons.bookmark : Icons.bookmark_border, 
                size: 18, 
                color: Colors.blue
              ),
              const SizedBox(width: 8),
              Text(isLocallyPinned ? "Удалить закладку" : "В закладки"),
            ],
          ),
        ),
        // Опция "Закрепить для всех"
        PopupMenuItem(
          value: 'global_pin',
          child: Row(
            children: [
              Icon(m.isPinned ? Icons.push_pin : Icons.push_pin_outlined, size: 18, color: Colors.orange),
              const SizedBox(width: 8),
              Text(m.isPinned ? "Открепить" : "Закрепить"),
            ],
          ),
        ),
        if (isMe)
          const PopupMenuItem(
            value: 'delete',
            child: Row(
              children: [
                Icon(Icons.delete_outline, size: 18, color: Colors.red),
                const SizedBox(width: 8),
                Text("Удалить", style: TextStyle(color: Colors.red)),
              ],
            ),
          ),
      ],
    ),
  );
}

Widget _buildChatInputArea() {
  return Consumer<GroupProvider>(
    builder: (context, prov, _) {
      final group = prov.groups.firstWhere((g) => g.id == widget.group.id, orElse: () => widget.group);
      bool bothFinished = group.ownerFinished && group.partnerFinished;

      if (bothFinished) {
        bool hasActiveProposal = prov.messages.any((m) => m.content.startsWith("[RESTART_PROPOSAL]"));

        return Container(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
          decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Color(0xFFF1F5F9)))),
          child: SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton.icon(
              onPressed: (hasActiveProposal || _isSystemActionLoading) ? null : () async {
                setState(() => _isSystemActionLoading = true);
                await prov.proposeRestart(group.id);
                if (mounted) setState(() => _isSystemActionLoading = false);
              },
              icon: Icon(hasActiveProposal ? Icons.hourglass_top : Icons.refresh, color: Colors.white),
              label: Text(
                hasActiveProposal ? "ОЖИДАНИЕ ПАРТНЕРА..." : "ВОЗОБНОВИТЬ ОБМЕН НАВЫКАМИ", 
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: hasActiveProposal ? Colors.grey : const Color(0xFF0D47A1),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              ),
            ),
          ),
        );
      }
      return _buildNormalInput(); 
    },
  );
}

  Widget _buildMentionOverlay() {
    return Positioned(
      bottom: 100,
      left: 20,
      right: 20,
      child: FadeInUp(
        duration: const Duration(milliseconds: 150),
        child: Material(
          elevation: 10,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            constraints: const BoxConstraints(maxHeight: 250),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _filteredMentionTasks.length,
              itemBuilder: (ctx, i) {
                final t = _filteredMentionTasks[i];
                return ListTile(
                  leading: Icon(
                    t.isTest ? Icons.quiz : Icons.assignment,
                    size: 18,
                  ),
                  title: Text(
                    t.content,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onTap: () {
                    final current = _messageController.text;
                    final lastAt = current.lastIndexOf('@');
                    setState(() {
                      _messageController.text =
                          "${current.substring(0, lastAt)}@\"${t.content}\" ";
                      _isMentioningTask = false;
                    });
                    _messageFocusNode.requestFocus();
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }

Widget _buildRoadmapTab(int myId) {
  return Consumer<GroupProvider>(
    builder: (context, prov, _) {
      GroupResponse group;
      try {
        group = prov.groups.firstWhere((g) => g.id == widget.group.id);
      } catch (e) {
        group = widget.group;
      }
      
      bool isOwner = group.ownerId == myId;
      bool iFinishedAsStudent = isOwner ? group.ownerFinished : group.partnerFinished;
      bool partnerFinishedAsStudent = isOwner ? group.partnerFinished : group.ownerFinished;
      bool bothFinished = group.ownerFinished && group.partnerFinished;

      // 1. Разделяем задачи на активные и архивные
      final activeSteps = prov.roadmapSteps.where((s) => !s.isArchived).toList();
      final archivedSteps = prov.roadmapSteps.where((s) => s.isArchived).toList();

      // 2. Фильтруем АКТИВНЫЕ задачи по выбранной роли
      final List<RoadmapStepDto> activeForMe = activeSteps.where((s) => s.creatorId != myId).toList();
      final List<RoadmapStepDto> activeFromMe = activeSteps.where((s) => s.creatorId == myId).toList();
      
      // 3. Фильтруем АРХИВНЫЕ задачи по выбранной роли (ВАШ ЗАПРОС)
      final List<RoadmapStepDto> archivedForMe = archivedSteps.where((s) => s.creatorId != myId).toList();
      final List<RoadmapStepDto> archivedFromMe = archivedSteps.where((s) => s.creatorId == myId).toList();

      // Выбираем списки для текущего индекса фильтра
      final currentActiveList = _roadmapFilterIndex == 0 ? activeForMe : activeFromMe;
      final currentArchivedList = _roadmapFilterIndex == 0 ? archivedForMe : archivedFromMe;

      return Column(
        children: [
          // ПАНЕЛЬ УПРАВЛЕНИЯ
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.1))),
            ),
            child: Row(
              children: [
                _filterTabButton("Я УЧЕНИК", 0),
                const SizedBox(width: 8),
                _filterTabButton("Я УЧИТЕЛЬ", 1),
                const Spacer(),
                
                if (_roadmapFilterIndex == 1) ...[
                  if (!partnerFinishedAsStudent) ...[
                    IconButton(
                      icon: const Icon(Icons.add_task, color: AppColors.primary),
                      onPressed: _showAddStepDialog,
                      tooltip: "Дать задание",
                    ),
                    IconButton(
                      icon: const Icon(Icons.quiz_outlined, color: Colors.purple),
                      onPressed: _openTestCreationScreen,
                      tooltip: "Создать тест",
                    ),
                  ] else 
                    const Text("Обучение завершено ✅", 
                      style: TextStyle(fontSize: 10, color: Colors.green, fontWeight: FontWeight.bold)),
                ],

                if (_roadmapFilterIndex == 0 && !iFinishedAsStudent && !bothFinished)
                  TextButton.icon(
                    onPressed: () {
                      bool hasPending = activeForMe.any((s) => s.status != "Done");
                      if (hasPending) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Выполните все текущие задачи перед выпуском!"), 
                            backgroundColor: Colors.orange,
                          ),
                        );
                      } else {
                        prov.requestMyCompletion(group.id);
                      }
                    },
                    icon: const Icon(Icons.verified_user_rounded, size: 18, color: Colors.orange),
                    label: const Text("Я ЗАВЕРШИЛ ОБУЧЕНИЕ", 
                      style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 11)),
                  ),
              ],
            ),
          ),

          // СПИСОК ЗАДАЧ
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // ТЕКУЩИЕ ЗАДАЧИ
                if (currentActiveList.isNotEmpty) ...[
                  Text(
                    _roadmapFilterIndex == 0 ? "АКТИВНЫЕ УРОКИ" : "ТЕКУЩИЙ ПЛАН ДЛЯ ПАРТНЕРА", 
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 10, color: Colors.grey, letterSpacing: 1.2)
                  ),
                  const SizedBox(height: 15),
                  ...currentActiveList.map((s) => _buildLogicStepCard(s, myId)),
                ] else if (currentArchivedList.isEmpty && !bothFinished)
                  _buildRoadmapEmptyState(),

                // АРХИВНЫЕ ЗАДАЧИ ЭТОЙ РОЛИ
                if (currentArchivedList.isNotEmpty) ...[
                  const SizedBox(height: 30),
                  Theme(
                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      initiallyExpanded: false,
                      tilePadding: EdgeInsets.zero,
                      leading: const Icon(Icons.history_edu_rounded, color: Colors.blueGrey),
                      title: Text(
                        _roadmapFilterIndex == 0 
                            ? "АРХИВ МОИХ УРОКОВ (${currentArchivedList.length})" 
                            : "ИСТОРИЯ ЗАДАНИЙ ПАРТНЕРУ (${currentArchivedList.length})", 
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.blueGrey)
                      ),
                      children: currentArchivedList.map((s) => Opacity(
                        opacity: 0.85, // Делаем чуть ярче, чтобы текст был читаемым
                        child: _buildLogicStepCard(s, myId),
                      )).toList(),
                    ),
                  ),
                ],
                const SizedBox(height: 100),
              ],
            ),
          ),
        ],
      );
    },
  );
}

Widget _buildCompletionRequestBubble(MessageDto m, bool isMe) {
  final String text = m.content.split('|').last;

  return FadeInUp(
    child: Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFE3F2FD),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.3), width: 2),
      ),
      child: Column(
        children: [
          const Icon(Icons.verified_user_rounded, color: Colors.blue, size: 30),
          const SizedBox(height: 10),
          Text(text, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          if (!isMe)
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                    // Если мы уже нажали кнопку, она становится disabled (null)
                    onPressed: _isSystemActionLoading ? null : _confirmFinish, 
                    child: _isSystemActionLoading 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text("ПОДТВЕРЖДАЮ", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    // Блокируем и вторую кнопку тоже
                    onPressed: _isSystemActionLoading ? null : () async {
                      setState(() => _isSystemActionLoading = true);
                      await context.read<GroupProvider>().rejectCompletion(widget.group.id);
                      // Здесь не сбрасываем loading, SignalR сам обновит сообщения
                    },
                    child: const Text("ЕЩЕ НЕТ"),
                  ),
                ),
              ],
            )
          else
            const Text("Ожидание подтверждения учителя...", 
              style: TextStyle(color: Colors.grey, fontSize: 12, fontStyle: FontStyle.italic)),
        ],
      ),
    ),
  );
}

  Widget _filterTabButton(String label, int idx) {
    bool active = _roadmapFilterIndex == idx;
    return InkWell(
      onTap: () => setState(() => _roadmapFilterIndex = idx),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: active ? AppColors.navy : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : Colors.grey,
            fontWeight: FontWeight.w900,
            fontSize: 10,
          ),
        ),
      ),
    );
  }

Widget _buildLogicStepCard(RoadmapStepDto s, int myId) {
    bool isTeacher = s.creatorId == myId;
    bool isDone = s.status == "Done";
    bool isReview = s.status == "UnderReview";
    bool isRejected = s.teacherComment != null && s.status == "ToDo";
    bool isArchived = s.isArchived;

    // ЛОГИКА ПРОСТОГО ЧЕКБОКСА:
    // Если это не тест и не обязательное задание (isRequired = false)
    bool isSimpleTask = !s.isTest && !s.isRequired;

    // Цвета границ
    Color borderColor = isDone 
        ? Colors.green 
        : (isRejected ? Colors.orange : (isArchived ? Colors.grey.shade200 : AppColors.primary));

    return FadeInUp(
      child: Container(
        margin: const EdgeInsets.only(bottom: 18),
        decoration: BoxDecoration(
          color: isArchived ? const Color(0xFFFDFDFD) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isArchived ? 0.01 : 0.03),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
          border: Border.all(
            color: borderColor.withValues(alpha: isArchived ? 0.2 : 0.4),
            width: isArchived ? 1.5 : 2,
          ),
        ),
        child: Column(
          children: [
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),

              // --- ЛЕВАЯ ЧАСТЬ: ИКОНКА ИЛИ ЧЕКБОКС ---
              leading: isArchived 
                ? Icon(
                    isDone ? Icons.check_circle : Icons.history, 
                    color: isDone ? Colors.green : Colors.grey,
                    size: 28,
                  )
                : (isSimpleTask 
                    ? Transform.scale(
                        scale: 1.2,
                        child: Checkbox(
                          value: isDone,
                          activeColor: Colors.green,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(5),
                          ),
                          // Только ученик может переключать простые задачи
                          onChanged: isTeacher 
                              ? null 
                              : (val) {
                                  context.read<GroupProvider>().toggleStepComplete(
                                    stepId: s.id, 
                                    groupId: widget.group.id
                                  );
                                },
                        ),
                      )
                    : _buildStepStatusIcon(s, isDone)),

              title: Text(
                s.content,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  decoration: isDone ? TextDecoration.lineThrough : null,
                  color: isArchived ? Colors.blueGrey.shade700 : AppColors.navy,
                ),
              ),
              subtitle: Text(
                isArchived 
                  ? "Завершено в прошлом цикле" 
                  : "Дедлайн: ${DateFormat('dd.MM.yyyy').format(s.dueDate)}",
                style: const TextStyle(fontSize: 11),
              ),
              
              // Меню действий (три точки) только для активных задач
              trailing: isArchived ? null : _buildTaskActionMenu(s, isTeacher),
              
              // Нажатие на карточку (для тестов и артефактов)
              onTap: (isSimpleTask || isArchived) 
                ? null 
                : () => _handlePartnerTaskAction(s),
            ),

            // Блок правок учителя (только для активных)
            if (isRejected && !isArchived) _buildRejectedCommentBlock(s.teacherComment!),

            // --- КОНТЕНТНАЯ ЧАСТЬ (Только для активных сложных задач) ---
            if (!isArchived) ...[
              if (s.isTest)
                _buildTestStepBlock(s, isTeacher, isDone)
              else if (s.isRequired && !isDone)
                _buildArtifactSubmissionBlock(s, isTeacher, isReview),
            ] 
            // В архиве для тестов показываем только кнопку просмотра разбора
            else if (s.isTest && s.usedAttempts > 0) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: TextButton.icon(
                  onPressed: () => _showDetailedTestResults(s),
                  icon: const Icon(Icons.analytics_outlined, size: 16),
                  label: const Text("ПОСМОТРЕТЬ РЕЗУЛЬТАТЫ ТЕСТА", 
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ),
            ],

            // --- РЕСУРСЫ: Доступны ВСЕГДА (и в активе, и в архиве) ---
            if (s.instructionUrl != null || s.artifactUrl != null)
              _buildStepResourcesRow(s),

            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }


  // Метод для обработки нажатия на "сложные" задачи (тесты или задания с артефактами)
  void _handlePartnerTaskAction(RoadmapStepDto task) {
    if (task.isArchived) return; // В архиве действия не выполняются

    // 1. Если это тест
    if (task.isTest) {
      _showTestActionDialog(task);
      return;
    }

    // 2. Если это обязательное задание (требует отчет/артефакт)
    if (task.isRequired) {
      _showArtifactStatusDialog(task);
    }
  }

  // Вспомогательное окно для перехода к тесту
  void _showTestActionDialog(RoadmapStepDto task) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.quiz, color: Colors.purple),
            const SizedBox(width: 10),
            const Text("ТЕСТ"),
          ],
        ),
        content: Text(
          "Пройти тест: ${task.content}?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("ОТМЕНА"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _startTest(task); // Вызов существующего метода начала теста
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
            child: const Text("НАЧАТЬ", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }


  // Виджет правки от учителя (для красоты и wrapping)
  Widget _buildRejectedCommentBlock(String comment) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 15),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha:0.08),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.edit_note, color: Colors.orange, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              "ПРАВКИ: $comment",
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.navy,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildArtifactSubmissionBlock(
    RoadmapStepDto s,
    bool isTeacher,
    bool isReview,
  ) {
    bool isDone = s.status == "Done";

    if (isTeacher) {
      if (isReview) {
        return Padding(
          padding: const EdgeInsets.all(15),
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha:0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  "УЧЕНИК ПРИСЛАЛ РАБОТУ",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                    color: Colors.orange,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      // ИСПРАВЛЕНО: Именованные аргументы
                      onPressed: () => context.read<GroupProvider>().verifyStep(
                        stepId: s.id,
                        approve: true,
                        groupId: widget.group.id,
                      ),
                      icon: const Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 18,
                      ),
                      label: const Text(
                        "ПРИНЯТЬ",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showTeacherDeclineDialog(s.id),
                      icon: const Icon(
                        Icons.edit_note,
                        color: Colors.orange,
                        size: 18,
                      ),
                      label: const Text(
                        "ПРАВКИ",
                        style: TextStyle(
                          color: Colors.orange,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.orange),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      }
      return const SizedBox.shrink();
    } else {
      // Вид для УЧЕНИКА
      if (isDone) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.all(15),
        child: SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            onPressed: () => _showArtifactStatusDialog(s),
            style: ElevatedButton.styleFrom(
              backgroundColor: isReview ? Colors.blueGrey : AppColors.navy,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
            ),
            icon: Icon(
              isReview ? Icons.hourglass_bottom : Icons.cloud_upload,
              color: Colors.white,
            ),
            label: Text(
              isReview ? "НА ПРОВЕРКЕ" : "СДАТЬ РАБОТУ",
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      );
    }
  }

  // Обновленный блок теста с кнопкой "Сдать"
  Widget _buildTestStepBlock(RoadmapStepDto s, bool isTeacher, bool isDone) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.purple.withValues(alpha:0.05),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "ПОПЫТКИ: ${s.usedAttempts} / ${s.maxAttempts}",
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  color: Colors.purple,
                  fontSize: 11,
                ),
              ),
              if (s.testScore != null)
                Text(
                  "РЕЗУЛЬТАТ: ${(s.testScore! * 100).toInt()}%",
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (!isDone && !isTeacher) ...[
            if (s.usedAttempts < s.maxAttempts)
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 45),
                ),
                onPressed: () => _startTest(s),
                child: const Text(
                  "ПРОЙТИ ТЕСТ",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            // КНОПКА "ЗАФИКСИРОВАТЬ": появляется после 1-й попытки
            if (s.usedAttempts > 0)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.purple),
                    minimumSize: const Size(double.infinity, 40),
                  ),
                  onPressed: () => context
                      .read<GroupProvider>()
                      .finalizeTestResult(s.id, widget.group.id),
                  child: const Text(
                    "СДАТЬ ТЕКУЩИЙ РЕЗУЛЬТАТ",
                    style: TextStyle(
                      color: Colors.purple,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
          ],
          if (isDone || (isTeacher && s.usedAttempts > 0))
            TextButton(
              onPressed: () => _showDetailedTestResults(s),
              child: const Text(
                "ПОСМОТРЕТЬ РАЗБОР",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: Colors.purple,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Иконка статуса задания в плане обучения (Галочка ТОЛЬКО если принято)
  Widget _buildStepStatusIcon(RoadmapStepDto s, bool isDone) {
    bool actuallyAccepted = s.status == "Done";
    bool isReview = s.status == "UnderReview";
    bool isRejected = s.teacherComment != null && s.status != "Done";

    Color col = actuallyAccepted
        ? Colors.green
        : (isReview || isRejected
              ? Colors.orange
              : (s.isTest ? Colors.purple : AppColors.primary));

    IconData icon = actuallyAccepted
        ? Icons.check_circle
        : (isReview
              ? Icons.hourglass_bottom
              : (isRejected
                    ? Icons.edit_notifications
                    : (s.isTest ? Icons.quiz : Icons.assignment_turned_in)));

    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: col.withValues(alpha:0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: col, size: 22),
    );
  }

  // Добавьте второй параметр int groupId сюда
  void _showAddLinkDialog(int stepId, int groupId) {
    final linkCtrl = TextEditingController();

    MainDashboardLayout.showHiveDialog(
      context,
      Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.link_rounded, size: 48, color: AppColors.primary),
            const SizedBox(height: 20),
            const Text(
              "ПРИКРЕПИТЬ ССЫЛКУ",
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 18,
                color: AppColors.navy,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              "Вставьте URL-адрес вашего ответа (например, Google Drive или GitHub)",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 25),
            TextField(
              controller: linkCtrl,
              decoration: AppDecorations.smartInput(
                "https://...",
                Icons.insert_link,
              ),
            ),
            const SizedBox(height: 30),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("ОТМЕНА"),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      if (linkCtrl.text.isEmpty) return;

                      // ВАЖНО: Используем groupId, который теперь приходит в метод
                      await context.read<GroupProvider>().submitStepResult(
                        stepId: stepId,
                        artifactUrl: linkCtrl.text.trim(),
                        studentComment: "Добавлена ссылка",
                        groupId: groupId, // Передаем его в провайдер
                      );

                      Navigator.pop(context);
                      _refreshData();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.navy,
                    ),
                    child: const Text(
                      "ОТПРАВИТЬ",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

void _showRatingDialog() async {
  if (_isRatingDialogShowing) return;
  _isRatingDialogShowing = true;

  final userProv = context.read<UserProvider>();
  final myId = context.read<AuthProvider>().user?.id;
  
  // 1. Загружаем профиль партнера, чтобы получить существующий отзыв
  await userProv.loadTargetProfile(widget.group.otherUserId!);
  final partnerProfile = userProv.targetFullProfile;
  
  // 2. Ищем наш предыдущий отзыв в профиле партнера
  ReviewDto? existingReview;
  if (partnerProfile != null && myId != null) {
    try {
      existingReview = partnerProfile.reviews.firstWhere(
        (r) => r.reviewerName == context.read<AuthProvider>().user?.username
      );
    } catch (_) {}
  }

  int selectedRating = existingReview?.rating ?? 5;
  final commentCtrl = TextEditingController(text: existingReview?.comment ?? "");

  if (!mounted) return;

  MainDashboardLayout.showHiveDialog(
    context,
    StatefulBuilder(
      builder: (ctx, setSt) => Padding(
        padding: const EdgeInsets.all(32),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.stars_rounded, size: 64, color: Colors.amber),
              const SizedBox(height: 16),
              Text(
                existingReview != null ? "ОБНОВИТЬ ОТЗЫВ" : "ОБУЧЕНИЕ ЗАВЕРШЕНО!",
                style: GoogleFonts.manrope(fontWeight: FontWeight.w900, fontSize: 18, color: AppColors.navy),
              ),
              const SizedBox(height: 8),
              Text(
                existingReview != null 
                  ? "Вы можете изменить свой предыдущий отзыв о партнере." 
                  : "Пожалуйста, оцените работу вашего партнера. Ваш отзыв влияет на его BeePower.",
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const SizedBox(height: 25),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) {
                  return IconButton(
                    onPressed: () => setSt(() => selectedRating = i + 1),
                    icon: Icon(
                      i < selectedRating ? Icons.star_rounded : Icons.star_outline_rounded,
                      color: Colors.amber, size: 42,
                    ),
                  );
                }),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: commentCtrl,
                maxLines: 3,
                style: const TextStyle(fontSize: 14),
                decoration: AppDecorations.smartInput("Ваш отзыв о партнере...", Icons.rate_review_outlined),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.navy,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () async {
                    bool ok = await userProv.submitReview(
                      widget.group.otherUserId!, 
                      selectedRating, 
                      commentCtrl.text.trim(),
                    );

                    if (mounted && ok) {
                      _hasSubmittedReviewInThisSession = true;
                      _isRatingDialogShowing = false;
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Отзыв сохранен!"), backgroundColor: Colors.green),
                      );
                    }
                  },
                  child: const Text("СОХРАНИТЬ И ВЫЙТИ", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
              TextButton(
                onPressed: () {
                  _isRatingDialogShowing = false;
                  Navigator.pop(ctx);
                },
                child: const Text("ПОЗЖЕ", style: TextStyle(color: Colors.grey)),
              )
            ],
          ),
        ),
      ),
    ),
  ).then((_) => _isRatingDialogShowing = false);
}

  // 1. Добавьте этот метод внутрь _ChatScreenState
  void _refreshData() {
    context.read<GroupProvider>().loadRoadmap(widget.group.id);
  }

  void _showTeacherDeclineDialog(int stepId) {
    final commentCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Что нужно исправить?"),
        content: TextField(
          controller: commentCtrl,
          maxLines: 3,
          decoration: AppDecorations.smartInput(
            "Замечания учителя...",
            Icons.comment,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("ОТМЕНА"),
          ),
          ElevatedButton(
            onPressed: () {
              if (commentCtrl.text.isNotEmpty) {
                context.read<GroupProvider>().verifyStep(
                  stepId: stepId,
                  groupId: widget.group.id,
                  approve: false,
                  comment: commentCtrl.text.trim(),
                );
                Navigator.pop(ctx);
              }
            },
            child: const Text("ОТПРАВИТЬ ПРАВКИ"),
          ),
        ],
      ),
    );
  }

  Widget _buildStepResourcesRow(RoadmapStepDto s) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      // В архиве фон ресурсов делаем чуть темнее для контраста
      color: s.isArchived ? const Color(0xFFF1F4F9) : const Color(0xFFF8FAFC),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (s.isArchived)
            const Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: Text("АРХИВНЫЕ МАТЕРИАЛЫ:", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.grey)),
            ),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              if (s.instructionUrl != null)
                _resourceBadge(
                  "ТЕОРИЯ / МАТЕРИАЛ",
                  Icons.menu_book,
                  Colors.blue,
                  s.instructionUrl!,
                ),
              if (s.artifactUrl != null)
                _resourceBadge(
                  "ОТЧЕТ УЧЕНИКА",
                  Icons.description,
                  Colors.green,
                  s.artifactUrl!,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _resourceBadge(String label, IconData icon, Color col, String url) {
    return InkWell(
      onTap: () => _handleResourceOpen(url),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: col.withValues(alpha:0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: col.withValues(alpha:0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: col),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: col,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskActionMenu(RoadmapStepDto s, bool isTeacher) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, color: Colors.grey),
      onSelected: (val) {
        if (val == "ask")
          _jumpToChatWithTask(s, "❓ Вопрос по задаче");
        else if (val == "unclear")
          _jumpToChatWithTask(s, "⚠️ Непонятно по задаче");
        else if (val == "clarify")
          _jumpToChatWithTask(s, "🔍 Уточнение по задаче");
        else if (val == "delete")
          _confirmDelete(s.id);
      },
      itemBuilder: (ctx) => [
        if (!isTeacher) ...[
          const PopupMenuItem(
            value: "ask",
            child: Text("Задать вопрос в чате"),
          ),
          const PopupMenuItem(
            value: "unclear",
            child: Text("Отметить как непонятное"),
          ),
          const PopupMenuItem(value: "clarify", child: Text("Уточнить детали")),
        ],
        if (isTeacher)
          const PopupMenuItem(
            value: "delete",
            child: Text("Удалить задачу", style: TextStyle(color: Colors.red)),
          ),
      ],
    );
  }

  void _confirmDelete(int id) => showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text("Удалить задачу?"),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text("ОТМЕНА"),
        ),
        TextButton(
          onPressed: () {
            context.read<GroupProvider>().deleteRoadmapStep(
              id,
              widget.group.id,
            );
            Navigator.pop(ctx);
          },
          child: const Text("УДАЛИТЬ", style: TextStyle(color: Colors.red)),
        ),
      ],
    ),
  );

  void _startTest(RoadmapStepDto s) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => TestTakingScreen(step: s)),
    ).then((_) async {
      // После возврата с теста принудительно обновляем данные группы
      await context.read<GroupProvider>().loadRoadmap(widget.group.id);
      if (mounted) setState(() {}); // Перерисовываем виджет чата
    });
  }

  Widget _buildRoadmapEmptyState() => const Center(
    child: Text(
      "В этом списке пока нет задач",
      style: TextStyle(color: Colors.grey),
    ),
  );
}
