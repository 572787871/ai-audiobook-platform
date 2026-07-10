import "package:flutter/material.dart";
import "package:provider/provider.dart";
import "../models/book.dart";
import "../models/local_tts.dart";
import "../providers/book_provider.dart";
import "../providers/local_tts_provider.dart";
import "../services/local_book_service.dart";
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
                      _StartPanel(onLocal: _startLocal),
                    if (provider.error != null) ...[
                      const SizedBox(height: 16),
                      Text(provider.error!,
                          style: TextStyle(color: AppTheme.danger)),
                    ],
                    const SizedBox(height: 32),
                    Text(
                      "本地生成会在 iPhone 上分段生成音频并缓存，不会上传书籍正文。生成时可以退出页面，已完成的分段会保留在本机。",
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
      final segments = await context.read<LocalTtsProvider>().generateBook(
          book: _book!, sourceText: widget.args.sourceText, voiceId: _voiceId);
      final duration =
          segments.fold<double>(0, (sum, seg) => sum + seg.duration);
      await LocalBookService.markCompleted(_book!.id, duration: duration);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("本地有声书已生成")));
      Navigator.pushReplacementNamed(context, "/player", arguments: _book!.id);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("本地生成失败: $e"), backgroundColor: AppTheme.danger));
    }
  }

  String _modeSubtitle(GenerationMode mode) => switch (mode) {
        GenerationMode.auto => "本地生成：正文不离开这台 iPhone",
        GenerationMode.local => "只用本地：正文不会上传服务器",
        GenerationMode.cloud => "云端已关闭：按本地生成执行",
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
  const _StartPanel({required this.onLocal});

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
      ],
    );
  }
}
