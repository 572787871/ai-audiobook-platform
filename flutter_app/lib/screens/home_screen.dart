import "package:flutter/material.dart";
import "package:provider/provider.dart";
import "../theme/app_theme.dart";
import "../widgets/common_widgets.dart";
import "../providers/auth_provider.dart";
import "../providers/book_provider.dart";
import "../providers/task_provider.dart";
import "../models/book.dart";
import "upload_screen.dart";

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  bool _isPicking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BookProvider>().loadBooks();
      context.read<TaskProvider>().loadTasks();
    });
  }

  Future<void> _goUpload() async {
    debugPrint("UPLOAD_BUTTON_TAPPED_FROM_REAL_HOME");
    if (_isPicking) return;
    setState(() => _isPicking = true);
    final result = await Navigator.push<bool>(
        context, MaterialPageRoute(builder: (_) => const UploadScreen()));
    if (mounted) setState(() => _isPicking = false);
    if (result == true) {
      context.read<BookProvider>().loadBooks();
      context.read<TaskProvider>().loadTasks();
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final books = context.watch<BookProvider>().books;
    final recent = books.take(6).toList();
    final processingTasks = context
        .watch<TaskProvider>()
        .tasks
        .where((t) => t.status == "processing" || t.status == "pending")
        .toList();
    final greeting = _greeting();
    final userName =
        auth.user?.username ?? auth.user?.email.split("@").first ?? "用户";

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // 顶部区域
          SliverToBoxAdapter(
            child: _buildHeader(context, greeting, userName, auth),
          ),
          // 搜索框
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: _buildSearchBar(context),
            ),
          ),
          // 快捷入口
          SliverToBoxAdapter(
            child: _buildQuickActions(context),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
          // 最近任务
          if (processingTasks.isNotEmpty) ...[
            _buildSectionHeader("生成中", "查看全部", () => _switchTab(2)),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 130,
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  scrollDirection: Axis.horizontal,
                  itemCount: processingTasks.length,
                  itemBuilder: (ctx, i) =>
                      _buildTaskCard(context, processingTasks[i], books),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
          // 推荐区域
          _buildSectionHeader("最近生成", "查看全部", () => _switchTab(1)),
          if (recent.isEmpty)
            SliverToBoxAdapter(
              child: EmptyState(
                icon: Icons.library_books_outlined,
                title: "还没有有声书",
                subtitle: "点击下方按钮上传小说，开始生成",
                actionLabel: "上传小说",
                onAction: _goUpload,
              ),
            )
          else
            SliverToBoxAdapter(
              child: SizedBox(
                height: 220,
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  scrollDirection: Axis.horizontal,
                  itemCount: recent.length,
                  itemBuilder: (ctx, i) => _BookCardWide(book: recent[i]),
                ),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
          // 上传按钮
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: GradientButton(
                label: _isPicking ? "正在上传..." : "上传小说生成有声书",
                icon: Icons.auto_awesome_rounded,
                onPressed: _isPicking ? () {} : _goUpload,
              ),
            ),
          ),
          // 版本号
          SliverToBoxAdapter(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 16, top: 8),
                child: Text("build: ui-v2-20260709",
                    style: TextStyle(
                        fontSize: 10,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.3))),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, String greeting, String userName,
      AuthProvider auth) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 16,
          left: 16,
          right: 16,
          bottom: 8),
      child: Row(
        children: [
          Row(
            children: [
              // 头像
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppTheme.primaryGradient,
                ),
                child: auth.user?.avatarUrl != null
                    ? ClipOval(
                        child: Image.network(auth.user!.avatarUrl!,
                            fit: BoxFit.cover))
                    : Center(
                        child: Text(
                          userName.isNotEmpty ? userName[0].toUpperCase() : "U",
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 20),
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(greeting,
                      style: TextStyle(
                          fontSize: 13,
                          color: cs.onSurface.withOpacity(0.5))),
                  Text(userName,
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3)),
                ],
              ),
            ],
          ),
          const Spacer(),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isDark ? AppTheme.cardDark : Colors.white,
              borderRadius: BorderRadius.circular(AppTheme.radiusFull),
              boxShadow:
                  AppTheme.cardShadow(cs.onSurface, opacity: 0.06, blur: 8),
            ),
            child: IconButton(
              icon: Icon(Icons.notifications_outlined,
                  color: cs.onSurface.withOpacity(0.6), size: 22),
              onPressed: () {
                ScaffoldMessenger.of(context)
                    .showSnackBar(const SnackBar(content: Text("暂无新通知")));
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () => _switchTab(1),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: isDark ? AppTheme.cardDark : Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.radiusFull),
          boxShadow: AppTheme.cardShadow(cs.onSurface, opacity: 0.04, blur: 10),
        ),
        child: Row(
          children: [
            const SizedBox(width: 16),
            Icon(Icons.search,
                color: cs.onSurface.withOpacity(0.3), size: 20),
            const SizedBox(width: 10),
            Text("搜索有声书...",
                style: TextStyle(
                    color: cs.onSurface.withOpacity(0.35), fontSize: 14)),
            const Spacer(),
            Icon(Icons.mic_outlined,
                color: cs.onSurface.withOpacity(0.2), size: 20),
            const SizedBox(width: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    final actions = [
      _QuickAction(
          icon: Icons.upload_file_rounded, label: "上传小说", onTap: _goUpload),
      _QuickAction(
          icon: Icons.library_books_rounded,
          label: "我的书库",
          onTap: () => _switchTab(1)),
      _QuickAction(
          icon: Icons.play_circle_outline_rounded,
          label: "最近播放",
          onTap: () => _switchTab(1)),
      _QuickAction(
          icon: Icons.graphic_eq_rounded,
          label: "AI 配音",
          onTap: () => _switchTab(3)),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: actions.map((a) => _buildQuickItem(context, a)).toList(),
      ),
    );
  }

  Widget _buildQuickItem(BuildContext context, _QuickAction a) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: a.onTap,
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: isDark ? AppTheme.cardDark : Colors.white,
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
              boxShadow:
                  AppTheme.cardShadow(cs.onSurface, opacity: 0.05, blur: 8),
              border: Border.all(
                  color: cs.primary.withOpacity(0.1), width: 0.5),
            ),
            child: Icon(a.icon, color: cs.primary, size: 26),
          ),
          const SizedBox(height: 8),
          Text(a.label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: cs.onSurface.withOpacity(0.7))),
        ],
      ),
    );
  }

  Widget _buildTaskCard(BuildContext context, dynamic task, List<Book> books) {
    final book = books.firstWhere(
      (b) => b.id == task.bookId,
      orElse: () => Book(
        id: 0,
        userId: 0,
        title: "未知书籍",
        author: "",
        status: task.status,
        createdAt: "",
        updatedAt: "",
      ),
    );
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: 260,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        boxShadow: AppTheme.cardShadow(cs.onSurface, opacity: 0.05, blur: 12),
      ),
      child: Row(
        children: [
          BookCover(
              title: book.title,
              coverUrl: book.coverUrl,
              width: 70,
              height: 100,
              radius: AppTheme.radiusSm),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(0, 12, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(book.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(height: 4),
                  Text(book.author ?? "未知",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurface.withOpacity(0.4))),
                  const Spacer(),
                  StatusTag(status: task.status),
                  if (task.status == "processing") ...[
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                      child: LinearProgressIndicator(
                        value: task.progress / 100,
                        minHeight: 4,
                        backgroundColor: cs.primary.withOpacity(0.1),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(
      String title, String action, VoidCallback onAction) {
    final cs = Theme.of(context).colorScheme;
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title,
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface)),
            GestureDetector(
              onTap: onAction,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(action,
                      style: TextStyle(
                          fontSize: 13,
                          color: cs.primary,
                          fontWeight: FontWeight.w500)),
                  Icon(Icons.chevron_right, size: 16, color: cs.primary),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _switchTab(int index) {
    tabSwitchNotifier.value = index;
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 6) return "凌晨好";
    if (h < 12) return "早上好";
    if (h < 14) return "中午好";
    if (h < 18) return "下午好";
    return "晚上好";
  }
}

class _QuickAction {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  _QuickAction({required this.icon, required this.label, required this.onTap});
}

/// 横向封面卡片
class _BookCardWide extends StatelessWidget {
  final Book book;
  const _BookCardWide({required this.book});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, "/book", arguments: book.id),
      child: Container(
        width: 140,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Hero(
              tag: "book_cover_${book.id}",
              child: BookCover(
                  title: book.title,
                  coverUrl: book.coverUrl,
                  width: 140,
                  height: 180,
                  radius: AppTheme.radiusMd),
            ),
            const SizedBox(height: 10),
            Text(book.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: cs.onSurface)),
            const SizedBox(height: 4),
            Row(
              children: [
                if (book.status == "completed")
                  Icon(Icons.play_circle_filled,
                      size: 12, color: AppTheme.success)
                else
                  Icon(AppTheme.statusIcon(book.status),
                      size: 12, color: AppTheme.statusColor(book.status)),
                const SizedBox(width: 4),
                Text(AppTheme.statusLabel(book.status),
                    style: TextStyle(
                        fontSize: 11,
                        color: cs.onSurface.withOpacity(0.4))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
