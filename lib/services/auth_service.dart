import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/all_models.dart';
import 'api_config.dart';

class AuthService {
  final Dio _dio = Dio(BaseOptions(baseUrl: ApiConfig.baseUrl));
  final _storage = const FlutterSecureStorage();

  Future<AuthResponse?> login(String email, String password) async {
    try {
      final response = await _dio.post("/Auth/login", data: {
        "email": email,
        "password": password
      });

      if (response.statusCode == 200) {
        final authData = AuthResponse.fromJson(response.data);
        await _storage.write(key: 'jwt_token', value: authData.token);
        return authData;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<bool> register(String username, String email, String password) async {
    try {
      final response = await _dio.post("/Auth/register", data: {
        "username": username,
        "email": email,
        "password": password
      });
      return response.statusCode == 200;
    } catch (e) {
      print("ОШИБКА РЕГИСТРАЦИИ: $e"); // Добавь это для отладки
      return false;
    }
  }
}