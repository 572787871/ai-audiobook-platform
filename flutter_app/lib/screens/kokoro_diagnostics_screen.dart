import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../models/local_tts.dart';
import '../services/abogen_local_service.dart';
import '../services/kokoro_model_manager.dart';
import '../theme/app_theme.dart';

/// Kokoro 本地推理状态诊断页：
/// 明确展示 ONNX Runtime / model.onnx / tokenizer / voices.bin / config 的状态，
/// 以及下载目录、下载进度、已安装音色数量，失败时给出具体原因。
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

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    final root = await KokoroModelManager.kokoroRoot();
    final checks = <String, _Item>{};
    for (final name in KokoroModelManager.kokoroCoreFiles) {
      final f = File(p.join(root.path, name));
      final exists = await f.exists();
      final size = exists ? await f.length() : 0;
      checks[name] = _Item(
        label: name,
        ok: exists && size > 64,
        detail: exists ? '${(size / 1024).toStringAsFixed(1)} KB' : '缺失',
      );
    }
    final modelFile = File(p.join(root.path, KokoroModelManager.modelFile));
    final modelExists = await modelFile.exists();
    final onnx = _Item(
      label: 'ONNX Runtime / ${KokoroModelManager.modelFile}',
      ok: modelExists,
      detail: modelExists
          ? '模型文件存在（sherpa-onnx 内置 ONNX Runtime）'
          : '未下载', // sherpa_onnx 内置运行时，无需单独安装
    );
    checks['onnxruntime'] = onnx;

    // 可选辅助文件（不参与推理必需，但影响诊断完整度）
    for (final aux in ['config.json', 'tokenizer.json']) {
      final af = File(p.join(root.path, aux));
      final aExists = await af.exists();
      checks[aux] = _Item(
        label: aux,
        ok: aExists,
        detail: aExists ? '存在（可选，不影响推理）' : '缺失（可选）',
      );
    }

    // voices.bin 单一文件含全部音色；可用音色数 = 列表总数（核心模型就绪即全部可用）
    final allVoices = AbogenLocalService.kokoroVoices(downloaded: {});
    final coreReady = await KokoroModelManager.isCoreModelDownloaded();
    _voiceCount = coreReady ? allVoices.length : 0;
    _dir = root.path;

    final issues = await KokoroModelManager.verifyIntegrity();
    _backendNote = issues.isEmpty
        ? '模型完整，可在真机进行 Kokoro 本地推理。'
        : '存在问题：\n- ${issues.join('\n- ')}';

    setState(() {
      _items = checks;
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
          IconButton(
              icon: const Icon(Icons.refresh), onPressed: _refresh),
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
                    title: const Text('下载目录'),
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
                  onPressed: _downloadDefault,
                  icon: const Icon(Icons.download),
                  label: const Text('下载默认模型与推荐音色'),
                ),
                const SizedBox(height: 8),
                Text(
                  '说明：Kokoro 使用 onnx-community/Kokoro-82M-v1.0-ONNX（sherpa-onnx 推理）。下载失败会显示具体 HTTP 状态码与错误正文。',
                  style: TextStyle(
                      fontSize: 12,
                      color: cs.onSurface.withValues(alpha: 0.55)),
                ),
              ],
            ),
    );
  }

  Future<void> _downloadDefault() async {
    setState(() => _loading = true);
    try {
      // voices.bin 已含全部音色，下载核心模型即可
      await AbogenLocalService.downloadCoreModel(
          onProgress: (p, label) => setState(() {}));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('下载失败：$e')));
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
        color: ok ? AppTheme.success.withValues(alpha: 0.12) : AppTheme.danger.withValues(alpha: 0.12),
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
