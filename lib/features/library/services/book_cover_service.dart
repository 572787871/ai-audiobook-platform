import 'dart:ui';
import '../models/book.dart';

/// 根据书籍 id 生成稳定（同一本书颜色不变）的封面渐变色。
class BookCoverService {
  BookCoverService._();

  static const List<List<Color>> _palette = [
    [Color(0xFF6D83F2), Color(0xFF3B4CCA)], // 蓝紫
    [Color(0xFFF2789F), Color(0xFFB5174E)], // 玫红
    [Color(0xFF42C6A5), Color(0xFF1E7E6B)], // 青绿
    [Color(0xFFF2A65A), Color(0xFFC75B1E)], // 橙
    [Color(0xFF8E7CF2), Color(0xFF5B3FC7)], // 紫
    [Color(0xFF4FA3F2), Color(0xFF1E63B5)], // 天蓝
    [Color(0xFFE2B85A), Color(0xFFB5862A)], // 金
    [Color(0xFF7AC74F), Color(0xFF3E7A24)], // 绿
    [Color(0xFFF2607C), Color(0xFFC72A4B)], // 红粉
    [Color(0xFF5FD0E0), Color(0xFF1E8DA0)], // 湖蓝
  ];

  static List<Color> colorsFor(Book book) {
    final hash = book.id.hashCode.abs();
    return _palette[hash % _palette.length];
  }

  /// 文字颜色：深色封面用白字，浅色封面用深色字。
  static Color textColorFor(Book book) => const Color(0xFFFFFFFF);
}
