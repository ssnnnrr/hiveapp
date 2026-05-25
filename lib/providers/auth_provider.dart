import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_app/providers/event_provider.dart';
import 'package:hive_app/providers/goal_provider.dart';
import 'package:provider/provider.dart';
import '../models/all_models.dart';
import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  UserDto? _user;
  bool _isLoading = false;
  bool _isReady = false;

  final AuthService _authService = AuthService();
  final _storage = const FlutterSecureStorage();

  UserDto? get user => _user;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _user != null && _isReady;

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    notifyListeners();
    final res = await _authService.login(email, password);
    if (res != null) {
      _user = res.user;
      await _storage.write(key: 'jwt_token', value: res.token);
      _isReady = true;
      _isLoading = false;
      notifyListeners();
      return true;
    }
    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<bool> register(String username, String email, String password) async {
    _isLoading = true;
    notifyListeners();
    final success = await _authService.register(username, email, password);
    _isLoading = false;
    notifyListeners();
    return success;
  }

  void completeAuth() {
    _isReady = true;
    notifyListeners();
  }

  void logout(BuildContext context) async {
    await _storage.delete(key: 'jwt_token');
    _user = null;
    _isReady = false;
    context.read<GoalProvider>().clearData();
    context.read<EventProvider>().clearData();
    notifyListeners();
  }
}