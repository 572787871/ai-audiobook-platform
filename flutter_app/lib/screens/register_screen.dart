/// 注册页面
import "package:flutter/material.dart";
import "package:provider/provider.dart";
import "../providers/auth_provider.dart";

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _emailCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscure = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    final ok = await auth.register(
      _emailCtrl.text.trim(),
      _usernameCtrl.text.trim(),
      _passwordCtrl.text,
    );
    if (!mounted) return;
    if (ok) {
      Navigator.pushReplacementNamed(context, "/home");
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(auth.error ?? "注册失败")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text("注册")),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                Icon(Icons.person_add, size: 64, color: Theme.of(context).colorScheme.primary),
                const SizedBox(height: 12),
                Text("创建账号", style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 32),
                TextFormField(
                  controller: _emailCtrl,
                  decoration: const InputDecoration(labelText: "邮箱", prefixIcon: Icon(Icons.email), border: OutlineInputBorder()),
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    if (v == null || v.isEmpty) return "请输入邮箱";
                    if (!RegExp(r"^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$").hasMatch(v)) return "邮箱格式不正确";
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _usernameCtrl,
                  decoration: const InputDecoration(labelText: "用户名", prefixIcon: Icon(Icons.person), border: OutlineInputBorder()),
                  validator: (v) => (v == null || v.length < 2) ? "用户名至少2个字符" : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordCtrl,
                  decoration: InputDecoration(
                    labelText: "密码",
                    prefixIcon: const Icon(Icons.lock),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off), onPressed: () => setState(() => _obscure = !_obscure)),
                  ),
                  obscureText: _obscure,
                  validator: (v) => (v == null || v.length < 6) ? "密码至少6位" : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _confirmCtrl,
                  decoration: const InputDecoration(labelText: "确认密码", prefixIcon: Icon(Icons.lock), border: OutlineInputBorder()),
                  obscureText: true,
                  validator: (v) => v != _passwordCtrl.text ? "两次密码不一致" : null,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton(
                    onPressed: auth.isLoading ? null : _submit,
                    child: auth.isLoading ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2)) : const Text("注册"),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(onPressed: () => Navigator.pop(context), child: const Text("已有账号？去登录")),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
