import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_audiobook_platform/features/import/file_import_service.dart';
import 'package:ai_audiobook_platform/features/import/file_import_result.dart';
import 'package:ai_audiobook_platform/features/library/models/book_file_type.dart';
import 'package:ai_audiobook_platform/features/library/models/book_parse_status.dart';
import 'package:ai_audiobook_platform/features/library/services/book_repository.dart';

void main() {
  late Directory booksRoot;

  setUp(() async {
    booksRoot = await Directory.systemTemp.createTemp('books_test_');
    BookRepository.instance.setBooksDirForTest(booksRoot);
  });

  tearDown(() async {
    if (await booksRoot.exists()) {
      await booksRoot.delete(recursive: true);
    }
  });

  // —— TXT 各类编码导入 ——
  test('UTF-8 TXT 导入成功', () async {
    final bytes = utf8.encode('第一章\n床前明月光，疑是地上霜。');
    final r = await FileImportService.instance.importBytes(bytes, 'test.txt');
    expect(r.success, true);
    expect(r.book!.fileType, BookFileType.txt);
    expect(r.book!.parseStatus, BookParseStatus.ready);
    expect(r.book!.characterCount, greaterThan(0));
    expect(r.book!.title, 'test');
    // content.txt 已保存
    final contentFile = File(r.book!.contentPath!);
    expect(await contentFile.exists(), true);
    expect(await contentFile.readAsString(), '第一章\n床前明月光，疑是地上霜。');
  });

  test('UTF-8 BOM TXT 导入成功', () async {
    final body = utf8.encode('春风又绿江南岸');
    final bytes = <int>[0xEF, 0xBB, 0xBF, ...body];
    final r = await FileImportService.instance.importBytes(bytes, 'bom.txt');
    expect(r.success, true);
    expect(r.book!.encoding, 'utf-8-bom');
    expect(r.book!.parseStatus, BookParseStatus.ready);
  });

  test('UTF-16 LE TXT 导入成功', () async {
    // "小说" U+5C0F U+8BF4 -> LE
    final cd = Uint8List(4)
      ..buffer.asByteData().setInt16(0, 0x5C0F, Endian.little)
      ..buffer.asByteData().setInt16(2, 0x8BF4, Endian.little);
    final r = await FileImportService.instance.importBytes(cd.toList(), 'u16le.txt');
    expect(r.success, true);
    expect(r.book!.encoding, 'utf-16le');
  });

  test('UTF-16 BE TXT 导入成功', () async {
    final cd = Uint8List(4)
      ..buffer.asByteData().setInt16(0, 0x5C0F, Endian.big)
      ..buffer.asByteData().setInt16(2, 0x8BF4, Endian.big);
    final r = await FileImportService.instance.importBytes(cd.toList(), 'u16be.txt');
    expect(r.success, true);
    expect(r.book!.encoding, 'utf-16be');
  });

  test('GBK TXT 导入成功', () async {
    final bytes = <int>[0xD6, 0xD0, 0xCE, 0xC4]; // 中文
    final r = await FileImportService.instance.importBytes(bytes, 'gbk.txt');
    expect(r.success, true);
    expect(r.book!.encoding, 'gbk');
    expect(r.book!.characterCount, 2);
  });

  // —— 校验失败 ——
  test('空文件导入失败', () async {
    final r = await FileImportService.instance.importBytes(<int>[], 'empty.txt');
    expect(r.success, false);
    expect(r.errorCode, FileImportErrorCode.emptyFile);
  });

  test('不支持扩展名失败', () async {
    final r = await FileImportService.instance.importBytes(
        utf8.encode('hello'), 'note.md');
    expect(r.success, false);
    expect(r.errorCode, FileImportErrorCode.unsupportedExtension);
  });

  test('编码不可识别失败', () async {
    final bytes = List<int>.generate(63, (i) => (i * 13 + 7) % 256);
    final r = await FileImportService.instance.importBytes(bytes, 'garbage.txt');
    expect(r.success, false);
    expect(r.errorCode, FileImportErrorCode.encodingFailed);
  });

  // —— 非 TXT 格式仅保存不解析 ——
  test('EPUB 导入保存且不伪解析', () async {
    final bytes = utf8.encode('epub placeholder');
    final r = await FileImportService.instance.importBytes(bytes, 'book.epub');
    expect(r.success, true);
    expect(r.book!.fileType, BookFileType.epub);
    expect(r.book!.parseStatus, BookParseStatus.pending);
    expect(r.book!.contentPath, isNull);
    // original.epub 存在
    final orig = File(r.book!.originalPath);
    expect(await orig.exists(), true);
    expect(r.book!.originalPath.endsWith('original.epub'), true);
  });

  test('PDF 导入保存且状态为 pending', () async {
    final bytes = <int>[0x25, 0x50, 0x44, 0x46, 0x2D, 0x31, 0x2E, 0x34]; // %PDF-1.4
    final r = await FileImportService.instance.importBytes(bytes, 'doc.pdf');
    expect(r.success, true);
    expect(r.book!.fileType, BookFileType.pdf);
    expect(r.book!.parseStatus, BookParseStatus.pending);
  });

  test('DOCX 导入保存且状态为 pending', () async {
    final bytes = utf8.encode('docx placeholder');
    final r = await FileImportService.instance.importBytes(bytes, 'report.docx');
    expect(r.success, true);
    expect(r.book!.fileType, BookFileType.docx);
    expect(r.book!.parseStatus, BookParseStatus.pending);
  });

  // —— 重复检测 ——
  test('重复文件检测', () async {
    final bytes = utf8.encode('重复测试内容');
    final r1 = await FileImportService.instance.importBytes(bytes, 'dup.txt');
    expect(r1.success, true);
    final r2 = await FileImportService.instance.importBytes(bytes, 'dup.txt');
    expect(r2.success, false);
    expect(r2.errorCode, FileImportErrorCode.duplicate);
    expect(r2.existingBookId, isNotNull);
    expect(r2.existingBookId, r1.book!.id);
  });

  test('forceImport 可绕过重复检测', () async {
    final bytes = utf8.encode('重复测试内容2');
    final r1 = await FileImportService.instance.importBytes(bytes, 'dup2.txt');
    final r2 = await FileImportService.instance.importBytes(bytes, 'dup2.txt',
        forceImport: true);
    expect(r2.success, true);
    expect(r2.book!.id, isNot(r1.book!.id));
  });

  // —— 持久化与恢复 ——
  test('book.json 保存与读取', () async {
    final bytes = utf8.encode('持久化测试');
    final r = await FileImportService.instance.importBytes(bytes, 'persist.txt');
    final id = r.book!.id;
    // 重新加载
    final books = await BookRepository.instance.loadAll();
    expect(books.length, 1);
    expect(books.first.id, id);
    expect(books.first.title, 'persist');
    expect(books.first.parseStatus, BookParseStatus.ready);
  });

  test('App 重启后恢复书库列表（重新 loadAll）', () async {
    final b1 = await FileImportService.instance
        .importBytes(utf8.encode('书一'), 'a.txt');
    final b2 = await FileImportService.instance
        .importBytes(utf8.encode('书二'), 'b.txt');
    expect(b1.success, true);
    expect(b2.success, true);
    // 模拟重启：新建 Repository 实例指向同一目录
    BookRepository.instance.setBooksDirForTest(booksRoot);
    final books = await BookRepository.instance.loadAll();
    expect(books.length, 2);
    final ids = books.map((b) => b.id).toList();
    expect(ids, contains(b1.book!.id));
    expect(ids, contains(b2.book!.id));
  });

  test('删除书籍同时清理记录与文件', () async {
    final r = await FileImportService.instance
        .importBytes(utf8.encode('待删除'), 'del.txt');
    final id = r.book!.id;
    final bookDir = Directory('${booksRoot.path}/$id');
    expect(await bookDir.exists(), true);
    await BookRepository.instance.delete(id);
    // 目录已删除
    expect(await bookDir.exists(), false);
    // 重新加载不再包含
    final books = await BookRepository.instance.loadAll();
    expect(books.any((b) => b.id == id), false);
  });

  test('损坏的 book.json 被跳过且崩溃', () async {
    final r = await FileImportService.instance
        .importBytes(utf8.encode('正常书'), 'ok.txt');
    // 手动写入一个损坏的 book.json
    final badDir = Directory('${booksRoot.path}/badid');
    await badDir.create(recursive: true);
    await File('${badDir.path}/book.json').writeAsString('{not valid json');
    final books = await BookRepository.instance.loadAll();
    expect(books.any((b) => b.id == 'badid'), false);
    expect(books.any((b) => b.id == r.book!.id), true);
  });
}
