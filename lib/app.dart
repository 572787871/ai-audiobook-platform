import 'package:flutter/cupertino.dart';
import 'theme/app_theme.dart';
import 'features/library/pages/book_shelf_page.dart';

class AudiobookApp extends StatelessWidget {
  const AudiobookApp({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoApp(
      title: '书架',
      theme: const CupertinoThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: AppTheme.background,
        textTheme: CupertinoTextThemeData(primaryColor: AppTheme.primaryText),
      ),
      home: const BookShelfPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}
