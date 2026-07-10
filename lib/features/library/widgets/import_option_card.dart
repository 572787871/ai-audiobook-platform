import 'package:flutter/cupertino.dart';
import '../../../theme/app_theme.dart';

class ImportOptionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const ImportOptionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: () => _showPlaceholder(context),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: AppTheme.cardDecoration,
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: AppTheme.iconBackground,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(icon, size: 22, color: AppTheme.primaryText),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                CupertinoIcons.chevron_right,
                size: 16,
                color: AppTheme.secondaryText,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
