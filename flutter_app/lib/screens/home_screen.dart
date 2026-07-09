/// 首页 - 正式听书 App 风格，含底部 Tab 导航
import "package:flutter/material.dart";
import "package:provider/provider.dart";
import "package:cached_network_image/cached_network_image.dart";
import "../providers/auth_provider.dart";
import "../providers/book_provider.dart";
import "../providers/task_provider.dart";
import "../models/book.dart";
import "../models/task.dart";
import "../theme/app_theme.dart";

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  final _searchCtrl = TextEditingController();
  bool _gridView = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BookProvider>().loadBooks();
      context.read<TaskProvider>().loadTasks();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _HomeTab(searchCtrl: _searchCtrl),
          _BookshelfTab(gridView: _gridView, onToggleView: () => setState(() => _gridView = !_gridView)),
          _TasksTab(),
          _MembershipTab(),
          _ProfileTab(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) {
          setState(() => _currentIndex = i);
          if (i == 0) context.read<BookProvider>().loadBooks();
          if (i == 1) context.read<BookProvider>().loadBooks();
          if (i == 2) context.read<TaskProvider>().loadTasks();
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: "首页"),
          NavigationDestination(icon: Icon(Icons.library_books_outlined), selectedIcon: Icon(Icons.library_books), label: "书架"),
          NavigationDestination(icon: Icon(Icons.assignment_outlined), selectedIcon: Icon(Icons.assignment), label: "任务"),
          NavigationDestination(icon: Icon(Icons.workspace_premium_outlined), selectedIcon: Icon(Icons.workspace_premium), label: "会员"),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: "我的"),
        ],
      ),
    );
  }
}

// ===================== 首页 Tab =====================
class _HomeTab extends StatelessWidget {
  final TextEditingController searchCtrl;
  const _HomeTab({required this.searchCtrl});

  @override
  Widget build(BuildContext context) {
    final bp = context.watch<BookProvider>();
    final books = bp.books;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text("AI有声书", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: isDark ? Colors.white : AppTheme.textPrimary)),
        actions: [
          IconButton(icon: const Icon(Icons.notifications_outlined), onPressed: () {}),
          IconButton(icon: const Icon(Icons.settings_outlined), onPressed: () => Navigator.pushNamed(context, "/settings")),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => context.read<BookProvider>().loadBooks(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          children: [
            // 搜索框
            Container(
              decoration: BoxDecoration(
                color: isDark ? AppTheme.surfaceCard : Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: TextField(
                controller: searchCtrl,
                decoration: InputDecoration(
                  hintText: "搜索有声书...",
                  prefixIcon: const Icon(Icons.search, color: Colors.grey),
                  suffixIcon: searchCtrl.text.isNotEmpty
                      ? IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: () { searchCtrl.clear(); })
                      : null,
                  border: InputBorder.none,
                  filled: false,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onSubmitted: (v) {},
              ),
            ),
            const SizedBox(height: 24),

            // 上传入口
            _GradientCard(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      width: 60, height: 60,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.mic, color: Colors.white, size: 30),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("上传小说生成有声书", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text("支持 EPUB/PDF/TXT/MD 格式", style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 18),
                      onPressed: () => Navigator.pushNamed(context, "/upload"),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28),

            // 最近生成
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("最近生成", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : AppTheme.textPrimary)),
                TextButton(onPressed: () {}, child: const Text("查看全部")),
              ],
            ),
            const SizedBox(height: 12),
            bp.isLoading && books.isEmpty
                ? const SizedBox(height: 100, child: Center(child: CircularProgressIndicator()))
                : books.isEmpty
                    ? Container(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          children: [
                            Icon(Icons.library_music_outlined, size: 48, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            Text("还没有有声书", style: TextStyle(color: Colors.grey.shade500)),
                            const SizedBox(height: 8),
                            TextButton(onPressed: () => Navigator.pushNamed(context, "/upload"), child: const Text("上传第一部小说")),
                          ],
                        ),
                      )
                    : SizedBox(
                        height: 200,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: books.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 12),
                          itemBuilder: (ctx, i) => _BookCard(book: books[i]),
                        ),
                      ),
            const SizedBox(height: 28),

            // 我的书架快捷入口
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("我的书架", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : AppTheme.textPrimary)),
                TextButton(onPressed: () {}, child: const Text("管理")),
              ],
            ),
            const SizedBox(height: 8),
            ...books.take(3).map((b) => _BookListItem(book: b)),

            if (books.length > 3) ...[
              const SizedBox(height: 8),
              Center(child: TextButton(onPressed: () {}, child: const Text("查看更多..."))),
            ],

            const SizedBox(height: 28),
            // 推荐
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("推荐", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : AppTheme.textPrimary)),
              ],
            ),
            const SizedBox(height: 12),
            _RecommendCard(),
            const SizedBox(height: 16),
            _RecommendCard(),

            const SizedBox(height: 28),
            // Pro 会员入口
            _GradientCard(
              colors: [AppTheme.primaryDark, AppTheme.primary],
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("升级 Pro 会员", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text("无限上传 · 优先合成 · 无损下载", style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13)),
                        ],
                      ),
                    ),
                    FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: AppTheme.primary),
                      onPressed: () => Navigator.pushNamed(context, "/membership"),
                      child: const Text("升级"),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

class _GradientCard extends StatelessWidget {
  final Widget child;
  final List<Color>? colors;
  const _GradientCard({required this.child, this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors ?? [AppTheme.gradientStart, AppTheme.gradientEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: AppTheme.primary.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 6)),
        ],
      ),
      child: child,
    );
  }
}

class _BookCard extends StatelessWidget {
  final Book book;
  const _BookCard({required this.book});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, "/book", arguments: book.id),
      child: Container(
        width: 130,
        decoration: BoxDecoration(
          color: isDark ? AppTheme.surfaceCard : Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              child: Container(
                height: 160,
                color: AppTheme.primary.withOpacity(0.15),
                child: Center(
                  child: Icon(Icons.book, size: 48, color: AppTheme.primary.withOpacity(0.4)),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(book.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? Colors.white : AppTheme.textPrimary)),
                  const SizedBox(height: 2),
                  Text(book.status == "completed" ? "已生成" : "处理中...",
                    style: TextStyle(fontSize: 11, color: book.status == "completed" ? Colors.green : Colors.orange)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BookListItem extends StatelessWidget {
  final Book book;
  const _BookListItem({required this.book});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: Container(
          width: 48, height: 48,
          decoration: BoxDecoration(
            color: AppTheme.primary.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.book, color: AppTheme.primary, size: 24),
        ),
        title: Text(book.title, style: TextStyle(fontWeight: FontWeight.w600, color: isDark ? Colors.white : AppTheme.textPrimary)),
        subtitle: Text(book.status == "completed" ? "已生成 - 点击播放" : book.status, style: const TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.play_circle_fill, color: AppTheme.primary),
        onTap: () => Navigator.pushNamed(context, "/book", arguments: book.id),
      ),
    );
  }
}

class _RecommendCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.auto_stories, color: AppTheme.primary, size: 36),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("快速体验", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isDark ? Colors.white : AppTheme.textPrimary)),
                  const SizedBox(height: 4),
                  Text("上传文本文件，AI 自动生成有声书", style: TextStyle(fontSize: 13, color: isDark ? Colors.grey.shade400 : AppTheme.textSecondary)),
                  const SizedBox(height: 8),
                  FilledButton.tonal(
                    onPressed: () => Navigator.pushNamed(context, "/upload"),
                    child: const Text("立即体验"),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ===================== 书架 Tab =====================
class _BookshelfTab extends StatefulWidget {
  final bool gridView;
  final VoidCallback onToggleView;
  const _BookshelfTab({required this.gridView, required this.onToggleView});

  @override
  State<_BookshelfTab> createState() => _BookshelfTabState();
}

class _BookshelfTabState extends State<_BookshelfTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BookProvider>().loadBooks();
    });
  }

  @override
  Widget build(BuildContext context) {
    final bp = context.watch<BookProvider>();
    final books = bp.books;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text("我的书架", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: isDark ? Colors.white : AppTheme.textPrimary)),
        actions: [
          IconButton(icon: Icon(widget.gridView ? Icons.list : Icons.grid_view), onPressed: widget.onToggleView),
          IconButton(icon: const Icon(Icons.upload), onPressed: () => Navigator.pushNamed(context, "/upload")),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => context.read<BookProvider>().loadBooks(),
        child: bp.isLoading && books.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : books.isEmpty
                ? Center(
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.library_books_outlined, size: 80, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text("书架空空如也", style: TextStyle(fontSize: 18, color: Colors.grey.shade500)),
                      const SizedBox(height: 16),
                      FilledButton(onPressed: () => Navigator.pushNamed(context, "/upload"), child: const Text("上传第一部有声书")),
                    ]),
                  )
                : widget.gridView ? _buildGrid(books, isDark) : _buildList(books, isDark),
      ),
    );
  }

  Widget _buildGrid(List<Book> books, bool isDark) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.62,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: books.length,
      itemBuilder: (ctx, i) => _BookGridItem(book: books[i]),
    );
  }

  Widget _buildList(List<Book> books, bool isDark) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: books.length,
      itemBuilder: (ctx, i) => Card(
        margin: const EdgeInsets.only(bottom: 10),
        child: ListTile(
          contentPadding: const EdgeInsets.all(12),
          leading: Container(
            width: 56, height: 72,
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.book, color: AppTheme.primary, size: 28),
          ),
          title: Text(books[i].title, style: TextStyle(fontWeight: FontWeight.w600, color: isDark ? Colors.white : AppTheme.textPrimary)),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text(books[i].status == "completed" ? "已生成" : books[i].status, style: TextStyle(fontSize: 12, color: books[i].status == "completed" ? Colors.green : Colors.orange)),
              if (books[i].audioDuration != null) Text("时长: ${books[i].audioDuration!.toStringAsFixed(0)}秒", style: const TextStyle(fontSize: 11, color: Colors.grey)),
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (books[i].status == "completed") ...[
                IconButton(icon: const Icon(Icons.play_circle_fill, color: AppTheme.primary), onPressed: () => Navigator.pushNamed(context, "/player", arguments: books[i].id)),
                PopupMenuButton(itemBuilder: (_) => [
                  const PopupMenuItem(value: "detail", child: Text("详情")),
                  const PopupMenuItem(value: "delete", child: Text("删除", style: TextStyle(color: Colors.red))),
                ], onSelected: (v) {
                  if (v == "detail") Navigator.pushNamed(context, "/book", arguments: books[i].id);
                }),
              ],
            ],
          ),
          onTap: () => Navigator.pushNamed(context, "/book", arguments: books[i].id),
        ),
      ),
    );
  }
}

class _BookGridItem extends StatelessWidget {
  final Book book;
  const _BookGridItem({required this.book});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, "/book", arguments: book.id),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppTheme.surfaceCard : Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                child: Container(
                  width: double.infinity,
                  color: AppTheme.primary.withOpacity(0.12),
                  child: Center(child: Icon(Icons.book, size: 48, color: AppTheme.primary.withOpacity(0.3))),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(book.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: isDark ? Colors.white : AppTheme.textPrimary)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: book.status == "completed" ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(book.status == "completed" ? "已完成" : book.status, style: TextStyle(fontSize: 10, color: book.status == "completed" ? Colors.green : Colors.orange)),
                      ),
                      if (book.status == "completed") ...[
                        const Spacer(),
                        Icon(Icons.play_circle_fill, color: AppTheme.primary, size: 22),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ===================== 任务 Tab =====================
class _TasksTab extends StatefulWidget {
  @override
  State<_TasksTab> createState() => _TasksTabState();
}

class _TasksTabState extends State<_TasksTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TaskProvider>().loadTasks();
      context.read<TaskProvider>().startPolling();
    });
  }

  @override
  void dispose() {
    context.read<TaskProvider>().stopPolling();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tp = context.watch<TaskProvider>();
    final tasks = tp.tasks;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text("生成任务", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: isDark ? Colors.white : AppTheme.textPrimary)),
      ),
      body: tp.isLoading && tasks.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : tasks.isEmpty
              ? Center(
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.inbox_outlined, size: 80, color: Colors.grey.shade400),
                    const SizedBox(height: 16),
                    Text("暂无任务", style: TextStyle(fontSize: 18, color: Colors.grey.shade500)),
                    const SizedBox(height: 16),
                    FilledButton(onPressed: () => Navigator.pushNamed(context, "/upload"), child: const Text("开始生成")),
                  ]),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: tasks.length,
                  itemBuilder: (ctx, i) => _TaskCard(task: tasks[i]),
                ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  final Task task;
  const _TaskCard({required this.task});

  String _statusLabel(String s) {
    return {"pending": "等待中", "processing": "合成中", "completed": "已完成", "failed": "失败"}[s] ?? s;
  }

  Color _statusColor(String s) {
    return {"pending": Colors.orange, "processing": AppTheme.primary, "completed": Colors.green, "failed": Colors.red}[s] ?? Colors.grey;
  }

  IconData _statusIcon(String s) {
    return {"pending": Icons.hourglass_empty, "processing": Icons.autorenew, "completed": Icons.check_circle, "failed": Icons.error}[s] ?? Icons.help;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_statusIcon(task.status), color: _statusColor(task.status), size: 20),
                const SizedBox(width: 8),
                Text("有声书 #${task.bookId}", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: isDark ? Colors.white : AppTheme.textPrimary)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _statusColor(task.status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(_statusLabel(task.status), style: TextStyle(fontSize: 11, color: _statusColor(task.status), fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (task.status != "failed") ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: task.progress / 100.0,
                  minHeight: 6,
                  backgroundColor: Colors.grey.withOpacity(0.15),
                  valueColor: AlwaysStoppedAnimation(_statusColor(task.status)),
                ),
              ),
              const SizedBox(height: 6),
              Text("${task.progress}%", style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            ],
            if (task.errorMessage != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 16),
                    const SizedBox(width: 8),
                    Expanded(child: Text(task.errorMessage!, style: const TextStyle(fontSize: 12, color: Colors.red))),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Text(task.createdAt, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                const Spacer(),
                if (task.status == "completed")
                  TextButton.icon(
                    icon: const Icon(Icons.play_arrow, size: 16),
                    label: const Text("播放"),
                    onPressed: () => Navigator.pushNamed(context, "/player", arguments: task.bookId),
                  ),
                if (task.status == "failed")
                  TextButton.icon(
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text("重试"),
                    onPressed: () {},
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ===================== 会员 Tab =====================
class _MembershipTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: Text("Pro 会员", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: isDark ? Colors.white : AppTheme.textPrimary)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [AppTheme.primaryDark, AppTheme.primary], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: AppTheme.primary.withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 8))],
            ),
            child: Column(children: const [
              Icon(Icons.workspace_premium, size: 72, color: Colors.white),
              SizedBox(height: 16),
              Text("解锁全部功能", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
              SizedBox(height: 8),
              Text("无限上传 · 优先合成 · 无损下载", style: TextStyle(color: Colors.white70, fontSize: 14)),
            ]),
          ),
          const SizedBox(height: 32),
          _FeatureItem(icon: Icons.all_inclusive, title: "无限上传", subtitle: "无限制创建有声书，不限文件大小"),
          _FeatureItem(icon: Icons.speed, title: "优先合成", subtitle: "TTS 任务优先处理，无需排队等待"),
          _FeatureItem(icon: Icons.download, title: "无损下载", subtitle: "高清音频下载，支持离线收听"),
          _FeatureItem(icon: Icons.headphones, title: "边看边听", subtitle: "同步高亮字幕，沉浸式阅读体验"),
          _FeatureItem(icon: Icons.support_agent, title: "专属客服", subtitle: "优先技术支持"),
          const SizedBox(height: 32),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54)),
            onPressed: () => Navigator.pushNamed(context, "/membership"),
            child: const Text("升级 Pro 会员", style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }
}

class _FeatureItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _FeatureItem({required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppTheme.primary, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.w600, color: isDark ? Colors.white : AppTheme.textPrimary)),
                const SizedBox(height: 2),
                Text(subtitle, style: TextStyle(fontSize: 13, color: Colors.grey)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ===================== 我的 Tab =====================
class _ProfileTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text("我的", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: isDark ? Colors.white : AppTheme.textPrimary)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // 用户信息卡片
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: AppTheme.primary,
                    child: Text(user?.username.substring(0, 1).toUpperCase() ?? "?", style: const TextStyle(fontSize: 28, color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user?.username ?? "", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : AppTheme.textPrimary)),
                        const SizedBox(height: 4),
                        Text(user?.email ?? "", style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                      ],
                    ),
                  ),
                  if (user?.isPremium == true)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.star, color: AppTheme.primary, size: 16),
                          SizedBox(width: 4),
                          Text("Pro", style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 12)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          _MenuItem(icon: Icons.person, title: "个人资料", onTap: () => Navigator.pushNamed(context, "/profile")),
          _MenuItem(icon: Icons.workspace_premium, title: "会员中心", onTap: () => Navigator.pushNamed(context, "/membership")),
          _MenuItem(icon: Icons.download, title: "下载管理", onTap: () {}),
          _MenuItem(icon: Icons.headset, title: "收听历史", onTap: () {}),
          _MenuItem(icon: Icons.settings, title: "设置", onTap: () => Navigator.pushNamed(context, "/settings")),
          const SizedBox(height: 24),
          Card(
            child: ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text("退出登录", style: TextStyle(color: Colors.red)),
              onTap: () async {
                await auth.logout();
                if (context.mounted) Navigator.pushReplacementNamed(context, "/login");
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  const _MenuItem({required this.icon, required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      margin: const EdgeInsets.only(bottom: 4),
      child: ListTile(
        leading: Icon(icon, color: AppTheme.primary),
        title: Text(title, style: TextStyle(color: isDark ? Colors.white : AppTheme.textPrimary)),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
        onTap: onTap,
      ),
    );
  }
}
