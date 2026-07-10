import 'dart:convert';
import 'dart:typed_data';
import 'dart:io' show Platform;
import 'package:charset/charset.dart';
import 'package:charset_converter/charset_converter.dart';

/// 文本编码识别与解码结果
class DecodedText {
  const DecodedText({
    required this.text,
    required this.encoding,
  });
  final String text;
  final String encoding;
}

/// 文本编码服务：识别并解码 TXT 文件字节为 UTF-8 字符串。
///
/// 纯 Dart 路径（可在任意平台单元测试中运行）：
/// 1. BOM（UTF-8 / UTF-16 LE / UTF-16 BE）
/// 2. UTF-8 严格解码
/// 3. UTF-16 LE / BE
/// 4. GB18030 / GBK
///
/// BIG5 为原生路径，仅在 iOS / macOS 上通过 [decodeBig5WithNative] 异步调用
/// charset_converter 完成，单测宿主（Linux）不会触碰该原生插件。
///
/// 设计原则：不允许把乱码保存为正常书籍。任何编码解码后若含占位符 U+FFFD，
/// 视为该编码不可靠；全部失败时抛出 [EncodingException]。
class TextEncodingService {
  TextEncodingService._();

  static const int _bomUtf8 = 0xEF;

  static bool get _nativeBig5Allowed => Platform.isIOS || Platform.isMacOS;

  /// 同步解码（utf8 / utf8-bom / utf16le / utf16be / gbk）。
  /// 不含 BIG5。失败抛出 [EncodingException]。
  static DecodedText decodeBytes(List<int> bytes) {
    if (bytes.isEmpty) {
      throw const EncodingException('文件为空或无法读取内容');
    }

    // 1. BOM
    if (bytes.length >= 3 &&
        bytes[0] == _bomUtf8 &&
        bytes[1] == 0xBB &&
        bytes[2] == 0xBF) {
      final body = bytes.sublist(3);
      final text = utf8.decode(body, allowMalformed: false);
      return DecodedText(text: text, encoding: 'utf-8-bom');
    }
    if (bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xFE) {
      final text = _utf16Le(bytes.sublist(2));
      return DecodedText(text: text, encoding: 'utf-16le');
    }
    if (bytes.length >= 2 && bytes[0] == 0xFE && bytes[1] == 0xFF) {
      final text = _utf16Be(bytes.sublist(2));
      return DecodedText(text: text, encoding: 'utf-16be');
    }

    // 2. UTF-16 LE / BE（先于 UTF-8，避免含 NUL 的 UTF-16 被误判为 UTF-8）
    if (bytes.length.isEven) {
      final le = _tryUtf16Le(bytes);
      if (le != null) return DecodedText(text: le, encoding: 'utf-16le');
      final be = _tryUtf16Be(bytes);
      if (be != null) return DecodedText(text: be, encoding: 'utf-16be');
    }

    // 3. UTF-8 严格解码
    final utf8Text = _tryStrictUtf8(bytes);
    if (utf8Text != null) {
      return DecodedText(text: utf8Text, encoding: 'utf-8');
    }

    // 4. GB18030 / GBK
    final gbk = _tryGbk(bytes);
    if (gbk != null) {
      return DecodedText(text: gbk, encoding: 'gbk');
    }

    throw const EncodingException('无法识别文件编码，可能是乱码或尚不支持的编码');
  }

  /// 异步解码，包含原生 BIG5（仅 iOS / macOS）。
  /// 在其他平台 BIG5 不可用时，退化到同步解码逻辑。
  static Future<DecodedText> decodeBytesAsync(List<int> bytes) async {
    if (_nativeBig5Allowed) {
      try {
        final big5 = await CharsetConverter.decode(
          'BIG5',
          Uint8List.fromList(bytes),
        );
        if (_looksValid(big5)) {
          return DecodedText(text: big5, encoding: 'big5');
        }
      } catch (_) {
        // 退化到其它编码
      }
    }
    return decodeBytes(bytes);
  }

  static String? _tryStrictUtf8(List<int> bytes) {
    try {
      final text = utf8.decode(bytes, allowMalformed: false);
      return text.isEmpty ? null : text;
    } on FormatException {
      return null;
    }
  }

  static String _utf16Le(List<int> bytes) {
    final len = bytes.length + (bytes.length.isOdd ? 1 : 0);
    final buffer = Uint8List(len);
    for (int i = 0; i < bytes.length; i++) {
      buffer[i] = bytes[i];
    }
    final bd = ByteData.sublistView(buffer);
    final units = <int>[];
    for (int i = 0; i < len ~/ 2; i++) {
      units.add(bd.getUint16(i * 2, Endian.little));
    }
    return String.fromCharCodes(units);
  }

  static String _utf16Be(List<int> bytes) {
    final len = bytes.length + (bytes.length.isOdd ? 1 : 0);
    final buffer = Uint8List(len);
    for (int i = 0; i < bytes.length; i++) {
      buffer[i] = bytes[i];
    }
    final bd = ByteData.sublistView(buffer);
    final units = <int>[];
    for (int i = 0; i < len ~/ 2; i++) {
      units.add(bd.getUint16(i * 2, Endian.big));
    }
    return String.fromCharCodes(units);
  }

  static String? _tryUtf16Le(List<int> bytes) {
    final text = _utf16Le(bytes);
    return _looksValid(text) ? text : null;
  }

  static String? _tryUtf16Be(List<int> bytes) {
    final text = _utf16Be(bytes);
    return _looksValid(text) ? text : null;
  }

  static String? _tryGbk(List<int> bytes) {
    try {
      final enc = Charset.getByName('gbk');
      if (enc == null) return null;
      final text = enc.decode(Uint8List.fromList(bytes));
      return _looksValid(text) ? text : null;
    } catch (_) {
      return null;
    }
  }

  /// 粗略判断解码结果是否可能是真实文本：不含 U+FFFD，
  /// 且可见字符（CJK / ASCII / 标点 / 换行）比例足够高。
  static bool _looksValid(String text) {
    if (text.isEmpty) return false;
    if (text.contains('�')) return false;
    int valid = 0;
    for (final r in text.runes) {
      if (r == 0xFFFD) return false;
      if (r >= 0x20 && r <= 0x7E) {
        valid++;
      } else if (r >= 0x4E00 && r <= 0x9FFF) {
        valid++;
      } else if (r >= 0x3000 && r <= 0x303F) {
        valid++;
      } else if (r >= 0xFF00 && r <= 0xFFEF) {
        valid++;
      } else if (r == 0x0A || r == 0x0D || r == 0x09) {
        valid++;
      }
    }
    return valid >= text.length * 0.6;
  }
}

/// 编码识别失败异常
class EncodingException implements Exception {
  const EncodingException(this.message);
  final String message;
  @override
  String toString() => 'EncodingException: $message';
}
