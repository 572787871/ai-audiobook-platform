import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/local_tts_provider.dart';
import '../services/local_import_service.dart';
import '../services/local_tts_service.dart';
import 'local_generation_screen.dart';

class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});
  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  final _titleCtrl = TextEditingController();
  final _authorCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  File? _selectedFile;
  String? _fileName;

  // 状态机：idle / picking / importing / success / error
  bool _busy = false; // 防重复点击/提交的总开关
  ImportStage _stage = ImportStage.idle;
  double _fraction = 0.0;
  String? _statusLabel;
  String? _errorMsg;
  String? _errorDetail;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _authorCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  void _resetError() {
    if (_errorMsg != null || _errorDetail != null) {
      setState(() {
        _errorMsg = null;
        _errorDetail = null;
      });
    }
  }

  Future<void> _pickFile() async {
    if (_busy) return;
    _resetError();
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['txt', 'md', 'pdf', 'epub', 'docx'],
      );
      if (result != null && result.files.single.path != null) {
        setState(() {
          _selectedFile = File(result.files.single.path!);
          _fileName = result.files.single.name;
          if (_titleCtrl.text.isEmpty) {
            _titleCtrl.text = _fileName!.replaceAll(RegExp(r'\.[^.]+$'), '');
          }
        });
      }
    } catch (e) {
      setState(() {
        _errorMsg = '选择文件失败：$e';
      });
    }
  }

  Future<void> _submit() async {
    if (_busy) return; // 防重复提交
    if (_selectedFile == null) {
      setState(() => _errorMsg = '请先选择文件');
      return;
    }
    if (_titleCtrl.text.trim().isEmpty) {
      setState(() => _errorMsg = '请填写标题');
      return;
    }

    setState(() {
      _busy = true;
      _stage = ImportStage.copying;
      _fraction = 0.0;
      _statusLabel = '准备导入…';
      _errorMsg = null;
      _errorDetail = null;
    });

    try {
      final book = await LocalImportService.import(
        sourceFile: _selectedFile!,
        title: _titleCtrl.text.trim(),
        author: _authorCtrl.text.trim().isEmpty ? null : _authorCtrl.text.trim(),
        description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        onProgress: (p) {
          if (mounted) {
            setState(() {
              _stage = p.stage;
              _fraction = p.fraction;
              _statusLabel = p.label;
            });
          }
        },
      );

      if (!mounted) return;

      // 读取正文用于本地生成（不依赖网络）
      String sourceText = '';
      try {
        sourceText = await LocalTtsService.readTextFile(_selectedFile!);
      } catch (_) {
        sourceText = '';
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('导入成功，进入书籍详情')));

      // 防返回栈堆叠：替换当前页，进入书籍详情
      Navigator.pushReplacementNamed(
        context,
        '/book',
        arguments: book.id,
      );
    } on ImportException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _stage = ImportStage.failed;
        _errorMsg = e.message;
        _errorDetail = e.detail;
        _statusLabel = null;
      });
    } catch (e, st) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _stage = ImportStage.failed;
        _errorMsg = '导入异常：$e';
        _errorDetail = st.toString();
        _statusLabel = null;
      });
    }
  }

  String _modeLabel(GenerationMode mode) => switch (mode) {
        GenerationMode.auto => '本地生成：正文只保存在这台 iPhone',
        GenerationMode.local => '本地生成：正文仅在 iPhone 上处理',
        GenerationMode.cloud => '云端已关闭：会按本地生成处理',
      };

  String _voiceName(LocalTtsProvider tts) {
    for (final voice in tts.voices) {
      if (voice.voiceId == tts.defaultVoiceId) return voice.displayName;
    }
    return tts.defaultVoiceId;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final importing = _busy && _stage != ImportStage.failed;
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: SafeArea(
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? AppTheme.bgDark : AppTheme.bgLight,
              border: Border(
                  bottom: BorderSide(
                      color: cs.onSurface.withValues(alpha: 0.06), width: 0.5)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(children: [
              IconButton(
                  icon: Icon(Icons.arrow_back, color: cs.onSurface),
                  onPressed: _busy ? null : () => Navigator.pop(context)),
              Text('上传有声书',
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface)),
            ]),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          GestureDetector(
            onTap: _busy ? null : _pickFile,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: double.infinity,
              height: 180,
              decoration: BoxDecoration(
                color: isDark ? AppTheme.cardDark : Colors.white,
                borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                border: Border.all(
                  color: _errorMsg != null && _selectedFile == null
                      ? AppTheme.danger
                      : (_selectedFile != null
                          ? AppTheme.success
                          : cs.primary.withValues(alpha: 0.2)),
                  width: 1.5,
                ),
                boxShadow:
                    AppTheme.cardShadow(cs.onSurface, opacity: 0.04, blur: 12),
              ),
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: _selectedFile != null
                            ? AppTheme.success.withValues(alpha: 0.1)
                            : cs.primary.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _selectedFile != null
                            ? Icons.check_rounded
                            : Icons.upload_file_rounded,
                        size: 32,
                        color: _selectedFile != null
                            ? AppTheme.success
                            : cs.primary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(_fileName ?? '点击选择文件',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: _selectedFile != null
                                ? cs.onSurface
                                : cs.onSurface.withValues(alpha: 0.4))),
                    const SizedBox(height: 6),
                    Text('支持 txt / md / pdf / epub / docx',
                        style: TextStyle(
                            fontSize: 12,
                            color: cs.onSurface.withValues(alpha: 0.3))),
                  ]),
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.cardDark : Colors.white,
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
              boxShadow:
                  AppTheme.cardShadow(cs.onSurface, opacity: 0.04, blur: 12),
            ),
            child: Column(children: [
              TextField(
                  controller: _titleCtrl,
                  decoration: const InputDecoration(
                      labelText: '标题', prefixIcon: Icon(Icons.title_rounded))),
              const SizedBox(height: 16),
              TextField(
                  controller: _authorCtrl,
                  decoration: const InputDecoration(
                      labelText: '作者（可选）',
                      prefixIcon: Icon(Icons.person_outline_rounded))),
              const SizedBox(height: 16),
              TextField(
                  controller: _descCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                      labelText: '简介（可选）',
                      prefixIcon: Icon(Icons.description_outlined))),
            ]),
          ),
          // 进度条
          if (importing) ...[
            const SizedBox(height: 16),
            LinearProgressIndicator(value: _fraction),
            const SizedBox(height: 8),
            Text(_statusLabel ?? '处理中…',
                style: TextStyle(
                    fontSize: 13, color: cs.onSurface.withValues(alpha: 0.65))),
          ],
          if (_errorMsg != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: AppTheme.danger.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(Icons.error_outline_rounded,
                          color: AppTheme.danger, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(_errorMsg!,
                              style: TextStyle(
                                  fontSize: 13, color: AppTheme.danger))),
                    ]),
                    if (_errorDetail != null) ...[
                      const SizedBox(height: 6),
                      Text(_errorDetail!,
                          style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.danger.withValues(alpha: 0.7))),
                    ],
                  ]),
            ),
            // 失败后可再次尝试
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _busy
                    ? null
                    : () => setState(() {
                          _errorMsg = null;
                          _errorDetail = null;
                          _stage = ImportStage.idle;
                        }),
                child: const Text('重试'),
              ),
            ),
          ],
          const SizedBox(height: 24),
          Consumer<LocalTtsProvider>(
            builder: (context, tts, _) => Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.cardDark : Colors.white,
                borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                boxShadow:
                    AppTheme.cardShadow(cs.onSurface, opacity: 0.04, blur: 12),
              ),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(Icons.tune_rounded, color: cs.primary),
                      const SizedBox(width: 8),
                      const Text('生成设置',
                          style: TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 16)),
                      const Spacer(),
                      TextButton(
                          onPressed: _busy
                              ? null
                              : () => Navigator.pushNamed(context, '/voice-packs'),
                          child: const Text('修改')),
                    ]),
                    const SizedBox(height: 8),
                    Text(_modeLabel(tts.mode),
                        style: TextStyle(
                            fontSize: 13,
                            color: cs.onSurface.withValues(alpha: 0.65))),
                    const SizedBox(height: 6),
                    Text('默认音色：${_voiceName(tts)}',
                        style: TextStyle(
                            fontSize: 13,
                            color: cs.onSurface.withValues(alpha: 0.65))),
                  ]),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: FilledButton.icon(
              onPressed: _busy ? null : _submit,
              style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primaryLight,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd))),
              icon: importing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.auto_awesome_rounded),
              label: Text(
                  importing ? (_statusLabel ?? '处理中…') : '导入并进入详情',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(height: 32),
        ]),
      ),
    );
  }
}
