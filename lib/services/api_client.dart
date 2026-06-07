import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart'; // Добавьте этот импорт
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'api_config.dart';

class ApiClient {
  late Dio dio;
  final _storage = const FlutterSecureStorage();

  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;

  ApiClient._internal() {
    dio = Dio(BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      // ИСПРАВЛЕНИЕ: На Web не шлем sendTimeout, если это не POST с телом
      sendTimeout: kIsWeb ? null : const Duration(seconds: 30), 
      followRedirects: true,
    ));

    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _storage.read(key: 'jwt_token');
        if (token != null) {
          options.headers["Authorization"] = "Bearer ${token.trim()}";
        }
        
        // Дополнительная защита для Web:
        if (kIsWeb && options.data == null) {
          options.sendTimeout = null;
        }
        
        return handler.next(options);
      },
    ));
  }
}