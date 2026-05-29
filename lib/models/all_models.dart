// --- ENUMS ---
enum GoalType { Social, Exchange, Group }
enum TaskStatus { ToDo, UnderReview, Done }
enum MaterialType { Link, File }

// --- AUTH & USER ---

class AuthResponse {
  final String token;
  final UserDto user;
  AuthResponse({required this.token, required this.user});

  factory AuthResponse.fromJson(Map<String, dynamic> json) => AuthResponse(
    token: json['token'] ?? "",
    user: UserDto.fromJson(json['user'] ?? {}),
  );
}

class UserDto {
  final int id;
  final String username;
  final String email;
  final String? avatarUrl;
  final double rating;
  final String synergyLevel;

  UserDto({
    required this.id, 
    required this.username, 
    required this.email, 
    this.avatarUrl, 
    required this.rating,
    required this.synergyLevel,
  });

  factory UserDto.fromJson(Map<String, dynamic> json) => UserDto(
    id: json['id'] ?? 0,
    username: json['username'] ?? "",
    email: json['email'] ?? "",
    avatarUrl: json['avatarUrl'],
    rating: (json['rating'] ?? 0.0).toDouble(),
    synergyLevel: json['synergyLevel'] ?? "None",
  );
}

class UserProfileDto {
  final int id;
  final String username;
  final String email;
  final List<UserSkillDto> skills;
  final List<ReviewDto> reviews;
  final double rating;
  final bool isPrivate;
  final int nectarBalance;
  final String relationshipStatus;
  final String? avatarUrl;

  UserProfileDto({
    required this.id,
    required this.username,
    required this.email,
    required this.skills,
    required this.reviews,
    required this.rating,
    required this.isPrivate,
    required this.nectarBalance,
    required this.relationshipStatus,
    this.avatarUrl,
  });

  factory UserProfileDto.fromJson(Map<String, dynamic> json) {
    var sList = (json['skills'] ?? []) as List;
    var rList = (json['reviews'] ?? []) as List;
    return UserProfileDto(
      id: json['id'] ?? 0,
      username: json['username'] ?? "",
      email: json['email'] ?? "",
      rating: (json['rating'] ?? 0.0).toDouble(),
      isPrivate: json['isPrivate'] ?? false,
      nectarBalance: json['nectarBalance'] ?? 0,
      relationshipStatus: json['relationshipStatus'] ?? "None",
      avatarUrl: json['avatarUrl'],
      skills: sList.map((e) => UserSkillDto.fromJson(e)).toList(),
      reviews: rList.map((e) => ReviewDto.fromJson(e)).toList(),
    );
  }
}

class UserSkillDto {
  final int skillId;
  final String skillName;
  final String type;
  UserSkillDto({required this.skillId, required this.skillName, required this.type});

  factory UserSkillDto.fromJson(Map<String, dynamic> json) => UserSkillDto(
    skillId: json['skillId'] ?? 0,
    skillName: json['skillName'] ?? "",
    type: json['type'] ?? "Learning",
  );
}

class SkillDto {
  final int id;
  final String name;
  SkillDto({required this.id, required this.name});
  factory SkillDto.fromJson(Map<String, dynamic> json) => SkillDto(
    id: json['id'] ?? 0, 
    name: json['name'] ?? ""
  );
}

// --- GOALS, TASKS & MATERIALS ---

class MaterialDto {
  final int id;
  final String title;
  final String content;
  final String type;
  final int creatorId;
  final String creatorName;
  final String? creatorAvatarUrl;
  final DateTime createdAt;
  final int? taskId;
  final String? taskTitle;

  MaterialDto({
    required this.id,
    required this.title,
    required this.content,
    required this.type,
    required this.creatorId,
    required this.creatorName,
    this.creatorAvatarUrl,
    required this.createdAt,
    this.taskId,
    this.taskTitle,
  });

  factory MaterialDto.fromJson(Map<String, dynamic> json) => MaterialDto(
    id: json['id'] ?? 0,
    title: json['title'] ?? "",
    content: json['content'] ?? "",
    type: json['type'] ?? "Link",
    creatorId: json['creatorId'] ?? 0,
    creatorName: json['creatorName'] ?? "Пользователь",
    creatorAvatarUrl: json['creatorAvatarUrl'],
    createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
    taskId: json['taskId'],
    taskTitle: json['taskTitle'],
  );
}

class TaskResponse {
  final int id;
  final String title;
  final DateTime dueDate;
  final String status;
  final int goalId;
  final String goalTitle;
  final int creatorId;
  final int? assigneeId;
  final List<TaskCommentDto> comments;
  final String? artifactUrl;
  final String? studentComment;
  final String? teacherComment;
  final List<UserMinimalDto> completions;

  TaskResponse({
    required this.id,
    required this.title,
    required this.dueDate,
    required this.status,
    required this.goalId,
    required this.goalTitle,
    required this.creatorId,
    this.assigneeId,
    this.artifactUrl,
    this.comments = const [],
    this.studentComment,
    this.teacherComment,
    required this.completions,
  });

  TaskResponse copyWith({
    int? id,
    String? title,
    DateTime? dueDate,
    String? status,
    int? goalId,
    String? goalTitle,
    int? creatorId,
    int? assigneeId,
    String? artifactUrl,
    String? studentComment,
    String? teacherComment,
    List<UserMinimalDto>? completions,
    List<TaskCommentDto>? comments,
  }) {
    return TaskResponse(
      id: id ?? this.id,
      title: title ?? this.title,
      dueDate: dueDate ?? this.dueDate,
      status: status ?? this.status,
      goalId: goalId ?? this.goalId,
      comments: comments ?? this.comments,
      goalTitle: goalTitle ?? this.goalTitle,
      creatorId: creatorId ?? this.creatorId,
      assigneeId: assigneeId ?? this.assigneeId,
      artifactUrl: artifactUrl ?? this.artifactUrl,
      studentComment: studentComment ?? this.studentComment,
      teacherComment: teacherComment ?? this.teacherComment,
      completions: completions ?? this.completions,
    );
  }

  factory TaskResponse.fromJson(Map<String, dynamic> json) {
    // 1. Парсим список выполнивших задачу
    final fetchedCompletions = (json['completions'] as List? ?? [])
        .map((e) => UserMinimalDto.fromJson(e))
        .toList();

    // 2. РЕШЕНИЕ ПРОБЛЕМЫ ДАТЫ: 
    // Получаем строку, парсим её и ПРИНУДИТЕЛЬНО выставляем полдень по местному времени.
    // Это нейтрализует сдвиг часовых поясов, из-за которого 00:00 превращалось в 21:00 вчерашнего дня.
    String rawDate = json['dueDate'] ?? DateTime.now().toIso8601String();
    DateTime parsed = DateTime.parse(rawDate).toLocal();
    DateTime normalizedDate = DateTime(parsed.year, parsed.month, parsed.day, 12, 0, 0);

    return TaskResponse(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      dueDate: normalizedDate, // Используем "безопасную" дату (полдень)
      status: json['status'] ?? 'ToDo',
      goalId: json['goalId'] ?? 0,
      goalTitle: json['goalTitle'] ?? '',
      creatorId: json['creatorId'] ?? 0,
      assigneeId: json['assigneeId'],
      artifactUrl: json['artifactUrl'],
      studentComment: json['studentComment'],
      teacherComment: json['teacherComment'],
      completions: fetchedCompletions,
      comments: (json['comments'] as List?)
          ?.map((e) => TaskCommentDto.fromJson(e))
          .toList() ?? [],
    );
  }
}

class TaskCommentDto {
  final int id;
  final int userId;
  final String userName;
  final String? avatarUrl;
  final String text;
  final DateTime createdAt;

  TaskCommentDto({
    required this.id,
    required this.userId,
    required this.userName,
    this.avatarUrl,
    required this.text,
    required this.createdAt,
  });

  factory TaskCommentDto.fromJson(Map<String, dynamic> json) => TaskCommentDto(
    id: json['id'] ?? 0,
    userId: json['userId'] ?? 0,
    userName: json['userName'] ?? "Аноним",
    avatarUrl: json['avatarUrl'],
    text: json['text'] ?? "",
    createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
  );
}

class UserMinimalDto {
  final String username;
  final String? avatarUrl;

  UserMinimalDto({required this.username, this.avatarUrl});

  factory UserMinimalDto.fromJson(Map<String, dynamic> json) => UserMinimalDto(
    username: json['username'] ?? "Аноним",
    avatarUrl: json['avatarUrl'],
  );
}

class GoalResponse {
  final int id;
  final String title;
  final String? description;
  final String? measurableResult;
  final DateTime targetDate;
  final bool isSolo;
  final double progress;
  final List<TaskResponse> tasks;
  final List<GoalPartnerDto> collaborators;
  final List<MaterialDto> materials;
  final int userId;
  final String goalType;

  GoalResponse({
    required this.id, required this.title, this.description, this.measurableResult,
    required this.targetDate, required this.isSolo, required this.progress,
    required this.tasks, required this.collaborators, required this.materials,
    required this.userId, required this.goalType,
  });

  GoalResponse copyWith({double? progress, List<TaskResponse>? tasks, List<GoalPartnerDto>? collaborators, bool? isSolo}) {
    return GoalResponse(
      id: id, title: title, description: description, 
      measurableResult: measurableResult, targetDate: targetDate,
      isSolo: isSolo ?? this.isSolo,
      progress: progress ?? this.progress,
      tasks: tasks ?? this.tasks,
      collaborators: collaborators ?? this.collaborators, 
      materials: materials,
      userId: userId,
      goalType: goalType,
    );
  }

  factory GoalResponse.fromJson(Map<String, dynamic> json) => GoalResponse(
    id: json['id'] ?? 0,
    title: json['title'] ?? "",
    description: json['description'],
    measurableResult: json['measurableResult'],
    targetDate: DateTime.parse(json['targetDate'] ?? DateTime.now().toIso8601String()),
    isSolo: json['isSolo'] ?? true,
    progress: (json['progress'] ?? 0.0).toDouble(),
    userId: json['userId'] ?? 0,
    goalType: json['goalType'] ?? "Social",
    tasks: (json['tasks'] as List? ?? []).map((i) => TaskResponse.fromJson(i)).toList(),
    collaborators: (json['collaborators'] as List? ?? []).map((i) => GoalPartnerDto.fromJson(i)).toList(),
    materials: (json['materials'] as List? ?? []).map((i) => MaterialDto.fromJson(i)).toList(),
  );
}

class GoalPartnerDto {
  final int id;
  final String name;
  final double progress;
  final String? avatarUrl;
  final bool isConfirmed;
  final bool isAdmin;

  GoalPartnerDto({
    required this.id,
    required this.name,
    required this.progress,
    this.avatarUrl,
    required this.isConfirmed,
    required this.isAdmin,
  });

  factory GoalPartnerDto.fromJson(Map<String, dynamic> json) => GoalPartnerDto(
    id: json['id'] ?? 0,
    name: json['name'] ?? json['username'] ?? "",
    progress: (json['progress'] ?? 0.0).toDouble(),
    avatarUrl: json['avatarUrl'],
    isConfirmed: json['isConfirmed'] ?? false,
    isAdmin: json['isAdmin'] ?? false,
  );
}

class MessageDto {
  final int id;
  final String content;
  final int senderId;
  final String senderName;
  final DateTime sentAt;
  final bool isPinned;
  final int groupId;

  MessageDto({
    required this.id, required this.content, required this.senderId,
    required this.senderName, required this.sentAt, this.isPinned = false, required this.groupId,
  });
  factory MessageDto.fromJson(Map<String, dynamic> json) => MessageDto(
    id: json['id'] ?? 0,
    content: json['content'] ?? "",
    senderId: json['senderId'] ?? 0,
    senderName: json['senderName'] ?? "Unknown",
    sentAt: DateTime.parse(json['sentAt'] ?? DateTime.now().toIso8601String()),
    isPinned: json['isPinned'] ?? false,
    groupId: json['groupId'] ?? 0,
  );
}

class GroupResponse {
  final int id;
  final String name;
  final String ownerName;
  final int membersCount;
  final String? description;
  final bool isSolo;
  final int? otherUserId;

  GroupResponse({
    required this.id,
    required this.name,
    required this.ownerName,
    required this.membersCount,
    this.description,
    required this.isSolo,
    this.otherUserId,
  });

  factory GroupResponse.fromJson(Map<String, dynamic> json) => GroupResponse(
    id: json['id'] ?? 0,
    name: json['name'] ?? "",
    ownerName: json['ownerName'] ?? "",
    membersCount: json['membersCount'] ?? 0,
    isSolo: json['isSolo'] ?? false,
    otherUserId: json['otherUserId'],
    description: json['description'],
  );
}

class AppNotification {
  final int id;
  final String title;
  final String message;
  final DateTime createdAt;
  bool isRead;
  final String? type;
  final String? data;
  final int? taskId;
  final int? roadmapStepId;

  AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.createdAt,
    this.isRead = false,
    this.type,
    this.data,
    this.taskId,
    this.roadmapStepId,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) => AppNotification(
    id: json['id'] ?? 0,
    title: json['title'] ?? "",
    message: json['message'] ?? "",
    createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
    isRead: json['isRead'] ?? false,
    type: json['type'],
    data: json['data'],
    taskId: json['taskId'],
    roadmapStepId: json['roadmapStepId'],
  );
}

class ChatRequestDto {
  final int id;
  final int senderId;
  final String senderName;
  final String status;
  final String? senderAvatar;

  ChatRequestDto({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.status,
    this.senderAvatar,
  });

  factory ChatRequestDto.fromJson(Map<String, dynamic> json) => ChatRequestDto(
    id: json['id'] ?? 0,
    senderId: json['senderId'] ?? 0,
    senderName: json['senderName'] ?? "Пользователь",
    status: json['status'] ?? "Pending",
    senderAvatar: json['avatarUrl'],
  );
}



class RoadmapStepDto {
  final int id;
  final String content;
  final DateTime dueDate;
  String status;
  final int creatorId;
  final String? creatorName;
  final String? instructionUrl;
  String? artifactUrl;
  final String? teacherComment;
  String? studentComment;
  final bool isTest;
  final String? testData;
  double? testScore;
  final bool isRequired;
  final int groupId; // Убираем final или оставляем, но даем дефолт
  final int maxAttempts;
  int usedAttempts;

  RoadmapStepDto({
    required this.id,
    required this.content,
    required this.dueDate,
    required this.status,
    required this.creatorId,
    this.creatorName,
    this.instructionUrl,
    this.artifactUrl,
    this.teacherComment,
    this.studentComment,
    this.isTest = false,
    this.testData,
    this.testScore,
    this.isRequired = true,
    this.groupId = 0,      // <--- ИЗМЕНИТЕ ЭТУ СТРОКУ (уберите required и добавьте = 0)
    this.maxAttempts = 3,
    this.usedAttempts = 0,
  });

  factory RoadmapStepDto.fromJson(Map<String, dynamic> json) {
      final uA = json['usedAttempts'] ?? json['UsedAttempts'] ?? 0;
  final status = json['status'] ?? json['Status'] ?? 'ToDo';
  
  // Если это тест, выведем инфу в консоль
  if (json['isTest'] == true || json['IsTest'] == true) {
    print("DEBUG PARSER: StepId: ${json['id']}, Status: $status, Attempts: $uA");
  }
    return RoadmapStepDto(
      id: json['id'],
      content: json['content'] ?? '',
      dueDate: DateTime.parse(json['dueDate'] ?? json['DueDate'] ?? DateTime.now().toIso8601String()),
      status: json['status'] ?? 'ToDo',
      creatorId: json['creatorId'],
      creatorName: json['creatorName'],
      instructionUrl: json['instructionUrl'],
      artifactUrl: json['artifactUrl'],
      teacherComment: json['teacherComment'],
      studentComment: json['studentComment'],
      isTest: json['isTest'] ?? false,
      testData: json['testData'],
      testScore: (json['testScore'] ?? json['TestScore'])?.toDouble(),
      isRequired: json['isRequired'] ?? true,
      groupId: json['groupId'] ?? 0, // <--- И ТУТ ДОБАВЬТЕ ?? 0
      maxAttempts: json['maxAttempts'] ?? json['MaxAttempts'] ?? 3,
      usedAttempts: json['usedAttempts'] ?? json['UsedAttempts'] ?? 0,
    );
  }
}


class StepCommentDto {
  final int id;
  final int userId;
  final String userName;
  final String text;
  final DateTime createdAt;

  StepCommentDto({
    required this.id,
    required this.userId,
    required this.userName,
    required this.text,
    required this.createdAt,
  });

  factory StepCommentDto.fromJson(Map<String, dynamic> json) {
    return StepCommentDto(
      id: json['id'] ?? 0,
      userId: json['userId'] ?? 0,
      userName: json['userName'] ?? 'Unknown',
      text: json['text'] ?? '',
      createdAt: DateTime.parse(json['createdAt']),
    );
  }
}

// --- ДОБАВИТЬ/ОБНОВИТЬ В all_models.dart ---

class TestQuestion {
  final String question;
  final List<String> options;
  final dynamic correctAnswer; // Может быть String для одиночного или List для множественного
  final String type; // 'single', 'multiple', 'boolean'

  TestQuestion({
    required this.question,
    required this.options,
    required this.correctAnswer,
    this.type = 'single',
  });

  factory TestQuestion.fromJson(Map<String, dynamic> json) {
    return TestQuestion(
      question: json['question'] ?? '',
      options: List<String>.from(json['options'] ?? []),
      correctAnswer: json['correctAnswer'],
      type: json['type'] ?? 'single',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'question': question,
      'options': options,
      'correctAnswer': correctAnswer,
      'type': type,
    };
  }
}
class ReviewDto {
  final int id;
  final int rating;
  final String comment;
  final String reviewerName;
  final DateTime createdAt;
  ReviewDto({
    required this.id,
    required this.rating,
    required this.comment,
    required this.reviewerName,
    required this.createdAt,
  });
  factory ReviewDto.fromJson(Map<String, dynamic> json) => ReviewDto(
    id: json['id'] ?? 0,
    rating: (json['rating'] ?? 0).toInt(),
    comment: json['comment'] ?? "",
    reviewerName: json['reviewerName'] ?? "Аноним",
    createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
  );
}

class EventResponse {
  final int id;
  final String title;
  final String? description;
  final DateTime eventDate;
  final bool isCompleted;
  final int? groupId;
  final String creatorName;
  final String? linkUrl;
  final String? location;
  final String? imageUrl; // Новое поле для фото

  EventResponse({
    required this.id,
    required this.title,
    this.description,
    required this.eventDate,
    required this.isCompleted,
    this.groupId,
    required this.creatorName,
    this.linkUrl,
    this.location,
    this.imageUrl,
  });

  factory EventResponse.fromJson(Map<String, dynamic> json) => EventResponse(
    id: json['id'] ?? 0,
    title: json['title'] ?? "",
    description: json['description'],
    // Обязательно .toLocal() для корректного отображения времени
    eventDate: DateTime.parse(json['eventDate'] ?? DateTime.now().toIso8601String()).toLocal(),
    isCompleted: json['isCompleted'] ?? false,
    groupId: json['groupId'],
    creatorName: json['creatorName'] ?? "Unknown",
    linkUrl: json['linkUrl'],
    location: json['location'],
    imageUrl: json['imageUrl'],
  );
}

class TaskDraftResponse {
  final String title;
  final DateTime dueDate;
  TaskDraftResponse({required this.title, required this.dueDate});
  factory TaskDraftResponse.fromJson(Map<String, dynamic> json) => TaskDraftResponse(
    title: json['title'] ?? "",
    dueDate: DateTime.parse(json['dueDate'] ?? DateTime.now().toIso8601String()),
  );
  Map<String, dynamic> toJson() => {
    "title": title,
    "dueDate": dueDate.toIso8601String(),
  };
}