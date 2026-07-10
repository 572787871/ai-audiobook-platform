/// Kokoro 本地模型管理：下载 sherpa-onnx 官方模型包（model.onnx + voices.bin + tokens.txt），
/// 下载完成后自动校验与“注册”（无需重启 App，voices.bin 已含全部音色）。
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../models/local_tts.dart';
import 'abogen_local_service.dart';
import 'download_sources.dart';
import 'resumable_downloader.dart' hide DownloadFailedException;

class DownloadFailedException implements Exception {
  final String message;
  final int? statusCode;
  final String? responseBody;
  final String? url;
  DownloadFailedException(this.message,
      {this.statusCode, this.responseBody, this.url});
  @override
  String toString() {
    final buf = StringBuffer(message);
    if (statusCode != null) buf.write(' (HTTP $statusCode)');
    if (url != null) buf.write('\n来源: ${toSafeString(url!)}');
    if (responseBody != null && responseBody!.isNotEmpty) {
      final body = responseBody!.length > 200
          ? '${responseBody!.substring(0, 200)}…'
          : responseBody!;
      buf.write('\n响应: $body');
    }
    return buf.toString();
  }
}

class KokoroModelManager {
  /// 语音包标识（前端展示与下载登记用）。
  static const String packId = 'kokoro';

  /// 当前绑定的模型版本（对应 csukuangfj/kokoro-en-v0_19）。
  static const String version = 'v0_19';

  /// sherpa_onnx 推理所需的三个核心文件。
  static const String modelFile = 'model.onnx';
  static const String voicesFile = 'voices.bin';
  static const String tokensFile = 'tokens.txt';

  /// 核心文件清单（下载与校验遍历用）。
  static const List<String> kokoroCoreFiles = [
    modelFile,
    voicesFile,
    tokensFile,
  ];

  static Future<Directory> kokoroRoot() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, 'kokoro'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// 单个核心文件是否存在（用于诊断页，不抛异常）。
  static Future<bool> _fileExists(String name) async {
    final root = await kokoroRoot();
    return File(p.join(root.path, name)).exists();
  }

  static Future<Map<String, bool>> checkCoreFiles() async {
    final map = <String, bool>{};
    for (final f in [
      modelFile,
      voicesFile,
      tokensFile,
      'config.json',
      'tokenizer.json'
    ]) {
      map[f] = await _fileExists(f);
    }
    return map;
  }

  static Future<bool> isCoreModelDownloaded() async {
    final root = await kokoroRoot();
    for (final f in kokoroCoreFiles) {
      if (!await File(p.join(root.path, f)).exists()) return false;
    }
    return true;
  }

  /// 校验模型完整性，返回缺失/异常文件清单（空列表表示完整）。
  /// [voiceIds] 可选：额外校验某些音色的可用性（voices.bin 已含全部，故仅校验 voices.bin 存在）。
  static Future<List<String>> verifyIntegrity(
      {Set<String>? voiceIds}) async {
    final issues = <String>[];
    final root = await kokoroRoot();
    for (final f in kokoroCoreFiles) {
      final file = File(p.join(root.path, f));
      if (!await file.exists()) {
        issues.add('缺少核心文件: $f（未下载或下载失败）');
        continue;
      }
      final size = await file.length();
      if (size < 1024) {
        issues.add('文件异常: $f 过小（${size} 字节），可能下载不完整');
      }
    }
    if (!issues.any((e) => e.contains(voicesFile)) && voiceIds != null) {
      // voices.bin 已打包全部音色，无需逐一下载；仅当文件缺失时报错。
    }
    return issues;
  }

  /// 下载核心模型包（model.onnx + voices.bin + tokens.txt），
  /// 带进度回调与断点续传，完成后自动“注册”（无需重启）。
  static Future<void> downloadCoreModel({
    void Function(double progress, String label)? onProgress,
    bool Function()? shouldCancel,
  }) async {
    final root = await kokoroRoot();
    // 文件大小估算（用于进度加权）：model.onnx ~75MB, voices.bin ~数 MB, tokens.txt 小。
    const weights = <String, double>{
      modelFile: 0.80,
      voicesFile: 0.15,
      tokensFile: 0.05,
    };
    double acc = 0;
    for (final f in kokoroCoreFiles) {
      if (shouldCancel?.call() == true) {
        throw DownloadFailedException('下载已取消');
      }
      final dest = File(p.join(root.path, f));
      final url = kokoroCoreUrl(f);
      onProgress?.call(acc, '下载 $f');
      await ResumableDownloader.download(
        urls: [url],
        outputPath: dest.path,
        onProgress: (p) {
          onProgress?.call(acc + weights[f]! * p.fraction, '下载 $f');
        },
        shouldCancel: shouldCancel,
      );
      acc += weights[f]!;
      onProgress?.call(acc, '校验 $f');
      // 基础完整性校验
      final size = await dest.length();
      if (size < 1024) {
        throw DownloadFailedException('$f 下载后文件过小，可能不完整',
            url: url);
      }
    }
    onProgress?.call(1.0, '完成');
    // 下载完成：模型已就绪，无需额外注册步骤（voices.bin 含全部音色）。
  }

  /// 诊断信息：返回当前状态摘要。
  static Future<Map<String, dynamic>> diagnostics() async {
    final files = await checkCoreFiles();
    final root = await kokoroRoot();
    final voices = AbogenLocalService.kokoroVoices(
        downloaded: {}); // 仅用于列出可用音色数量
    return {
      'root': root.path,
      'files': files,
      'coreReady': await isCoreModelDownloaded(),
      'voiceCount': voices.length,
    };
  }
}
