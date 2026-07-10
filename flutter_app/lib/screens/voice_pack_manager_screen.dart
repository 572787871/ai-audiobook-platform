import "package:flutter/material.dart";
import "package:just_audio/just_audio.dart";
import "package:provider/provider.dart";
import "../models/local_tts.dart";
import "../providers/local_tts_provider.dart";
import "../theme/app_theme.dart";

class VoicePackManagerScreen extends StatefulWidget {
  const VoicePackManagerScreen({super.key});

  @override
  State<VoicePackManagerScreen> createState() => _VoicePackManagerScreenState();
}

class _VoicePackManagerScreenState extends State<VoicePackManagerScreen> {
  final AudioPlayer _player = AudioPlayer();
  String? _playingVoiceId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => context.read<LocalTtsProvider>().init());
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LocalTtsProvider>();
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text("语音包管理")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _ModeCard(mode: provider.mode, onChanged: provider.setMode),
          const SizedBox(height: 16),
          Text("已安装与可下载",
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface)),
          const SizedBox(height: 10),
          ...provider.voicePacks.map((pack) => _PackTile(
              pack: pack, onDownload: () => provider.downloadVoicePack(pack))),
          const SizedBox(height: 24),
          Text("Abogen 混合音色",
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface)),
          const SizedBox(height: 10),
          ...provider.voiceFormulas.map((formula) => _FormulaTile(
                formula: formula,
                voices: provider.voices,
              )),
          const SizedBox(height: 24),
          Text("默认旁白音色",
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface)),
          const SizedBox(height: 10),
          ...provider.voices.map((voice) => _VoiceTile(
                voice: voice,
                selected: provider.defaultVoiceId == voice.voiceId,
                playing: _playingVoiceId == voice.voiceId,
                onSelect: () => provider.setDefaultVoice(voice.voiceId),
                onDownload: () => provider.downloadVoice(voice),
                onPreview: () => _preview(provider, voice),
              )),
          if (provider.error != null) ...[
            const SizedBox(height: 16),
            Text(provider.error!, style: TextStyle(color: AppTheme.danger)),
          ],
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Future<void> _preview(LocalTtsProvider provider, TtsVoice voice) async {
    try {
      setState(() => _playingVoiceId = voice.voiceId);
      final path = await provider.previewVoice(voice);
      if (path == null) return;
      await _player.setFilePath(path);
      await _player.play();
    } finally {
      if (mounted) setState(() => _playingVoiceId = null);
    }
  }
}

class _ModeCard extends StatelessWidget {
  final GenerationMode mode;
  final ValueChanged<GenerationMode> onChanged;
  const _ModeCard({required this.mode, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final options = [
      (GenerationMode.local, "本地生成", "正文、分段、音频缓存全部保存在这台 iPhone"),
    ];
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("生成方式",
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 6),
          Text("云端生成已关闭。上传文件不会发送到服务器。",
              style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.55))),
          const SizedBox(height: 10),
          ...options.map((item) {
            final selected = mode == item.$1;
            return ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color:
                      selected ? Theme.of(context).colorScheme.primary : null),
              title: Text(item.$2),
              subtitle: Text(item.$3),
              onTap: () => onChanged(item.$1),
            );
          }),
        ],
      ),
    );
  }
}

class _PackTile extends StatelessWidget {
  final VoicePack pack;
  final VoidCallback onDownload;
  const _PackTile({required this.pack, required this.onDownload});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final size = pack.sizeBytes <= 0
        ? "系统内置"
        : "${(pack.sizeBytes / 1024 / 1024).toStringAsFixed(0)} MB";
    return Card(
      child: ListTile(
        leading: Icon(
            pack.isDownloaded
                ? Icons.check_circle_rounded
                : Icons.cloud_download_outlined,
            color: pack.isDownloaded ? AppTheme.success : cs.primary),
        title: Text(pack.displayName,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text("${pack.language} · ${pack.modelVersion} · $size"),
        trailing: pack.isDownloaded
            ? const Text("可用")
            : FilledButton.tonal(
                onPressed: pack.downloadUrl.isEmpty ? null : onDownload,
                child: const Text("下载")),
      ),
    );
  }
}

class _VoiceTile extends StatelessWidget {
  final TtsVoice voice;
  final bool selected;
  final bool playing;
  final VoidCallback onSelect;
  final VoidCallback onDownload;
  final VoidCallback onPreview;
  const _VoiceTile(
      {required this.voice,
      required this.selected,
      required this.playing,
      required this.onSelect,
      required this.onDownload,
      required this.onPreview});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final gender = switch (voice.gender) {
      TtsVoiceGender.male => "男声",
      TtsVoiceGender.female => "女声",
      TtsVoiceGender.neutral => "中性",
    };
    final backend = voice.backend == TtsBackend.kokoro ? "Kokoro" : "iPhone 系统";
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor:
              selected ? cs.primary : cs.primary.withValues(alpha: 0.08),
          child: Icon(Icons.record_voice_over_rounded,
              color: selected ? Colors.white : cs.primary),
        ),
        title: Text(voice.displayName,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
            "$gender · ${voice.language} · $backend${voice.grade == null ? "" : " · ${voice.grade}"}\n${voice.description}",
            maxLines: 2,
            overflow: TextOverflow.ellipsis),
        isThreeLine: true,
        trailing: Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              IconButton(
                  tooltip: "试听",
                  onPressed: onPreview,
                  icon: Icon(playing
                      ? Icons.stop_circle_outlined
                      : Icons.play_circle_outline_rounded)),
              if (!voice.isDownloaded)
                TextButton(onPressed: onDownload, child: const Text("下载"))
              else if (selected)
                Icon(Icons.check_rounded, color: cs.primary)
              else
                TextButton(onPressed: onSelect, child: const Text("设为默认")),
            ]),
      ),
    );
  }
}

class _FormulaTile extends StatelessWidget {
  final VoiceFormula formula;
  final List<TtsVoice> voices;
  const _FormulaTile({required this.formula, required this.voices});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final names = formula.parts.map((part) {
      final matches = voices.where((v) => v.voiceId == part.voiceId);
      final voice = matches.isEmpty ? null : matches.first;
      final name = voice?.displayName ?? part.voiceId;
      return "$name ${(part.weight * 100).toStringAsFixed(0)}%";
    }).join(" + ");
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: cs.secondaryContainer,
          child: Icon(Icons.tune_rounded, color: cs.onSecondaryContainer),
        ),
        title: Text(formula.displayName,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text("${formula.language}\n$names",
            maxLines: 2, overflow: TextOverflow.ellipsis),
        isThreeLine: true,
        trailing: formula.isDefault
            ? Icon(Icons.check_rounded, color: cs.primary)
            : const Text("可选"),
      ),
    );
  }
}
