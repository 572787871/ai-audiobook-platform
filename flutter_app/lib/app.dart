/// App 配置与路由
import "package:flutter/material.dart";
import "package:provider/provider.dart";
import "theme/app_theme.dart";
import "services/api_service.dart";
import "providers/auth_provider.dart";
import "providers/book_provider.dart";
import "providers/task_provider.dart";
import "screens/splash_screen.dart";
import "screens/login_screen.dart";
import "screens/register_screen.dart";
import "screens/home_screen.dart";
import "screens/upload_screen.dart";
import "screens/book_detail_screen.dart";
import "screens/player_screen.dart";
import "screens/membership_screen.dart";
import "screens/profile_screen.dart";
import "screens/settings_screen.dart";

class AiAudiobookApp extends StatelessWidget {
  const AiAudiobookApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "AI有声书",
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      initialRoute: "/",
      onGenerateRoute: (settings) {
        final protectedRoutes = ["/home", "/upload", "/profile", "/membership"];
        final auth = context.read<AuthProvider>();
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
          case "/profile":
            return MaterialPageRoute(builder: (_) => const ProfileScreen());
          case "/membership":
            return MaterialPageRoute(builder: (_) => const MembershipScreen());
          case "/settings":
            return MaterialPageRoute(builder: (_) => const SettingsScreen());
          case "/book":
            final bookId = settings.arguments as int;
            return MaterialPageRoute(builder: (_) => BookDetailScreen(bookId: bookId));
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