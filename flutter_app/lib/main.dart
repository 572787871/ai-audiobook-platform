/// App 入口
import "package:flutter/material.dart";
import "package:provider/provider.dart";
import "services/api_service.dart";
import "app.dart";
import "providers/auth_provider.dart";
import "providers/book_provider.dart";
import "providers/task_provider.dart";

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiService.init();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => BookProvider()),
        ChangeNotifierProvider(create: (_) => TaskProvider()),
      ],
      child: const AiAudiobookApp(),
    ),
  );
}
