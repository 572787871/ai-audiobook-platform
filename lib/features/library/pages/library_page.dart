import 'package:flutter/cupertino.dart';
import 'dart:async' show Completer;
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import '../../../theme/app_theme.dart';
import '../../../shared/widgets/circular_icon_button.dart';
import '../models/book.dart';
import '../services/book_repository.dart';
import '../widgets/empty_library_header.dart';
import '../widgets/import_option_card.dart';
import '../../import/file_import_service.dart';
import '../../import/file_import_result.dart';
import '../../import/import_progress.dart';
import 'book_shelf_page.dart';

/// 书库首页
class LibraryPage extends StatefulWidget {
  final BookRepositoryBase? repository;

  const LibraryPage({super.key, this.repository});

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  final List<Book> _books = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadBooks();
  }

  Future<void> _loadBooks() async {
    final books = await (widget.repository ?? BookRepository.instance)
        .loadAll();
    // 最近添加在前
    books.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (mounted) {
      setState(() {
        _books
          ..clear()
          ..addAll(books);
        _loading = false;
      });
    }
  }

  Future<void> _pickAndImport() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['txt', 'epub', 'pdf', 'docx'],
    );
    if (result == null || result.files.isEmpty) return;
    final path = result.files.single.path;
    if (path == null) return;

    await _showImportFlow(path);
  }

  Future<void> _showImportFlow(String sourcePath) async {
    final progressKey = GlobalKey<_ImportProgressModalState>();
    showCupertinoModalPopup<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ImportProgressModal(key: progressKey),
    );

    final importResult = await FileImportService.instance.importFile(
      File(sourcePath),
      onProgress: (p) {
        progressKey.currentState?._update(p);
      },
    );

    if (!mounted) return;
    Navigator.of(context).pop(); // 关闭进度弹窗

    if (importResult.isDuplicate && importResult.existingBookId != null) {
      final proceed = await _askDuplicate();
      if (proceed) {
        final force = await FileImportService.instance.importFile(
          File(sourcePath),
          forceImport: true,
        );
        _handleResult(force);
      }
      return;
    }

    _handleResult(importResult);
  }

  void _handleResult(FileImportResult result) {
    if (result.success && result.book != null) {
      // 导入成功：刷新首页数据并停留在书库首页（不进入详情、不 push 新页面）
      _loadBooks();
      _returnToLibrary();
    } else if (result.errorMessage != null) {
      _showError(result.errorMessage!);
    }
  }

  /// 确保当前停留在书库首页：关闭任何残留的导入/详情页面，回到根。
  void _returnToLibrary() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  Future<bool> _askDuplicate() async {
    final completer = Completer<bool>();
    showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('重复提示'),
        content: const Text('这本书似乎已经导入过了'),
        actions: [
          CupertinoDialogAction(
            child: const Text('取消'),
            onPressed: () {
              Navigator.of(ctx).pop();
              completer.complete(false);
            },
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            child: const Text('仍然导入'),
            onPressed: () {
              Navigator.of(ctx).pop();
              completer.complete(true);
            },
          ),
        ],
      ),
    );
    return completer.future;
  }

  void _showError(String message) {
    showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('导入失败'),
        content: Text(message),
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

  Future<void> _openShelf() async {
    await Navigator.of(context).push<bool>(
      CupertinoPageRoute(
        builder: (_) => BookShelfPage(repository: widget.repository),
      ),
    );
    // 无论返回结果如何，重新加载以同步“已导入 N 本书”数量
    if (mounted) await _loadBooks();
  }

  void _showUnsupported() {
    _toast('该功能将在后续版本加入');
  }

  void _toast(String message) {
    showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('提示'),
        content: Text(message),
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

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppTheme.background,
      child: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(child: _buildContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return const Padding(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Row(
        children: [
          Text(
            '书库',
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryText,
            ),
          ),
          Spacer(),
          CircularIconButton(icon: CupertinoIcons.search),
          SizedBox(width: 12),
          CircularIconButton(icon: CupertinoIcons.person),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_loading) {
      return const Center(child: CupertinoActivityIndicator());
    }
    return ListView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.horizontalPadding,
      ),
      children: [
        const SizedBox(height: 8),
        // 导入入口区：首页本身就是导入入口
        const EmptyLibraryHeader(),
        ImportOptionCard(
          icon: CupertinoIcons.doc,
          title: '本地文件',
          subtitle: 'TXT、EPUB、PDF',
          onTap: _pickAndImport,
        ),
        ImportOptionCard(
          icon: CupertinoIcons.doc_on_doc,
          title: '粘贴文本',
          subtitle: '输入或粘贴小说内容',
          onTap: _showUnsupported,
        ),
        ImportOptionCard(
          icon: CupertinoIcons.camera,
          title: '扫描文字',
          subtitle: '从图片或文档中识别',
          onTap: _showUnsupported,
        ),
        ImportOptionCard(
          icon: CupertinoIcons.share,
          title: '从其他 App 导入',
          subtitle: '通过系统分享菜单添加',
          onTap: _showUnsupported,
        ),
        const SizedBox(height: 24),
        // 书库入口卡片（不在此直接展示书籍列表）
        _buildShelfEntry(),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildShelfEntry() {
    final count = _books.length;
    final subtitle = count == 0
        ? '暂无已导入书籍'
        : count == 1
        ? '已导入 1 本书'
        : '已导入 $count 本书';
    return GestureDetector(
      key: const Key('shelf_entry'),
      onTap: _openShelf,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: AppTheme.cardDecoration,
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppTheme.iconBackground,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Center(
                child: Icon(
                  CupertinoIcons.square_stack_3d_up,
                  size: 24,
                  color: AppTheme.primaryText,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '书库',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryText,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.secondaryText,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              CupertinoIcons.chevron_right,
              size: 16,
              color: AppTheme.secondaryText,
            ),
          ],
        ),
      ),
    );
  }
}

/// 导入进度弹窗
class _ImportProgressModal extends StatefulWidget {
  const _ImportProgressModal({super.key});

  @override
  State<_ImportProgressModal> createState() => _ImportProgressModalState();
}

class _ImportProgressModalState extends State<_ImportProgressModal> {
  String _message = ImportProgressState.picking.label;

  void _update(ImportProgress p) {
    if (mounted) setState(() => _message = p.state.label);
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoAlertDialog(
      content: Column(
        children: [
          const CupertinoActivityIndicator(),
          const SizedBox(height: 12),
          Text(_message),
        ],
      ),
    );
  }
}
