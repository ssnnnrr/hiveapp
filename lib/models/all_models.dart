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
  final String synergyLevel; // ВЕРНУЛИ ЭТО ПОЛЕ

  UserDto({
    required this.id, 
    required this.username, 
    required this.email, 
    this.avatarUrl, 
    required this.rating,
    required this.synergyLevel, // Добавили в конструктор
  });

  factory UserDto.fromJson(Map<String, dynamic> json) => UserDto(
    id: json['id'],
    username: json['username'],
    email: json['email'] ?? "",
    avatarUrl: json['avatarUrl'],
    rating: (json['rating'] ?? 0.0).toDouble(),
    synergyLevel: json['synergyLevel'] ?? "None", // Читаем из JSON
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
  final DateTime createdAt;
  final int? taskId; // ДОБАВИТЬ ЭТУ СТРОКУ

  MaterialDto({
    required this.id, required this.title, required this.content,
    required this.type, required this.creatorId, required this.createdAt,
    this.taskId, // ДОБАВИТЬ СЮДА
  });

  factory MaterialDto.fromJson(Map<String, dynamic> json) => MaterialDto(
    id: json['id'],
    title: json['title'] ?? "",
    content: json['content'] ?? "",
    type: json['type'] ?? "Link",
    creatorId: json['creatorId'] ?? 0,
    createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
    taskId: json['taskId'], // И СЮДА
  );
}

class TaskResponse {
  final int id;
  final String title;
  final DateTime dueDate;
  String status;
  final int goalId;
  final String goalTitle;
  final int creatorId;
  final int? assigneeId;
  final String? artifactUrl;
  String? studentComment;
  final String? teacherComment;
  final List<String> completions;
  final String? studentName; // Добавляем имя студента
  final String? studentAvatarUrl; // Добавляем аватар студента

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
    this.studentComment,
    this.teacherComment,
    this.completions = const [],
    this.studentName,
    this.studentAvatarUrl,
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
    List<String>? completions,
    String? studentName,
    String? studentAvatarUrl,
  }) {
    return TaskResponse(
      id: id ?? this.id,
      title: title ?? this.title,
      dueDate: dueDate ?? this.dueDate,
      status: status ?? this.status,
      goalId: goalId ?? this.goalId,
      goalTitle: goalTitle ?? this.goalTitle,
      creatorId: creatorId ?? this.creatorId,
      assigneeId: assigneeId ?? this.assigneeId,
      artifactUrl: artifactUrl ?? this.artifactUrl,
      studentComment: studentComment ?? this.studentComment,
      teacherComment: teacherComment ?? this.teacherComment,
      completions: completions ?? this.completions,
      studentName: studentName ?? this.studentName,
      studentAvatarUrl: studentAvatarUrl ?? this.studentAvatarUrl,
    );
  }

  factory TaskResponse.fromJson(Map<String, dynamic> json) {
    return TaskResponse(
      id: json['id'],
      title: json['title'],
      dueDate: DateTime.parse(json['dueDate']),
      status: json['status'],
      goalId: json['goalId'],
      goalTitle: json['goalTitle'] ?? '',
      creatorId: json['creatorId'],
      assigneeId: json['assigneeId'],
      artifactUrl: json['artifactUrl'],
      studentComment: json['studentComment'],
      teacherComment: json['teacherComment'],
      completions: json['completions'] != null 
        ? List<String>.from(json['completions']) 
        : [],
      studentName: json['studentName'],
      studentAvatarUrl: json['studentAvatarUrl'],
    );
  }
}


class GoalResponse {
  final int id;
  final String title;
  final String? description;
  final String? measurableResult; // Добавлено
  final DateTime targetDate; // Добавлено
  final bool isSolo;
  final double progress;
  final List<TaskResponse> tasks;
  final List<GoalPartnerDto> collaborators;
  final List<MaterialDto> materials;
  final int userId;
  final String goalType; // Добавлено

  GoalResponse({
    required this.id, required this.title, this.description, this.measurableResult,
    required this.targetDate, required this.isSolo, required this.progress,
    required this.tasks, required this.collaborators, required this.materials,
    required this.userId, required this.goalType,
  });

  // Этот метод исправит ошибку в GoalProvider
  GoalResponse copyWith({double? progress, List<TaskResponse>? tasks, bool? isSolo}) {
    return GoalResponse(
      id: id, title: title, description: description, 
      measurableResult: measurableResult, targetDate: targetDate,
      isSolo: isSolo ?? this.isSolo,
      progress: progress ?? this.progress,
      tasks: tasks ?? this.tasks,
      collaborators: collaborators,
      materials: materials,
      userId: userId,
      goalType: goalType,
    );
  }

  factory GoalResponse.fromJson(Map<String, dynamic> json) => GoalResponse(
    id: json['id'],
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
  final bool isAdmin; // Для учебных групп

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
    name: json['name'] ?? "",
    progress: (json['progress'] ?? 0.0).toDouble(),
    avatarUrl: json['avatarUrl'],
    isConfirmed: json['isConfirmed'] ?? false,
    isAdmin: json['isAdmin'] ?? false,
  );
}

// --- MESSAGES, CHATS & NOTIFICATIONS ---

class MessageDto {
  final int id;
  final String content;
  final int senderId;
  final String senderName;
  final DateTime sentAt;
  MessageDto({
    required this.id,
    required this.content,
    required this.senderId,
    required this.senderName,
    required this.sentAt,
  });
  factory MessageDto.fromJson(Map<String, dynamic> json) => MessageDto(
    id: json['id'] ?? 0,
    content: json['content'] ?? "",
    senderId: json['senderId'] ?? 0,
    senderName: json['senderName'] ?? "Unknown",
    sentAt: DateTime.parse(json['sentAt'] ?? DateTime.now().toIso8601String()),
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

// --- REMAINING MODELS ---

class RoadmapStepDto {
  final int id;
  final String content;
  final int creatorId;
  final DateTime dueDate;
  final String status; // ToDo, UnderReview, Done
  final String? instructionUrl;
  final String? artifactUrl;
  final String? teacherComment;
  final String? groupName;
  final String? creatorName;

  RoadmapStepDto({
    required this.id,
    required this.content,
    required this.creatorId,
    required this.dueDate,
    required this.status,
    this.instructionUrl,
    this.artifactUrl,
    this.teacherComment,
    this.groupName,
    this.creatorName,
  });

  // ДОБАВЬТЕ ЭТОТ МЕТОД:
  RoadmapStepDto copyWith({String? status}) {
    return RoadmapStepDto(
      id: id,
      content: content,
      creatorId: creatorId,
      dueDate: dueDate,
      status: status ?? this.status,
      instructionUrl: instructionUrl,
      artifactUrl: artifactUrl,
      teacherComment: teacherComment,
      groupName: groupName,
      creatorName: creatorName,
    );
  }

  factory RoadmapStepDto.fromJson(Map<String, dynamic> json) => RoadmapStepDto(
    id: json['id'] ?? 0,
    content: json['content'] ?? "",
    creatorId: json['creatorId'] ?? 0,
    dueDate: DateTime.parse(json['dueDate'] ?? DateTime.now().toIso8601String()),
    status: json['status'] ?? "ToDo",
    instructionUrl: json['instructionUrl'],
    artifactUrl: json['artifactUrl'],
    teacherComment: json['teacherComment'],
    groupName: json['groupName'],
    creatorName: json['creatorName'],
  );
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

  EventResponse({
    required this.id,
    required this.title,
    this.description,
    required this.eventDate,
    required this.isCompleted,
    this.groupId,
    required this.creatorName,
  });

  factory EventResponse.fromJson(Map<String, dynamic> json) => EventResponse(
    id: json['id'] ?? 0,
    title: json['title'] ?? "",
    description: json['description'],
    eventDate: DateTime.parse(json['eventDate'] ?? DateTime.now().toIso8601String()),
    isCompleted: json['isCompleted'] ?? false,
    groupId: json['groupId'],
    creatorName: json['creatorName'] ?? "Unknown",
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