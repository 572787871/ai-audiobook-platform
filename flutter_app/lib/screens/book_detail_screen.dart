import "package:flutter/material.dart";
import "package:provider/provider.dart";
import "../theme/app_theme.dart";
import "../widgets/common_widgets.dart";
import "../providers/book_provider.dart";
import "../models/book.dart";
import "../services/local_tts_service.dart";
import "local_generation_screen.dart";
import "voice_select_screen.dart";

class BookDetailScreen extends StatefulWidget {
  final int bookId;
  const BookDetailScreen({super.key, required this.bookId});

  @override
  State<BookDetailScreen> createState() => _BookDetailScreenState();
}

class _BookDetailScreenState extends State<BookDetailScreen> {
  BookDetail? _detail;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final d =
          await context.read<BookProvider>().fetchBookDetail(widget.bookId);
      if (mounted)
        setState(() {
          _detail = d;
          _loading = false;
        });
    } catch (e) {
      if (mounted)
        setState(() {
          _error = "加载失败: $e";
          _loading = false;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: _loading
          ? _buildSkeleton()
          : _error != null
              ? Center(
                  child: EmptyState(
                      icon: Icons.error_outline_rounded,
                      title: "加载失败",
                      subtitle: _error,
                      actionLabel: "重试",
                      onAction: _loadDetail))
              : CustomScrollView(
                  slivers: [
                    _buildCoverSection(context, isDark),
                    _buildInfoSection(context, cs),
                    _buildStatsSection(context, cs, isDark),
                    _buildActionButtons(context, cs),
                    _buildChapterSection(context, cs, isDark),
                    const SliverToBoxAdapter(child: SizedBox(height: 40)),
                  ],
                ),
    );
  }

  Widget _buildSkeleton() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          SkeletonBox(height: 200, radius: AppTheme.radiusLg),
          const SizedBox(height: 16),
          SkeletonBox(height: 24, width: 200),
          const SizedBox(height: 8),
          SkeletonBox(height: 16, width: 120),
          const SizedBox(height: 24),
          Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(
                  3,
                  (_) => SkeletonBox(
                      height: 60, width: 80, radius: AppTheme.radiusMd))),
          const SizedBox(height: 24),
          SkeletonBox(height: 52, radius: AppTheme.radiusMd),
        ],
      ),
    );
  }

  Widget _buildCoverSection(BuildContext context, bool isDark) {
    final d = _detail!;
    return SliverAppBar(
      expandedHeight: 380,
      pinned: true,
      automaticallyImplyLeading: true,
      leading: Padding(
        padding: const EdgeInsets.all(8),
        child: GlassBox(
          borderRadius: AppTheme.radiusFull,
          child: IconButton(
            icon: Icon(Icons.arrow_back,
                color: isDark ? Colors.white : Colors.black87),
            onPressed: () => Navigator.pop(context),
          ),
        ),
      ),
      backgroundColor: isDark ? AppTheme.bgDark : AppTheme.bgLight,
      surfaceTintColor: Colors.transparent,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppTheme.primaryLight.withValues(alpha: 0.3),
                isDark ? AppTheme.bgDark : AppTheme.bgLight
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 40),
                child: Hero(
                  tag: "book_cover_${d.id}",
                  child: BookCover(
                      title: d.title,
                      coverUrl: d.coverUrl,
                      width: 180,
                      height: 240,
                      radius: AppTheme.radiusLg),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoSection(BuildContext context, ColorScheme cs) {
    final d = _detail!;
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
        child: Column(
          children: [
            Text(d.title,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                    letterSpacing: -0.5)),
            if (d.author != null && d.author!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(d.author!,
                  style: TextStyle(
                      fontSize: 15,
                      color: cs.onSurface.withValues(alpha: 0.5))),
            ],
            const SizedBox(height: 12),
            StatusTag(status: d.status),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsSection(BuildContext context, ColorScheme cs, bool isDark) {
    final d = _detail!;
    final stats = [
      (
        "字数",
        d.wordCount != null
            ? "${(d.wordCount! / 10000).toStringAsFixed(1)}万"
            : "—"
      ),
      ("章节", d.chapters.isNotEmpty ? "${d.chapters.length}" : "—"),
      ("时长", d.totalDuration != null ? _formatDuration(d.totalDuration!) : "—"),
      ("更新", d.updatedAt.isNotEmpty ? _formatDate(d.updatedAt) : "—"),
    ];
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.cardDark : Colors.white,
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            boxShadow:
                AppTheme.cardShadow(cs.onSurface, opacity: 0.04, blur: 12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: stats.map((s) {
              return Column(children: [
                Text(s.$2,
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface)),
                const SizedBox(height: 4),
                Text(s.$1,
                    style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurface.withValues(alpha: 0.4))),
              ]);
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, ColorScheme cs) {
    final d = _detail!;
    final isCompleted = d.status == "completed";
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 主按钮
            if (isCompleted)
              GradientButton(
                label: "开始播放",
                icon: Icons.play_arrow_rounded,
                onPressed: () =>
                    Navigator.pushNamed(context, "/player", arguments: d.id),
              )
            else if (d.status == "processing")
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: null,
                  icon: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: cs.primary)),
                  label: Text("合成中...",
                      style: TextStyle(
                          color: cs.onSurface.withValues(alpha: 0.5))),
                ),
              )
            else if (d.status == "failed")
              GradientButton(
                label: "重新生成",
                icon: Icons.refresh_rounded,
                gradient: const LinearGradient(
                    colors: [AppTheme.warning, AppTheme.danger]),
                onPressed: () => _regenerate(context, d.id),
              )
            else
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: null,
                  icon: Icon(Icons.hourglass_top_rounded,
                      color: cs.onSurface.withValues(alpha: 0.4)),
                  label: Text("等待中",
                      style: TextStyle(
                          color: cs.onSurface.withValues(alpha: 0.4))),
                ),
              ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.pushNamed(
                  context,
                  "/local-generation",
                  arguments: LocalGenerationArgs(bookId: d.id),
                ),
                icon: const Icon(Icons.phone_iphone_rounded),
                label: Text(isCompleted ? "重新生成本地缓存" : "本地生成 / 生成设置"),
              ),
            ),
            const SizedBox(height: 12),
            // 次按钮组
            Row(
              children: [
                Expanded(
                    child: _SecondaryBtn(
                        icon: Icons.menu_book_rounded,
                        label: "边看边听",
                        onTap: isCompleted
                            ? () => Navigator.pushNamed(context, "/read",
                                arguments: d.id)
                            : null)),
                const SizedBox(width: 12),
                Expanded(
                    child: _SecondaryBtn(
                        icon: Icons.record_voice_over_rounded,
                        label: "音色",
                        onTap: () => Navigator.pushNamed(
                            context, "/voice-select",
                            arguments: VoiceSelectArgs(
                                bookId: d.id, title: "选择本书旁白")))),
                const SizedBox(width: 12),
                Expanded(
                    child: _SecondaryBtn(
                        icon: Icons.download_rounded,
                        label: "下载",
                        onTap: isCompleted
                            ? () => _downloadBook(context, d)
                            : null)),
                const SizedBox(width: 12),
                Expanded(
                    child: _SecondaryBtn(
                        icon: Icons.share_rounded,
                        label: "分享",
                        onTap: () => _shareBook(context, d))),
              ],
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                  child: _SecondaryBtn(
                      icon: Icons.delete_outline_rounded,
                      label: "删除",
                      color: AppTheme.danger,
                      onTap: () => _deleteBook(context, d.id))),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildChapterSection(
      BuildContext context, ColorScheme cs, bool isDark) {
    final chapters = _detail!.chapters;
    if (chapters.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text("章节列表",
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface)),
            ),
            ...chapters.asMap().entries.map((entry) {
              final i = entry.key;
              final ch = entry.value;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.cardDark : Colors.white,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  boxShadow:
                      AppTheme.cardShadow(cs.onSurface, opacity: 0.03, blur: 8),
                ),
                child: ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    ),
                    child: Center(
                        child: Text("${i + 1}",
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: cs.primary))),
                  ),
                  title: Text(ch.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: cs.onSurface)),
                  subtitle: Text(_formatSec(ch.end - ch.start),
                      style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurface.withValues(alpha: 0.4))),
                  trailing: Icon(Icons.play_arrow_rounded,
                      size: 22, color: cs.primary),
                  onTap: () => Navigator.pushNamed(context, "/player",
                      arguments: _detail!.id),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  // ====== 操作 ======

  Future<void> _regenerate(BuildContext context, int bookId) async {
    Navigator.pushNamed(context, "/local-generation",
        arguments: LocalGenerationArgs(bookId: bookId));
  }

  Future<void> _downloadBook(BuildContext context, BookDetail d) async {
    try {
      final segments = await LocalTtsService.getSegments(d.id);
      if (segments.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text("还没有本地音频，请先生成")));
        }
        return;
      }
      final path = segments.first.audioPath ?? "";
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("音频已在本机缓存：$path")));
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("下载失败: $e")));
    }
  }

  void _shareBook(BuildContext context, BookDetail d) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text("分享《${d.title}》")));
  }

  Future<void> _deleteBook(BuildContext context, int bookId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusLg)),
        title: const Text("删除书籍"),
        content: const Text("确定要删除这本书吗？此操作不可撤销。"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("取消")),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppTheme.danger),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text("删除")),
        ],
      ),
    );
    if (confirm != true) return;
    final ok = await context.read<BookProvider>().deleteBook(bookId);
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("已删除")));
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("删除失败")));
    }
  }

  String _formatSec(double sec) {
    final m = (sec ~/ 60).toInt();
    final s = (sec % 60).toInt();
    return "$m:${s.toString().padLeft(2, '0')}";
  }

  String _formatDuration(String dur) {
    try {
      final sec = int.parse(dur);
      final h = sec ~/ 3600;
      final m = (sec % 3600) ~/ 60;
      if (h > 0) return "$h小时${m}分钟";
      return "$m分钟";
    } catch (_) {
      return dur;
    }
  }

  String _formatDate(String dateStr) {
    try {
      final dt = DateTime.parse(dateStr);
      return "${dt.month}/${dt.day}";
    } catch (_) {
      return dateStr;
    }
  }
}

class _SecondaryBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color? color;
  const _SecondaryBtn(
      {required this.icon, required this.label, this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final disabled = onTap == null;
    final c = color ?? cs.onSurface;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: isDark ? AppTheme.cardDark : Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          boxShadow: AppTheme.cardShadow(cs.onSurface,
              opacity: disabled ? 0 : 0.04, blur: 8),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 22,
                color: disabled ? cs.onSurface.withValues(alpha: 0.2) : c),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: disabled ? cs.onSurface.withValues(alpha: 0.2) : c)),
          ],
        ),
      ),
    );
  }
}
