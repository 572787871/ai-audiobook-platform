import "package:flutter/material.dart";
import "../theme/app_theme.dart";
import "../widgets/common_widgets.dart";

class MembershipScreen extends StatefulWidget {
  const MembershipScreen({super.key});
  @override
  State<MembershipScreen> createState() => _MembershipScreenState();
}

class _MembershipScreenState extends State<MembershipScreen> {
  int _selectedPlan = 1;

  final _plans = [
    _Plan(id: 0, name: "月度", price: "¥18", perMonth: "每月", desc: "灵活订阅"),
    _Plan(
        id: 1,
        name: "年度",
        price: "¥128",
        perMonth: "¥10.7/月",
        desc: "省 ¥88",
        popular: true),
    _Plan(id: 2, name: "终身", price: "¥298", perMonth: "一次性", desc: "永久使用"),
  ];

  final _benefits = [
    ("无限", "transform", "无限生成有声书"),
    ("优先", "flash_on", "优先队列合成"),
    ("无损", "audio_file", "FLAC 无损下载"),
    ("多设备", "devices", "最多 5 台设备"),
    ("独家", "auto_awesome", "AI 语音选择"),
    ("专属", "support_agent", "专属客服"),
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: CustomScrollView(slivers: [
        SliverAppBar(
          automaticallyImplyLeading: false,
          floating: true,
          backgroundColor: isDark ? AppTheme.bgDark : AppTheme.bgLight,
          surfaceTintColor: Colors.transparent,
          title: Text("会员中心",
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 22,
                  letterSpacing: -0.3)),
        ),
        // Pro 封面
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [Color(0xFF2A1F3D), Color(0xFF3D2A5C)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(AppTheme.radiusXl),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                            color: Color(0xFFE94B78)..withValues(alpha: 0.2),
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusFull)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.workspace_premium,
                              size: 14, color: Color(0xFFFFB800)),
                          const SizedBox(width: 4),
                          Text("PRO 会员",
                              style: TextStyle(
                                  color: Color(0xFFFFB800),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700))
                        ])),
                    const Spacer(),
                    Icon(Icons.workspace_premium,
                        size: 32,
                        color: Color(0xFFFFB800)..withValues(alpha: 0.5)),
                  ]),
                  const SizedBox(height: 16),
                  Text("解锁全部能力",
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: -0.3)),
                  const SizedBox(height: 4),
                  Text("下个月起剩余额度将清零",
                      style: TextStyle(fontSize: 13, color: Colors.white54)),
                ],
              ),
            ),
          ),
        ),
        // 权益网格
        SliverToBoxAdapter(
            child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text("会员权益",
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface)))),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 1.0,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12),
            delegate: SliverChildBuilderDelegate((ctx, i) {
              final b = _benefits[i];
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: isDark ? AppTheme.cardDark : Colors.white,
                    borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                    boxShadow: AppTheme.cardShadow(cs.onSurface,
                        opacity: 0.04, blur: 8)),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Icon(Icons.check_circle,
                            size: 16, color: AppTheme.success),
                        const SizedBox(width: 4),
                        Text(b.$1,
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: cs.onSurface)),
                      ]),
                      const Spacer(),
                      Text(b.$3,
                          style: TextStyle(
                              fontSize: 12,
                              color: cs.onSurface..withValues(alpha: 0.5))),
                    ]),
              );
            }, childCount: _benefits.length),
          ),
        ),
        // 套餐
        SliverToBoxAdapter(
            child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                child: Text("选择套餐",
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface)))),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: _plans
                  .map((p) => Expanded(
                          child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedPlan = p.id),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                                vertical: 20, horizontal: 8),
                            decoration: BoxDecoration(
                              color: _selectedPlan == p.id
                                  ? cs.primary..withValues(alpha: 0.05)
                                  : (isDark ? AppTheme.cardDark : Colors.white),
                              borderRadius:
                                  BorderRadius.circular(AppTheme.radiusLg),
                              border: Border.all(
                                  color: _selectedPlan == p.id
                                      ? cs.primary
                                      : Colors.transparent,
                                  width: 2),
                              boxShadow: AppTheme.cardShadow(cs.onSurface,
                                  opacity: 0.04, blur: 8),
                            ),
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                if (p.popular)
                                  Positioned(
                                      top: -20,
                                      left: 0,
                                      right: 0,
                                      child: Center(
                                          child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 2),
                                              decoration: BoxDecoration(
                                                  gradient:
                                                      AppTheme.primaryGradient,
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          AppTheme.radiusFull)),
                                              child: const Text("推荐",
                                                  style: TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 10,
                                                      fontWeight:
                                                          FontWeight.w600))))),
                                Column(children: [
                                  Text(p.name,
                                      style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: cs.onSurface
                                              ..withValues(alpha: 0.7))),
                                  const SizedBox(height: 8),
                                  Text(p.price,
                                      style: TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.w700,
                                          color: cs.onSurface)),
                                  const SizedBox(height: 2),
                                  Text(p.perMonth,
                                      style: TextStyle(
                                          fontSize: 11, color: cs.primary)),
                                  const SizedBox(height: 4),
                                  Text(p.desc,
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: cs.onSurface
                                              ..withValues(alpha: 0.4))),
                                ]),
                              ],
                            ),
                          ),
                        ),
                      )))
                  .toList(),
            ),
          ),
        ),
        // 购买按钮
        SliverToBoxAdapter(
            child: Padding(
                padding: const EdgeInsets.all(16),
                child: GradientButton(
                    label: "立即开通",
                    icon: Icons.workspace_premium_rounded,
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("支付功能开发中")));
                    }))),
        // 恢复购买
        SliverToBoxAdapter(
            child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Center(
                    child: TextButton(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("已恢复购买")));
                        },
                        child: const Text("恢复购买"))))),
        // 消费记录
        SliverToBoxAdapter(
            child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text("消费记录",
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface)))),
        SliverList(
          delegate: SliverChildBuilderDelegate((ctx, i) {
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: isDark ? AppTheme.cardDark : Colors.white,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
              child: Row(
                children: [
                  Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                          color: AppTheme.primaryLight..withValues(alpha: 0.08),
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusSm)),
                      child: Icon(Icons.receipt_long,
                          size: 20, color: AppTheme.primaryLight)),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text("年度会员",
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: cs.onSurface)),
                        Text("2026-0${i + 1}-01",
                            style: TextStyle(
                                fontSize: 12,
                                color: cs.onSurface..withValues(alpha: 0.4))),
                      ])),
                  Text("-¥128",
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.danger)),
                ],
              ),
            );
          }, childCount: 3),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 80)),
      ]),
    );
  }
}

class _Plan {
  final int id;
  final String name;
  final String price;
  final String perMonth;
  final String desc;
  final bool popular;
  _Plan(
      {required this.id,
      required this.name,
      required this.price,
      required this.perMonth,
      required this.desc,
      this.popular = false});
}
