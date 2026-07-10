/// 下载源配置：支持可配置镜像、GitHub Release 备用、HuggingFace 官方最后。
/// 不硬编码 UI，所有地址集中在配置层。
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Kokoro 资源类型，分别处理 ONNX 模型 / config / voices.bin / 具体 voice 文件。
enum KokoroAssetKind { model, config, voicesBin, voiceFile, shaFile }

class DownloadSource {
  final String id;
  final String displayName;
  /// 基础地址模板，{kind} 与 {file} 会被替换。
  final String baseUrl;
  /// 优先级，越小越优先。
  final int priority;
  final bool enabled;

  const DownloadSource({
    required this.id,
    required this.displayName,
    required this.baseUrl,
    this.priority = 100,
    this.enabled = true,
  });

  /// 解析某个资产的完整地址。
  String resolve(KokoroAssetKind kind, String fileName, {String? mirror}) {
    final base = mirror ?? baseUrl;
    switch (kind) {
      case KokoroAssetKind.model:
        return '$base/kokoro-v1_0.pth';
      case KokoroAssetKind.config:
        return '$base/config.json';
      case KokoroAssetKind.voicesBin:
        return '$base/voices.bin';
      case KokoroAssetKind.voiceFile:
        return '$base/voices/$fileName';
      case KokoroAssetKind.shaFile:
        return '$base/voices/$fileName.sha256';
    }
  }
}

class DownloadSourceConfig {
  DownloadSourceConfig._();

  static const String _mirrorKey = 'kokoro_mirror_base_url';
  static const String _githubReleaseKey = 'kokoro_github_release_url';
  static const String _hfBaseUrl = 'https://huggingface.co/hexgrad/Kokoro-82M/resolve/main';

  /// 默认按顺序：
  /// 1) 用户可配置镜像（首选）
  /// 2) GitHub Release 备用
  /// 3) HuggingFace 官方（最后）
  static Future<List<DownloadSource>> sources() async {
    final prefs = await SharedPreferences.getInstance();
    final mirror = prefs.getString(_mirrorKey);
    final ghRelease = prefs.getString(_githubReleaseKey);

    final list = <DownloadSource>[];
    if (mirror != null && mirror.trim().isNotEmpty) {
      list.add(DownloadSource(
        id: 'user_mirror',
        displayName: '用户镜像',
        baseUrl: mirror.trim().replaceAll(RegExp(r'/+\$'), ''),
        priority: 1,
      ));
    }
    if (ghRelease != null && ghRelease.trim().isNotEmpty) {
      list.add(DownloadSource(
        id: 'github_release',
        displayName: 'GitHub Release',
        baseUrl: ghRelease.trim().replaceAll(RegExp(r'/+\$'), ''),
        priority: 50,
      ));
    }
    list.add(const DownloadSource(
      id: 'huggingface',
      displayName: 'HuggingFace 官方',
      baseUrl: _hfBaseUrl,
      priority: 100,
    ));
    list.sort((a, b) => a.priority.compareTo(b.priority));
    return list;
  }

  /// 设置首选镜像地址（UI 调用）。
  static Future<void> setMirror(String? url) async {
    final prefs = await SharedPreferences.getInstance();
    if (url == null || url.trim().isEmpty) {
      await prefs.remove(_mirrorKey);
    } else {
      await prefs.setString(_mirrorKey, url.trim());
    }
  }

  /// 设置 GitHub Release 备用地址（UI 调用）。
  static Future<void> setGithubRelease(String? url) async {
    final prefs = await SharedPreferences.getInstance();
    if (url == null || url.trim().isEmpty) {
      await prefs.remove(_githubReleaseKey);
    } else {
      await prefs.setString(_githubReleaseKey, url.trim());
    }
  }

  static Future<String?> getMirror() async =>
      (await SharedPreferences.getInstance()).getString(_mirrorKey);

  static Future<String?> getGithubRelease() async =>
      (await SharedPreferences.getInstance()).getString(_githubReleaseKey);

  /// 序列化为可调试 JSON（UI 展示用，绝不打印超长签名 URL）。
  static Map<String, dynamic> debugInfo(List<DownloadSource> sources) => {
        'count': sources.length,
        'order': sources.map((e) => '${e.id}(${e.displayName})').toList(),
      };

  static String toSafeString(List<DownloadSource> sources) =>
      jsonEncode(debugInfo(sources));
}
