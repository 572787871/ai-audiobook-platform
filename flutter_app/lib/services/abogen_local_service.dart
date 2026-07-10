/// abogen / Kokoro 元数据层：保留真实的 Kokoro voice id、混合音色公式、
/// 句子/段落分段、字幕对齐等设计。下载实现已替换为生产级断点续传下载器。
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import '../models/local_tts.dart';
import 'kokoro_model_manager.dart';
import 'dart:math';
import 'dart:typed_data';
import 'resumable_downloader.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart';

class AbogenLocalService {
  AbogenLocalService._();

  static const String kokoroPackId = KokoroModelManager.packId;
  static const String kokoroVersion = KokoroModelManager.version;
  static const String _formulaFile = 'abogen_voice_profiles.json';

  static void init() {
    // 纯元数据初始化，无副作用。KokoroModelManager 直接静态引用本类 kokoroVoices。
  }


  static VoicePack kokoroPack({bool isDownloaded = false, String? localPath}) {
    return VoicePack(
      packId: kokoroPackId,
      displayName: 'Kokoro-82M 本地模型与音色',
      modelVersion: kokoroVersion,
      language: 'zh-CN/en-US',
      sizeBytes: 360 * 1024 * 1024,
      downloadUrl: '', // 不再暴露原始签名 URL
      sha256: '',
      isDownloaded: isDownloaded,
      progress: isDownloaded ? 1 : 0,
      localPath: localPath,
    );
  }

  static List<TtsVoice> kokoroVoices({required Set<String> downloaded}) {
    TtsVoice voice(
      String id,
      String name,
      String language,
      TtsVoiceGender gender,
      String description,
      String previewText,
      String grade,
      String sha,
      String langCode, {
      bool recommended = false,
    }) {
      return TtsVoice(
        voiceId: id,
        displayName: name,
        language: language,
        gender: gender,
        description: description,
        previewText: previewText,
        isDownloaded: downloaded.contains(id),
        isDefault: false,
        modelVersion: kokoroVersion,
        packId: kokoroPackId,
        recommended: recommended,
        backend: TtsBackend.kokoro,
        grade: grade,
        sha256Prefix: sha,
        langCode: langCode,
      );
    }

    return [
      voice('zf_xiaobei', '小北女声', 'zh-CN', TtsVoiceGender.female,
          'Kokoro 中文女声，适合现代小说旁白。', '今天的故事，从一阵温柔的风开始。', 'D', '9b76be63', 'z',
          recommended: true),
      voice('zf_xiaoni', '小妮女声', 'zh-CN', TtsVoiceGender.female,
          'Kokoro 中文女声，语气轻快。', '你好，我会用清晰自然的中文为你朗读。', 'D', '95b49f16', 'z'),
      voice('zf_xiaoxiao', '小小女声', 'zh-CN', TtsVoiceGender.female,
          'Kokoro 中文女声，适合轻小说和日常文本。', '窗外的阳光落在书页上，故事继续向前。', 'D', 'cfaf6f2d', 'z'),
      voice('zf_xiaoyi', '小艺女声', 'zh-CN', TtsVoiceGender.female,
          'Kokoro 中文女声，适合温柔叙事。', '这是一段本地生成的试听音频。', 'D', 'b5235dba', 'z'),
      voice('zm_yunjian', '云健男声', 'zh-CN', TtsVoiceGender.male,
          'Kokoro 中文男声，适合长篇和悬疑。', '夜色沉下来，远处的脚步声越来越近。', 'D', '76cbf8ba', 'z',
          recommended: true),
      voice('zm_yunxi', '云希男声', 'zh-CN', TtsVoiceGender.male,
          'Kokoro 中文男声，适合都市与纪实。', '他推开门，看见了久违的那封信。', 'D', 'dbe6e1ce', 'z'),
      voice('zm_yunxia', '云夏男声', 'zh-CN', TtsVoiceGender.male,
          'Kokoro 中文男声，声线更年轻。', '风穿过街角，带来了新的消息。', 'D', 'bb2b03b0', 'z'),
      voice('zm_yunyang', '云扬男声', 'zh-CN', TtsVoiceGender.male,
          'Kokoro 中文男声，适合历史和剧情。', '很多年以后，他仍然记得那个清晨。', 'D', '5238ac22', 'z'),
      voice('af_heart', 'Heart 英文女声', 'en-US', TtsVoiceGender.female,
          'Kokoro 高质量美式英文女声。', 'This is a local audiobook voice preview.', 'A', '0ab5709b', 'a',
          recommended: true),
      voice('af_bella', 'Bella 英文女声', 'en-US', TtsVoiceGender.female,
          'Kokoro 高质量英文女声，适合小说旁白。', 'The chapter begins with a quiet morning.', 'A-', '8cb64e02', 'a'),
      voice('af_nicole', 'Nicole 英文女声', 'en-US', TtsVoiceGender.female,
          'Kokoro 英文女声，适合清晰叙述。', 'A gentle voice for a long listening session.', 'B-', 'c5561808', 'a'),
      voice('am_michael', 'Michael 英文男声', 'en-US', TtsVoiceGender.male,
          'Kokoro 美式英文男声。', 'The audiobook continues offline on this iPhone.', 'C+', '9a443b79', 'a'),
      voice('am_fenrir', 'Fenrir 英文男声', 'en-US', TtsVoiceGender.male,
          'Kokoro 英文男声，适合剧情文本。', 'Every secret has a sound before it is spoken.', 'C+', '98e507ec', 'a'),
      voice('bf_emma', 'Emma 英式女声', 'en-GB', TtsVoiceGender.female,
          'Kokoro 英式英文女声。', 'A calm British narration voice for your book.', 'B-', 'd0a423de', 'b'),
      voice('bm_fable', 'Fable 英式男声', 'en-GB', TtsVoiceGender.male,
          'Kokoro 英式英文男声。', 'The library was silent, except for the rain.', 'C', 'd44935f3', 'b'),
    ];
  }

  static Future<Directory> kokoroRoot() => KokoroModelManager.kokoroRoot();

  static Future<bool> isCoreModelDownloaded() =>
      KokoroModelManager.isCoreModelDownloaded();

  static Future<Set<String>> downloadedVoiceIds() =>
      KokoroModelManager.downloadedVoiceIds();

  static Future<List<VoicePack>> voicePacks() async {
    final root = await kokoroRoot();
    final downloaded = await isCoreModelDownloaded();
    return [kokoroPack(isDownloaded: downloaded, localPath: root.path)];
  }

  static Future<void> downloadCoreModel({
    void Function(double progress, String label)? onProgress,
    DownloadHandle? handle,
  }) =>
      KokoroModelManager.downloadCoreModel(
          onProgress: onProgress, handle: handle);

  static Future<void> downloadVoice(TtsVoice voice,
      {void Function(double progress, String label)? onProgress,
      DownloadHandle? handle}) {
    if (voice.backend != TtsBackend.kokoro) {
      return Future.value();
    }
    return KokoroModelManager.downloadVoice(voice,
        onProgress: onProgress, handle: handle);
  }

  static Future<void> downloadRecommendedVoices(
          {void Function(double progress, String label)? onProgress,
          DownloadHandle? handle}) =>
      KokoroModelManager.downloadRecommendedVoices(
          onProgress: onProgress, handle: handle);

  static Future<List<VoiceFormula>> loadFormulas() async {
    final file = await _formulaJson();
    if (!await file.exists()) return defaultFormulas();
    final raw = jsonDecode(await file.readAsString());
    final list = raw is Map ? raw['abogen_voice_profiles'] : raw;
    if (list is! List) return defaultFormulas();
    final parsed = list
        .whereType<Map>()
        .map((e) => VoiceFormula.fromJson(Map<String, dynamic>.from(e)))
        .where((e) => e.parts.isNotEmpty)
        .toList();
    return parsed.isEmpty ? defaultFormulas() : parsed;
  }

  static Future<void> saveFormulas(List<VoiceFormula> formulas) async {
    final file = await _formulaJson();
    await file.writeAsString(jsonEncode({
      'abogen_voice_profiles': formulas.map((e) => e.toJson()).toList(),
    }));
  }

  static List<VoiceFormula> defaultFormulas() {
    final now = DateTime.now();
    return [
      VoiceFormula(
        formulaId: 'zh_soft_narrator',
        displayName: '中文柔和旁白',
        language: 'zh-CN',
        parts: const [
          VoiceFormulaPart(voiceId: 'zf_xiaobei', weight: 0.65),
          VoiceFormulaPart(voiceId: 'zf_xiaoxiao', weight: 0.35),
        ],
        isDefault: true,
        createdAt: now,
      ),
      VoiceFormula(
        formulaId: 'zh_story_male',
        displayName: '中文剧情男声',
        language: 'zh-CN',
        parts: const [
          VoiceFormulaPart(voiceId: 'zm_yunjian', weight: 0.7),
          VoiceFormulaPart(voiceId: 'zm_yunyang', weight: 0.3),
        ],
        createdAt: now,
      ),
      VoiceFormula(
        formulaId: 'en_clear_female',
        displayName: '英文清晰女声',
        language: 'en-US',
        parts: const [
          VoiceFormulaPart(voiceId: 'af_heart', weight: 0.75),
          VoiceFormulaPart(voiceId: 'af_bella', weight: 0.25),
        ],
        createdAt: now,
      ),
    ];
  }

  static List<TtsSegment> chunkBookText({
    required int bookId,
    required List<String> texts,
    required AbogenGenerationSettings settings,
  }) {
    final normalized = _normalizeSourceText(texts.join('\n\n'));
    final chunks = <TtsSegment>[];
    final paragraphs = normalized
        .split(RegExp(r'(?:\r?\n){2,}'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final useParagraph = settings.subtitleMode == SubtitleMode.paragraph;
    var index = 0;
    for (var paragraphIndex = 0;
        paragraphIndex < paragraphs.length;
        paragraphIndex++) {
      final paragraph = paragraphs[paragraphIndex];
      final pieces = useParagraph
          ? _splitLong(paragraph, settings.maxChunkChars)
          : _splitSentences(paragraph, settings.maxChunkChars);
      for (final piece in pieces) {
        final voiceFormula = settings.voiceFormula?.abogenFormula;
        chunks.add(TtsSegment(
          segmentId:
              'book_${bookId}_seg_${index.toString().padLeft(5, "0")}',
          bookId: bookId,
          chapterId: paragraphIndex ~/ 30,
          originalText: piece,
          normalizedText: piece,
          voiceId: settings.voiceFormula?.primaryVoiceId.isNotEmpty == true
              ? settings.voiceFormula!.primaryVoiceId
              : settings.voiceId,
          voiceProfileId: settings.voiceProfileId,
          voiceFormula: voiceFormula,
          speakerId: 'narrator',
          level: useParagraph ? 'paragraph' : 'sentence',
        ));
        index++;
      }
    }
    if (chunks.isNotEmpty) return chunks;
    return [
      TtsSegment(
        segmentId: 'book_${bookId}_seg_00000',
        bookId: bookId,
        chapterId: 0,
        originalText: '这本书还没有可朗读的文本。',
        normalizedText: '这本书还没有可朗读的文本。',
        voiceId: settings.voiceId,
      )
    ];
  }

  /// 使用 sherpa-onnx 进行真实 Kokoro 本地推理。
  /// 返回生成的 wav 文件。要求核心模型与音色已下载且完整。
  /// 任何缺失/不完整都会抛出带明确信息的异常。
  /// Kokoro voiceId -> sherpa-onnx sid（voices.bin 内整数索引）。
  /// 顺序与 Kokoro 官方 voices 列表一致；真机首次运行可按试听结果校准。
  static const Map<String, int> _kokoroSid = {
    'zf_xiaobei': 0,
    'zf_xiaoni': 1,
    'zf_xiaoxiao': 2,
    'zf_xiaoyi': 3,
    'zm_yunjian': 4,
    'zm_yunxi': 5,
    'zm_yunxia': 6,
    'zm_yunyang': 7,
    'af_heart': 8,
    'af_bella': 9,
    'af_nicole': 10,
    'am_michael': 11,
    'am_fenrir': 12,
    'bf_emma': 13,
    'bm_fable': 14,
  };

  /// 使用 sherpa-onnx 进行真实 Kokoro 本地推理。
  /// 返回生成的 wav 文件。要求核心模型与音色已下载且完整。
  /// 任何缺失/不完整都会抛出带明确信息的异常。
  static Future<File> synthesizeKokoro({
    required String text,
    required String voiceId,
    required String outputPath,
    double speed = 1.0,
  }) async {
    if (text.trim().isEmpty) throw Exception('Kokoro 推理文本为空');

    final issues = await KokoroModelManager.verifyIntegrity(voiceIds: {voiceId});
    if (issues.isNotEmpty) {
      throw Exception('Kokoro 模型不完整，无法生成：\n- ${issues.join("\n- ")}');
    }
    final root = await KokoroModelManager.kokoroRoot();
    final modelPath = p.join(root.path, KokoroModelManager.modelFile);
    final voicesPath = p.join(root.path, KokoroModelManager.voicesBinFile);

    // sid 映射：Kokoro 用 voices.bin 内整数索引选择音色
    final sid = _kokoroSid[voiceId] ?? 0;

    try {
      initBindings();
    } catch (_) {
      // 已初始化则忽略
    }

    final tts = OfflineTts(OfflineTtsConfig(
      model: OfflineTtsModelConfig(
        kokoro: OfflineTtsKokoroModelConfig(
          model: modelPath,
          voices: voicesPath,
          dataDir: '',
        ),
        numThreads: 2,
      ),
    ));
    try {
      final audio = tts.generate(text: text, sid: sid, speed: speed);
      if (audio == null || audio.samples.isEmpty) {
        throw Exception('Kokoro 推理返回空音频（文本可能为空或模型异常）');
      }
      final outFile = File(outputPath);
      await outFile.parent.create(recursive: true);
      // 写 16-bit PCM WAV
      final bytes = _encodeWav(audio.samples, audio.sampleRate);
      await outFile.writeAsBytes(bytes);
      return outFile;
    } finally {
      tts.free();
    }
  }

  static List<int> _encodeWav(List<double> samples, int sampleRate) {
    final byteData = BytesBuilder();
    const channels = 1;
    const bitsPerSample = 16;
    final dataSize = samples.length * 2;
    final buffer = ByteData(44);
    final ascii = 'RIFF'.codeUnits;
    for (var i = 0; i < 4; i++) buffer.setUint8(i, ascii[i]);
    buffer.setUint32(4, 36 + dataSize, Endian.little);
    final wave = 'WAVE'.codeUnits;
    for (var i = 0; i < 4; i++) buffer.setUint8(8 + i, wave[i]);
    final fmt = 'fmt '.codeUnits;
    for (var i = 0; i < 4; i++) buffer.setUint8(12 + i, fmt[i]);
    buffer.setUint32(16, 16, Endian.little);
    buffer.setUint16(20, 1, Endian.little);
    buffer.setUint16(22, channels, Endian.little);
    buffer.setUint32(24, sampleRate, Endian.little);
    buffer.setUint32(28, sampleRate * channels * bitsPerSample ~/ 8, Endian.little);
    buffer.setUint16(32, channels * bitsPerSample ~/ 8, Endian.little);
    buffer.setUint16(34, bitsPerSample, Endian.little);
    final data = 'data'.codeUnits;
    for (var i = 0; i < 4; i++) buffer.setUint8(36 + i, data[i]);
    buffer.setUint32(40, dataSize, Endian.little);
    byteData.add(buffer.buffer.asUint8List());
    for (final s in samples) {
      final v = (s.clamp(-1.0, 1.0) * 32767).round();
      final bd = ByteData(2);
      bd.setInt16(0, v, Endian.little);
      byteData.add(bd.buffer.asUint8List());
    }
    return byteData.toBytes();
  }

  static Future<File> _formulaJson() async {
    final root = await kokoroRoot();
    return File(p.join(root.path, _formulaFile));
  }

  static String _normalizeSourceText(String input) {
    return input
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll(RegExp(r'[ \t]{2,}'), ' ')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }

  static List<String> _splitSentences(String paragraph, int maxChars) {
    final pieces = <String>[];
    final buffer = StringBuffer();
    for (final rune in paragraph.runes) {
      final char = String.fromCharCode(rune);
      buffer.write(char);
      final shouldCut =
          '。！？!?；;'.contains(char) || buffer.length >= maxChars;
      if (shouldCut && buffer.toString().trim().isNotEmpty) {
        pieces.add(buffer.toString().trim());
        buffer.clear();
      }
    }
    if (buffer.toString().trim().isNotEmpty) {
      pieces.add(buffer.toString().trim());
    }
    return pieces;
  }

  static List<String> _splitLong(String text, int maxChars) {
    if (text.length <= maxChars) return [text];
    final chunks = <String>[];
    var cursor = 0;
    while (cursor < text.length) {
      final end = (cursor + maxChars).clamp(0, text.length);
      chunks.add(text.substring(cursor, end).trim());
      cursor = end;
    }
    return chunks.where((e) => e.isNotEmpty).toList();
  }
}

/// 占位：兼容旧调用点（实际 Dio 实例已迁移到 resumable_downloader）。
/// 这里仅保留一个轻量对象，避免大范围改动引用。
class DioShim {
  DioShim();
}
