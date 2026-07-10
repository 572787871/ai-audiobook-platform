import "package:flutter/material.dart";
import "../theme/app_theme.dart";
import "../widgets/common_widgets.dart";
import "home_screen.dart";
import "bookshelf_screen.dart";
import "task_list_screen.dart";
import "membership_screen.dart";
import "profile_screen.dart";

class MainTabScreen extends StatefulWidget {
  const MainTabScreen({super.key});

  @override
  State<MainTabScreen> createState() => _MainTabScreenState();
}

class _MainTabScreenState extends State<MainTabScreen>
    with TickerProviderStateMixin {
  late TabController _tabCtrl;
  int _index = 0;

  final _pages = <Widget>[
    const HomeScreen(),
    const BookshelfScreen(),
    const TaskListScreen(),
    const MembershipScreen(),
    const ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 5, vsync: this);
    _tabCtrl.addListener(() {
      if (!_tabCtrl.indexIsChanging) setState(() => _index = _tabCtrl.index);
    });
    // 监听全局 tab 切换
    tabSwitchNotifier.addListener(_onTabSwitch);
  }

  void _onTabSwitch() {
    final idx = tabSwitchNotifier.value;
    if (idx >= 0 && idx < 5 && idx != _index) _tabCtrl.animateTo(idx);
  }

  @override
  void dispose() {
    tabSwitchNotifier.removeListener(_onTabSwitch);
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: TabBarView(
        controller: _tabCtrl,
        physics: const NeverScrollableScrollPhysics(),
        children: _pages,
      ),
      bottomNavigationBar: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? AppTheme.cardDark : Colors.white,
            boxShadow: AppTheme.cardShadow(Colors.black,
                opacity: 0.08, blur: 20, y: -2),
          ),
          child: SafeArea(
            top: false,
            child: TabBar(
              controller: _tabCtrl,
              indicatorSize: TabBarIndicatorSize.label,
              indicatorColor: Colors.transparent,
              labelColor: AppTheme.primaryLight,
              unselectedLabelColor: isDark
                  ? AppTheme.textTertiaryDark
                  : AppTheme.textTertiaryLight,
              tabs: [
                _TabItem(
                    icon: Icons.home_rounded,
                    label: "首页",
                    isActive: _index == 0),
                _TabItem(
                    icon: Icons.library_books_rounded,
                    label: "书架",
                    isActive: _index == 1),
                _TabItem(
                    icon: Icons.task_alt_rounded,
                    label: "任务",
                    isActive: _index == 2),
                _TabItem(
                    icon: Icons.workspace_premium_rounded,
                    label: "会员",
                    isActive: _index == 3),
                _TabItem(
                    icon: Icons.person_rounded,
                    label: "我的",
                    isActive: _index == 4),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;

  const _TabItem(
      {required this.icon, required this.label, required this.isActive});

  @override
  Widget build(BuildContext context) {
    return Tab(
      icon: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isActive
              ? AppTheme.primaryLight..withValues(alpha: HOLDER__0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppTheme.radiusFull),
        ),
        child: Icon(icon, size: 22),
      ),
      text: label,
    );
  }
}
