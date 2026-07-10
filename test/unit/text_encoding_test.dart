import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_audiobook_platform/shared/services/text_encoding_service.dart';

void main() {
  test('UTF-8 解码', () {
    final bytes = utf8.encode('中文测试 ABC');
    final d = TextEncodingService.decodeBytes(bytes);
    expect(d.encoding, 'utf-8');
    expect(d.text, '中文测试 ABC');
  });

  test('UTF-8 BOM 解码', () {
    final body = utf8.encode('带 BOM 的文本');
    final bytes = <int>[0xEF, 0xBB, 0xBF, ...body];
    final d = TextEncodingService.decodeBytes(bytes);
    expect(d.encoding, 'utf-8-bom');
    expect(d.text, '带 BOM 的文本');
  });

  test('UTF-16 LE 解码', () {
    // "a小" : a=0x0061, 小=0x5C0F。LE 字节 [61,00,0F,5C] 解码为 "a小" 合法；BE 则为非法。
    final cd = Uint8List(4)
      ..buffer.asByteData().setInt16(0, 0x0061, Endian.little)
      ..buffer.asByteData().setInt16(2, 0x5C0F, Endian.little);
    final d = TextEncodingService.decodeBytes(cd.toList());
    expect(d.encoding, 'utf-16le');
    expect(d.text, 'a小');
  });

  test('UTF-16 BE 解码', () {
    // "小a" : 小=0x5C0F, a=0x0061。BE 字节 [5C,0F,00,61] 解码为 "小a" 合法；LE 则为非法。
    final cd = Uint8List(4)
      ..buffer.asByteData().setInt16(0, 0x5C0F, Endian.big)
      ..buffer.asByteData().setInt16(2, 0x0061, Endian.big);
    final d = TextEncodingService.decodeBytes(cd.toList());
    expect(d.encoding, 'utf-16be');
    expect(d.text, '小a');
  });

  test('GBK 解码', () {
    final bytes = <int>[0xD6, 0xD0, 0xCE, 0xC4]; // 中文
    final d = TextEncodingService.decodeBytes(bytes);
    expect(d.encoding, 'gbk');
    expect(d.text, '中文');
  });

  test('奇数长度乱码字节解码失败', () {
    // 奇数长度无法被偶数对称的 UTF-16 解析，且 GBK 遇不成对的尾字节会抛异常，
    // 因此整体走到编码失败分支。
    final bytes = List<int>.generate(63, (i) => (i * 31 + 3) % 256);
    expect(() => TextEncodingService.decodeBytes(bytes),
        throwsA(isA<EncodingException>()));
  });

  test('空字节解码失败', () {
    expect(() => TextEncodingService.decodeBytes(<int>[]),
        throwsA(isA<EncodingException>()));
  });
}
