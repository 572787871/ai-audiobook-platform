import "package:flutter/material.dart";
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
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => context.read<LocalTtsProvider>().init());
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
          Text("默认旁白音色",
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface)),
          const SizedBox(height: 10),
          ...provider.voices.map((voice) => _VoiceTile(
                voice: voice,
                selected: provider.defaultVoiceId == voice.voiceId,
                onSelect: () => provider.setDefaultVoice(voice.voiceId),
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
}

class _ModeCard extends StatelessWidget {
  final GenerationMode mode;
  final ValueChanged<GenerationMode> onChanged;
  const _ModeCard({required this.mode, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final options = [
      (GenerationMode.auto, "自动选择", "优先本地，失败后提示切换云端"),
      (GenerationMode.local, "只用本地", "正文不上传服务器，适合隐私内容"),
      (GenerationMode.cloud, "只用云端", "继续使用服务器 Abogen/TTS 链路"),
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
  final VoidCallback onSelect;
  const _VoiceTile(
      {required this.voice, required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final gender = switch (voice.gender) {
      TtsVoiceGender.male => "男声",
      TtsVoiceGender.female => "女声",
      TtsVoiceGender.neutral => "中性",
    };
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
        subtitle: Text("$gender · ${voice.language}\n${voice.description}",
            maxLines: 2, overflow: TextOverflow.ellipsis),
        isThreeLine: true,
        trailing: selected
            ? Icon(Icons.check_rounded, color: cs.primary)
            : TextButton(onPressed: onSelect, child: const Text("设为默认")),
      ),
    );
  }
}
