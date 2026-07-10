import 'package:flutter/cupertino.dart';
import '../../theme/app_theme.dart';
import '../../shared/widgets/circular_icon_button.dart';
import 'widgets/empty_library_header.dart';
import 'widgets/import_option_card.dart';

class LibraryPage extends StatelessWidget {
  const LibraryPage({super.key});

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
}
