import "package:flutter/material.dart";
import "package:shimmer/shimmer.dart";
import "../theme/app_theme.dart";

/// 全局 Tab 切换通知
final ValueNotifier<int> tabSwitchNotifier = ValueNotifier<int>(0);

/// 书籍封面占位图（渐变 + 图标）
class BookCover extends StatelessWidget {
  final String? coverUrl;
  final String title;
  final double width;
  final double height;
  final double radius;

  const BookCover({super.key, this.coverUrl, required this.title, this.width = 100, this.height = 140, this.radius = AppTheme.radiusMd});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (coverUrl != null && coverUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Image.network(
          coverUrl!,
          width: width,
          height: height,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _gradientCover(isDark),
        ),
      );
    }
    return _gradientCover(isDark);
  }

  Widget _gradientCover(bool isDark) {
    final hash = title.hashCode.abs();
    final palettes = [
      [const Color(0xFF5B7CFA), const Color(0xFF9B6BFF)],
      [const Color(0xFF00C896), const Color(0xFF00B8D4)],
      [const Color(0xFFFFB800), const Color(0xFFFF7E5F)],
      [const Color(0xFFE94B78), const Color(0xFF9B6BFF)],
      [const Color(0xFF3D5AFE), const Color(0xFF1A237E)],
      [const Color(0xFF00BFA5), const Color(0xFF00BCD4)],
    ];
    final p = palettes[hash % palettes.length];
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(colors: p, begin: Alignment.topLeft, end: Alignment.bottomRight),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(radius),
              child: CustomPaint(painter: _PatternPainter(hash)),
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13, shadows: [Shadow(color: Colors.black38, blurRadius: 4)]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PatternPainter extends CustomPainter {
  final int seed;
  _PatternPainter(this.seed);
  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < 4; i++) {
      final r = (seed % 40 + i * 15 + 20.0);
      final cx = ((seed * (i + 1)) % size.width.toInt().max(1)).toDouble();
      final cy = ((seed * (i + 3)) % size.height.toInt().max(1)).toDouble();
      final paint = Paint()..color = Colors.white.withValues(alpha: 0.06)..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(cx, cy), r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Skeleton 加载占位
class SkeletonBox extends StatelessWidget {
  final double width;
  final double height;
  final double radius;

  const SkeletonBox({super.key, this.width = double.infinity, required this.height, this.radius = AppTheme.radiusSm});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = isDark ? const Color(0xFF1A1D2E) : const Color(0xFFE5E8F5);
    final highlight = isDark ? const Color(0xFF252840) : const Color(0xFFF5F7FA);

    return Shimmer.fromColors(
      baseColor: base,
      highlightColor: highlight,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(color: base, borderRadius: BorderRadius.circular(radius)),
      ),
    );
  }
}

/// 渐变按钮
class GradientButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Gradient? gradient;
  final VoidCallback onPressed;
  final double height;

  const GradientButton({super.key, required this.label, this.icon, this.gradient, required this.onPressed, this.height = 52});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        child: Ink(
          decoration: BoxDecoration(
            gradient: gradient ?? AppTheme.primaryGradient,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            boxShadow: AppTheme.cardShadow(AppTheme.primaryLight, opacity: 0.3, blur: 12),
          ),
          child: SizedBox(
            height: height,
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                  ],
                  Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 状态标签
class StatusTag extends StatelessWidget {
  final String status;
  final double fontSize;

  const StatusTag({super.key, required this.status, this.fontSize = 11});

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(AppTheme.radiusFull)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(AppTheme.statusIcon(status), size: 10, color: c),
          const SizedBox(width: 3),
          Text(AppTheme.statusLabel(status), style: TextStyle(color: c, fontSize: fontSize, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

/// 空状态
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: cs.primary.withValues(alpha: 0.06),
              ),
              child: Icon(icon, size: 36, color: cs.primary.withValues(alpha: 0.4)),
            ),
            const SizedBox(height: 16),
            Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: cs.onSurface), textAlign: TextAlign.center),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(subtitle!, style: TextStyle(fontSize: 13, color: cs.onSurface.withValues(alpha: 0.5)), textAlign: TextAlign.center),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 24),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

// int max extension
extension IntMax on int {
  int max(int other) => this > other ? this : other;
}
