import 'package:flutter/cupertino.dart';
import '../../../theme/app_theme.dart';

class EmptyLibraryHeader extends StatelessWidget {
  const EmptyLibraryHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(top: 60, bottom: 32),
      child: Column(
        children: [
          Text(
            '开始听第一本书',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryText,
            ),
          ),
          SizedBox(height: 8),
          Text(
            '导入小说，让 AI 为你实时朗读',
            style: TextStyle(fontSize: 16, color: AppTheme.secondaryText),
          ),
        ],
      ),
    );
  }
}
