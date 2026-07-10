import "package:flutter/material.dart";
import "package:provider/provider.dart";
import "../models/book.dart";
import "../models/local_tts.dart";
import "../providers/book_provider.dart";
import "../providers/local_tts_provider.dart";
import "../providers/task_provider.dart";
import "../services/local_tts_service.dart";
import "../theme/app_theme.dart";
import "../widgets/common_widgets.dart";
import "voice_select_screen.dart";

class LocalGenerationArgs {
  final int bookId;
  final String? sourceText;
  const LocalGenerationArgs({required this.bookId, this.sourceText});
}

class LocalGenerationScreen extends StatefulWidget {
  final LocalGenerationArgs args;
  const LocalGenerationScreen({super.key, required this.args});

  @override
  State<LocalGenerationScreen> createState() => _LocalGenerationScreenState();
}

class _LocalGenerationScreenState extends State<LocalGenerationScreen> {
  BookDetail? _book;
  String? _voiceId;
  bool _loading = true;
  bool _cloudSubmitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await context.read<LocalTtsProvider>().init();
      final book = await context
          .read<BookProvider>()
          .fetchBookDetail(widget.args.bookId);
      final voiceId =
          await LocalTtsService.resolveVoiceId(bookId: widget.args.bookId);
      if (!mounted) return;
      setState(() {
        _book = book;
        _voiceId = voiceId;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = "加载生成设置失败: $e";
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LocalTtsProvider>();
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text("生成有声书")),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: EmptyState(
                      icon: Icons.error_outline_rounded,
                      title: "无法生成",
                      subtitle: _error,
                      actionLabel: "重试",
                      onAction: _load))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _BookHeader(book: _book!),
                    const SizedBox(height: 16),
                    _SettingCard(
                      title: "生成方式",
                      subtitle: _modeSubtitle(provider.mode),
                      icon: Icons.privacy_tip_outlined,
                      actionLabel: "修改",
                      onTap: () => Navigator.pushNamed(context, "/voice-packs"),
                    ),
                    _SettingCard(
                      title: "旁白音色",
                      subtitle: _voiceName(provider, _voiceId),
                      icon: Icons.record_voice_over_rounded,
                      actionLabel: "选择",
                      onTap: _selectVoice,
                    ),
                    const SizedBox(height: 16),
                    if (provider.generating)
                      _ProgressPanel(provider: provider)
                    else
                      _StartPanel(
                          onLocal: _startLocal,
                          onCloud: _startCloud,
                          cloudSubmitting: _cloudSubmitting),
                    if (provider.error != null) ...[
                      const SizedBox(height: 16),
                      Text(provider.error!,
                          style: TextStyle(color: AppTheme.danger)),
                    ],
                    const SizedBox(height: 32),
                    Text(
                      "本地生成会在 iPhone 上分段生成音频并缓存，不会上传书籍正文。云端生成仍保留为兼容旧设备和本地失败时的备用方案。",
                      style: TextStyle(
                          fontSize: 13,
                          height: 1.5,
                          color: cs.onSurface.withValues(alpha: 0.55)),
                    ),
                  ],
                ),
    );
  }

  Future<void> _selectVoice() async {
    final selected = await Navigator.pushNamed(
      context,
      "/voice-select",
      arguments: VoiceSelectArgs(bookId: widget.args.bookId, title: "选择本书旁白"),
    );
    if (selected is String && mounted) setState(() => _voiceId = selected);
  }

  Future<void> _startLocal() async {
    if (_book == null) return;
    try {
      await context.read<LocalTtsProvider>().generateBook(
          book: _book!, sourceText: widget.args.sourceText, voiceId: _voiceId);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("本地有声书已生成")));
      Navigator.pushReplacementNamed(context, "/player", arguments: _book!.id);
    } catch (e) {
      if (!mounted) return;
      final switchCloud = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text("本地生成失败"),
          content: Text("$e\n\n是否切换云端生成？"),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text("稍后再试")),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text("用云端生成")),
          ],
        ),
      );
      if (switchCloud == true) _startCloud();
    }
  }

  Future<void> _startCloud() async {
    setState(() => _cloudSubmitting = true);
    try {
      await context.read<TaskProvider>().createTask(widget.args.bookId,
          params: {"generation_mode": "cloud", "voice": _voiceId});
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("已提交云端生成任务")));
      Navigator.pop(context, true);
    } finally {
      if (mounted) setState(() => _cloudSubmitting = false);
    }
  }

  String _modeSubtitle(GenerationMode mode) => switch (mode) {
        GenerationMode.auto => "自动选择：优先本地，失败后询问是否切换云端",
        GenerationMode.local => "只用本地：正文不会上传服务器",
        GenerationMode.cloud => "只用云端：使用服务器生成链路",
      };

  String _voiceName(LocalTtsProvider provider, String? voiceId) {
    final id = voiceId ?? provider.defaultVoiceId;
    return provider.voices
        .firstWhere((v) => v.voiceId == id,
            orElse: () => LocalTtsServiceFallback.voice(id))
        .displayName;
  }
}

class LocalTtsServiceFallback {
  static TtsVoice voice(String id) => TtsVoice(
        voiceId: id,
        displayName: id,
        language: "zh-CN",
        gender: TtsVoiceGender.neutral,
        description: "",
        previewText: "",
        isDownloaded: true,
        isDefault: false,
        modelVersion: "",
        packId: "unknown",
      );
}

class _BookHeader extends StatelessWidget {
  final BookDetail book;
  const _BookHeader({required this.book});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        BookCover(
            title: book.title,
            coverUrl: book.coverUrl,
            width: 82,
            height: 110,
            radius: AppTheme.radiusMd),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(book.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text(book.author?.isNotEmpty == true ? book.author! : "未知作者",
                  style: TextStyle(color: cs.onSurface.withValues(alpha: 0.5))),
              const SizedBox(height: 10),
              StatusTag(status: book.status),
            ],
          ),
        ),
      ],
    );
  }
}

class _SettingCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final String actionLabel;
  final VoidCallback onTap;
  const _SettingCard(
      {required this.title,
      required this.subtitle,
      required this.icon,
      required this.actionLabel,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(subtitle),
        trailing: TextButton(onPressed: onTap, child: Text(actionLabel)),
      ),
    );
  }
}

class _ProgressPanel extends StatelessWidget {
  final LocalTtsProvider provider;
  const _ProgressPanel({required this.provider});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(provider.generationLabel,
              style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          LinearProgressIndicator(
              value: provider.generationProgress.clamp(0, 1)),
          const SizedBox(height: 12),
          Text(
              "${(provider.generationProgress * 100).clamp(0, 100).toStringAsFixed(0)}%"),
        ],
      ),
    );
  }
}

class _StartPanel extends StatelessWidget {
  final VoidCallback onLocal;
  final VoidCallback onCloud;
  final bool cloudSubmitting;
  const _StartPanel(
      {required this.onLocal,
      required this.onCloud,
      required this.cloudSubmitting});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
            width: double.infinity,
            height: 54,
            child: FilledButton.icon(
                onPressed: onLocal,
                icon: const Icon(Icons.phone_iphone_rounded),
                label: const Text("开始本地生成"))),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: OutlinedButton.icon(
            onPressed: cloudSubmitting ? null : onCloud,
            icon: cloudSubmitting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.cloud_queue_rounded),
            label: Text(cloudSubmitting ? "提交中..." : "改用云端生成"),
          ),
        ),
      ],
    );
  }
}
