import "package:flutter/material.dart";
import "package:just_audio/just_audio.dart";
import "package:provider/provider.dart";
import "../models/local_tts.dart";
import "../providers/local_tts_provider.dart";
import "../theme/app_theme.dart";

class VoiceSelectArgs {
  final int? bookId;
  final int? chapterId;
  final String title;
  const VoiceSelectArgs({this.bookId, this.chapterId, this.title = "选择音色"});
}

class VoiceSelectScreen extends StatefulWidget {
  final VoiceSelectArgs args;
  const VoiceSelectScreen({super.key, required this.args});

  @override
  State<VoiceSelectScreen> createState() => _VoiceSelectScreenState();
}

class _VoiceSelectScreenState extends State<VoiceSelectScreen> {
  final AudioPlayer _previewPlayer = AudioPlayer();
  String _filter = "全部";
  String? _playingVoiceId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => context.read<LocalTtsProvider>().init());
  }

  @override
  void dispose() {
    _previewPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LocalTtsProvider>();
    final voices = _filtered(provider.voices);
    return Scaffold(
      appBar: AppBar(title: Text(widget.args.title)),
      body: Column(
        children: [
          SizedBox(
            height: 46,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              children:
                  ["全部", "推荐", "中文", "英文", "男声", "女声", "已下载"].map((label) {
                final active = _filter == label;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(label),
                    selected: active,
                    onSelected: (_) => setState(() => _filter = label),
                  ),
                );
              }).toList(),
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: voices.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final voice = voices[index];
                final selected = provider.defaultVoiceId == voice.voiceId;
                return _VoiceCard(
                  voice: voice,
                  selected: selected,
                  playing: _playingVoiceId == voice.voiceId,
                  onPreview: () => _preview(provider, voice),
                  onSelect: () => _select(provider, voice),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  List<TtsVoice> _filtered(List<TtsVoice> voices) {
    return voices.where((voice) {
      return switch (_filter) {
        "推荐" => voice.recommended,
        "中文" => voice.language.toLowerCase().startsWith("zh"),
        "英文" => voice.language.toLowerCase().startsWith("en"),
        "男声" => voice.gender == TtsVoiceGender.male,
        "女声" => voice.gender == TtsVoiceGender.female,
        "已下载" => voice.isDownloaded,
        _ => true,
      };
    }).toList();
  }

  Future<void> _preview(LocalTtsProvider provider, TtsVoice voice) async {
    try {
      setState(() => _playingVoiceId = voice.voiceId);
      final path = await provider.previewVoice(voice);
      if (path == null) return;
      await _previewPlayer.setFilePath(path);
      await _previewPlayer.play();
    } finally {
      if (mounted) setState(() => _playingVoiceId = null);
    }
  }

  Future<void> _select(LocalTtsProvider provider, TtsVoice voice) async {
    if (widget.args.bookId != null && widget.args.chapterId != null) {
      await provider.setChapterVoice(
          widget.args.bookId!, widget.args.chapterId!, voice.voiceId);
    } else if (widget.args.bookId != null) {
      await provider.setBookVoice(widget.args.bookId!, voice.voiceId);
    } else {
      await provider.setDefaultVoice(voice.voiceId);
    }
    if (!mounted) return;
    Navigator.pop(context, voice.voiceId);
  }
}

class _VoiceCard extends StatelessWidget {
  final TtsVoice voice;
  final bool selected;
  final bool playing;
  final VoidCallback onPreview;
  final VoidCallback onSelect;
  const _VoiceCard({
    required this.voice,
    required this.selected,
    required this.playing,
    required this.onPreview,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final gender = switch (voice.gender) {
      TtsVoiceGender.male => "男声",
      TtsVoiceGender.female => "女声",
      TtsVoiceGender.neutral => "中性",
    };
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(
            color:
                selected ? cs.primary : cs.onSurface.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: cs.primary.withValues(alpha: 0.1),
            child: Icon(Icons.graphic_eq_rounded, color: cs.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                      child: Text(voice.displayName,
                          style: const TextStyle(fontWeight: FontWeight.w700))),
                  if (voice.recommended) const _Badge(label: "推荐"),
                ]),
                const SizedBox(height: 4),
                Text("$gender · ${voice.language} · ${voice.modelVersion}",
                    style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurface.withValues(alpha: 0.55))),
                const SizedBox(height: 4),
                Text(voice.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 13,
                        color: cs.onSurface.withValues(alpha: 0.75))),
              ],
            ),
          ),
          IconButton(
            tooltip: "试听",
            onPressed: onPreview,
            icon: Icon(playing
                ? Icons.stop_circle_outlined
                : Icons.play_circle_outline_rounded),
          ),
          selected
              ? Icon(Icons.check_circle_rounded, color: cs.primary)
              : FilledButton.tonal(
                  onPressed: onSelect, child: const Text("使用")),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  const _Badge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
          color: AppTheme.success.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppTheme.radiusFull)),
      child: Text(label,
          style: const TextStyle(
              fontSize: 11,
              color: AppTheme.success,
              fontWeight: FontWeight.w600)),
    );
  }
}
