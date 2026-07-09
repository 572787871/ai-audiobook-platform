/// 会员页
import "package:flutter/material.dart";
import "package:provider/provider.dart";
import "../providers/auth_provider.dart";
import "../theme/app_theme.dart";

class MembershipScreen extends StatelessWidget {
  const MembershipScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    final isPremium = user?.isPremium ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text("Pro 会员")),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [AppTheme.primaryDark, AppTheme.primary]),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: AppTheme.primary.withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 8))],
            ),
            child: Column(children: [
              Icon(isPremium ? Icons.verified : Icons.workspace_premium, size: 72, color: Colors.white),
              const SizedBox(height: 16),
              Text(isPremium ? "您是 Pro 会员" : "升级为 Pro 会员", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 8),
              Text(isPremium ? "感谢您的支持！" : "解锁更多高级功能", style: const TextStyle(color: Colors.white70)),
            ]),
          ),
          const SizedBox(height: 32),
          _FeatureItem(icon: Icons.all_inclusive, title: "无限上传", subtitle: "无限制创建有声书"),
          _FeatureItem(icon: Icons.speed, title: "优先合成", subtitle: "TTS 任务优先处理"),
          _FeatureItem(icon: Icons.download, title: "无损下载", subtitle: "高码率音频下载"),
          _FeatureItem(icon: Icons.headphones, title: "边看边听", subtitle: "同步高亮字幕"),
          _FeatureItem(icon: Icons.support_agent, title: "专属客服", subtitle: "优先支持"),
          const SizedBox(height: 32),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54)),
            onPressed: isPremium ? null : () async {
              final ok = await auth.upgradePremium();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ok ? "已升级为 Pro 会员" : auth.error ?? "升级失败")));
              }
            },
            child: Text(isPremium ? "已是 Pro 会员" : "立即升级 - 限时免费", style: const TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }
}

class _FeatureItem extends StatelessWidget {
  final IconData icon; final String title; final String subtitle;
  const _FeatureItem({required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(children: [
        Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: AppTheme.primary, size: 24)),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
          Text(subtitle, style: const TextStyle(fontSize: 13, color: Colors.grey)),
        ])),
      ]),
    );
  }
}
