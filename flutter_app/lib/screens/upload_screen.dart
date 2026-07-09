import "dart:io";
import "package:flutter/material.dart";
import "package:file_picker/file_picker.dart";
import "package:provider/provider.dart";
import "../providers/book_provider.dart";

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
  bool _uploading = false;
  String? _fileName;
  String? _errorMsg;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _authorCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    debugPrint("UploadScreen _pickFile started");
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ["txt", "md", "pdf", "epub"],
      );
      if (result != null && result.files.single.path != null) {
        debugPrint("UploadScreen file picked: \${result.files.single.name}");
        setState(() {
          _selectedFile = File(result.files.single.path!);
          _fileName = result.files.single.name;
          if (_titleCtrl.text.isEmpty) {
            _titleCtrl.text = _fileName!.replaceAll(RegExp(r"\.[^.]+$"), "");
          }
          _errorMsg = null;
        });
      }
    } catch (e) {
      debugPrint("UploadScreen pickFile error: $e");
      setState(() => _errorMsg = "选择文件失败: $e");
    }
    debugPrint("UploadScreen _pickFile ended");
  }

  Future<void> _submit() async {
    if (_selectedFile == null) {
      setState(() => _errorMsg = "请先选择文件");
      return;
    }
    if (_titleCtrl.text.isEmpty) {
      setState(() => _errorMsg = "请填写标题");
      return;
    }
    setState(() { _uploading = true; _errorMsg = null; });
    try {
      final bp = context.read<BookProvider>();
      final book = await bp.uploadBook(
        _selectedFile!,
        _titleCtrl.text.trim(),
        author: _authorCtrl.text.trim().isEmpty ? null : _authorCtrl.text.trim(),
        description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
      );
      if (book == null) {
        setState(() {
          _errorMsg = bp.error ?? "上传失败，请检查服务器地址";
          _uploading = false;
        });
        return;
      }
      await bp.createTask(book.id);
      if (context.mounted) {
        debugPrint("UploadScreen upload success, popping with true");
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("上传成功，正在生成有声书")));
        if (context.mounted) {
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      debugPrint("UploadScreen upload exception: $e");
      setState(() {
        _errorMsg = "上传异常: $e";
        _uploading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text("上传有声书"),
        leading: IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: _uploading ? null : _pickFile,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: double.infinity,
                height: 140,
                decoration: BoxDecoration(
                  border: Border.all(color: _errorMsg != null && _selectedFile == null ? Colors.red.shade300 : Colors.grey.shade300, width: 1.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(_selectedFile == null ? Icons.upload_file : Icons.check_circle, size: 48,
                      color: _selectedFile == null ? (_errorMsg != null ? Colors.red : Colors.grey) : Colors.green),
                  const SizedBox(height: 8),
                  Text(_fileName ?? "点击选择文件", style: TextStyle(color: _selectedFile == null ? Colors.grey : Colors.black87)),
                  const Text("支持 txt / md / pdf / epub", style: TextStyle(fontSize: 12, color: Colors.grey)),
                ]),
              ),
            ),
            const SizedBox(height: 24),
            TextField(controller: _titleCtrl, decoration: const InputDecoration(labelText: "标题", prefixIcon: Icon(Icons.title), border: OutlineInputBorder())),
            const SizedBox(height: 16),
            TextField(controller: _authorCtrl, decoration: const InputDecoration(labelText: "作者（可选）", prefixIcon: Icon(Icons.person_outline), border: OutlineInputBorder())),
            const SizedBox(height: 16),
            TextField(controller: _descCtrl, maxLines: 3, decoration: const InputDecoration(labelText: "简介（可选）", prefixIcon: Icon(Icons.description), border: OutlineInputBorder())),
            if (_errorMsg != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.red.shade200)),
                child: Row(children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 20),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_errorMsg!, style: const TextStyle(color: Colors.red, fontSize: 13))),
                ]),
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(width: double.infinity, height: 50,
              child: FilledButton(
                style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                onPressed: _uploading ? null : _submit,
                child: _uploading
                    ? Row(mainAxisAlignment: MainAxisAlignment.center, children: const [
                        SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                        SizedBox(width: 12), Text("上传中..."),
                      ])
                    : const Text("上传并生成有声书"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
