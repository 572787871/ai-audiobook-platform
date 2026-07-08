/// App 配置与路由
import "package:flutter/material.dart";
import "package:provider/provider.dart";
import "providers/auth_provider.dart";
import "screens/splash_screen.dart";
import "screens/login_screen.dart";
import "screens/register_screen.dart";
import "screens/home_screen.dart";
import "screens/upload_screen.dart";
import "screens/task_list_screen.dart";
import "screens/task_detail_screen.dart";
import "screens/book_detail_screen.dart";
import "screens/player_screen.dart";
import "screens/profile_screen.dart";
import "screens/membership_screen.dart";
import "screens/settings_screen.dart";

class AiAudiobookApp extends StatelessWidget {
  const AiAudiobookApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "AI有声书",
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6B4EFF),
          brightness: Brightness.light,
        ),
        appBarTheme: const AppBarTheme(centerTitle: false, elevation: 0),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6B4EFF),
          brightness: Brightness.dark,
        ),
        appBarTheme: const AppBarTheme(centerTitle: false, elevation: 0),
      ),
      themeMode: ThemeMode.system,
      initialRoute: "/",
      onGenerateRoute: (settings) {
        // 根据 auth 状态分发
        final auth = context.read<AuthProvider>();

        // 未登录 -> 路由守卫
        final protectedRoutes = [
          "/home", "/upload", "/tasks", "/profile", "/membership", "/settings"
        ];
        if (protectedRoutes.any((r) => settings.name == r || (settings.name ?? "").startsWith(r)) && !auth.isLoggedIn) {
          return MaterialPageRoute(builder: (_) => const LoginScreen());
        }

        switch (settings.name) {
          case "/":
            return MaterialPageRoute(builder: (_) => const SplashScreen());
          case "/login":
            return MaterialPageRoute(builder: (_) => const LoginScreen());
          case "/register":
            return MaterialPageRoute(builder: (_) => const RegisterScreen());
          case "/home":
            return MaterialPageRoute(builder: (_) => const HomeScreen());
          case "/upload":
            return MaterialPageRoute(builder: (_) => const UploadScreen());
          case "/tasks":
            return MaterialPageRoute(builder: (_) => const TaskListScreen());
          case "/profile":
            return MaterialPageRoute(builder: (_) => const ProfileScreen());
          case "/membership":
            return MaterialPageRoute(builder: (_) => const MembershipScreen());
          case "/settings":
            return MaterialPageRoute(builder: (_) => const SettingsScreen());
          case "/book":
            final bookId = settings.arguments as int;
            return MaterialPageRoute(builder: (_) => BookDetailScreen(bookId: bookId));
          case "/task":
            final taskId = settings.arguments as int;
            return MaterialPageRoute(builder: (_) => TaskDetailScreen(taskId: taskId));
          case "/player":
            final bookId = settings.arguments as int;
            return MaterialPageRoute(builder: (_) => PlayerScreen(bookId: bookId));
          default:
            return MaterialPageRoute(builder: (_) => const SplashScreen());
        }
      },
    );
  }
}
