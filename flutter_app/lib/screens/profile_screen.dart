import "package:flutter/material.dart";
import "package:provider/provider.dart";
import "../providers/auth_provider.dart";
import "../theme/app_theme.dart";

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _usernameCtrl = TextEditingController();

  @override
  void dispose() { _usernameCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    if (user != null && _usernameCtrl.text.isEmpty) _usernameCtrl.text = user.username;

    return Scaffold(
      appBar: AppBar(title: const Text("个人资料")),
      body: ListView(padding: const EdgeInsets.all(24), children: [
        Center(
          child: Column(children: [
            CircleAvatar(radius: 48, backgroundColor: AppTheme.primary, child: Text(user?.username.substring(0, 1).toUpperCase() ?? "?", style: const TextStyle(fontSize: 40, color: Colors.white))),
            const SizedBox(height: 12),
            Text(user?.email ?? "", style: TextStyle(color: Colors.grey.shade600)),
            if (user?.isPremium == true) ...[const SizedBox(height: 8), Chip(label: const Text("Pro"), avatar: const Icon(Icons.star, size: 16), backgroundColor: AppTheme.primary.withOpacity(0.1))],
          ]),
        ),
        const SizedBox(height: 32),
        TextField(controller: _usernameCtrl, decoration: const InputDecoration(labelText: "用户名", prefixIcon: Icon(Icons.person))),
        const SizedBox(height: 16),
        FilledButton(onPressed: () async {
          await auth.updateProfile(username: _usernameCtrl.text.trim());
          if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("已保存")));
        }, child: const Text("保存")),
        const Divider(height: 48),
        ListTile(leading: const Icon(Icons.workspace_premium, color: AppTheme.primary), title: const Text("会员中心"), trailing: const Icon(Icons.chevron_right), onTap: () => Navigator.pushNamed(context, "/membership")),
        ListTile(leading: const Icon(Icons.settings, color: AppTheme.primary), title: const Text("设置"), trailing: const Icon(Icons.chevron_right), onTap: () => Navigator.pushNamed(context, "/settings")),
        ListTile(leading: const Icon(Icons.logout, color: Colors.red), title: const Text("退出登录", style: TextStyle(color: Colors.red)), onTap: () async {
          await auth.logout();
          if (context.mounted) Navigator.pushReplacementNamed(context, "/login");
        }),
      ]),
    );
  }
}
