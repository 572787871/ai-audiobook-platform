import 'package:flutter/cupertino.dart';

class AppTheme {
  AppTheme._();

  static const Color background = Color(0xFFF2F2F7);
  static const Color cardBackground = Color(0xFFFFFFFF);
  static const Color primaryText = Color(0xFF000000);
  static const Color secondaryText = Color(0xFF8E8E93);
  static const Color iconBackground = Color(0xFFE5E5EA);
  static const Color iconColor = Color(0xFF8E8E93);
  static const Color shadowColor = Color(0x1A000000);

  static const double cardRadius = 14.0;
  static const double horizontalPadding = 20.0;

  static BoxDecoration cardDecoration = BoxDecoration(
    color: cardBackground,
    borderRadius: BorderRadius.all(Radius.circular(cardRadius)),
    boxShadow: [
      BoxShadow(color: shadowColor, blurRadius: 8, offset: Offset(0, 2)),
    ],
  );
}
