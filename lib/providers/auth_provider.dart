import 'package:flutter/material.dart';
import 'package:hive_app/providers/event_provider.dart';
import 'package:hive_app/providers/goal_provider.dart';
import 'package:hive_app/providers/group_provider.dart';
import 'package:hive_app/providers/notification_provider.dart';
import 'package:hive_app/providers/task_provider.dart';
import 'package:hive_app/providers/user_provider.dart';
import 'package:provider/provider.dart';
import '../models/all_models.dart';
import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  
  UserDto? _user;
  String? _token;
  bool _isLoading = false;

  UserDto? get user => _user;
  String? get token => _token;
  bool get isLoading => _isLoading;

  // ИСПРАВЛЕНИЕ: Добавляем именно этот геттер для main.dart
  bool get isAuthenticated => _token != null;
  
  // Дополнительный короткий геттер для удобства
  bool get isAuth => _token != null;

  // Логин
  Future<bool> login(String email, String password) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _authService.login(email, password);
      if (response != null) {
        _token = response.token;
        _user = response.user;
        
        _isLoading = false;
        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint("AuthProvider Login Error: $e");
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  // Регистрация
  Future<bool> register(String name, String email, String pass) async {
    _isLoading = true;
    notifyListeners();
    try {
      bool success = await _authService.register(name, email, pass);
      _isLoading = false;
      notifyListeners();
      return success;
    } catch (e) {
      debugPrint("AuthProvider Register Error: $e");
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

Future<void> logout(BuildContext context) async {
  // 1. Очищаем данные во всех провайдерах немедленно
  context.read<UserProvider>().clearData();
  context.read<TaskProvider>().clearData();
  context.read<GoalProvider>().clearData();
  context.read<EventProvider>().clearData();
  context.read<NotificationProvider>().clearData();
  context.read<GroupProvider>().clearData();

  // 2. Вызываем сервис логаута (удаление токена из памяти)
  try {
    await _authService.logout();
  } catch (e) { debugPrint(e.toString()); }
  
  _token = null;
  _user = null;
  
  notifyListeners(); // Гнать UI на экран входа
}

  // Завершение авторизации (если нужно просто обновить UI)
  void completeAuth() {
    notifyListeners();
  }
}