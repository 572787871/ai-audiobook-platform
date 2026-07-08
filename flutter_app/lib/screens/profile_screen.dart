/// 个人资料页
import "package:flutter/material.dart";
import "package:provider/provider.dart";
import "../providers/auth_provider.dart";

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _usernameCtrl = TextEditingController();

  @override
  void dispose() {
    _usernameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    if (user != null && _usernameCtrl.text.isEmpty) _usernameCtrl.text = user.username;
    return Scaffold(
      appBar: AppBar(title: const Text("个人资料")),
      body: ListView(padding: const EdgeInsets.all(24), children: [
        CircleAvatar(radius: 60,
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            child: Text(user?.username.substring(0, 1).toUpperCase() ?? "?", style: const TextStyle(fontSize: 48))),
        const SizedBox(height: 24),
        Text("邮箱：" + (user?.email ?? ""), style: TextStyle(color: Colors.grey.shade600)),
        if (user?.isPremium == true)
          const Padding(padding: EdgeInsets.only(top: 8), child: Chip(label: Text("会员"), avatar: Icon(Icons.star))),
        const SizedBox(height: 24),
        TextField(controller: _usernameCtrl, decoration: const InputDecoration(labelText: "用户名", border: OutlineInputBorder())),
        const SizedBox(height: 16),
        FilledButton(onPressed: () async {
          await auth.updateProfile(username: _usernameCtrl.text.trim());
          if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("已保存")));
        }, child: const Text("保存")),
        const SizedBox(height: 32),
        ListTile(leading: const Icon(Icons.star), title: const Text("会员"), trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.pushNamed(context, "/membership")),
        ListTile(leading: const Icon(Icons.settings), title: const Text("设置"), trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.pushNamed(context, "/settings")),
        ListTile(leading: const Icon(Icons.logout, color: Colors.red), title: const Text("退出登录", style: TextStyle(color: Colors.red)),
            onTap: () async { await auth.logout(); if (context.mounted) Navigator.pushReplacementNamed(context, "/login"); }),
      ]),
    );
  }
}
