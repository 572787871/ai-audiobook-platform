import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import '../models/local_tts.dart';
import '../services/abogen_local_service.dart';
import '../services/kokoro_model_manager.dart';
import '../theme/app_theme.dart';

/// Kokoro 本地推理状态诊断页：
/// 展示模型来源（App 内置）、Bundle 资源存在与大小、本地安装目录与大小、
/// 安装状态、最后复制错误，以及已安装音色数量。
class KokoroDiagnosticsScreen extends StatefulWidget {
  const KokoroDiagnosticsScreen({super.key});
  @override
  State<KokoroDiagnosticsScreen> createState() => _KokoroDiagnosticsScreenState();
}

class _KokoroDiagnosticsScreenState extends State<KokoroDiagnosticsScreen> {
  Map<String, _Item> _items = {};
  int _voiceCount = 0;
  String _dir = '';
  bool _loading = true;
  String _backendNote = '';
  String _source = '';
  String _installError = '';
  Map<String, int> _bundleSizes = {};
  Map<String, int> _localSizes = {};

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    final root = await KokoroModelManager.kokoroRoot();
    final diag = await KokoroModelManager.diagnostics();
    final checks = <String, _Item>{};

    final bundleSizes = Map<String, int>.from(diag['bundleSizes'] as Map);
    final localSizes = Map<String, int>.from(diag['localSizes'] as Map);
    final coreReady = diag['coreReady'] as bool;

    for (final name in KokoroModelManager.kokoroCoreFiles) {
      final f = File(p.join(root.path, name));
      final exists = await f.exists();
      final size = exists ? await f.length() : 0;
      final bundleSize = bundleSizes[name] ?? -1;
      final bundleOk = bundleSize > 0;
      final detail = exists
          ? '${(size / 1024 / 1024).toStringAsFixed(1)} MB'
          : '缺失';
      final bundleDetail =
          bundleOk ? '${(bundleSize / 1024 / 1024).toStringAsFixed(1)} MB' : '缺失';
      checks[name] = _Item(
        label: name,
        ok: exists && size > 64,
        detail: '本地: $detail · Bundle: $bundleDetail',
      );
    }

    // Bundle 资源存在性（直接从 asset 探测）
    final bundleChecks = <String, bool>{
      for (final a in KokoroModelManager.bundledAssetPaths)
        p.basename(a): await KokoroModelManager.bundledExists(a),
    };

    // 已安装音色数
    final allVoices = AbogenLocalService.kokoroVoices(downloaded: {});
    _voiceCount = coreReady ? allVoices.length : 0;
    _dir = root.path;
    _source = diag['source'] as String? ?? '未安装';
    _installError = (diag['installError'] as String?) ?? '';
    _bundleSizes = bundleSizes;
    _localSizes = localSizes;

    final issues = await KokoroModelManager.verifyIntegrity();
    _backendNote = issues.isEmpty
        ? '模型完整，可在真机进行 Kokoro 本地推理（模型来源：$_source）。'
        : '存在问题：\n- ${issues.join('\n- ')}';

    final bundleAllOk = bundleChecks.values.every((v) => v);

    setState(() {
      _items = {
        ...checks,
        'bundle_model': _Item(
          label: 'Bundle model.onnx',
          ok: bundleChecks['model.onnx'] ?? false,
          detail: bundleChecks['model.onnx'] ?? false
              ? '存在 (${(_bundleSizes['model.onnx'] ?? 0) / 1024 / 1024 ~/ 1} MB)'
              : '缺失（请确认已打包 assets/kokoro/）',
        ),
        'bundle_voices': _Item(
          label: 'Bundle voices.bin',
          ok: bundleChecks['voices.bin'] ?? false,
          detail: bundleChecks['voices.bin'] ?? false
              ? '存在 (${(_bundleSizes['voices.bin'] ?? 0) / 1024 ~/ 1} KB)'
              : '缺失（请确认已打包 assets/kokoro/）',
        ),
        'bundle_tokens': _Item(
          label: 'Bundle tokens.txt',
          ok: bundleChecks['tokens.txt'] ?? false,
          detail: bundleChecks['tokens.txt'] ?? false
              ? '存在'
              : '缺失（请确认已打包 assets/kokoro/）',
        ),
        'source': _Item(
          label: '模型来源',
          ok: coreReady,
          detail: _source,
        ),
        'install_status': _Item(
          label: '安装状态',
          ok: coreReady,
          detail: coreReady ? '已安装（可离线使用）' : '未安装',
        ),
        if (_installError.isNotEmpty)
          'install_error': _Item(
            label: '最后复制错误',
            ok: false,
            detail: _installError,
          ),
        'bundle_all': _Item(
          label: 'App Bundle 资源完整性',
          ok: bundleAllOk,
          detail: bundleAllOk ? '三项资源均已随 App 打包' : '存在缺失资源',
        ),
      };
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kokoro 状态'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _refresh),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _Banner(note: _backendNote),
                const SizedBox(height: 16),
                Text('模型文件',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 16)),
                const SizedBox(height: 8),
                ..._items.values.map((e) => _Row(item: e)),
                const SizedBox(height: 16),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.folder_open_outlined),
                    title: const Text('本地安装目录'),
                    subtitle: Text(_dir,
                        style: TextStyle(
                            fontSize: 12,
                            color: cs.onSurface.withValues(alpha: 0.6))),
                  ),
                ),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.record_voice_over_outlined),
                    title: const Text('已安装音色数量'),
                    trailing: Text('$_voiceCount',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 18)),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _reinstall,
                  icon: const Icon(Icons.install_mobile_outlined),
                  label: const Text('重新安装内置模型'),
                ),
                const SizedBox(height: 8),
                Text(
                  '说明：Kokoro 模型（model.onnx + voices.bin + tokens.txt）已随 App 内置，'
                  '首次启动自动从 Bundle 复制到本地，无需联网。飞行模式下也可正常试听与生成。',
                  style: TextStyle(
                      fontSize: 12,
                      color: cs.onSurface.withValues(alpha: 0.55)),
                ),
              ],
            ),
    );
  }

  Future<void> _reinstall() async {
    setState(() => _loading = true);
    try {
      await AbogenLocalService.installBundledModel(
          onProgress: (p) => setState(() {}));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('安装失败：$e')));
      }
    } finally {
      await _refresh();
    }
  }
}

class _Item {
  final String label;
  final bool ok;
  final String detail;
  _Item({required this.label, required this.ok, required this.detail});
}

class _Row extends StatelessWidget {
  final _Item item;
  const _Row({required this.item});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: ListTile(
        leading: Icon(
          item.ok ? Icons.check_circle_rounded : Icons.error_outline_rounded,
          color: item.ok ? AppTheme.success : AppTheme.danger,
        ),
        title: Text(item.label),
        subtitle: Text(item.detail),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  final String note;
  const _Banner({required this.note});
  @override
  Widget build(BuildContext context) {
    final ok = !note.contains('存在问题');
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ok
            ? AppTheme.success.withValues(alpha: 0.12)
            : AppTheme.danger.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(ok ? Icons.verified_rounded : Icons.warning_amber_rounded,
              color: ok ? AppTheme.success : AppTheme.danger),
          const SizedBox(width: 10),
          Expanded(
            child: Text(note,
                style: TextStyle(
                    color: ok ? AppTheme.success : AppTheme.danger,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
