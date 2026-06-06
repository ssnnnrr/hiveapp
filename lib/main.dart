import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:hive_app/services/goal_service.dart';
import 'package:hive_app/services/task_service.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';

// Импорты твоих провайдеров
import 'providers/auth_provider.dart';
import 'providers/goal_provider.dart';
import 'providers/event_provider.dart';
import 'providers/task_provider.dart';
import 'providers/group_provider.dart';
import 'providers/user_provider.dart';
import 'providers/notification_provider.dart';

// Импорты экранов
import 'screens/auth_screen.dart';
import 'screens/main_screen.dart';
import 'services/user_service.dart';
import 'theme/app_theme.dart';

void main() async {
  // Инициализация локализации для дат (чтобы было "Понедельник", а не "Monday")
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ru', null);

  runApp(
    MultiProvider(
      providers: [
        Provider<TaskService>(create: (_) => TaskService()), // Добавьте это
        Provider<GoalService>(create: (_) => GoalService()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => GoalProvider()),
        ChangeNotifierProvider(create: (_) => EventProvider()),
        ChangeNotifierProvider(create: (_) => TaskProvider()),
        ChangeNotifierProvider(create: (_) => GroupProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
        // UserProvider требует UserService
        ChangeNotifierProxyProvider<AuthProvider, UserProvider>(
          create: (_) => UserProvider(UserService()),
          update: (_, auth, userProv) =>
              userProv!..loadMyProfile(auth.user?.id ?? 0),
        ),
      ],
      child: const HiveApp(),
    ),
  );
}

class HiveApp extends StatelessWidget {
  const HiveApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'хайв',
      // --- ДОБАВЬ ЭТИ СТРОКИ ---
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ru', 'RU'), // Устанавливаем русский язык как основной
      ],
      locale: const Locale('ru', 'RU'),
      // -------------------------
      theme: ThemeData(
        useMaterial3: true, // Включаем современный стиль Material 3
        colorSchemeSeed: AppColors.navy,
      ),
      home: Consumer<AuthProvider>(
        builder: (context, auth, _) =>
            auth.isAuthenticated ? const MainScreen() : const AuthScreen(),
      ),
    );
  }
}
