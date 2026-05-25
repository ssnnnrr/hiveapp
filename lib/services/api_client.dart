import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'api_config.dart';

class ApiClient {
  late Dio dio;
  final _storage = const FlutterSecureStorage();

  // Создаем синглтон (один экземпляр на всё приложение)
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;

  ApiClient._internal() {
    dio = Dio(BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
    ));

    // ИНТЕРЦЕПТОР: Это магия, которая добавляет токен в каждый заголовок
    dio.interceptors.add(InterceptorsWrapper(
  onRequest: (options, handler) async {
    final token = await _storage.read(key: 'jwt_token');
    if (token != null) {
      // Убеждаемся, что нет лишних пробелов
      options.headers["Authorization"] = "Bearer ${token.trim()}";
    }
    return handler.next(options);
  },
));
  }
}