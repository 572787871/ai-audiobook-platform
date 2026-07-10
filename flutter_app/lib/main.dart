import "package:flutter/material.dart";
import "package:provider/provider.dart";
import "providers/auth_provider.dart";
import "providers/book_provider.dart";
import "providers/task_provider.dart";
import "providers/local_tts_provider.dart";
import "screens/splash_screen.dart";
import "screens/login_screen.dart";
import "screens/register_screen.dart";
import "screens/main_tab_screen.dart";
import "screens/browse_read_screen.dart";
import "screens/book_detail_screen.dart";
import "screens/player_screen.dart";
import "screens/task_detail_screen.dart";
import "screens/profile_screen.dart";
import "screens/membership_screen.dart";
import "screens/settings_screen.dart";
import "screens/upload_screen.dart";
import "screens/voice_pack_manager_screen.dart";
import "screens/voice_select_screen.dart";
import "screens/local_generation_screen.dart";

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => BookProvider()),
        ChangeNotifierProvider(create: (_) => TaskProvider()),
        ChangeNotifierProvider(create: (_) => LocalTtsProvider()..init()),
      ],
      child: const AiAudiobookApp(),
    ),
  );
}

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
          seedColor: const Color(0xFF4A6CF7),
          brightness: Brightness.light,
          surface: const Color(0xFFF5F7FA),
        ),
        appBarTheme: const AppBarTheme(centerTitle: false, elevation: 0),
        cardTheme: CardTheme(
          elevation: 2,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4A6CF7),
          brightness: Brightness.dark,
        ),
        appBarTheme: const AppBarTheme(centerTitle: false, elevation: 0),
      ),
      themeMode: ThemeMode.system,
      initialRoute: "/",
      onGenerateRoute: (settings) {
        final auth = context.read<AuthProvider>();
        final protectedRoutes = [
          "/home",
          "/upload",
          "/tasks",
          "/profile",
          "/membership",
          "/voice-packs",
          "/voice-select",
          "/local-generation"
        ];
        if (protectedRoutes.any((r) =>
                settings.name == r || (settings.name ?? "").startsWith(r)) &&
            !auth.isLoggedIn) {
          return MaterialPageRoute(builder: (_) => const LoginScreen());
        }
        switch (settings.name) {
          case "/":
            return MaterialPageRoute(builder: (_) => const SplashScreen());
          case "/login":
            return MaterialPageRoute(builder: (_) => const LoginScreen());
          case "/register":
            return MaterialPageRoute(builder: (_) => const RegisterScreen());
          case "/upload":
            return MaterialPageRoute(builder: (_) => const UploadScreen());
          case "/home":
            return MaterialPageRoute(builder: (_) => const MainTabScreen());
          case "/book":
            final bookId = settings.arguments as int;
            return MaterialPageRoute(
                builder: (_) => BookDetailScreen(bookId: bookId));
          case "/task":
            final taskId = settings.arguments as int;
            return MaterialPageRoute(
                builder: (_) => TaskDetailScreen(taskId: taskId));
          case "/player":
            final bookId = settings.arguments as int;
            return MaterialPageRoute(
                builder: (_) => PlayerScreen(bookId: bookId));
          case "/read":
            final bookId = settings.arguments as int;
            return MaterialPageRoute(
                builder: (_) => BrowseReadScreen(bookId: bookId));
          case "/profile":
            return MaterialPageRoute(builder: (_) => const ProfileScreen());
          case "/membership":
            return MaterialPageRoute(builder: (_) => const MembershipScreen());
          case "/settings":
            return MaterialPageRoute(builder: (_) => const SettingsScreen());
          case "/voice-packs":
            return MaterialPageRoute(
                builder: (_) => const VoicePackManagerScreen());
          case "/voice-select":
            final args = settings.arguments as VoiceSelectArgs? ??
                const VoiceSelectArgs();
            return MaterialPageRoute(
                builder: (_) => VoiceSelectScreen(args: args));
          case "/local-generation":
            final args = settings.arguments as LocalGenerationArgs;
            return MaterialPageRoute(
                builder: (_) => LocalGenerationScreen(args: args));
          default:
            return MaterialPageRoute(builder: (_) => const SplashScreen());
        }
      },
    );
  }
}
