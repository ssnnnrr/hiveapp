import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/all_models.dart';
import '../providers/group_provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';

class ChatScreen extends StatefulWidget {
  final GroupResponse group;
  const ChatScreen({super.key, required this.group});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _messageCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    Future.microtask(() {
      context.read<GroupProvider>().openChat(widget.group.id);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final myId = context.read<AuthProvider>().user?.id;
    
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: AppColors.navy),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.group.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.navy)),
            Text(widget.group.isSolo ? "Личный диалог" : "Учебная группа", style: const TextStyle(fontSize: 10, color: Colors.grey)),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: Colors.grey,
          labelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1),
          tabs: const [
            Tab(text: "ОБСУЖДЕНИЕ"),
            Tab(text: "ПЛАН ОБУЧЕНИЯ"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildChatTab(myId),
          _buildRoadmapTab(myId),
        ],
      ),
    );
  }// --- ВКЛАДКА 1: ОБСУЖДЕНИЕ (ЧАТ) ---
  Widget _buildChatTab(int? myId) {
    return Column(
      children: [
        Expanded(
          child: Consumer<GroupProvider>(
            builder: (context, prov, _) {
              final msgs = prov.messages;
              return ListView.builder(
                padding: const EdgeInsets.all(20),
                itemCount: msgs.length,
                itemBuilder: (context, i) {
                  final m = msgs[i];
                  final isMe = m.senderId == myId;
                  return _buildMessageBubble(m, isMe);
                },
              );
            },
          ),
        ),
        _buildChatInput(),
      ],
    );
  }

  Widget _buildMessageBubble(MessageDto m, bool isMe) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isMe ? AppColors.navy : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(15),
            topRight: const Radius.circular(15),
            bottomLeft: Radius.circular(isMe ? 15 : 0),
            bottomRight: Radius.circular(isMe ? 0 : 15),
          ),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isMe) Text(m.senderName, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary)),
            const SizedBox(height: 4),
            Text(m.content, style: TextStyle(color: isMe ? Colors.white : AppColors.textDark, fontSize: 14)),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.bottomRight,
              child: Text(DateFormat('HH:mm').format(m.sentAt), style: TextStyle(color: isMe ? Colors.white60 : Colors.grey, fontSize: 9)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatInput() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
      decoration: const BoxDecoration(color: Colors.white),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageCtrl,
              decoration: AppDecorations.smartInput("Напишите сообщение...", Icons.chat_bubble_outline),
            ),
          ),
          const SizedBox(width: 15),
          CircleAvatar(
            backgroundColor: AppColors.navy,
            child: IconButton(
              icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
              onPressed: () {
                if (_messageCtrl.text.trim().isEmpty) return;
                context.read<GroupProvider>().sendMessage(widget.group.id, _messageCtrl.text.trim());
                _messageCtrl.clear();
              },
            ),
          )
        ],
      ),
    );
  }

  // --- ВКЛАДКА 2: ПЛАН ОБУЧЕНИЯ (ROADMAP) ---
  Widget _buildRoadmapTab(int? myId) {
    return Consumer<GroupProvider>(
      builder: (context, prov, _) {
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            ...prov.roadmapSteps.map((s) => _buildRoadmapCard(s, myId)),
            const SizedBox(height: 20),
            if (!widget.group.isSolo || widget.group.ownerName == context.read<AuthProvider>().user?.username)
              _buildAddStepButton(),
          ],
        );
      },
    );
  }

  Widget _buildRoadmapCard(RoadmapStepDto s, int? myId) {
    bool isTeacher = s.creatorId == myId;
    bool isUnderReview = s.status == "UnderReview";
    bool isDone = s.status == "Done";

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(20),
      decoration: AppDecorations.glassCard.copyWith(
        border: Border.all(color: isUnderReview ? AppColors.accent : (isDone ? Colors.green : Colors.transparent), width: 1.5)
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: Text(s.content, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
              if (isDone) const Icon(Icons.verified, color: Colors.green)
            ],
          ),
          const SizedBox(height: 15),
          if (isUnderReview) _statusBadge("НА ПРОВЕРКЕ", AppColors.accent),
          if (isDone) _statusBadge("ПРИНЯТО", Colors.green),
          
          const Divider(height: 30),

          // --- ЛОГИКА КНОПОК ДЛЯ УЧЕНИКА И УЧИТЕЛЯ ---
          if (!isTeacher && !isDone && !isUnderReview)
            _actionButton("СДАТЬ НА ПРОВЕРКУ", AppColors.navy, () => _showSubmitDialog(s.id)),
          
          if (isTeacher && isUnderReview)
            Row(
              children: [
                Expanded(child: _actionButton("ПРИНЯТЬ", Colors.green, () => _handleVerify(s.id, true))),
                const SizedBox(width: 10),
                Expanded(child: _actionButton("ОТКЛОНИТЬ", Colors.redAccent, () => _handleVerify(s.id, false))),
              ],
            ),
          
          if (!isTeacher && s.teacherComment != null)
            _buildTeacherFeedback(s.teacherComment!),
        ],
      ),
    );
  }

  Widget _statusBadge(String t, Color c) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: c.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
      child: Text(t, style: TextStyle(color: c, fontSize: 9, fontWeight: FontWeight.w900)),
    );
  }

  Widget _actionButton(String label, Color col, VoidCallback onTap) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: col, 
        elevation: 0, 
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        minimumSize: const Size(double.infinity, 45)
      ),
      onPressed: onTap,
      child: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
    );
  }

  Widget _buildTeacherFeedback(String comment) {
    return Container(
      margin: const EdgeInsets.only(top: 15),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.05), borderRadius: BorderRadius.circular(10)),
      child: Text("Замечание: $comment", style: const TextStyle(color: Colors.redAccent, fontSize: 12, fontStyle: FontStyle.italic)),
    );
  }// --- ДИАЛОГИ (МОДУЛЬ 2: ЦИКЛ СДАЧИ) ---

  void _showSubmitDialog(int stepId) {
    final urlCtrl = TextEditingController();
    final commentCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom + 30, left: 25, right: 25, top: 25),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("СДАТЬ ЗАДАНИЕ", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: AppColors.navy)),
            const SizedBox(height: 25),
            TextField(controller: urlCtrl, decoration: AppDecorations.smartInput("Ссылка на результат (GitHub/PDF)", Icons.link_rounded)),
            const SizedBox(height: 15),
            TextField(controller: commentCtrl, maxLines: 3, decoration: AppDecorations.smartInput("Ваш комментарий", Icons.chat_bubble_outline_rounded)),
            const SizedBox(height: 30),
            _actionButton("ОТПРАВИТЬ УЧИТЕЛЮ", AppColors.primary, () async {
              if (urlCtrl.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Прикрепите ссылку на работу")));
                return;
              }
              await context.read<GroupProvider>().submitStepResult(stepId, urlCtrl.text.trim());
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Задание сдано на проверку")));
            }),
          ],
        ),
      ),
    );
  }

  void _handleVerify(int stepId, bool approve) async {
    if (approve) {
      await context.read<GroupProvider>().verifyStep(stepId, true, "");
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Задание принято! ✅")));
    } else {
      // ОБЯЗАТЕЛЬНОЕ ПОЛЕ: Почему не принято (Модуль 2)
      _showRejectionDialog(stepId);
    }
  }

  void _showRejectionDialog(int stepId) {
    final reasonCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("ПОЧЕМУ НЕ ПРИНЯТО?", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
        content: TextField(
          controller: reasonCtrl,
          maxLines: 3,
          decoration: const InputDecoration(hintText: "Укажите причину (обязательно)", border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("ОТМЕНА")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              if (reasonCtrl.text.trim().isEmpty) return;
              await context.read<GroupProvider>().verifyStep(stepId, false, reasonCtrl.text.trim());
              Navigator.pop(ctx);
            },
            child: const Text("ОТКЛОНИТЬ", style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }

  // --- ДОБАВЛЕНИЕ НОВОГО ЭТАПА В ROADMAP (УЧИТЕЛЕМ) ---

  Widget _buildAddStepButton() {
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 15),
        side: const BorderSide(color: AppColors.navy),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      ),
      onPressed: () => _showAddRoadmapStepDialog(),
      icon: const Icon(Icons.add_task_rounded, color: AppColors.navy),
      label: const Text("ДОБАВИТЬ ЭТАП ОБУЧЕНИЯ", style: TextStyle(color: AppColors.navy, fontWeight: FontWeight.bold)),
    );
  }

  void _showAddRoadmapStepDialog() {
    final stepCtrl = TextEditingController();
    DateTime date = DateTime.now().add(const Duration(days: 3));

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: const Text("НОВОЕ ЗАДАНИЕ"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: stepCtrl, decoration: const InputDecoration(hintText: "Что нужно сделать?")),
              const SizedBox(height: 15),
              ListTile(
                title: Text("Срок: ${DateFormat('dd.MM').format(date)}"),
                trailing: const Icon(Icons.calendar_month),
                onTap: () async {
                  final d = await showDatePicker(context: context, initialDate: date, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 100)));
                  if (d != null) setSt(() => date = d);
                },
              )
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("ОТМЕНА")),
            ElevatedButton(
              onPressed: () async {
                if (stepCtrl.text.isEmpty) return;
                await context.read<GroupProvider>().addRoadmapStep(widget.group.id, stepCtrl.text.trim(), date);
                Navigator.pop(ctx);
              },
              child: const Text("СОЗДАТЬ"),
            )
          ],
        ),
      ),
    );
  }
}