import 'package:flutter/cupertino.dart';
import '../../theme/app_theme.dart';

class CircularIconButton extends StatelessWidget {
  final IconData icon;
  final double size;

  const CircularIconButton({
    super.key,
    required this.icon,
    this.size = 36,
  });

  void _showPlaceholder(BuildContext context) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('提示'),
        content: const Text('功能将在下一阶段加入'),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            child: const Text('好的'),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double iconSize = size * 0.5;
    return GestureDetector(
      onTap: () => _showPlaceholder(context),
      child: Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          color: AppTheme.iconBackground,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Icon(icon, size: iconSize, color: AppTheme.iconColor),
        ),
      ),
    );
  }
}
