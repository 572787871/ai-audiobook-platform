/// 首页（书架）：参考 Apple Books / Audible
import "package:flutter/material.dart";
import "package:provider/provider.dart";
import "package:cached_network_image/cached_network_image.dart";
import "../providers/auth_provider.dart";
import "../providers/book_provider.dart";
import "../providers/task_provider.dart";

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
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _BookshelfPage(),
          _TasksTab(),
          _ProfileTab(auth: auth),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) {
          if (i == 1) context.read<BookProvider>().loadBooks();
          setState(() => _currentIndex = i);
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.library_books), label: "书架"),
          NavigationDestination(icon: Icon(Icons.queue), label: "任务"),
          NavigationDestination(icon: Icon(Icons.person), label: "我的"),
        ],
      ),
      floatingActionButton: _currentIndex == 0
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.pushNamed(context, "/upload"),
              icon: const Icon(Icons.upload_file),
              label: const Text("上传"),
            )
          : null,
    );
  }
}

class _BookshelfPage extends StatelessWidget {
  Future<void> _refresh(BuildContext context) async {
    await context.read<BookProvider>().loadBooks();
  }

  @override
  Widget build(BuildContext context) {
    final bp = context.watch<BookProvider>();
    final books = bp.books;
    return Scaffold(
      appBar: AppBar(
        title: const Text("书架"),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: () => _refresh(context)),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _refresh(context),
        child: bp.isLoading && books.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : books.isEmpty
                ? ListView(children: [
                    const SizedBox(height: 200),
                    Center(child: Column(children: const [
                      Icon(Icons.library_books_outlined, size: 80, color: Colors.grey),
                      SizedBox(height: 16),
                      Text("书架空空如也", style: TextStyle(color: Colors.grey)),
                      SizedBox(height: 8),
                      Text("点击右下角上传文本创建有声书"),
                    ])),
                  ])
                : GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 160,
                      childAspectRatio: 0.62,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: books.length,
                    itemBuilder: (ctx, i) {
                      final b = books[i];
                      return GestureDetector(
                        onTap: () => Navigator.pushNamed(context, "/book", arguments: b.id),
                        child: Card(
                          clipBehavior: Clip.antiAlias,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              AspectRatio(
                                aspectRatio: 0.8,
                                child: b.coverUrl != null
                                    ? CachedNetworkImage(imageUrl: b.coverUrl!, fit: BoxFit.cover)
                                    : Container(
                                        color: Theme.of(context).colorScheme.primaryContainer,
                                        child: Center(child: Icon(Icons.book, size: 48, color: Theme.of(context).colorScheme.primary)),
                                      ),
                              ),
                              const Spacer(),
                              Padding(
                                padding: const EdgeInsets.all(8),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(b.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                    if (b.author != null)
                                      Text(b.author!, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}

class _TasksTab extends StatefulWidget {

  @override
  State<_TasksTab> createState() => _TasksTabState();
}

class _TasksTabState extends State<_TasksTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await context.read<TaskProvider>().loadTasks();
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
    final taskP = context.watch<TaskProvider>();
    final tasks = taskP.tasks;
    return Scaffold(
      appBar: AppBar(title: const Text("任务"), automaticallyImplyLeading: false),
      body: taskP.isLoading && tasks.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : tasks.isEmpty
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: const [Icon(Icons.inbox, size: 80, color: Colors.grey), SizedBox(height: 16), Text("暂无任务")]))
              : ListView.builder(
                  itemCount: tasks.length,
                  itemBuilder: (ctx, i) {
                    final t = tasks[i];
                    return ListTile(
                      leading: CircleAvatar(child: Text(t.taskType[0].toUpperCase())),
                      title: Text("#\${t.id} - \${t.bookId}"),
                      subtitle: Text("\${t.status} - \${t.progress}%"),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.pushNamed(context, "/task", arguments: t.id),
                    );
                  },
                ),
    );
  }
}

class _ProfileTab extends StatelessWidget {
  final AuthProvider auth;
  const _ProfileTab({required this.auth});

  @override
  Widget build(BuildContext context) {
    final user = auth.user;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        CircleAvatar(radius: 50, foregroundColor: Theme.of(context).colorScheme.primary,
          child: Text(user?.username.substring(0, 1).toUpperCase() ?? "?", style: const TextStyle(fontSize: 36))),
        const SizedBox(height: 12),
        Center(child: Text(user?.username ?? "", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
        Center(child: Text(user?.email ?? "", style: TextStyle(color: Colors.grey.shade600))),
        if (user?.isPremium == true)
          const Padding(padding: EdgeInsets.only(top: 8), child: Center(child: Chip(label: Text("会员"), avatar: Icon(Icons.star)))),
        const SizedBox(height: 32),
        ListTile(leading: const Icon(Icons.person), title: const Text("个人资料"), trailing: const Icon(Icons.chevron_right), onTap: () => Navigator.pushNamed(context, "/profile")),
        ListTile(leading: const Icon(Icons.star), title: const Text("会员"), trailing: const Icon(Icons.chevron_right), onTap: () => Navigator.pushNamed(context, "/membership")),
        ListTile(leading: const Icon(Icons.settings), title: const Text("设置"), trailing: const Icon(Icons.chevron_right), onTap: () => Navigator.pushNamed(context, "/settings")),
        const SizedBox(height: 24),
        ListTile(
          leading: const Icon(Icons.logout, color: Colors.red),
          title: const Text("退出登录", style: TextStyle(color: Colors.red)),
          onTap: () async {
            await auth.logout();
            if (context.mounted) Navigator.pushReplacementNamed(context, "/login");
          },
        ),
      ],
    );
  }
}
