import "package:flutter/material.dart";
import "package:provider/provider.dart";
import "../providers/auth_provider.dart";
import "../providers/local_tts_provider.dart";
import "../models/local_tts.dart";

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final tts = context.watch<LocalTtsProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text("设置")),
      body: ListView(padding: const EdgeInsets.all(24), children: [
        const Text("本地生成",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 8),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.offline_bolt_outlined),
          title: const Text("生成方式"),
          subtitle: Text(_modeText(tts.mode)),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.pushNamed(context, "/voice-packs"),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.record_voice_over_outlined),
          title: const Text("默认旁白音色"),
          subtitle: Text(_voiceName(tts)),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.pushNamed(context, "/voice-select"),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.inventory_2_outlined),
          title: const Text("语音包与缓存管理"),
          subtitle: Text(
              "${tts.voicePacks.where((e) => e.isDownloaded).length} 个语音包可用"),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.pushNamed(context, "/voice-packs"),
        ),
        const Divider(height: 40),
        const Text("账号",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 8),
        ListTile(
            title: const Text("当前账号"),
            subtitle: Text(auth.user?.email ?? "本机离线账户"),
            leading: const Icon(Icons.person)),
        ListTile(
            title: const Text("版本"),
            trailing: const Text("0.1.0"),
            leading: const Icon(Icons.info_outline)),
        const Divider(height: 40),
        ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text("退出登录", style: TextStyle(color: Colors.red)),
            onTap: () async {
              await auth.logout();
              if (context.mounted)
                Navigator.pushReplacementNamed(context, "/login");
            }),
      ]),
    );
  }

  String _modeText(GenerationMode mode) => switch (mode) {
        GenerationMode.auto => "本地生成",
        GenerationMode.local => "只在 iPhone 本地生成",
        GenerationMode.cloud => "云端已关闭",
      };

  String _voiceName(LocalTtsProvider tts) {
    final id = tts.defaultVoiceId;
    for (final voice in tts.voices) {
      if (voice.voiceId == id) return voice.displayName;
    }
    return id;
  }
}
