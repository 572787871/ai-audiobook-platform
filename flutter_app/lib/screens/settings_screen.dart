import "package:flutter/material.dart";
import "package:provider/provider.dart";
import "../providers/auth_provider.dart";
import "../services/api_service.dart";
import "../theme/app_theme.dart";

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _baseUrlCtrl;

  @override
  void initState() { super.initState(); _baseUrlCtrl = TextEditingController(text: ApiService.baseUrl); }
  @override
  void dispose() { _baseUrlCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text("设置")),
      body: ListView(padding: const EdgeInsets.all(24), children: [
        const Text("服务器", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: TextField(controller: _baseUrlCtrl, decoration: const InputDecoration(labelText: "API 地址", prefixIcon: Icon(Icons.dns)))),
          const SizedBox(width: 8),
          FilledButton(onPressed: () async {
            await ApiService.setBaseUrl(_baseUrlCtrl.text.trim());
            if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("已保存")));
          }, child: const Text("保存")),
        ]),
        const Divider(height: 40),
        const Text("账号", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 8),
        ListTile(title: const Text("当前账号"), subtitle: Text(auth.user?.email ?? "-"), leading: const Icon(Icons.person)),
        ListTile(title: const Text("版本"), trailing: const Text("0.1.0"), leading: const Icon(Icons.info_outline)),
        const Divider(height: 40),
        ListTile(leading: const Icon(Icons.logout, color: Colors.red), title: const Text("退出登录", style: TextStyle(color: Colors.red)), onTap: () async {
          await auth.logout();
          if (context.mounted) Navigator.pushReplacementNamed(context, "/login");
        }),
      ]),
    );
  }
}
