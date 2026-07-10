import "package:flutter/material.dart";
import "package:provider/provider.dart";
import "../theme/app_theme.dart";
import "../providers/auth_provider.dart";

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final userName =
        auth.user?.username ?? auth.user?.email.split("@").first ?? "用户";
    final email = auth.user?.email ?? "";
    final isPro = auth.user?.isPremium ?? false;

    return Scaffold(
      body: CustomScrollView(slivers: [
        SliverAppBar(
          automaticallyImplyLeading: false,
          floating: true,
          backgroundColor: isDark ? AppTheme.bgDark : AppTheme.bgLight,
          surfaceTintColor: Colors.transparent,
          title: Text("我的",
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 22,
                  letterSpacing: -0.3)),
        ),
        // 头像+会员状态
        SliverToBoxAdapter(
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                  colors: isPro
                      ? [const Color(0xFFE94B78), const Color(0xFF9B6BFF)]
                      : [
                          AppTheme.primaryLight.withValues(alpha: 0.8),
                          AppTheme.accent.withValues(alpha: 0.6)
                        ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(AppTheme.radiusXl),
            ),
            child: Column(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.3),
                      border: Border.all(color: Colors.white, width: 2)),
                  child: Center(
                      child: Text(
                          userName.isNotEmpty ? userName[0].toUpperCase() : "U",
                          style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              color: Colors.white))),
                ),
                const SizedBox(height: 12),
                Text(userName,
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: -0.3)),
                const SizedBox(height: 4),
                Text(email,
                    style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.8))),
                const SizedBox(height: 12),
                if (isPro)
                  Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusFull)),
                      child:
                          const Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.workspace_premium,
                            size: 14, color: Colors.white),
                        SizedBox(width: 4),
                        Text("PRO 会员",
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600))
                      ]))
                else
                  Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusFull)),
                      child: const Text("免费用户",
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w500))),
              ],
            ),
          ),
        ),
        // 额度统计
        SliverToBoxAdapter(
            child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                child: _StatGrid(isDark: isDark, cs: cs))),
        // 功能列表
        SliverList(
          delegate: SliverChildListDelegate([
            const SizedBox(height: 16),
            _MenuSection(title: "订单", items: [
              _MenuItem(
                  icon: Icons.shopping_bag_outlined,
                  title: "我的订单",
                  onTap: () => _showComingSoon(context, "我的订单")),
              _MenuItem(
                  icon: Icons.download_outlined,
                  title: "下载管理",
                  onTap: () => _showComingSoon(context, "下载管理")),
              _MenuItem(
                  icon: Icons.storage_outlined,
                  title: "缓存管理",
                  value: "23.5MB",
                  onTap: () => _showComingSoon(context, "缓存管理")),
            ]),
            _MenuSection(title: "设置", items: [
              _MenuItem(
                  icon: Icons.settings_outlined,
                  title: "设置",
                  onTap: () => Navigator.pushNamed(context, "/settings")),
              _MenuItem(
                  icon: Icons.feedback_outlined,
                  title: "意见反馈",
                  onTap: () => _showComingSoon(context, "意见反馈")),
              _MenuItem(
                  icon: Icons.info_outline,
                  title: "关于",
                  onTap: () => _showComingSoon(context, "关于")),
            ]),
            const SizedBox(height: 16),
            Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: OutlinedButton.icon(
                        onPressed: () async {
                          await auth.logout();
                          if (context.mounted)
                            Navigator.pushReplacementNamed(context, "/login");
                        },
                        icon: Icon(Icons.logout, color: AppTheme.danger),
                        label: Text("退出登录",
                            style: TextStyle(
                                color: AppTheme.danger,
                                fontWeight: FontWeight.w600))))),
            const SizedBox(height: 80),
          ]),
        ),
      ]),
    );
  }

  void _showComingSoon(BuildContext context, String title) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text("$title 开发中")));
  }
}

class _StatGrid extends StatelessWidget {
  final bool isDark;
  final ColorScheme cs;
  const _StatGrid({required this.isDark, required this.cs});

  @override
  Widget build(BuildContext context) {
    final stats = [
      ("0", "生成分钟数"),
      ("0", "已下载"),
      ("3", "本月额度"),
      ("0", "收藏"),
    ];
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
          color: isDark ? AppTheme.cardDark : Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          boxShadow:
              AppTheme.cardShadow(cs.onSurface, opacity: 0.04, blur: 12)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: stats
            .map((s) => Column(children: [
                  Text(s.$1,
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: cs.onSurface)),
                  const SizedBox(height: 4),
                  Text(s.$2,
                      style: TextStyle(
                          fontSize: 11,
                          color: cs.onSurface.withValues(alpha: 0.4))),
                ]))
            .toList(),
      ),
    );
  }
}

class _MenuSection extends StatelessWidget {
  final String title;
  final List<_MenuItem> items;
  const _MenuSection({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(title,
                  style: TextStyle(
                      fontSize: 14,
                      color: cs.onSurface.withValues(alpha: 0.5),
                      fontWeight: FontWeight.w500))),
          Container(
            decoration: BoxDecoration(
                color: isDark ? AppTheme.cardDark : Colors.white,
                borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                boxShadow:
                    AppTheme.cardShadow(cs.onSurface, opacity: 0.04, blur: 10)),
            child: Column(
                children: items.asMap().entries.map((entry) {
              final i = entry.key;
              final item = entry.value;
              return Column(children: [
                _MenuRow(item: item, isDark: isDark, cs: cs),
                if (i < items.length - 1)
                  Padding(
                      padding: const EdgeInsets.only(left: 52),
                      child: Divider(
                          height: 1,
                          color: cs.onSurface.withValues(alpha: 0.06))),
              ]);
            }).toList()),
          ),
        ]));
  }
}

class _MenuItem {
  final IconData icon;
  final String title;
  final String? value;
  final VoidCallback onTap;
  _MenuItem(
      {required this.icon,
      required this.title,
      this.value,
      required this.onTap});
}

class _MenuRow extends StatelessWidget {
  final _MenuItem item;
  final bool isDark;
  final ColorScheme cs;
  const _MenuRow({required this.item, required this.isDark, required this.cs});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: item.onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(children: [
          Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm)),
              child: Icon(item.icon, size: 18, color: cs.primary)),
          const SizedBox(width: 12),
          Expanded(
              child: Text(item.title,
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: cs.onSurface))),
          if (item.value != null)
            Text(item.value!,
                style: TextStyle(
                    fontSize: 13, color: cs.onSurface.withValues(alpha: 0.4))),
          const SizedBox(width: 8),
          Icon(Icons.chevron_right,
              size: 20, color: cs.onSurface.withValues(alpha: 0.2)),
        ]),
      ),
    );
  }
}
