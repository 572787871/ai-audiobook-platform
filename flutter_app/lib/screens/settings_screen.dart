/// 设置页
import "package:flutter/material.dart";
import "package:provider/provider.dart";
import "../providers/auth_provider.dart";
import "../services/api_service.dart";

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _baseUrlCtrl;
  ThemeMode _themeMode = ThemeMode.system;

  @override
  void initState() {
    super.initState();
    _baseUrlCtrl = TextEditingController(text: ApiService.baseUrl);
  }

  @override
  void dispose() {
    _baseUrlCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text("设置")),
      body: ListView(padding: const EdgeInsets.all(24), children: [
        const Text("服务器", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 12),
        TextField(
          controller: _baseUrlCtrl,
          decoration: const InputDecoration(labelText: "后端地址", prefixIcon: Icon(Icons.dns), border: OutlineInputBorder(), helperText: "修改后自动生效"),
        ),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          TextButton(onPressed: () async {
            await ApiService.setBaseUrl(_baseUrlCtrl.text.trim());
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("已保存")));
            }
          }, child: const Text("保存地址")),
        ]),
        const SizedBox(height: 24),
        const Text("外观", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        RadioListTile<ThemeMode>(title: const Text("跟随系统"), value: ThemeMode.system, groupValue: _themeMode, onChanged: (v) => setState(() => _themeMode = v!)),
        RadioListTile<ThemeMode>(title: const Text("浅色"), value: ThemeMode.light, groupValue: _themeMode, onChanged: (v) => setState(() => _themeMode = v!)),
        RadioListTile<ThemeMode>(title: const Text("深色"), value: ThemeMode.dark, groupValue: _themeMode, onChanged: (v) => setState(() => _themeMode = v!)),
        const SizedBox(height: 24),
        const Text("账号", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ListTile(leading: const Text("当前账号"), title: Text(auth.user?.email ?? "-")),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.logout, color: Colors.red),
          title: const Text("退出登录", style: TextStyle(color: Colors.red)),
          onTap: () async {
            await auth.logout();
            if (context.mounted) Navigator.pushReplacementNamed(context, "/login");
          },
        ),
        const SizedBox(height: 24),
        const Text("关于", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ListTile(title: const Text("版本"), trailing: const Text("0.1.0")),
        ListTile(title: const Text("技术栈"), subtitle: const Text("Flutter + FastAPI + PostgreSQL + Celery + Redis")),
      ]),
    );
  }
}
