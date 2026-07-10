import 'dart:io';
import 'package:crypto/crypto.dart';

/// 文件哈希服务（用于重复检测）
class FileHashService {
  FileHashService._();

  /// 计算文件 SHA-256 十六进制字符串
  static Future<String> fileSha256(File file) async {
    final bytes = await file.readAsBytes();
    return sha256Hex(bytes);
  }

  /// 从字节计算 SHA-256 十六进制字符串
  static String sha256Hex(List<int> bytes) {
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
}
