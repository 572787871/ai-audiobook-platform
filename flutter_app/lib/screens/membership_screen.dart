/// 会员页
import "package:flutter/material.dart";
import "package:provider/provider.dart";
import "../providers/auth_provider.dart";

class MembershipScreen extends StatelessWidget {
  const MembershipScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    final isPremium = user?.isPremium ?? false;
    return Scaffold(
      appBar: AppBar(title: const Text("会员")),
      body: ListView(padding: const EdgeInsets.all(24), children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(gradient: LinearGradient(colors: [Theme.of(context).colorScheme.primary, Theme.of(context).colorScheme.primaryContainer]), borderRadius: BorderRadius.circular(16)),
          child: Column(children: [
            Icon(isPremium ? Icons.verified : Icons.workspace_premium, size: 80, color: Colors.white),
            const SizedBox(height: 12),
            Text(isPremium ? "您是会员" : "升级为会员", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 8),
            Text(isPremium ? "感谢支持！" : "解锁更多功能", style: const TextStyle(color: Colors.white70)),
          ]),
        ),
        const SizedBox(height: 24),
        ...[_FeatureItem(icon: Icons.all_inclusive, title: "无限上传", subtitle: "无限制创建有声书"),
          _FeatureItem(icon: Icons.speed, title: "优先合成", subtitle: "TTS 任务优先处理"),
          _FeatureItem(icon: Icons.download, title: "无损下载", subtitle: "高码率音频下载"),
          _FeatureItem(icon: Icons.support_agent, title: "专属客服", subtitle: "优先支持"),
        ],
        const SizedBox(height: 32),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
          onPressed: isPremium ? null : () async {
            final ok = await auth.upgradePremium();
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ok ? "已升级会员" : auth.error ?? "升级失败")));
            }
          },
          child: Text(isPremium ? "已是会员" : "立即升级（演示）"),
        ),
      ]),
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
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(title),
      subtitle: Text(subtitle),
    );
  }
}
