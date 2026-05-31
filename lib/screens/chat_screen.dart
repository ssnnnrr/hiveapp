import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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
  late TabController _tabController;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();
  final FocusNode _messageFocusNode = FocusNode();

  // Состояние Roadmap
  int _roadmapFilterIndex = 0;
  bool _isInitialized = false;
  bool _isMentioningTask = false;
  List<RoadmapStepDto> _filteredMentionTasks = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initializeChat();
    _messageController.addListener(_onChatInputChanged);
  }

   Future<void> _initializeChat() async {
    // Небольшая задержка, чтобы дать UI отрисоваться и не конфликтовать с анимациями перехода
    await Future.delayed(Duration.zero);
    
    if (!mounted) return;

    try {
      final groupProv = context.read<GroupProvider>();
      final authProv = context.read<AuthProvider>();
      final myId = authProv.user?.id ?? 0;

      // ОЧЕНЬ ВАЖНО: проверяем, не загружены ли уже сообщения для этой группы, 
      // чтобы не перезапускать SignalR зря
      await groupProv.openChat(widget.group.id, myId);

    } catch (e) {
      debugPrint("Init Error: $e");
    } finally {
      // Даже если произошла ошибка, убираем индикатор загрузки, 
      // иначе будет "вечная загрузка"
      if (mounted) {
        setState(() => _isInitialized = true);
      }
    }
  }


  Widget _buildPinnedHeader(MessageDto pinned) {
  return FadeInDown( // Анимация появления
    duration: const Duration(milliseconds: 200),
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
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
                    style: const TextStyle(fontSize: 13, color: Colors.black87),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 20, color: Colors.grey),
              onPressed: () => context.read<GroupProvider>().togglePinMessage(pinned.id, false, widget.group.id),
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
  final index = prov.messages.reversed.toList().indexWhere((m) => m.id == messageId);

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
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("ОТМЕНА")),
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
    if (path.startsWith('http')) {
      await launchUrl(Uri.parse(path), mode: LaunchMode.externalApplication);
      return;
    }
    String fileName = path.contains('/') ? path.split('/').last : path;
    final downloadUrl =
        'http://localhost:5254/api/Chat/download/${Uri.encodeComponent(fileName)}';
    try {
      await launchUrl(
        Uri.parse(downloadUrl),
        mode: LaunchMode.externalApplication,
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Ошибка открытия файла: $e")));
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
          ),
          title: const Text(
            "НОВОЕ ЗАДАНИЕ / МАТЕРИАЛ",
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration: AppDecorations.smartInput(
                    "Текст задания *",
                    Icons.edit_note,
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 20),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.calendar_month,
                    color: AppColors.primary,
                  ),
                  title: const Text("Дедлайн:"),
                  subtitle: Text(
                    DateFormat('dd MMMM yyyy', 'ru').format(deadline),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
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
                  title: const Text(
                    "Использовать файл",
                    style: TextStyle(fontSize: 14),
                  ),
                  value: useFileInsteadOfLink,
                  onChanged: (v) => setSt(() => useFileInsteadOfLink = v),
                ),
                if (!useFileInsteadOfLink)
                  TextField(
                    controller: theoryCtrl,
                    decoration: const InputDecoration(
                      labelText: "Ссылка на теорию (URL)",
                    ),
                  )
                else
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 10),
                    child: selectedFile == null
                        ? OutlinedButton.icon(
                            onPressed: () async {
                              final result = await FilePicker.platform
                                  .pickFiles(withData: true);
                              if (result != null)
                                setSt(() => selectedFile = result.files.first);
                            },
                            icon: const Icon(Icons.upload_file),
                            label: const Text("Выбрать файл"),
                          )
                        : Row(
                            children: [
                              const Icon(
                                Icons.description,
                                color: Colors.green,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  selectedFile!.name,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              IconButton(
                                onPressed: () =>
                                    setSt(() => selectedFile = null),
                                icon: const Icon(
                                  Icons.close,
                                  color: Colors.red,
                                ),
                              ),
                            ],
                          ),
                  ),
                const SizedBox(height: 10),
                CheckboxListTile(
                  title: const Text(
                    "Требовать отчет от ученика",
                    style: TextStyle(fontSize: 13),
                  ),
                  value: needArtifact,
                  onChanged: (v) => setSt(() => needArtifact = v!),
                ),
                if (isUploading)
                  const Padding(
                    padding: EdgeInsets.all(10),
                    child: LinearProgressIndicator(),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("ОТМЕНА"),
            ),
            ElevatedButton(
              onPressed: isUploading
                  ? null
                  : () async {
                      if (titleCtrl.text.isEmpty) return;
                      setSt(() => isUploading = true);
                      String? finalPath;
                      try {
                        if (useFileInsteadOfLink && selectedFile != null) {
                          finalPath = await context
                              .read<GroupProvider>()
                              .uploadFileToServer(selectedFile!);
                        } else {
                          finalPath = theoryCtrl.text.isNotEmpty
                              ? theoryCtrl.text.trim()
                              : null;
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
                            ? Colors.green.withOpacity(0.03)
                            : Colors.red.withOpacity(0.03),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isCorrect
                              ? Colors.green.withOpacity(0.2)
                              : Colors.red.withOpacity(0.2),
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
      // ИСПРАВЛЕНО: Скрываем кнопку назад в вебе, так как сайдбар доступен всегда
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
            backgroundColor: AppColors.navy.withOpacity(0.1),
            child: Text(
              widget.group.name[0].toUpperCase(),
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
          // Работа считается отклоненной, только если есть комментарий и статус не Done/UnderReview
          bool isRejected = s.teacherComment != null && s.status == "ToDo";
          bool hasArtifact = s.artifactUrl != null;
          bool isUnderReview = s.status == "UnderReview";
          bool isDone = s.status == "Done";

          return Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
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
                Text(
                  isDone
                      ? "ЗАДАНИЕ ПРИНЯТО"
                      : (isRejected
                            ? "НУЖНЫ ПРАВКИ"
                            : (isUnderReview ? "НА ПРОВЕРКЕ" : "СДАТЬ РАБОТУ")),
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    color: AppColors.navy,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  s.content,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                ),

                // Блок правок (скрывается, если статус изменился на UnderReview)
                if (isRejected)
                  Container(
                    margin: const EdgeInsets.only(top: 20),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: Colors.orange.withOpacity(0.3)),
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
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          s.teacherComment!,
                          style: const TextStyle(
                            fontSize: 14,
                            height: 1.4,
                            color: AppColors.navy,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 25),

                // ОТОБРАЖЕНИЕ ПОСЛЕДНЕГО ОТВЕТА (Кликабельно)
                if (hasArtifact)
                  InkWell(
                    onTap: () => _handleResourceOpen(
                      s.artifactUrl,
                    ), // Открывает файл или ссылку
                    borderRadius: BorderRadius.circular(15),
                    child: Container(
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: isUnderReview
                            ? Colors.blue.withOpacity(0.05)
                            : const Color(0xFFF1F4F9),
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                          color: isUnderReview
                              ? Colors.blue.withOpacity(0.2)
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
                                  "ВАШ ПОСЛЕДНИЙ ОТВЕТ (НАЖМИТЕ, ЧТОБЫ ОТКРЫТЬ):",
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
                          if (!isDone)
                            IconButton(
                              onPressed: () =>
                                  setSt(() => s.artifactUrl = null),
                              icon: const Icon(
                                Icons.delete_sweep_rounded,
                                color: Colors.redAccent,
                              ),
                              tooltip: "Загрузить другое",
                            ),
                        ],
                      ),
                    ),
                  ),

                const SizedBox(height: 30),

                // КНОПКИ ЗАГРУЗКИ НОВОГО
                if (!hasArtifact && !isDone)
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            _showAddLinkDialog(s.id);
                          },
                          icon: const Icon(Icons.link),
                          label: const Text("ССЫЛКА"),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.navy,
                          ),
                          onPressed: () async {
                            await context.read<GroupProvider>().uploadArtifact(
                              s.id,
                              s.groupId,
                            );
                            Navigator.pop(context);
                            _refreshData();
                          },
                          icon: const Icon(
                            Icons.upload_file,
                            color: Colors.white,
                          ),
                          label: const Text(
                            "ФАЙЛ",
                            style: TextStyle(color: Colors.white),
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
                      child: const Text("ЗАКРЫТЬ"),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showTeacherDeclineDialog(int stepId) {
    final commentCtrl = TextEditingController();

    MainDashboardLayout.showHiveDialog(
      context,
      Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.assignment_return_rounded,
              size: 50,
              color: Colors.orange,
            ),
            const SizedBox(height: 20),
            const Text(
              "ВЕРНУТЬ НА ДОРАБОТКУ",
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 18,
                color: AppColors.navy,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              "Опишите ученику, что именно нужно исправить в работе.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 25),
            TextField(
              controller: commentCtrl,
              maxLines: 4,
              decoration: AppDecorations.smartInput(
                "Замечания по работе...",
                Icons.edit_note_rounded,
              ),
            ),
            const SizedBox(height: 30),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("ОТМЕНА"),
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    onPressed: () {
                      if (commentCtrl.text.trim().isNotEmpty) {
                        context.read<GroupProvider>().verifyStep(
                          stepId,
                          false,
                          commentCtrl.text.trim(),
                          widget.group.id,
                        );
                        Navigator.pop(context);
                      }
                    },
                    child: const Text(
                      "ОТПРАВИТЬ ПРАВКИ",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
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

Widget _buildMessagesTab(int myId) {
  return Consumer<GroupProvider>(
    builder: (context, prov, _) {
      final pinned = prov.pinnedMessage;
      // Работаем с перевернутым списком для ListView
      final displayMessages = prov.messages.reversed.toList();

      return Column(
        children: [
          // ЭТОТ БЛОК ПОЯВИТСЯ СРАЗУ ПОД ВКЛАДКАМИ
          if (pinned != null) _buildPinnedHeader(pinned),

          Expanded(
            child: prov.messages.isEmpty
                ? const Center(child: Text("Сообщений нет"))
                : ListView.builder(
                    controller: _chatScrollController,
                    reverse: true, // НОВЫЕ СООБЩЕНИЯ СНИЗУ
                    padding: const EdgeInsets.all(20),
                    itemCount: displayMessages.length,
                    itemBuilder: (ctx, i) {
                      return _buildMessageBubble(displayMessages[i], displayMessages[i].senderId == myId);
                    },
                  ),
          ),
          _buildChatInputArea(),
        ],
      );
    },
  );
}

Widget _buildMessageBubble(MessageDto m, bool isMe) {
  // Следим за изменениями в GroupProvider (для обновления закрепов)
  final prov = context.watch<GroupProvider>();
  
  // Проверяем, закреплено ли сообщение локально (закладка)
  final isLocallyPinned = prov.myPinnedMessages.contains(m.id);
  // Общее состояние: закреплено хоть как-то
  final isAnyPinned = m.isPinned || isLocallyPinned;

  return Align(
    alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
    child: Container(
      width: 380,
      margin: const EdgeInsets.symmetric(vertical: 5),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        // Синий цвет для "меня" (как на скрине), белый для собеседника
        color: isMe ? const Color(0xFF0D47A1) : Colors.white,
        borderRadius: BorderRadius.circular(15),
        // Рамка появляется только при закрепе
        border: isAnyPinned 
            ? Border.all(
                color: m.isPinned ? Colors.orange : Colors.blue, 
                width: 1.5,
              ) 
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ВЕРХНЯЯ СТРОКА: Имя/Индикатор и Кнопка меню
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Левая сторона заголовка сообщения
              Expanded(
                child: isAnyPinned
                    ? Row(
                        children: [
                          Icon(
                            m.isPinned ? Icons.push_pin : Icons.bookmark, 
                            size: 12, 
                            color: isMe ? Colors.white70 : (m.isPinned ? Colors.orange : Colors.blue),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            m.isPinned ? "ЗАКРЕПЛЕНО ДЛЯ ВСЕХ" : "ВАША ЗАКЛАДКА",
                            style: TextStyle(
                              fontSize: 9, 
                              fontWeight: FontWeight.bold,
                              color: isMe ? Colors.white70 : Colors.grey[600],
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

              // КНОПКА ТРИ ТОЧКИ (Меню)
              _buildMessageMenu(m, isMe),
            ],
          ),

          const SizedBox(height: 6),

          // ТЕКСТ СООБЩЕНИЯ
          Text(
            m.content,
            style: TextStyle(
              color: isMe ? Colors.white : Colors.black87,
              fontSize: 14,
              height: 1.3, // Межстрочный интервал для читаемости
            ),
          ),

          const SizedBox(height: 6),

          // НИЖНЯЯ СТРОКА: Время и Статус прочтения
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

Widget _buildMessageMenu(MessageDto m, bool isMe) {
  final prov = context.read<GroupProvider>();
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
            prov.toggleLocalPin(m.id);
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
        // Опция 2: Для всех
        PopupMenuItem(
          value: 'global_pin',
          child: Row(
            children: [
              Icon(m.isPinned ? Icons.push_pin : Icons.push_pin_outlined, size: 18, color: Colors.orange),
              const SizedBox(width: 8),
              Text(m.isPinned ? "Открепить для всех" : "Закрепить для всех"),
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
                hintText:
                    "Напишите сообщение... (используйте @ для привязки к задаче)",
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          CircleAvatar(
            backgroundColor: AppColors.navy,
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
        final all = prov.roadmapSteps;
        final List<RoadmapStepDto> tasksForMe = all
            .where((s) => s.creatorId != myId)
            .toList();
        final List<RoadmapStepDto> tasksFromMe = all
            .where((s) => s.creatorId == myId)
            .toList();

        final currentList = _roadmapFilterIndex == 0 ? tasksForMe : tasksFromMe;

        return Column(
          children: [
            Container(
              padding: const EdgeInsets.all(15),
              color: Colors.white,
              child: Column(
                children: [
                  Row(
                    children: [
                      _filterTabButton("МНЕ НАЗНАЧЕНО", 0),
                      const SizedBox(width: 10),
                      _filterTabButton("ОТ МЕНЯ (УЧЕНИКУ)", 1),
                      const Spacer(),
                      if (_roadmapFilterIndex == 1) ...[
                        // Кнопка добавления обычного задания
                        IconButton(
                          icon: const Icon(
                            Icons.add_task,
                            color: AppColors.primary,
                          ),
                          onPressed: _showAddStepDialog,
                          tooltip: "Добавить задание",
                        ),
                        // Кнопка перехода на страницу создания теста
                        IconButton(
                          icon: const Icon(
                            Icons.quiz_outlined,
                            color: Colors.purple,
                          ),
                          onPressed:
                              _openTestCreationScreen, // ИСПОЛЬЗУЕМ НОВЫЙ МЕТОД
                          tooltip: "Создать тест",
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: currentList.isEmpty
                  ? _buildRoadmapEmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.all(20),
                      itemCount: currentList.length,
                      itemBuilder: (ctx, i) =>
                          _buildLogicStepCard(currentList[i], myId),
                    ),
            ),
          ],
        );
      },
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
    // Задание отклонено, если есть коммент и статус вернулся в ToDo
    bool isRejected = s.teacherComment != null && s.status == "ToDo";

    return FadeInUp(
      child: Container(
        margin: const EdgeInsets.only(bottom: 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
          border: Border.all(
            color: isDone
                ? Colors.green.withOpacity(0.2)
                : (isRejected
                      ? Colors.orange.withOpacity(0.3)
                      : Colors.grey.shade100),
            width: 2,
          ),
        ),
        child: Column(
          children: [
            ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 10,
              ),

              // --- ЛОГИКА ИКОНКИ (Галочка ТОЛЬКО если статус Done) ---
              leading: _buildStepStatusIcon(s, isDone),

              title: Text(
                s.content,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  decoration: isDone ? TextDecoration.lineThrough : null,
                  color: isDone ? Colors.grey : AppColors.navy,
                ),
              ),
              subtitle: Text(
                "Дедлайн: ${DateFormat('dd.MM.yyyy').format(s.dueDate)}",
                style: const TextStyle(fontSize: 11),
              ),
              trailing: _buildTaskActionMenu(s, isTeacher),
            ),

            // --- БЛОК ПРАВОК ОТ УЧИТЕЛЯ (Виден ученику сразу в списке) ---
            if (isRejected)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 15),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.withOpacity(0.2)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.info_outline_rounded,
                        size: 16,
                        color: Colors.orange,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "НУЖНЫ ПРАВКИ:",
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                color: Colors.orange,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              s.teacherComment!,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.navy,
                                fontWeight: FontWeight.w600,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // --- БЛОК ТЕСТА ---
            if (s.isTest) _buildTestStepBlock(s, isTeacher, isDone),

            // --- БЛОК СДАЧИ / ПРОВЕРКИ (Для заданий с файлами) ---
            if (!s.isTest && s.isRequired && !isDone)
              _buildArtifactSubmissionBlock(s, isTeacher, isReview),

            // --- КНОПКИ РЕСУРСОВ ---
            if (s.instructionUrl != null || s.artifactUrl != null)
              _buildStepResourcesRow(s),

            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  // Обновленный блок теста с кнопкой "Сдать"
  Widget _buildTestStepBlock(RoadmapStepDto s, bool isTeacher, bool isDone) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.purple.withOpacity(0.05),
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
        color: col.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: col, size: 22),
    );
  }

  void _showAddLinkDialog(int stepId) {
    final linkCtrl = TextEditingController();

    MainDashboardLayout.showHiveDialog(
      context,
      Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize
              .min, // Окно будет занимать минимум места по вертикали
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
              "Вставьте URL-адрес вашего ответа. Новый ответ заменит предыдущий и сбросит правки учителя.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 25),

            // Поле ввода с ограничением
            TextField(
              controller: linkCtrl,
              autofocus: true,
              style: const TextStyle(fontSize: 14),
              decoration:
                  AppDecorations.smartInput(
                    "https://example.com/your-work",
                    Icons.insert_link_rounded,
                  ).copyWith(
                    helperText: "Обязательно http:// или https://",
                    // Это предотвратит бесконечное расширение поля вширь
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 15,
                      vertical: 15,
                    ),
                  ),
            ),

            const SizedBox(height: 30),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text("ОТМЕНА"),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      String url = linkCtrl.text.trim();

                      // Валидация протокола
                      if (url.isEmpty ||
                          (!url.startsWith('http://') &&
                              !url.startsWith('https://'))) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              "Ошибка: Ссылка должна начинаться с http:// или https://",
                            ),
                            backgroundColor: Colors.redAccent,
                          ),
                        );
                        return;
                      }

                      // Логика отправки (находим шаг и groupId)
                      final groupProv = context.read<GroupProvider>();
                      // Пытаемся найти шаг в общем списке
                      final step = groupProv.allRoadmapSteps.firstWhere(
                        (e) => e.id == stepId,
                        orElse: () => RoadmapStepDto(
                          id: -1,
                          content: '',
                          dueDate: DateTime.now(),
                          status: '',
                          creatorId: 0,
                        ),
                      );

                      int finalGroupId = step.id != -1 ? step.groupId : 0;
                      // Если мы в чате, используем ID группы из виджета
                      if (finalGroupId == 0 && widget is ChatScreen) {
                        finalGroupId = (widget as ChatScreen).group.id;
                      }

                      await groupProv.submitStepResult(
                        stepId,
                        url,
                        "Ответ обновлен",
                        finalGroupId,
                      );

                      Navigator.pop(context);
                      _refreshData();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.navy,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
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

  // 1. Добавьте этот метод внутрь _ChatScreenState
  void _refreshData() {
    context.read<GroupProvider>().loadRoadmap(widget.group.id);
  }

  Widget _buildArtifactSubmissionBlock(
    RoadmapStepDto s,
    bool isTeacher,
    bool isReview,
  ) {
    // Работа отклонена учителем (есть коммент, но еще не исправлено)
    bool isRejected = s.teacherComment != null && s.status == "ToDo";
    bool isDone = s.status == "Done";

    return Padding(
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isTeacher) ...[
            // --- ВИД ДЛЯ УЧИТЕЛЯ ---
            if (isReview)
              // Учитель видит кнопки, только если работа СДАНА (UnderReview)
              Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.pending_actions,
                          color: Colors.orange,
                          size: 18,
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            "Работа сдана на проверку",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.orange,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => context
                              .read<GroupProvider>()
                              .verifyStep(s.id, true, "", widget.group.id),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            padding: const EdgeInsets.symmetric(vertical: 12),
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
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _showTeacherDeclineDialog(s.id),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.orange),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
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
                        ),
                      ),
                    ],
                  ),
                ],
              )
            else if (isRejected)
              // НОВОЕ: Если учитель уже отправил правки — показываем статус ожидания
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.withOpacity(0.1)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.hourglass_top_rounded,
                      color: Colors.blue,
                      size: 16,
                    ),
                    SizedBox(width: 8),
                    Text(
                      "Ждем ответ от ученика (правки отправлены)",
                      style: TextStyle(
                        color: Colors.blue,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              )
            else
              // Если работа еще не сдавалась или уже принята
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  isDone
                      ? "✅ Задание успешно выполнено"
                      : "⏳ Ожидание первой загрузки ответа",
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
          ] else ...[
            // --- ВИД ДЛЯ УЧЕНИКА (остается без изменений) ---
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () => _showArtifactStatusDialog(s),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isRejected
                      ? Colors.orange
                      : (isReview ? Colors.blueGrey : AppColors.navy),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: Icon(
                  isRejected
                      ? Icons.help_outline
                      : (isReview ? Icons.hourglass_empty : Icons.upload_file),
                  color: Colors.white,
                ),
                label: Text(
                  isRejected
                      ? "ЕСТЬ ПРАВКИ (ПЕРЕСДАТЬ)"
                      : (isReview ? "НА ПРОВЕРКЕ" : "СДАТЬ РАБОТУ"),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStepResourcesRow(RoadmapStepDto s) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      color: const Color(0xFFF8FAFC),
      child: Wrap(
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
    );
  }

  Widget _resourceBadge(String label, IconData icon, Color col, String url) {
    return InkWell(
      onTap: () => _handleResourceOpen(url),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: col.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: col.withOpacity(0.2)),
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
