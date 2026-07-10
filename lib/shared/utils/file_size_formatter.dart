/// 文件大小格式化工具
class FileSizeFormatter {
  FileSizeFormatter._();

  /// 将字节数格式化为可读字符串，例如 "1.2 MB"
  static String format(int bytes) {
    if (bytes <= 0) return '0 B';
    const units = ['B', 'KB', 'MB', 'GB'];
    int unitIndex = 0;
    double size = bytes.toDouble();
    while (size >= 1024 && unitIndex < units.length - 1) {
      size /= 1024;
      unitIndex++;
    }
    if (unitIndex == 0) return '${size.toInt()} ${units[unitIndex]}'; // B 不保留小数
    final str = size >= 100 ? size.toStringAsFixed(0) : size.toStringAsFixed(1);
    return '$str ${units[unitIndex]}'; // 例如 "1.2 MB"
  }
}
