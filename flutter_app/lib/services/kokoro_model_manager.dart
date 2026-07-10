/// Kokoro 模型与音色管理：分别处理 ONNX 模型、config、voices.bin、具体 voice 文件，
/// 使用可配置下载源（镜像 / GitHub Release / HuggingFace）与生产级断点续传下载器。
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../models/local_tts.dart';
import 'download_sources.dart';
import 'abogen_local_service.dart';
import 'resumable_downloader.dart';

class KokoroModelManager {
  KokoroModelManager._();

  static const String packId = 'kokoro_82m_int8';
  static const String version = 'Kokoro-82M';

  /// 各资产的文件名与（可选）完整/前缀 SHA256。
  static const String modelFile = 'kokoro-v1_0.pth';
  static const String configFile = 'config.json';
  static const String voicesBinFile = 'voices.bin';

  /// 内置已知 voice 的 SHA256 前缀（来自 Kokoro 官方仓库 voices 目录）。
  /// 仅作校验提示，缺失时仍允许下载。
  static const Map<String, String> voiceShaPrefix = {
    'zf_xiaobei': '9b76be63',
    'zf_xiaoni': '95b49f16',
    'zf_xiaoxiao': 'cfaf6f2d',
    'zf_xiaoyi': 'b5235dba',
    'zm_yunjian': '76cbf8ba',
    'zm_yunxi': 'dbe6e1ce',
    'zm_yunxia': 'bb2b03b0',
    'zm_yunyang': '5238ac22',
    'af_heart': '0ab5709b',
    'af_bella': '8cb64e02',
    'af_nicole': 'c5561808',
    'am_michael': '9a443b79',
    'am_fenrir': '98e507ec',
    'bf_emma': 'd0a423de',
    'bm_fable': 'd44935f3',
  };

  static Future<Directory> kokoroRoot() async {
    final support = await getApplicationSupportDirectory();
    final dir =
        Directory(p.join(support.path, 'abogen', 'kokoro_82m'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// 列出按顺序尝试的下载地址（多源回退）。
  static Future<List<String>> _resolveUrls(
      KokoroAssetKind kind, String fileName) async {
    final sources = await DownloadSourceConfig.sources();
    final out = <String>[];
    for (final s in sources) {
      out.add(s.resolve(kind, fileName));
    }
    return out;
  }

  static Future<Map<String, List<String>>> debugSources() async {
    return {
      'model': await _resolveUrls(KokoroAssetKind.model, modelFile),
      'config': await _resolveUrls(KokoroAssetKind.config, configFile),
    };
  }

  /// 下载核心模型（config + ONNX）。
  /// 进度：前 15% 为 config，其余为模型。
  static Future<void> downloadCoreModel({
    void Function(double progress, String label)? onProgress,
    DownloadHandle? handle,
  }) async {
    final root = await kokoroRoot();
    final configUrls =
        await _resolveUrls(KokoroAssetKind.config, configFile);
    await ResumableDownloader.download(
      urls: configUrls,
      outputPath: p.join(root.path, configFile),
      onProgress: (pr) =>
          onProgress?.call(pr.fraction * 0.15, '下载 config.json'),
      handle: handle,
    );
    final modelUrls = await _resolveUrls(KokoroAssetKind.model, modelFile);
    await ResumableDownloader.download(
      urls: modelUrls,
      outputPath: p.join(root.path, modelFile),
      onProgress: (pr) =>
          onProgress?.call(0.15 + pr.fraction * 0.85, '下载 Kokoro 模型'),
      handle: handle,
    );
  }

  /// 下载单个音色 .pt 文件，并校验 SHA256（前缀或完整）。
  static Future<void> downloadVoice(
    TtsVoice voice, {
    void Function(double progress, String label)? onProgress,
    DownloadHandle? handle,
  }) async {
    if (voice.backend != TtsBackend.kokoro) return;
    final root = await kokoroRoot();
    final voicesDir = Directory(p.join(root.path, 'voices'));
    if (!await voicesDir.exists()) await voicesDir.create(recursive: true);
    final fileName = '${voice.voiceId}.pt';
    final urls = await _resolveUrls(KokoroAssetKind.voiceFile, fileName);
    final sha = voiceShaPrefix[voice.voiceId];
    await ResumableDownloader.download(
      urls: urls,
      outputPath: p.join(voicesDir.path, fileName),
      expectedSha256: sha,
      onProgress: (pr) =>
          onProgress?.call(pr.fraction, '下载音色 ${voice.voiceId}'),
      handle: handle,
    );
  }

  static Future<bool> isCoreModelDownloaded() async {
    final root = await kokoroRoot();
    final model = File(p.join(root.path, modelFile));
    final config = File(p.join(root.path, configFile));
    return model.existsSync() &&
        model.lengthSync() > 0 &&
        config.existsSync() &&
        config.lengthSync() > 0;
  }

  /// 返回缺失的核心文件清单（用于 UI 提示）。若全部就绪返回空列表。
  static Future<List<String>> missingCoreFiles() async {
    final root = await kokoroRoot();
    final missing = <String>[];
    final model = File(p.join(root.path, modelFile));
    if (!model.existsSync() || model.lengthSync() == 0) {
      missing.add('kokoro-v1_0.pth（ONNX 模型）');
    }
    final config = File(p.join(root.path, configFile));
    if (!config.existsSync() || config.lengthSync() == 0) {
      missing.add('config.json');
    }
    return missing;
  }

  static Future<Set<String>> downloadedVoiceIds() async {
    final root = await kokoroRoot();
    final voicesDir = Directory(p.join(root.path, 'voices'));
    if (!await voicesDir.exists()) return {};
    return voicesDir
        .listSync()
        .whereType<File>()
        .where((f) => p.extension(f.path) == '.pt')
        .map((f) => p.basenameWithoutExtension(f.path))
        .toSet();
  }

  static Future<void> downloadRecommendedVoices({
    void Function(double progress, String label)? onProgress,
    DownloadHandle? handle,
  }) async {
    final downloaded = await downloadedVoiceIds();
    final voices = AbogenLocalService.kokoroVoices(downloaded: downloaded)
        .where((v) => v.recommended)
        .toList();
    for (var i = 0; i < voices.length; i++) {
      final v = voices[i];
      await downloadVoice(v,
          onProgress: (pg, label) => onProgress?.call(
              (i + pg) / voices.length.clamp(1, 999), label),
          handle: handle);
    }
  }

  /// 校验已下载核心模型与指定音色文件的完整性。
  /// 返回缺失或不完整的文件清单；为空表示完整。
  static Future<List<String>> verifyIntegrity(
      {Set<String>? voiceIds}) async {
    final root = await kokoroRoot();
    final issues = <String>[];
    final model = File(p.join(root.path, modelFile));
    if (!model.existsSync() || model.lengthSync() < 1024 * 1024) {
      issues.add('kokoro-v1_0.pth 缺失或过小（<1MB）');
    }
    final config = File(p.join(root.path, configFile));
    if (!config.existsSync() || config.lengthSync() == 0) {
      issues.add('config.json 缺失或为空');
    }
    final voicesDir = Directory(p.join(root.path, 'voices'));
    if (voiceIds != null && voiceIds.isNotEmpty) {
      for (final id in voiceIds) {
        final vf = File(p.join(voicesDir.path, '$id.pt'));
        if (!vf.existsSync() || vf.lengthSync() == 0) {
          issues.add('音色 $id.pt 缺失或为空');
        }
      }
    }
    return issues;
  }
}

