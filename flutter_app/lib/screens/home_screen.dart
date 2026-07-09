/// 首页：5 Tab 导航（首页 / 书架 / 任务 / 会员 / 我的）
import "package:flutter/material.dart";
import "package:provider/provider.dart";
import "../providers/auth_provider.dart";
import "../providers/book_provider.dart";
import "../providers/task_provider.dart";
import "../models/book.dart";
import "../models/task.dart";

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BookProvider>().loadBooks();
      context.read<TaskProvider>().loadTasks();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: const [
        _HomeTab(),
        _BookshelfTab(),
        _TasksTab(),
        _MembershipTab(),
        _ProfileTab(),
      ]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) {
          setState(() => _currentIndex = i);
          if (i == 0) context.read<BookProvider>().loadBooks();
          if (i == 1) context.read<BookProvider>().loadBooks();
          if (i == 2) context.read<TaskProvider>().loadTasks();
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home), label: "首页"),
          NavigationDestination(icon: Icon(Icons.library_books), label: "书架"),
          NavigationDestination(icon: Icon(Icons.queue), label: "任务"),
          NavigationDestination(icon: Icon(Icons.workspace_premium), label: "会员"),
          NavigationDestination(icon: Icon(Icons.person), label: "我的"),
        ],
      ),
    );
  }
}

// ===== Tab 1: 首页 =====
class _HomeTab extends StatelessWidget {
  const _HomeTab();

  @override
  Widget build(BuildContext context) {
    final books = context.watch<BookProvider>().books;
    return Scaffold(
      appBar: AppBar(title: const Text("AI 有声书"), automaticallyImplyLeading: false),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 搜索框
          TextField(
            decoration: InputDecoration(
              hintText: "搜索书名或作者...",
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 24),
          // 快捷入口
          Row(children: [
            _QuickEntry(icon: Icons.upload_file, label: "上传小说", color: Colors.blue, onTap: () => Navigator.pushNamed(context, "/upload")),
            const SizedBox(width: 12),
            _QuickEntry(icon: Icons.headphones, label: "边看边听", color: Colors.purple, onTap: () {}),
            const SizedBox(width: 12),
            _QuickEntry(icon: Icons.workspace_premium, label: "Pro 会员", color: Colors.amber, onTap: () {}),
          ]),
          const SizedBox(height: 28),
          // 最近生成
          Row(children: [Text("最近生成", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
            const Spacer(), TextButton(child: const Text("查看全部"), onPressed: () {})]),
          const SizedBox(height: 12),
          SizedBox(
            height: 190,
            child: books.isEmpty
                ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Icon(Icons.library_books_outlined, size: 48, color: Colors.grey),
                    const SizedBox(height: 8),
                    Text("还没有有声书，点击「上传小说」开始", style: TextStyle(color: Colors.grey.shade500)),
                  ]))
                : ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: books.length,
                    itemBuilder: (ctx, i) => _BookCard(book: books[i], onTap: () => Navigator.pushNamed(context, "/book", arguments: books[i].id)),
                  ),
          ),
          const SizedBox(height: 28),
          // 推荐模板
          Row(children: [Text("推荐模板", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
            const Spacer(), TextButton(child: const Text("更多"), onPressed: () {})]),
          const SizedBox(height: 12),
          Row(children: [
            _TemplateCard(icon: Icons.auto_stories, label: "小说", sub: "适合长篇故事"),
            const SizedBox(width: 12),
            _TemplateCard(icon: Icons.article, label: "散文", sub: "适合抒情文字"),
            const SizedBox(width: 12),
            _TemplateCard(icon: Icons.school, label: "知识", sub: "适合科普内容"),
          ]),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

class _QuickEntry extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _QuickEntry({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(child: GestureDetector(onTap: onTap,
      child: Container(padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(16)),
        child: Column(children: [
          Icon(icon, size: 32, color: color),
          const SizedBox(height: 8),
          Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color)),
        ]))));
  }
}

class _BookCard extends StatelessWidget {
  final Book book;
  final VoidCallback onTap;
  const _BookCard({required this.book, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 130,
        margin: const EdgeInsets.only(right: 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 2))],
            ),
            child: Center(child: Icon(Icons.menu_book, size: 48, color: Theme.of(context).colorScheme.primary.withOpacity(0.4))),
          )),
          const SizedBox(height: 8),
          Text(book.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          if (book.author != null) Text(book.author!, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
        ]),
      ),
    );
  }
}

class _TemplateCard extends StatelessWidget {
  final IconData icon;
  final String label, sub;
  const _TemplateCard({required this.icon, required this.label, required this.sub});
  @override
  Widget build(BuildContext context) {
    return Expanded(child: Container(padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade200), borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        Icon(icon, size: 24, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          Text(sub, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
        ]),
      ])));
  }
}

// ===== Tab 2: 书架 =====
class _BookshelfTab extends StatefulWidget {
  const _BookshelfTab();
  @override
  State<_BookshelfTab> createState() => _BookshelfTabState();
}

class _BookshelfTabState extends State<_BookshelfTab> {
  bool _isGrid = true;

  @override
  Widget build(BuildContext context) {
    final books = context.watch<BookProvider>().books;
    return Scaffold(
      appBar: AppBar(title: const Text("我的书架"), automaticallyImplyLeading: false, actions: [
        IconButton(icon: Icon(_isGrid ? Icons.view_list : Icons.grid_view), onPressed: () => setState(() => _isGrid = !_isGrid)),
      ]),
      body: books.isEmpty
          ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.library_books_outlined, size: 80, color: Colors.grey),
              const SizedBox(height: 16), const Text("书架空空"),
              const SizedBox(height: 8), ElevatedButton.icon(icon: const Icon(Icons.upload), label: const Text("上传有声书"),
                onPressed: () => Navigator.pushNamed(context, "/upload")),
            ]))
          : _isGrid ? _GridBookshelf(books: books) : _ListBookshelf(books: books),
    );
  }
}

class _GridBookshelf extends StatelessWidget {
  final List<Book> books;
  const _GridBookshelf({required this.books});
  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 150, childAspectRatio: 0.65, crossAxisSpacing: 12, mainAxisSpacing: 12),
      itemCount: books.length,
      itemBuilder: (ctx, i) => _ShelfCard(book: books[i], onTap: () => Navigator.pushNamed(context, "/book", arguments: books[i].id)),
    );
  }
}

class _ListBookshelf extends StatelessWidget {
  final List<Book> books;
  const _ListBookshelf({required this.books});
  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: books.length,
      itemBuilder: (ctx, i) {
        final b = books[i];
        return Card(margin: const EdgeInsets.symmetric(vertical: 4), child: ListTile(
          leading: Container(width: 50, height: 60, decoration: BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer, borderRadius: BorderRadius.circular(8)),
            child: Center(child: Icon(Icons.menu_book, color: Theme.of(context).colorScheme.primary))),
          title: Text(b.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text("${b.status == "completed" ? "已完成" : b.status}"),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.pushNamed(context, "/book", arguments: b.id),
        ));
      },
    );
  }
}

class _ShelfCard extends StatelessWidget {
  final Book book;
  final VoidCallback onTap;
  const _ShelfCard({required this.book, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDone = book.status == "completed";
    return GestureDetector(
      onTap: onTap,
      child: Card(
        clipBehavior: Clip.antiAlias,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Container(
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Center(child: Icon(Icons.menu_book, size: 56, color: Theme.of(context).colorScheme.primary.withOpacity(0.4))),
          )),
          Padding(padding: const EdgeInsets.all(10), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(book.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 2),
            Row(children: [
              Icon(isDone ? Icons.check_circle : Icons.hourglass_empty, size: 12, color: isDone ? Colors.green : Colors.orange),
              const SizedBox(width: 4),
              Text(isDone ? "已完成" : book.status, style: TextStyle(fontSize: 11, color: isDone ? Colors.green : Colors.orange)),
            ]),
          ])),
        ]),
      ),
    );
  }
}

// ===== Tab 3: 任务 =====
class _TasksTab extends StatefulWidget {
  const _TasksTab();
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
    return Scaffold(
      appBar: AppBar(title: const Text("任务中心"), automaticallyImplyLeading: false),
      body: tp.isLoading && tasks.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : tasks.isEmpty
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: const [
                  Icon(Icons.inbox, size: 80, color: Colors.grey), SizedBox(height: 16), Text("暂无任务"),
                ]))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: tasks.length,
                  itemBuilder: (ctx, i) => _TaskCard(task: tasks[i], onTap: () => Navigator.pushNamed(context, "/task", arguments: tasks[i].id)),
                ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  final Task task;
  final VoidCallback onTap;
  const _TaskCard({required this.task, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final statusMap = {"pending": ("等待中", Colors.orange), "processing": ("合成中", Colors.blue),
      "completed": ("已完成", Colors.green), "failed": ("失败", Colors.red)};
    final info = statusMap[task.status] ?? (task.status, Colors.grey);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(12),
        child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: info.$2.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
              child: Text(info.$1, style: TextStyle(color: info.$2, fontSize: 12, fontWeight: FontWeight.w600))),
            const Spacer(),
            Text("#${task.id}", style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
          ]),
          const SizedBox(height: 10),
          ClipRRect(borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(value: task.progress / 100.0, minHeight: 6,
              backgroundColor: Colors.grey.shade200, valueColor: AlwaysStoppedAnimation(info.$2))),
          const SizedBox(height: 6),
          Row(children: [
            Text("${task.progress}%", style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            const Spacer(),
            Text("有声书 #${task.bookId}", style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
          ]),
          if (task.errorMessage != null) ...[
            const SizedBox(height: 6),
            Text(task.errorMessage!, style: const TextStyle(fontSize: 12, color: Colors.red), maxLines: 2, overflow: TextOverflow.ellipsis),
          ],
        ]))),
    );
  }
}

// ===== Tab 4: 会员 =====
class _MembershipTab extends StatelessWidget {
  const _MembershipTab();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isPremium = auth.user?.isPremium ?? false;
    return Scaffold(
      appBar: AppBar(title: const Text("会员"), automaticallyImplyLeading: false),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [Colors.indigo, Colors.purple.shade400]),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(children: [
            Icon(isPremium ? Icons.verified : Icons.workspace_premium, size: 72, color: Colors.white),
            const SizedBox(height: 12),
            Text(isPremium ? "您是 Pro 会员" : "升级 Pro 会员", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
            Text(isPremium ? "感谢您的支持" : "解锁全部功能", style: const TextStyle(color: Colors.white70)),
          ]),
        ),
        const SizedBox(height: 24),
        _Feature(icon: Icons.all_inclusive, title: "无限上传", sub: "无限制创建有声书", premium: true),
        _Feature(icon: Icons.speed, title: "优先合成", sub: "TTS 任务插队处理", premium: true),
        _Feature(icon: Icons.download, title: "无损下载", sub: "高码率音频下载", premium: true),
        _Feature(icon: Icons.voice_over_off, title: "真人讲书", sub: "接入高品质 TTS", premium: true),
        const SizedBox(height: 24),
        SizedBox(width: double.infinity, height: 52, child: FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Colors.indigo),
          onPressed: isPremium ? null : () async {
            await auth.upgradePremium();
            if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isPremium ? "已是会员" : "已升级为 Pro 会员（演示）")));
          },
          child: Text(isPremium ? "已是会员" : "立即升级", style: const TextStyle(fontSize: 16)),
        )),
      ]),
    );
  }
}

class _Feature extends StatelessWidget {
  final IconData icon; final String title, sub; final bool premium;
  const _Feature({required this.icon, required this.title, required this.sub, this.premium = false});
  @override
  Widget build(BuildContext context) {
    return Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Row(children: [
      Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.indigo.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: Colors.indigo)),
      const SizedBox(width: 14),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w600)), Text(sub, style: TextStyle(fontSize: 13, color: Colors.grey.shade600))]),
      const Spacer(),
      if (premium) Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: Colors.indigo.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
        child: const Text("Pro", style: TextStyle(color: Colors.indigo, fontSize: 11, fontWeight: FontWeight.bold))),
    ]));
  }
}

// ===== Tab 5: 我的 =====
class _ProfileTab extends StatelessWidget {
  const _ProfileTab();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    return Scaffold(
      appBar: AppBar(title: const Text("我的"), automaticallyImplyLeading: false),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        // 用户卡片
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [Theme.of(context).colorScheme.primaryContainer, Theme.of(context).colorScheme.surface]),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(children: [
            CircleAvatar(radius: 30, child: Text(user?.username.substring(0, 1).toUpperCase() ?? "?", style: const TextStyle(fontSize: 24))),
            const SizedBox(width: 16),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(user?.username ?? "未登录", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Text(user?.email ?? "", style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
              if (user?.isPremium == true)
                Container(margin: const EdgeInsets.only(top: 4), padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: Colors.indigo.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                  child: const Text("Pro 会员", style: TextStyle(color: Colors.indigo, fontSize: 11, fontWeight: FontWeight.bold),)),
            ]),
          ]),
        ),
        const SizedBox(height: 24),
        _MenuTile(icon: Icons.person, title: "个人资料", onTap: () => Navigator.pushNamed(context, "/profile")),
        _MenuTile(icon: Icons.workspace_premium, title: "会员中心", onTap: () {}),
        _MenuTile(icon: Icons.download, title: "下载管理", onTap: () {}),
        _MenuTile(icon: Icons.settings, title: "设置", onTap: () => Navigator.pushNamed(context, "/settings")),
        const SizedBox(height: 24),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.logout, color: Colors.red),
          title: const Text("退出登录", style: TextStyle(color: Colors.red)),
          onTap: () async { await auth.logout(); if (context.mounted) Navigator.pushReplacementNamed(context, "/login"); },
        ),
      ]),
    );
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon; final String title; final VoidCallback onTap;
  const _MenuTile({required this.icon, required this.title, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return ListTile(leading: Icon(icon), title: Text(title), trailing: const Icon(Icons.chevron_right, size: 18), onTap: onTap);
  }
}
