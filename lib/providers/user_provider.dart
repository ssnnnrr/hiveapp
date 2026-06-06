import 'package:flutter/material.dart';
import 'package:hive_app/providers/group_provider.dart';
import 'package:hive_app/providers/task_provider.dart';
import 'package:provider/provider.dart';
import '../models/all_models.dart';
import '../services/user_service.dart';

class UserProvider extends ChangeNotifier {
  final UserService _userService;
  UserProvider(this._userService);

  UserProfileDto? _myProfile;
  UserProfileDto? _targetFullProfile;
  List<UserDto> _friends = [];
  List<ChatRequestDto> _pendingRequests = [];
  List<SkillDto> _allSkills = [];
  List<UserDto> _searchResults = [];
  bool _isLoading = false;

  UserProfileDto? get myProfile => _myProfile;
  UserProfileDto? get targetFullProfile => _targetFullProfile;
  List<UserDto> get friends => _friends;
  List<ChatRequestDto> get pendingRequests => _pendingRequests;
  List<SkillDto> get allSkills => _allSkills;
  List<UserDto> get searchResults => _searchResults;
  bool get isLoading => _isLoading;


Future<void> initUserData(int myId) async {
  // Запускаем всё параллельно
  await Future.wait([
    loadMyProfile(myId),
    loadFriends(),
    loadRequests(),
    loadAllSkills(),
  ]);
}

  Future<void> loadMyProfile(int id) async {
    _isLoading = true;
    // Используем микрозадачу, чтобы избежать ошибки markNeedsBuild
    Future.microtask(() => notifyListeners());
    try {
      _myProfile = await _userService.getUserProfile(id);
    } catch (e) {
      debugPrint("USER_PROV ERROR: loadMyProfile: $e");
    } finally {
      _isLoading = false;
      Future.microtask(() => notifyListeners());
    }
  }

  Future<void> loadTargetProfile(int id) async {
    debugPrint("----------------------------------------");
    debugPrint("DEBUG: Начинаю загрузку профиля цели ID: $id");
    _isLoading = true;
    _targetFullProfile = null;
    Future.microtask(() => notifyListeners());
    try {
      _targetFullProfile = await _userService.getUserProfile(id);
      debugPrint("DEBUG: Профиль загружен успешно. Статус: ${_targetFullProfile?.relationshipStatus}");
    } catch (e) {
      debugPrint("USER_PROV ERROR: loadTargetProfile: $e");
    } finally {
      _isLoading = false;
      Future.microtask(() => notifyListeners());
    }
  }

  // КНОПКА СТАТЬ ПАРТНЕРАМИ (ЛОГИРОВАНИЕ)
  Future<bool> sendChatRequest(int targetId) async {
    debugPrint("DEBUG: [ACTION] Нажата кнопка СТАТЬ ПАРТНЕРАМИ для ID: $targetId");
    try {
      bool ok = await _userService.sendRequest(targetId);
      debugPrint("DEBUG: [SERVER RESPONSE] Запрос принят: $ok");
      if (ok) {
        // Мгновенно перезагружаем профиль, чтобы UI увидел статус "Pending"
        await loadTargetProfile(targetId);
      } else {
        debugPrint("DEBUG: [SERVER ERROR] Сервер вернул false. Проверь логи бэкенда (возможен дубликат запроса или ошибка 500)");
      }
      return ok;
    } catch (e) {
      debugPrint("DEBUG: [CRITICAL ERROR] sendChatRequest failed: $e");
      return false;
    }
  }

  Future<void> loadFriends() async {
    try {
      _friends = await _userService.getFriends();
      notifyListeners();
    } catch (e) {
      debugPrint("USER_PROV ERROR: loadFriends: $e");
    }
  }

  Future<void> loadAllSkills() async {
    try {
      _allSkills = await _userService.getAllSkills();
      notifyListeners();
    } catch (e) {
      debugPrint("USER_PROV ERROR: loadAllSkills: $e");
    }
  }

Future<void> searchPartners(int? skillId, String type, {String? query}) async {
    _isLoading = true;
    notifyListeners(); // Используй notifyListeners(), это безопаснее Future.microtask
    try {
      // Подготовка параметров для API
      final Map<String, dynamic> params = {"type": type};
      
      // Если skillId == 0, значит выбрано "Все", не шлем этот параметр
      if (skillId != null && skillId != 0) {
        params["skillId"] = skillId;
      }
      
      if (query != null && query.isNotEmpty) {
        params["query"] = query;
      }

      _searchResults = await _userService.findPartners(
        skillId: skillId == 0 ? null : skillId, 
        type: type, 
        query: query
      );
    } catch (e) {
      debugPrint("Ошибка поиска: $e");
      _searchResults = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Обновите этот метод в UserProvider
  Future<bool> terminatePartnership(int friendId, BuildContext context) async {
    _isLoading = true;
    notifyListeners();
    
    bool ok = await _userService.unfriend(friendId);
    if (ok) {
      // 1. Удаляем из списка друзей локально
      _friends.removeWhere((f) => f.id == friendId);
      
      // 2. ОБНОВЛЯЕМ ЧАТЫ И ЗАДАЧИ:
      // Мы вызываем loadGroups и loadAllTasks, чтобы удаленный чат и его шаги исчезли из UI
      await context.read<GroupProvider>().loadGroups();
      await context.read<TaskProvider>().loadAllTasks();

      // 3. Если смотрим профиль этого человека, обновляем статус кнопок
      if (_targetFullProfile?.id == friendId) {
        await loadTargetProfile(friendId);
      }
      
      notifyListeners();
    }
    
    _isLoading = false;
    notifyListeners();
    return ok;
  }


Future<String?> getVerificationTest(int skillId) async {
  // ИСПРАВЛЕНО: Убрали глобальный _isLoading. 
  // Теперь этот метод просто возвращает данные, не ломая UI на фоне.
  try {
    final response = await _userService.getVerificationTest(skillId);
    return response; // Возвращаем сырой JSON строку
  } catch (e) {
    debugPrint("UserProvider Error: $e");
    return null;
  }
}

Future<bool> submitVerificationResult(int skillId, double score) async {
  try {
    final result = await _userService.submitVerification(skillId, score);
    if (result != null && result['isVerified'] == true) {
      // Сразу обновляем свой профиль, чтобы синяя галочка появилась мгновенно
      if (_myProfile != null) {
        await loadMyProfile(_myProfile!.id);
      }
      return true;
    }
  } catch (e) {
    debugPrint("UserProvider Error [submitVerificationResult]: $e");
  }
  return false;
}


  Future<List<UserDto>> getPartnersOfUser(int userId) async {
    return await _userService.getPartnersOfUser(userId);
  }

  // Метод для полной очистки данных пользователя (при выходе)
  void clearData() {
    _myProfile = null;
    _targetFullProfile = null;
    _friends = [];
    _pendingRequests = [];
    _allSkills = [];
    _searchResults = [];
    _isLoading = false;
    notifyListeners();
  }

  Future<void> saveSkills(List<int> selectedIds, String type) async {
    _isLoading = true;
    notifyListeners();
    bool ok = await _userService.syncSkills(selectedIds, type);
    if (ok && _myProfile != null) await loadMyProfile(_myProfile!.id);
    _isLoading = false;
    notifyListeners();
  }

  Future<void> addSkillToMe(int skillId, String type) async {
    bool ok = await _userService.addUserSkill(skillId, type);
    if (ok && _myProfile != null) await loadMyProfile(_myProfile!.id);
  }

  Future<void> updateSelfProfile({required String name, required bool isPrivate, String? pass, String? confirm, String? avatarUrl}) async {
    _isLoading = true;
    notifyListeners();
    bool ok = await _userService.updateProfile(name, pass, confirm, isPrivate, avatarUrl: avatarUrl);
    if (ok && _myProfile != null) await loadMyProfile(_myProfile!.id);
    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadRequests() async {
    _pendingRequests = await _userService.getPendingRequests();
    notifyListeners();
  }

Future<void> acceptChatRequest(int requestId) async {
  await _userService.acceptRequest(requestId);
  
  // УДАЛЯЕМ запрос из локального списка, чтобы уведомление исчезло мгновенно
  _pendingRequests.removeWhere((r) => r.id == requestId);
  
  notifyListeners();
  await loadFriends();
}

  Future<void> declineChatRequest(int requestId) async {
    await _userService.declineRequest(requestId);
    await loadRequests();
  }

  Future<bool> submitReview(int targetId, int rating, String comment) async {
    bool ok = await _userService.leaveReview(targetId, rating, comment);
    if (ok) await loadTargetProfile(targetId);
    return ok;
  }

  Future<void> removeReview(int targetUserId) async {
    bool ok = await _userService.deleteReview(targetUserId);
    if (ok) await loadTargetProfile(targetUserId);
  }
}