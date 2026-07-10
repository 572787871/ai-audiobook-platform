import "dart:ui";
import "package:flutter/material.dart";
import "package:google_fonts/google_fonts.dart";

/// 商业级主题系统
/// 设计语言：高级感 + 科技感 + 简洁 + 圆角 + 渐变 + 毛玻璃
class AppTheme {
  // 品牌色
  static const Color primaryLight = Color(0xFF5B7CFA);
  static const Color primaryDark = Color(0xFF7B9BFF);
  static const Color accent = Color(0xFF9B6BFF);
  static const Color success = Color(0xFF00C896);
  static const Color warning = Color(0xFFFFB800);
  static const Color danger = Color(0xFFFF5757);

  // 浅色模式
  static const Color bgLight = Color(0xFFF7F8FC);
  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color textPrimaryLight = Color(0xFF1A1D2E);
  static const Color textSecondaryLight = Color(0xFF6B7290);
  static const Color textTertiaryLight = Color(0xFF9CA3C0);

  // 深色模式
  static const Color bgDark = Color(0xFF0D0F1A);
  static const Color cardDark = Color(0xFF1A1D2E);
  static const Color elevatedDark = Color(0xFF252840);
  static const Color textPrimaryDark = Color(0xFFF0F2FF);
  static const Color textSecondaryDark = Color(0xFF9CA3C0);
  static const Color textTertiaryDark = Color(0xFF5B6380);

  // 渐变
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF5B7CFA), Color(0xFF9B6BFF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient warmGradient = LinearGradient(
    colors: [Color(0xFFFFB800), Color(0xFFFF7E5F)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient bookCoverGradient = LinearGradient(
    colors: [Color(0xFF3D5AFE), Color(0xFF7E5FFF)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient playerGradient = LinearGradient(
    colors: [Color(0xFF1A1D2E), Color(0xFF0D0F1A)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // 圆角
  static const double radiusSm = 8.0;
  static const double radiusMd = 12.0;
  static const double radiusLg = 16.0;
  static const double radiusXl = 24.0;
  static const double radiusFull = 999.0;

  // 间距
  static const double spacingXs = 4.0;
  static const double spacingSm = 8.0;
  static const double spacingMd = 16.0;
  static const double spacingLg = 24.0;
  static const double spacingXl = 32.0;

  // 阴影
  static List<BoxShadow> cardShadow(Color color,
      {double opacity = 0.08,
      double blur = 20,
      double spread = 0,
      double y = 4}) {
    return [
      BoxShadow(
          color: color..withValues(alpha: opacity),
          blurRadius: blur,
          spreadRadius: spread,
          offset: Offset(0, y))
    ];
  }

  static List<BoxShadow> glowShadow(Color color,
      {double opacity = 0.3, double blur = 30}) {
    return [
      BoxShadow(
          color: color..withValues(alpha: opacity),
          blurRadius: blur,
          spreadRadius: 0)
    ];
  }

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: bgLight,
        primaryColor: primaryLight,
        colorScheme: ColorScheme.light(
          primary: primaryLight,
          secondary: accent,
          surface: cardLight,
          onPrimary: Colors.white,
          onSurface: textPrimaryLight,
        ),
        textTheme: GoogleFonts.notoSansScTextTheme().copyWith(
          headlineLarge: TextStyle(
              color: textPrimaryLight,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5),
          headlineMedium: TextStyle(
              color: textPrimaryLight,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5),
          headlineSmall:
              TextStyle(color: textPrimaryLight, fontWeight: FontWeight.w600),
          titleLarge:
              TextStyle(color: textPrimaryLight, fontWeight: FontWeight.w600),
          titleMedium:
              TextStyle(color: textPrimaryLight, fontWeight: FontWeight.w600),
          bodyLarge: TextStyle(color: textPrimaryLight, fontSize: 16),
          bodyMedium: TextStyle(color: textPrimaryLight, fontSize: 14),
          bodySmall: TextStyle(color: textSecondaryLight, fontSize: 12),
          labelLarge: TextStyle(
              color: textPrimaryLight,
              fontWeight: FontWeight.w600,
              fontSize: 14),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: bgLight,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
              color: textPrimaryLight,
              fontSize: 18,
              fontWeight: FontWeight.w600),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radiusLg)),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          hintStyle: TextStyle(color: textTertiaryLight, fontSize: 14),
          labelStyle: TextStyle(color: textSecondaryLight, fontSize: 14),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(radiusMd),
              borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(radiusMd),
              borderSide: BorderSide(color: primaryLight, width: 1.5)),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: primaryLight,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(radiusMd)),
            textStyle:
                const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
              foregroundColor: primaryLight,
              textStyle:
                  const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: primaryLight,
            side: BorderSide(color: primaryLight..withValues(alpha: 0.3)),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(radiusMd)),
            minimumSize: const Size.fromHeight(52),
          ),
        ),
        dividerTheme: DividerThemeData(
            color: const Color(0xFFE5E8F5), thickness: 1, space: 1),
        chipTheme: ChipThemeData(
          backgroundColor: const Color(0xFFF0F2FF),
          selectedColor: primaryLight..withValues(alpha: 0.1),
          labelStyle: TextStyle(
              color: textSecondaryLight,
              fontSize: 12,
              fontWeight: FontWeight.w500),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radiusFull)),
          side: BorderSide.none,
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          indicatorColor: primaryLight..withValues(alpha: 0.1),
          indicatorShape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radiusMd)),
          labelTextStyle: WidgetStateProperty.all(
              const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
        ),
      );

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: bgDark,
        primaryColor: primaryDark,
        colorScheme: ColorScheme.dark(
          primary: primaryDark,
          secondary: accent,
          surface: cardDark,
          onPrimary: Colors.white,
          onSurface: textPrimaryDark,
        ),
        textTheme: GoogleFonts.notoSansScTextTheme(ThemeData.dark().textTheme)
            .copyWith(
          headlineLarge: TextStyle(
              color: textPrimaryDark,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5),
          headlineMedium: TextStyle(
              color: textPrimaryDark,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5),
          headlineSmall:
              TextStyle(color: textPrimaryDark, fontWeight: FontWeight.w600),
          titleLarge:
              TextStyle(color: textPrimaryDark, fontWeight: FontWeight.w600),
          titleMedium:
              TextStyle(color: textPrimaryDark, fontWeight: FontWeight.w600),
          bodyLarge: TextStyle(color: textPrimaryDark, fontSize: 16),
          bodyMedium: TextStyle(color: textPrimaryDark, fontSize: 14),
          bodySmall: TextStyle(color: textSecondaryDark, fontSize: 12),
          labelLarge: TextStyle(
              color: textPrimaryDark,
              fontWeight: FontWeight.w600,
              fontSize: 14),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: bgDark,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
              color: textPrimaryDark,
              fontSize: 18,
              fontWeight: FontWeight.w600),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          color: cardDark,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radiusLg)),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: cardDark,
          hintStyle: TextStyle(color: textTertiaryDark, fontSize: 14),
          labelStyle: TextStyle(color: textSecondaryDark, fontSize: 14),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(radiusMd),
              borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(radiusMd),
              borderSide: BorderSide(color: primaryDark, width: 1.5)),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: primaryDark,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(radiusMd)),
            textStyle:
                const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
              foregroundColor: primaryDark,
              textStyle:
                  const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: primaryDark,
            side: BorderSide(color: primaryDark..withValues(alpha: 0.3)),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(radiusMd)),
            minimumSize: const Size.fromHeight(52),
          ),
        ),
        dividerTheme: const DividerThemeData(
            color: Color(0xFF252840), thickness: 1, space: 1),
        chipTheme: ChipThemeData(
          backgroundColor: const Color(0xFF1A1D2E),
          selectedColor: primaryDark..withValues(alpha: 0.15),
          labelStyle: TextStyle(
              color: textSecondaryDark,
              fontSize: 12,
              fontWeight: FontWeight.w500),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radiusFull)),
          side: BorderSide.none,
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: cardDark,
          surfaceTintColor: cardDark,
          indicatorColor: primaryDark..withValues(alpha: 0.15),
          indicatorShape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radiusMd)),
          labelTextStyle: WidgetStateProperty.all(
              const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
        ),
      );

  // 状态颜色
  static Color statusColor(String status) {
    switch (status) {
      case "completed":
        return success;
      case "processing":
        return warning;
      case "failed":
        return danger;
      default:
        return const Color(0xFF9CA3C0);
    }
  }

  static String statusLabel(String status) {
    switch (status) {
      case "completed":
        return "已完成";
      case "processing":
        return "合成中";
      case "failed":
        return "失败";
      default:
        return "等待中";
    }
  }

  static IconData statusIcon(String status) {
    switch (status) {
      case "completed":
        return Icons.check_circle_rounded;
      case "processing":
        return Icons.hourglass_top_rounded;
      case "failed":
        return Icons.error_outline_rounded;
      default:
        return Icons.schedule_rounded;
    }
  }
}

/// 玻璃容器组件
class GlassBox extends StatelessWidget {
  final Widget child;
  final double? blur;
  final double borderRadius;
  final Color? color;

  const GlassBox(
      {super.key,
      required this.child,
      this.blur,
      this.borderRadius = AppTheme.radiusLg,
      this.color});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: blur != null
            ? ImageFilter.blur(sigmaX: blur!, sigmaY: blur!)
            : ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: color ??
                (isDark
                    ? Colors.black..withValues(alpha: 0.3)
                    : Colors.white..withValues(alpha: 0.6)),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
                color: isDark
                    ? Colors.white..withValues(alpha: 0.1)
                    : Colors.white..withValues(alpha: 0.4),
                width: 0.5),
          ),
          child: child,
        ),
      ),
    );
  }
}
