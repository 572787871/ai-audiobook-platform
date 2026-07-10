/// Kokoro 本地模型管理：
/// 默认从 App Bundle 内置模型安装（model.onnx + voices.bin + tokens.txt），
/// 无需联网。网络下载仅作为可选兜底（默认禁用）。
import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
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

  /// 版本标记文件名（位于 Documents/kokoro/ 下）。
  static const String versionMarker = '.bundled_model_version';

  /// 核心文件清单（安装与校验遍历用）。
  static const List<String> kokoroCoreFiles = [
    modelFile,
    voicesFile,
    tokensFile,
  ];

  /// Bundle 内资源路径（pubspec.yaml 已声明）。
  static const List<String> bundledAssetPaths = [
    'assets/kokoro/model.onnx',
    'assets/kokoro/voices.bin',
    'assets/kokoro/tokens.txt',
  ];

  /// 合理最小文件大小阈值（防止损坏/空文件被误判为已安装）。
  static const int minModelBytes = 1024 * 1024; // 1MB
  static const int minVoicesBytes = 1024; // 1KB
  static const int minTokensBytes = 64; // 64B

  static int _minBytes(String name) {
    if (name == modelFile) return minModelBytes;
    if (name == voicesFile) return minVoicesBytes;
    if (name == tokensFile) return minTokensBytes;
    return 1024;
  }

  static Future<Directory> kokoroRoot() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, 'kokoro'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// 读取 Bundle 资源大小（用于校验，不把整个文件载入内存）。
  static Future<int> _bundleSize(String assetPath) async {
    final data = await rootBundle.load(assetPath);
    return data.lengthInBytes;
  }

  /// 单个本地核心文件是否存在（用于诊断页，不抛异常）。
  static Future<bool> _fileExists(String name) async {
    final root = await kokoroRoot();
    return File(p.join(root.path, name)).exists();
  }

  /// Bundle 内某资源是否存在（用于诊断页）。
  static Future<bool> bundledExists(String assetPath) async {
    try {
      await rootBundle.load(assetPath);
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<Map<String, bool>> checkCoreFiles() async {
    final map = <String, bool>{};
    for (final f in kokoroCoreFiles) {
      map[f] = await _fileExists(f);
    }
    return map;
  }

  static Future<Map<String, int>> localFileSizes() async {
    final map = <String, int>{};
    final root = await kokoroRoot();
    for (final f in kokoroCoreFiles) {
      final file = File(p.join(root.path, f));
      map[f] = await file.exists() ? await file.length() : 0;
    }
    return map;
  }

  static Future<Map<String, int>> bundleFileSizes() async {
    final map = <String, int>{};
    for (final asset in bundledAssetPaths) {
      final name = p.basename(asset);
      try {
        map[name] = await _bundleSize(asset);
      } catch (_) {
        map[name] = -1; // 不存在
      }
    }
    return map;
  }

  static Future<bool> isCoreModelDownloaded() async => isBundledInstalled();

  /// 判断内置模型是否已正确安装（文件存在、大小与 Bundle 一致、版本号匹配）。
  static Future<bool> isBundledInstalled() async {
    final root = await kokoroRoot();
    // 版本标记
    final marker = File(p.join(root.path, versionMarker));
    if (!await marker.exists()) return false;
    final markerVer = (await marker.readAsString()).trim();
    if (markerVer != version) return false;
    // 三文件存在且大小匹配
    for (var i = 0; i < kokoroCoreFiles.length; i++) {
      final name = kokoroCoreFiles[i];
      final asset = bundledAssetPaths[i];
      final file = File(p.join(root.path, name));
      if (!await file.exists()) return false;
      final size = await file.length();
      if (size < _minBytes(name)) return false;
      int bundleSize;
      try {
        bundleSize = await _bundleSize(asset);
      } catch (_) {
        return false;
      }
      if (size != bundleSize) return false;
    }
    return true;
  }

  /// 校验模型完整性，返回缺失/异常文件清单（空列表表示完整）。
  static Future<List<String>> verifyIntegrity(
      {Set<String>? voiceIds}) async {
    final issues = <String>[];
    final root = await kokoroRoot();
    for (final f in kokoroCoreFiles) {
      final file = File(p.join(root.path, f));
      if (!await file.exists()) {
        issues.add('缺少核心文件: $f（未安装或安装失败）');
        continue;
      }
      final size = await file.length();
      if (size < _minBytes(f)) {
        issues.add('文件异常: $f 过小（${size} 字节），可能安装不完整');
      }
    }
    return issues;
  }

  /// 从 App Bundle 复制内置模型到 Documents/kokoro。
  /// 流程：rootBundle.load → 写 .part → 原子重命名 → 写版本标记 → 校验。
  /// 跳过条件：已安装且大小/版本一致。
  static Future<void> installBundledModel({
    void Function(double progress)? onProgress,
  }) async {
    final root = await kokoroRoot();

    // 跳过已安装
    if (await isBundledInstalled()) {
      onProgress?.call(1.0);
      return;
    }

    String? lastError;
    try {
      final total = bundledAssetPaths.length;
      var done = 0;
      for (var i = 0; i < total; i++) {
        final asset = bundledAssetPaths[i];
        final name = kokoroCoreFiles[i];
        onProgress?.call(done / total, '安装 $name');

        final data = await rootBundle.load(asset);
        final bytes = data.buffer.asUint8List(
          data.offsetInBytes,
          data.lengthInBytes,
        );

        final part = File(p.join(root.path, '$name.part'));
        final dest = File(p.join(root.path, name));

        // 写入临时文件
        final sink = part.openWrite();
        sink.add(bytes);
        await sink.flush();
        await sink.close();

        // 原子重命名
        if (await dest.exists()) await dest.delete();
        await part.rename(dest.path);

        // 校验大小
        final size = await dest.length();
        final expected = bytes.length;
        if (size != expected) {
          throw Exception('$name 写入后大小不一致（期望 $expected，实际 $size）');
        }
        if (size < _minBytes(name)) {
          throw Exception('$name 安装后过小（${size} 字节），可能资源损坏');
        }

        done++;
        onProgress?.call(done / total, '已安装 $name');
      }

      // 写版本标记（最后一步，标志安装完成）
      final marker = File(p.join(root.path, versionMarker));
      await marker.writeAsString(version);

      // 最终校验
      if (!await isBundledInstalled()) {
        throw Exception('安装后校验失败：文件大小或版本不匹配');
      }

      onProgress?.call(1.0, '完成');
    } catch (e) {
      lastError = e.toString();
      // 清理不完整文件，避免下次误判为已安装
      for (final name in kokoroCoreFiles) {
        final part = File(p.join(root.path, '$name.part'));
        if (await part.exists()) {
          try {
            await part.delete();
          } catch (_) {}
        }
      }
      throw Exception('内置模型安装失败：$lastError');
    }
  }

  /// 写最后复制错误到版本标记旁（供诊断页读取）。
  static Future<void> _writeInstallError(String error) async {
    try {
      final root = await kokoroRoot();
      final f = File(p.join(root.path, '.bundled_model_error'));
      await f.writeAsString(error);
    } catch (_) {}
  }

  static Future<String?> lastInstallError() async {
    try {
      final root = await kokoroRoot();
      final f = File(p.join(root.path, '.bundled_model_error'));
      if (await f.exists()) return await f.readAsString();
    } catch (_) {}
    return null;
  }

  /// 可选兜底：从网络下载核心模型包（默认不调用，仅用户手动触发）。
  static Future<void> downloadCoreModel({
    void Function(double progress, String label)? onProgress,
    bool Function()? shouldCancel,
  }) async {
    final root = await kokoroRoot();
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
      );
      acc += weights[f]!;
      onProgress?.call(acc, '校验 $f');
      final size = await dest.length();
      if (size < _minBytes(f)) {
        throw DownloadFailedException('$f 下载后文件过小，可能不完整',
            url: url);
      }
    }
    // 网络下载成功后也写入版本标记，避免重复下载
    final marker = File(p.join(root.path, versionMarker));
    await marker.writeAsString(version);
    onProgress?.call(1.0, '完成');
  }

  /// 诊断信息：返回当前状态摘要（含 Bundle 来源与大小）。
  static Future<Map<String, dynamic>> diagnostics() async {
    final files = await checkCoreFiles();
    final root = await kokoroRoot();
    final bundleSizes = await bundleFileSizes();
    final localSizes = await localFileSizes();
    final installed = await isBundledInstalled();
    final error = await lastInstallError();
    return {
      'root': root.path,
      'files': files,
      'coreReady': installed,
      'source': installed ? 'App 内置' : '未安装',
      'bundleSizes': bundleSizes,
      'localSizes': localSizes,
      'version': version,
      'installError': error,
      'voiceCount': AbogenLocalService.kokoroVoices(downloaded: {}).length,
    };
  }
}
