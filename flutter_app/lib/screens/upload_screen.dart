/// 上传有声书页面：选择文件 -> 填表 -> 上传 -> 创建任务
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

  @override
  void dispose() {
    _titleCtrl.dispose();
    _authorCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ["txt", "md", "pdf", "epub"]);
    if (result != null && result.files.single.path != null) {
      setState(() {
        _selectedFile = File(result.files.single.path!);
        _fileName = result.files.single.name;
        if (_titleCtrl.text.isEmpty) {
          _titleCtrl.text = _fileName!.replaceAll(RegExp(r"\.[^.]+$"), "");
        }
      });
    }
  }

  Future<void> _submit() async {
    if (_selectedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("请先选择文件")));
      return;
    }
    if (_titleCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("请填写标题")));
      return;
    }
    setState(() => _uploading = true);
    final bp = context.read<BookProvider>();
    final book = await bp.uploadBook(
      _selectedFile!,
      _titleCtrl.text.trim(),
      author: _authorCtrl.text.trim().isEmpty ? null : _authorCtrl.text.trim(),
      description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
    );
    setState(() => _uploading = false);
    if (book != null) {
      // 自动创建 TTS 任务
      await bp.createTask(book.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("上传成功，TTS 任务已创建")));
        Navigator.pop(context);
      }
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(bp.error ?? "上传失败")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("上传有声书")),
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
                height: 120,
                decoration: BoxDecoration(border: Border.all(color: Colors.grey, style: BorderStyle.solid, width: 1), borderRadius: BorderRadius.circular(12)),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(_selectedFile == null ? Icons.upload_file : Icons.check_circle, size: 48, color: _selectedFile == null ? Colors.grey : Colors.green),
                  const SizedBox(height: 8),
                  Text(_fileName ?? "点击选择文件", style: TextStyle(color: _selectedFile == null ? Colors.grey : Colors.black)),
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
            const SizedBox(height: 32),
            SizedBox(width: double.infinity, height: 50,
              child: FilledButton(
                onPressed: _uploading ? null : _submit,
                child: _uploading
                    ? Row(mainAxisAlignment: MainAxisAlignment.center, children: const [SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)), SizedBox(width: 12), Text("上传中...")])
                    : const Text("上传并创建任务"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
