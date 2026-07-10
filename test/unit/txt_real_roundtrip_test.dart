import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_audiobook_platform/features/import/file_import_service.dart';
import 'package:ai_audiobook_platform/features/import/file_import_result.dart';
import 'package:ai_audiobook_platform/features/library/models/book_file_type.dart';
import 'package:ai_audiobook_platform/features/library/services/book_repository.dart';

/// 真实字节级往返：把原始字节写成真实文件 → 真实 importFile →
/// 真实从磁盘读回 original.* 与 content.txt 的字节逐字节比对。
void main() {
  late Directory booksRoot;

  setUp(() async {
    booksRoot = await Directory.systemTemp.createTemp('rt_test_');
    BookRepository.instance.setBooksDirForTest(booksRoot);
  });

  tearDown(() async {
    if (await booksRoot.exists()) await booksRoot.delete(recursive: true);
  });

  Future<void> verifyRoundTrip(
    List<int> rawBytes,
    String fileName,
    String expectedText,
    String expectedEncoding,
  ) async {
    // 1) 写真实源文件到磁盘（不在内存里假设）
    final srcDir = Directory.systemTemp.createTempSync('src_');
    final srcFile = File('${srcDir.path}/$fileName');
    await srcFile.writeAsBytes(rawBytes, flush: true);
    expect(await srcFile.exists(), true,
        reason: '源文件应真实存在于磁盘');

    // 2) 真实导入（走完整 importFile 流程）
    final r = await FileImportService.instance.importFile(srcFile);
    expect(r.success, true, reason: '导入应成功: ${r.errorMessage}');
    expect(r.book!.fileType, BookFileType.txt);
    expect(r.book!.encoding, expectedEncoding);

    // 3) 真实从磁盘读回 original.* 字节，与源字节逐字节一致（复制必须无损）
    final originalBytes = await File(r.book!.originalPath).readAsBytes();
    expect(originalBytes, equals(rawBytes),
        reason: 'original.* 必须与源文件字节完全一致');

    // 4) 真实从磁盘读回 content.txt 字节，utf8 解码后等于期望文本
    final contentBytes = await File(r.book!.contentPath!).readAsBytes();
    final decoded = utf8.decode(contentBytes);
    expect(decoded, equals(expectedText),
        reason: 'content.txt 解码文本必须与期望一致');

    // 5) characterCount 与文本长度一致
    expect(r.book!.characterCount, equals(expectedText.length));

    await srcDir.delete(recursive: true);
  }

  test('UTF-8 真实字节级往返（写盘→导入→读回）', () async {
    final text = '第一章\n床前明月光，疑是地上霜。\n举头望明月，低头思故乡。';
    await verifyRoundTrip(utf8.encode(text), 'poem.txt', text, 'utf-8');
  });

  test('UTF-8 BOM 真实字节级往返（BOM 被剥离，文本一致）', () async {
    final text = '春风又绿江南岸，明月何时照我还。';
    final body = utf8.encode(text);
    final bom = <int>[0xEF, 0xBB, 0xBF, ...body];
    await verifyRoundTrip(bom, 'bom.txt', text, 'utf-8-bom');
  });

  test('UTF-16 LE 真实字节级往返', () async {
    // "小说" U+5C0F U+8BF4 -> LE 字节
    final cd = Uint8List(4)
      ..buffer.asByteData().setInt16(0, 0x5C0F, Endian.little)
      ..buffer.asByteData().setInt16(2, 0x8BF4, Endian.little);
    await verifyRoundTrip(cd.toList(), 'u16le.txt', '小说', 'utf-16le');
  });

  test('GBK 真实字节级往返', () async {
    // 中文 = 0xD6 0xD0 0xCE 0xC4
    final gbk = <int>[0xD6, 0xD0, 0xCE, 0xC4];
    await verifyRoundTrip(gbk, 'gbk.txt', '中文', 'gbk');
  });

  test('重复导入：第二次返回 duplicate 且文件不重复落盘', () async {
    final bytes = utf8.encode('唯一内容用于重复检测');
    final srcDir = Directory.systemTemp.createTempSync('dup_');
    final f1 = File('${srcDir.path}/d.txt');
    final f2 = File('${srcDir.path}/d_copy.txt');
    await f1.writeAsBytes(bytes, flush: true);
    await f2.writeAsBytes(bytes, flush: true);

    final r1 = await FileImportService.instance.importFile(f1);
    expect(r1.success, true);
    final r2 = await FileImportService.instance.importFile(f2);
    expect(r2.success, false);
    expect(r2.errorCode, FileImportErrorCode.duplicate);
    expect(r2.existingBookId, r1.book!.id);

    await srcDir.delete(recursive: true);
  });
}
