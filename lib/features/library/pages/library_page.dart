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
import '../widgets/book_card.dart';
import '../widgets/import_action_sheet.dart';
import '../../import/file_import_service.dart';
import '../../import/file_import_result.dart';
import '../../import/import_progress.dart';
import 'book_detail_page.dart';

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
    final books = await (widget.repository ?? BookRepository.instance).loadAll();
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
      _loadBooks();
      _openDetail(result.book!);
    } else if (result.errorMessage != null) {
      _showError(result.errorMessage!);
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

  void _openDetail(Book book) {
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) => BookDetailPage(book: book),
      ),
    );
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
        child: Stack(
          children: [
            Column(
              children: [
                _buildHeader(),
                Expanded(child: _buildContent()),
              ],
            ),
            _buildFab(),
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
    if (_books.isEmpty) {
      return ListView(
        padding: const EdgeInsets.symmetric(horizontal: AppTheme.horizontalPadding),
        children: const [
          EmptyLibraryHeader(),
          ImportOptionCard(
            icon: CupertinoIcons.doc,
            title: '本地文件',
            subtitle: 'TXT、EPUB、PDF 等格式',
          ),
          ImportOptionCard(
            icon: CupertinoIcons.doc_on_doc,
            title: '粘贴文本',
            subtitle: '输入或粘贴小说内容',
          ),
          ImportOptionCard(
            icon: CupertinoIcons.camera,
            title: '扫描文字',
            subtitle: '从图片或文档中识别',
          ),
          ImportOptionCard(
            icon: CupertinoIcons.share,
            title: '从其他 App 导入',
            subtitle: '通过系统分享菜单添加',
          ),
          SizedBox(height: 32),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.horizontalPadding),
      children: [
        const SizedBox(height: 8),
        const Text(
          '最近添加',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: AppTheme.primaryText,
          ),
        ),
        const SizedBox(height: 12),
        ..._books.map(
          (b) => BookCard(
            book: b,
            onTap: () => _openDetail(b),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildFab() {
    return Positioned(
        right: 20,
        bottom: 20,
        child: CupertinoButton(
        key: const Key('import_fab'),
        color: CupertinoColors.activeBlue,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          onPressed: () {
            ImportActionSheet.show(
              context: context,
              onLocalFile: _pickAndImport,
              onUnsupported: _showUnsupported,
            );
          },
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(CupertinoIcons.add, size: 18, color: CupertinoColors.white),
              SizedBox(width: 4),
              Text('导入小说'),
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
