/// 下载源配置：Kokoro 模型使用 sherpa-onnx 官方维护的 csukuangfj/kokoro-en-v0_19
/// （含 model.onnx + voices.bin + tokens.txt，与 sherpa_onnx 的
/// OfflineTtsKokoroModelConfig 三个必需字段完全对应）。
/// 所有 URL 均不硬编码签名，使用公开 HuggingFace resolve 接口（带重定向）。
import 'dart:convert';

/// HuggingFace 公开下载根（无需 token）。resolve 会 307 重定向到 CDN。
const String _hfBase = 'https://huggingface.co';

/// Kokoro 核心模型包（csukuangfj 官方，sherpa-onnx 兼容）。
const String kokoroModelRepo = 'csukuangfj/kokoro-en-v0_19';

/// 核心文件清单：sherpa_onnx 推理 Kokoro 所必需。
const List<String> kokoroCoreFiles = [
  'model.onnx',
  'voices.bin',
  'tokens.txt',
];

/// 构造某个核心文件的下载 URL（不暴露任何密钥）。
String kokoroCoreUrl(String fileName) =>
    '$_hfBase/$kokoroModelRepo/resolve/main/$fileName';

/// 把可能超长的 URL 转为不泄露的展示串（调试用）。
String toSafeString(String url) {
  try {
    final uri = Uri.parse(url);
    return '${uri.host}${uri.path}';
  } catch (_) {
    return url.length > 64 ? '${url.substring(0, 32)}…${url.substring(url.length - 16)}' : url;
  }
}

/// 把异常转成可展示的简短信息（避免泄漏响应正文中的长 URL/密钥）。
String safeError(Object e) {
  final s = e.toString();
  // 截断过长的 URL
  if (s.length > 300) return '${s.substring(0, 300)}…';
  return s;
}

/// 统一 JSON 序列化入口（便于后续替换为加密存储）。
String encodeMeta(Map<String, dynamic> m) => jsonEncode(m);
Map<String, dynamic> decodeMeta(String s) => jsonDecode(s) as Map<String, dynamic>;
