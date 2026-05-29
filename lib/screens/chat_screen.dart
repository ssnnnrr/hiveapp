import 'dart:convert';
import 'dart:io';
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
    try {
      final groupProv = context.read<GroupProvider>();
      await groupProv.openChat(widget.group.id);
      if (mounted) setState(() => _isInitialized = true);
    } catch (e) {
      debugPrint("Init Error: $e");
      if (mounted) setState(() => _isInitialized = true);
    }
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
    final downloadUrl = 'http://localhost:5254/api/Chat/download/${Uri.encodeComponent(fileName)}';
    try {
      await launchUrl(Uri.parse(downloadUrl), mode: LaunchMode.externalApplication);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Ошибка открытия файла: $e")));
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
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration: AppDecorations.smartInput("Текст задания *", Icons.edit_note),
                  maxLines: 2,
                ),
                const SizedBox(height: 20),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_month, color: AppColors.primary),
                  title: const Text("Дедлайн:"),
                  subtitle: Text(DateFormat('dd MMMM yyyy', 'ru').format(deadline), 
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
                  title: const Text("Использовать файл", style: TextStyle(fontSize: 14)),
                  value: useFileInsteadOfLink,
                  onChanged: (v) => setSt(() => useFileInsteadOfLink = v),
                ),
                if (!useFileInsteadOfLink)
                  TextField(controller: theoryCtrl, decoration: const InputDecoration(labelText: "Ссылка на теорию (URL)"))
                else
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 10),
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
                  title: const Text("Требовать отчет от ученика", style: TextStyle(fontSize: 13)),
                  value: needArtifact,
                  onChanged: (v) => setSt(() => needArtifact = v!),
                ),
                if (isUploading) const Padding(padding: EdgeInsets.all(10), child: LinearProgressIndicator()),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("ОТМЕНА")),
            ElevatedButton(
              onPressed: isUploading ? null : () async {
                if (titleCtrl.text.isEmpty) return;
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

  void _showDeclineDialog(int id) {
    final c = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("На доработку"),
        content: TextField(controller: c, decoration: const InputDecoration(hintText: "Укажите замечания...")),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("ОТМЕНА")),
          ElevatedButton(
            onPressed: () {
              context.read<GroupProvider>().verifyStep(id, false, c.text.trim(), widget.group.id);
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text("ОТПРАВИТЬ"),
          ),
        ],
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
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
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
                borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("РАЗБОР ТЕСТА", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: AppColors.navy)),
                      Text("Лучший результат: ${((s.testScore ?? 0) * 100).toInt()}%", style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close_rounded, size: 28)),
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
                  
                  final bool isCorrect = studentAns.toLowerCase().trim() == correct.toLowerCase().trim();

                  return FadeInUp(
                    delay: Duration(milliseconds: 50 * i),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 15),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: isCorrect ? Colors.green.withOpacity(0.03) : Colors.red.withOpacity(0.03),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: isCorrect ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 12, 
                                backgroundColor: isCorrect ? Colors.green : Colors.red,
                                child: Text("${i + 1}", style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                              ),
                              const SizedBox(width: 10),
                              Expanded(child: Text(q['question'], style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.navy))),
                            ],
                          ),
                          const Padding(padding: EdgeInsets.symmetric(vertical: 15), child: Divider(height: 1)),
                          _resultValue("ВАШ ОТВЕТ:", studentAns, isCorrect ? Colors.green : Colors.red),
                          if (!isCorrect) ...[
                            const SizedBox(height: 12),
                            _resultValue("ПРАВИЛЬНЫЙ ОТВЕТ:", correct, Colors.green),
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
        Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1)),
        const SizedBox(height: 4),
        Text(val, style: TextStyle(color: col, fontWeight: FontWeight.w900, fontSize: 14)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) return const Scaffold(body: Center(child: CircularProgressIndicator()));
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
                    children: [
                      _buildMessagesTab(myId),
                      _buildRoadmapTab(myId),
                    ],
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
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0.5,
      toolbarHeight: 70,
      title: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppColors.navy.withOpacity(0.1),
            child: Text(widget.group.name[0].toUpperCase(), style: const TextStyle(color: AppColors.navy, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.group.name, style: GoogleFonts.manrope(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.navy)),
                Text(widget.group.isSolo ? "Личный диалог" : "Учебная группа", style: const TextStyle(fontSize: 10, color: Colors.grey)),
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
        tabs: const [Tab(text: "ОБСУЖДЕНИЕ"), Tab(text: "ПЛАН ОБУЧЕНИЯ")],
      ),
    );
  }

  Widget _buildMessagesTab(int myId) {
    return Column(
      children: [
        Expanded(
          child: Consumer<GroupProvider>(
            builder: (context, prov, _) {
              if (prov.messages.isEmpty) return const Center(child: Text("Сообщений пока нет. Начните обучение!", style: TextStyle(color: Colors.grey)));
              final msgs = prov.messages.reversed.toList();
              return ListView.builder(
                controller: _chatScrollController,
                reverse: true,
                padding: const EdgeInsets.all(20),
                itemCount: msgs.length,
                itemBuilder: (ctx, i) => _buildMessageBubble(msgs[i], msgs[i].senderId == myId),
              );
            },
          ),
        ),
        _buildChatInputArea(),
      ],
    );
  }

  Widget _buildMessageBubble(MessageDto m, bool isMe) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: FadeInUp(
        duration: const Duration(milliseconds: 200),
        child: Container(
          width: 380,
          margin: const EdgeInsets.symmetric(vertical: 5),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isMe ? AppColors.navy : Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(15),
              topRight: const Radius.circular(15),
              bottomLeft: Radius.circular(isMe ? 15 : 0),
              bottomRight: Radius.circular(isMe ? 0 : 15),
            ),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 5)],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isMe) Text(m.senderName, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary)),
              const SizedBox(height: 2),
              Text(m.content, style: TextStyle(color: isMe ? Colors.white : Colors.black87, fontSize: 14)),
              const SizedBox(height: 4),
              Text(DateFormat('HH:mm').format(m.sentAt), style: TextStyle(fontSize: 8, color: isMe ? Colors.white60 : Colors.grey)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChatInputArea() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
      decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Color(0xFFF1F5F9)))),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              focusNode: _messageFocusNode,
              maxLines: null,
              decoration: InputDecoration(
                hintText: "Напишите сообщение... (используйте @ для привязки к задаче)",
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(25), borderSide: BorderSide.none),
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
                  context.read<GroupProvider>().sendMessage(widget.group.id, _messageController.text.trim());
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
      bottom: 100, left: 20, right: 20,
      child: FadeInUp(
        duration: const Duration(milliseconds: 150),
        child: Material(
          elevation: 10,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            constraints: const BoxConstraints(maxHeight: 250),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _filteredMentionTasks.length,
              itemBuilder: (ctx, i) {
                final t = _filteredMentionTasks[i];
                return ListTile(
                  leading: Icon(t.isTest ? Icons.quiz : Icons.assignment, size: 18),
                  title: Text(t.content, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  onTap: () {
                    final current = _messageController.text;
                    final lastAt = current.lastIndexOf('@');
                    setState(() {
                      _messageController.text = "${current.substring(0, lastAt)}@\"${t.content}\" ";
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
        final List<RoadmapStepDto> tasksForMe = all.where((s) => s.creatorId != myId).toList();
        final List<RoadmapStepDto> tasksFromMe = all.where((s) => s.creatorId == myId).toList();
        
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
                          icon: const Icon(Icons.add_task, color: AppColors.primary), 
                          onPressed: _showAddStepDialog,
                          tooltip: "Добавить задание",
                        ),
                        // Кнопка перехода на страницу создания теста
                        IconButton(
                          icon: const Icon(Icons.quiz_outlined, color: Colors.purple), 
                          onPressed: _openTestCreationScreen, // ИСПОЛЬЗУЕМ НОВЫЙ МЕТОД
                          tooltip: "Создать тест",
                        ),
                      ]
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
                    itemBuilder: (ctx, i) => _buildLogicStepCard(currentList[i], myId),
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
        child: Text(label, style: TextStyle(color: active ? Colors.white : Colors.grey, fontWeight: FontWeight.w900, fontSize: 10)),
      ),
    );
  }

  Widget _buildLogicStepCard(RoadmapStepDto s, int myId) {
    bool isTeacher = s.creatorId == myId;
    bool isActuallyFinished = s.status == "Done" && (!s.isTest || s.usedAttempts >= s.maxAttempts);
    bool isReview = s.status == "UnderReview";

    return FadeInUp(
      child: Container(
        margin: const EdgeInsets.only(bottom: 18),
        decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15, offset: const Offset(0, 5))],
          border: Border.all(color: isActuallyFinished ? Colors.green.withOpacity(0.2) : Colors.grey.shade100, width: 2),
        ),
        child: Column(
          children: [
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              leading: _buildStepStatusIcon(s, isActuallyFinished),
              title: Text(s.content, style: TextStyle(fontWeight: FontWeight.bold, decoration: isActuallyFinished ? TextDecoration.lineThrough : null, color: isActuallyFinished ? Colors.grey : AppColors.navy)),
              subtitle: Text("Дедлайн: ${DateFormat('dd.MM.yyyy').format(s.dueDate)}", style: const TextStyle(fontSize: 11)),
              trailing: _buildTaskActionMenu(s, isTeacher),
            ),
            if (s.isTest) _buildTestStepBlock(s, isTeacher, isActuallyFinished),
            if (!s.isTest && s.isRequired && !isActuallyFinished) _buildArtifactSubmissionBlock(s, isTeacher, isReview),
            if (s.instructionUrl != null || s.artifactUrl != null) _buildStepResourcesRow(s),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _buildStepStatusIcon(RoadmapStepDto s, bool isDone) {
    Color col = isDone ? Colors.green : (s.isTest ? Colors.purple : AppColors.primary);
    return Container(
      width: 46, height: 46,
      decoration: BoxDecoration(color: col.withOpacity(0.1), shape: BoxShape.circle),
      child: Icon(isDone ? Icons.check_circle : (s.isTest ? Icons.quiz : Icons.assignment_turned_in), color: col, size: 22),
    );
  }

  Widget _buildTestStepBlock(RoadmapStepDto s, bool isTeacher, bool isDone) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: Colors.purple.withOpacity(0.05), borderRadius: BorderRadius.circular(18)),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("ПОПЫТКИ: ${s.usedAttempts} / ${s.maxAttempts}", 
                  style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.purple, fontSize: 11)),
              if (s.testScore != null) 
                Text("ЛУЧШИЙ: ${(s.testScore! * 100).toInt()}%", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 12),
          if (!isDone && !isTeacher && s.usedAttempts < s.maxAttempts)
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.purple, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 45)),
              onPressed: () => _startTest(s),
              child: const Text("ПРОЙТИ ТЕСТ", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          if (isDone || (isTeacher && s.usedAttempts > 0))
            TextButton(
              onPressed: () => _showDetailedTestResults(s),
              child: Text(isTeacher ? "ОТВЕТЫ УЧЕНИКА" : "ПОСМОТРЕТЬ РАЗБОР ОШИБОК", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.purple)),
            )
        ],
      ),
    );
  }

  Widget _buildArtifactSubmissionBlock(RoadmapStepDto s, bool isTeacher, bool isReview) {
    return Padding(
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isTeacher)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: isReview ? Colors.orange.withOpacity(0.1) : Colors.grey.shade50, borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  Icon(isReview ? Icons.pending_actions : Icons.hourglass_empty, color: isReview ? Colors.orange : Colors.grey, size: 18),
                  const SizedBox(width: 10),
                  Text(isReview ? "Работа сдана на проверку" : "Ученик еще не сдал работу", style: TextStyle(fontWeight: FontWeight.bold, color: isReview ? Colors.orange : Colors.grey, fontSize: 12)),
                ],
              ),
            )
          else if (isReview)
             const Text("✅ Работа на проверке у учителя", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12))
          else
            Row(
              children: [
                Expanded(child: OutlinedButton(onPressed: () => _showAddLinkDialog(s.id), child: const Text("ССЫЛКА"))),
                const SizedBox(width: 10),
                Expanded(child: ElevatedButton(onPressed: () => context.read<GroupProvider>().uploadArtifact(s.id, widget.group.id), child: const Text("ФАЙЛ"))),
              ],
            ),
          if (isTeacher && isReview) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: ElevatedButton(onPressed: () => context.read<GroupProvider>().verifyStep(s.id, true, "", widget.group.id), style: ElevatedButton.styleFrom(backgroundColor: Colors.green), child: const Text("ПРИНЯТЬ"))),
                const SizedBox(width: 10),
                Expanded(child: OutlinedButton(onPressed: () => _showDeclineDialog(s.id), child: const Text("ПРАВКИ"))),
              ],
            )
          ]
        ],
      ),
    );
  }

  void _showAddLinkDialog(int id) {
    final c = TextEditingController();
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text("Прикрепить ссылку"),
      content: TextField(controller: c, decoration: const InputDecoration(hintText: "https://...")),
      actions: [ElevatedButton(onPressed: () {
        context.read<GroupProvider>().submitStepResult(id, c.text, "Ссылка прикреплена", widget.group.id);
        Navigator.pop(ctx);
      }, child: const Text("СДАТЬ"))],
    ));
  }

  Widget _buildStepResourcesRow(RoadmapStepDto s) {
    return Container(
      width: double.infinity, padding: const EdgeInsets.all(15), color: const Color(0xFFF8FAFC),
      child: Wrap(
        spacing: 10, runSpacing: 10,
        children: [
          if (s.instructionUrl != null) _resourceBadge("ТЕОРИЯ / МАТЕРИАЛ", Icons.menu_book, Colors.blue, s.instructionUrl!),
          if (s.artifactUrl != null) _resourceBadge("ОТЧЕТ УЧЕНИКА", Icons.description, Colors.green, s.artifactUrl!),
        ],
      ),
    );
  }

  Widget _resourceBadge(String label, IconData icon, Color col, String url) {
    return InkWell(
      onTap: () => _handleResourceOpen(url),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: col.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: col.withOpacity(0.2))),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: col),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: col)),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskActionMenu(RoadmapStepDto s, bool isTeacher) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, color: Colors.grey),
      onSelected: (val) {
        if (val == "ask") _jumpToChatWithTask(s, "❓ Вопрос по задаче");
        else if (val == "unclear") _jumpToChatWithTask(s, "⚠️ Непонятно по задаче");
        else if (val == "clarify") _jumpToChatWithTask(s, "🔍 Уточнение по задаче");
        else if (val == "delete") _confirmDelete(s.id);
      },
      itemBuilder: (ctx) => [
        if (!isTeacher) ...[
          const PopupMenuItem(value: "ask", child: Text("Задать вопрос в чате")),
          const PopupMenuItem(value: "unclear", child: Text("Отметить как непонятное")),
          const PopupMenuItem(value: "clarify", child: Text("Уточнить детали")),
        ],
        if (isTeacher)
          const PopupMenuItem(value: "delete", child: Text("Удалить задачу", style: TextStyle(color: Colors.red))),
      ],
    );
  }

  void _confirmDelete(int id) => showDialog(context: context, builder: (ctx) => AlertDialog(
    title: const Text("Удалить задачу?"),
    actions: [
      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("ОТМЕНА")),
      TextButton(onPressed: () { context.read<GroupProvider>().deleteRoadmapStep(id, widget.group.id); Navigator.pop(ctx); }, child: const Text("УДАЛИТЬ", style: TextStyle(color: Colors.red))),
    ],
  ));

void _startTest(RoadmapStepDto s) {
  Navigator.push(
    context, 
    MaterialPageRoute(builder: (_) => TestTakingScreen(step: s))
  ).then((_) async {
    // После возврата с теста принудительно обновляем данные группы
    await context.read<GroupProvider>().loadRoadmap(widget.group.id);
    if (mounted) setState(() {}); // Перерисовываем виджет чата
  });
}
  Widget _buildRoadmapEmptyState() => const Center(child: Text("В этом списке пока нет задач", style: TextStyle(color: Colors.grey)));
}