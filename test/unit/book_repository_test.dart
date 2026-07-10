import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_audiobook_platform/features/library/models/book.dart';
import 'package:ai_audiobook_platform/features/library/models/book_file_type.dart';
import 'package:ai_audiobook_platform/features/library/models/book_parse_status.dart';
import 'package:ai_audiobook_platform/features/library/services/book_repository.dart';

Book makeBook(String id, String title, Directory root) {
  final bookDir = '${root.path}/$id';
  return Book(
    id: id,
    title: title,
    originalFileName: '$title.txt',
    fileType: BookFileType.txt,
    originalPath: '$bookDir/original.txt',
    contentPath: '$bookDir/content.txt',
    fileSize: 100,
    characterCount: 10,
    encoding: 'utf-8',
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
    parseStatus: BookParseStatus.ready,
    chapterCount: 0,
  );
}

void main() {
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('repo_test_');
    BookRepository.instance.setBooksDirForTest(root);
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  test('save 后 loadAll 能找回书籍', () async {
    final b = makeBook('id1', '书一', root);
    await File(b.originalPath).create(recursive: true);
    await BookRepository.instance.save(b);
    final books = await BookRepository.instance.loadAll();
    expect(books.length, 1);
    expect(books.first.title, '书一');
  });

  test('index.json 被写入', () async {
    final b = makeBook('id2', '书二', root);
    await File(b.originalPath).create(recursive: true);
    await BookRepository.instance.save(b);
    final indexFile = File('${root.path}/index.json');
    expect(await indexFile.exists(), true);
    final content = await indexFile.readAsString();
    expect(content.contains('id2'), true);
  });

  test('按 id 获取书籍', () async {
    final b = makeBook('id3', '书三', root);
    await File(b.originalPath).create(recursive: true);
    await BookRepository.instance.save(b);
    final got = await BookRepository.instance.get('id3');
    expect(got!.title, '书三');
    final miss = await BookRepository.instance.get('nope');
    expect(miss, isNull);
  });

  test('delete 清理目录与 index', () async {
    final b = makeBook('id4', '书四', root);
    await File(b.originalPath).create(recursive: true);
    await BookRepository.instance.save(b);
    expect(await Directory('${root.path}/id4').exists(), true);
    await BookRepository.instance.delete('id4');
    expect(await Directory('${root.path}/id4').exists(), false);
    final books = await BookRepository.instance.loadAll();
    expect(books.isEmpty, true);
  });

  test('文件缺失的书籍在 loadAll 时被跳过', () async {
    // originalPath 指向一个不存在的文件，保存记录后 loadAll 应跳过它
    final b = makeBook('id5', '书五', root);
    final missing = Book(
      id: b.id,
      title: b.title,
      originalFileName: b.originalFileName,
      fileType: b.fileType,
      originalPath: '${root.path}/id5/does_not_exist.txt',
      contentPath: b.contentPath,
      fileSize: b.fileSize,
      characterCount: b.characterCount,
      encoding: b.encoding,
      createdAt: b.createdAt,
      updatedAt: b.updatedAt,
      parseStatus: b.parseStatus,
      chapterCount: b.chapterCount,
    );
    await BookRepository.instance.save(missing);
    final books = await BookRepository.instance.loadAll();
    expect(books.any((x) => x.id == 'id5'), false);
  });

  test('损坏 book.json 被跳过', () async {
    final dir = Directory('${root.path}/bad');
    await dir.create(recursive: true);
    await File('${dir.path}/book.json').writeAsString('broken');
    final good = makeBook('good', '好书', root);
    await File(good.originalPath).create(recursive: true);
    await BookRepository.instance.save(good);
    final books = await BookRepository.instance.loadAll();
    expect(books.length, 1);
    expect(books.first.id, 'good');
  });
}
