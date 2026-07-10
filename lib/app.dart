import 'package:flutter/cupertino.dart';
import 'theme/app_theme.dart';
import 'features/library/library_page.dart';

class AudiobookApp extends StatelessWidget {
  const AudiobookApp({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoApp(
      title: '听书 AI',
      theme: const CupertinoThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: AppTheme.background,
        textTheme: CupertinoTextThemeData(
          primaryColor: AppTheme.primaryText,
        ),
      ),
      home: const LibraryPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}
