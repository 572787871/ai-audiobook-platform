import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors;
import 'package:file_picker/file_picker.dart';
import '../../../theme/app_theme.dart';
import '../models/book.dart';
import '../models/book_file_type.dart';
import '../services/book_repository.dart';
import '../services/book_cover_service.dart';
import 'book_detail_page.dart';
import '../../reader/pages/reader_page.dart';
import '../../import/file_import_service.dart';

/// 书架主页 —— App 启动后直接显示。
/// 顶部：标题"书架"、加号导入、用户设置。
/// 分类：全部/阅读中/已完成（文字Tab + 细下划线 + 真实数量）。
/// 三列书籍网格，按最近阅读排序，点击直接进阅读器。
class BookShelfPage extends StatefulWidget {
  final BookRepositoryBase? repository;
  final Future<String> Function(Book book)? contentLoader;

  const BookShelfPage({super.key, this.repository, this.contentLoader});

  @override
  State<BookShelfPage> createState() => _BookShelfPageState();
}

class _BookShelfPageState extends State<BookShelfPage> {
  final List<Book> _books = [];
  bool _loading = true;
  bool _importing = false;

  BookRepositoryBase get _repo => widget.repository ?? BookRepository.instance;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    final books = await _repo.loadAll();
    books.sort((a, b) {
      final aTime = a.lastReadAt ?? a.createdAt;
      final bTime = b.lastReadAt ?? b.createdAt;
      return bTime.compareTo(aTime);
    });
    if (!mounted) return;
    setState(() {
      _books
        ..clear()
        ..addAll(books);
      _loading = false;
    });
  }


  // ---- 导入 ----

  void _showImportSheet() {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('导入书籍'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(ctx).pop();
              _pickFile();
            },
            child: const Text('从文件导入'),
          ),
          CupertinoActionSheetAction(
            child: const Text('粘贴文本'),
            onPressed: () {
              Navigator.of(ctx).pop();
              _showPasteDialog();
            },
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('取消'),
        ),
      ),
    );
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['txt'],
    );
    if (result == null || result.files.isEmpty) return;
    final path = result.files.single.path;
    if (path == null) return;
    await _importFile(File(path));
  }


  Future<void> _showPasteDialog() async {
    final controller = TextEditingController();
    final text = await showCupertinoDialog<String?>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('粘贴文本'),
        content: CupertinoTextField(
          controller: controller,
          maxLines: 10,
          minLines: 5,
          placeholder: '在此粘贴小说内容…',
          keyboardType: TextInputType.multiline,
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('取消'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            child: const Text('导入'),
            onPressed: () => Navigator.of(ctx).pop(controller.text),
          ),
        ],
      ),
    );
    if (text == null || text.trim().isEmpty) return;
    await _importPasteText(text.trim());
  }

  Future<void> _importPasteText(String text) async {
    if (_importing) return;
    setState(() => _importing = true);
    try {
      final dir = Directory.systemTemp;
      final tmpDir = Directory('${dir.path}/paste_import_${DateTime.now().microsecondsSinceEpoch}');
      await tmpDir.create(recursive: true);
      final tmpFile = File('${tmpDir.path}/pasted.txt');
      await tmpFile.writeAsString(text, flush: true);
      await _importFile(tmpFile);
      if (await tmpDir.exists()) await tmpDir.delete(recursive: true);
    } catch (e) {
      if (mounted) _showError('导入失败：$e');
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<void> _importFile(File sourceFile) async {
    if (_importing) return;
    setState(() => _importing = true);

    try {
      final importResult = await FileImportService.instance.importFile(
        sourceFile,
        onProgress: (_) {},
      );

      if (!mounted) return;

      if (importResult.success && importResult.book != null) {
        _load();
      } else if (importResult.isDuplicate &&
          importResult.existingBookId != null) {
        final proceed = await _askDuplicate();
        if (proceed && mounted) {
          final retry = await FileImportService.instance.importFile(
            sourceFile,
            forceImport: true,
          );
          if (retry.success && retry.book != null && mounted) {
            _load();
          } else if (retry.errorMessage != null && mounted) {
            _showError(retry.errorMessage!);
          }
        }
      } else if (importResult.errorMessage != null) {
        _showError(importResult.errorMessage!);
      }
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<bool> _askDuplicate() async {
    final result = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('重复提示'),
        content: const Text('这本书似乎已经导入过了'),
        actions: [
          CupertinoDialogAction(
            child: const Text('取消'),
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            child: const Text('仍然导入'),
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _showError(String msg) {
    showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('导入失败'),
        content: Text(msg),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            child: const Text('好的'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
        ],
      ),
    );
  }

  void _toast(String msg) {
    showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('提示'),
        content: Text(msg),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            child: const Text('好的'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
        ],
      ),
    );
  }

  // ---- 阅读器 ----

  Future<void> _openReader(Book book) async {
    if (book.fileType != BookFileType.txt) {
      _toast('该书暂未解析，无法阅读');
      return;
    }
    final updated = await Navigator.of(context).push<Book?>(
      CupertinoPageRoute(
        builder: (_) => ReaderPage(
          book: book,
          repository: _repo,
          contentLoader: widget.contentLoader,
        ),
      ),
    );
    if (!mounted) return;
    if (updated != null) {
      _replaceBook(updated);
    }
  }

  void _replaceBook(Book updated) {
    final idx = _books.indexWhere((b) => b.id == updated.id);
    if (idx >= 0) {
      setState(() => _books[idx] = updated);
    }
  }

  // ---- 长按菜单 ----

  void _showMenu(Book book) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text(book.title),
        actions: [
          if (book.readingProgress > 0)
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.of(ctx).pop();
                _openReader(book);
              },
              child: const Text('继续阅读'),
            ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(ctx).pop();
              _openReaderFromStart(book);
            },
            child: const Text('从头阅读'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(ctx).pop();
              _openDetail(book);
            },
            child: const Text('书籍详情'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(ctx).pop();
              _rename(book);
            },
            child: const Text('重命名'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(ctx).pop();
              _toast('更换封面将在后续版本加入');
            },
            child: const Text('更换封面'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(ctx).pop();
              _markDone(book);
            },
            child: const Text('标记为已完成'),
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.of(ctx).pop();
              _delete(book);
            },
            child: const Text('删除书籍'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('取消'),
        ),
      ),
    );
  }

  Future<void> _openReaderFromStart(Book book) async {
    final reset = book.copyWith(
      lastReadOffset: 0,
      chapterIndex: 0,
      pageIndex: 0,
      readingProgress: 0.0,
    );
    final updated = await Navigator.of(context).push<Book?>(
      CupertinoPageRoute(
        builder: (_) => ReaderPage(
          book: reset,
          repository: _repo,
          contentLoader: widget.contentLoader,
        ),
      ),
    );
    if (!mounted) return;
    if (updated != null) _replaceBook(updated);
  }

  Future<void> _openDetail(Book book) async {
    await Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) => BookDetailPage(
          book: book,
          repository: _repo,
          contentLoader: widget.contentLoader,
        ),
      ),
    );
    await _load();
  }

  Future<void> _rename(Book book) async {
    final controller = TextEditingController(text: book.title);
    final result = await showCupertinoDialog<String?>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('重命名'),
        content: CupertinoTextField(controller: controller),
        actions: [
          CupertinoDialogAction(
            child: const Text('取消'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            child: const Text('确定'),
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
          ),
        ],
      ),
    );
    if (result != null && result.isNotEmpty && result != book.title) {
      await _repo.save(book.copyWith(title: result, updatedAt: DateTime.now()));
      _load();
    }
  }

  Future<void> _markDone(Book book) async {
    final updated = book
        .copyWith(readingProgress: 1.0)
        .withReadingToday(DateTime.now());
    await _repo.save(updated);
    _replaceBook(updated);
  }

  Future<void> _delete(Book book) async {
    final confirm = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text('删除《${book.title}》？'),
        content: const Text('删除后本地文件、阅读进度和缓存将一并清除，不可恢复。'),
        actions: [
          CupertinoDialogAction(
            child: const Text('取消'),
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('删除'),
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _repo.delete(book.id);
      if (!mounted) return;
      setState(() => _books.removeWhere((b) => b.id == book.id));
    }
  }

  // ---- 设置页 ----

  void _openSettings() {
    _toast('用户设置将在后续版本实现');
  }

  // ---- 构建 ----

  @override
  Widget build(BuildContext context) {
    final safeTop = MediaQuery.of(context).padding.top;
    return CupertinoPageScaffold(
      backgroundColor: AppTheme.background,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildHeader(safeTop),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(double safeTop) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, safeTop > 0 ? 8 : 12, 12, 4),
      child: Row(
        children: [
          const Text(
            '书架',
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryText,
            ),
          ),
          const Spacer(),
          if (_importing)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CupertinoActivityIndicator(),
              ),
            )
          else
            CupertinoButton(
              padding: const EdgeInsets.all(8),
              onPressed: _showImportSheet,
              child: const Icon(
                CupertinoIcons.add,
                size: 24,
                color: AppTheme.primaryText,
              ),
            ),
          const SizedBox(width: 4),
          CupertinoButton(
            padding: const EdgeInsets.all(8),
            onPressed: _openSettings,
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppTheme.iconBackground,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                CupertinoIcons.person_fill,
                size: 18,
                color: AppTheme.secondaryText,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CupertinoActivityIndicator());
    }
    final items = _books;
    if (items.isEmpty) {
      return _buildEmpty();
    }
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 20,
        crossAxisSpacing: 12,
        childAspectRatio: 0.52,
      ),
      itemCount: items.length,
      itemBuilder: (ctx, i) => _bookTile(items[i]),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 60),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 80),
            Icon(
              CupertinoIcons.book,
              size: 64,
              color: AppTheme.secondaryText.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 16),
            const Text(
              '暂无书籍',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppTheme.primaryText,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '点击右上角"＋"导入第一本小说',
              style: TextStyle(
                fontSize: 15,
                color: AppTheme.secondaryText.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: 24),
            CupertinoButton.filled(
              onPressed: _showImportSheet,
              child: const Text('导入书籍'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bookTile(Book book) {
    final pct = (book.readingProgress * 100).round();
    final statusLabel = book.readingProgress <= 0
        ? '未开始'
        : pct >= 100
        ? '已完成'
        : '已读 $pct%';
    final colors = BookCoverService.colorsFor(book);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _openReader(book),
      onLongPress: () => _showMenu(book),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 封面
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: AspectRatio(
              aspectRatio: 2 / 3,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: colors,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    // 纹理装饰
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _CoverTexturePainter(colors.last),
                      ),
                    ),
                    // 书名
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          book.title,
                          textAlign: TextAlign.center,
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ),
                    // 书脊效果
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      child: Container(
                        width: 4,
                        decoration: BoxDecoration(
                          color: colors.last.withValues(alpha: 0.3),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(10),
                            bottomLeft: Radius.circular(10),
                          ),
                        ),
                      ),
                    ),
                    // 阅读进度条
                    if (book.readingProgress > 0)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: Column(
                          children: [
                            Container(
                              height: 2,
                              color: Colors.white.withValues(alpha: 0.25),
                            ),
                            Container(
                              height: 2,
                              color: CupertinoColors.activeBlue,
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // 书名
          Text(
            book.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.primaryText,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 2),
          // 当前章节
          if (book.lastReadChapter != null && book.lastReadChapter!.isNotEmpty)
            Text(
              book.lastReadChapter!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                color: AppTheme.secondaryText,
              ),
            ),
          const SizedBox(height: 2),
          // 进度
          Text(
            statusLabel,
            style: TextStyle(
              fontSize: 12,
              color: book.readingProgress >= 1
                  ? CupertinoColors.activeBlue
                  : AppTheme.secondaryText,
            ),
          ),
        ],
      ),
    );
  }
}

/// 封面纹理装饰：几何渐变纹理
class _CoverTexturePainter extends CustomPainter {
  final Color baseColor;
  _CoverTexturePainter(this.baseColor);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x0FFFFFFF)
      ..strokeWidth = 1;
    for (var x = 0.0; x < size.width; x += 20) {
      for (var y = 0.0; y < size.height; y += 20) {
        if ((x + y) % 40 < 20) {
          canvas.drawCircle(Offset(x + 2, y + 2), 1.5, paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
