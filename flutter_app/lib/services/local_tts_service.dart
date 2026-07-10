import "dart:async";
import "dart:convert";
import "dart:io";
import "package:flutter/services.dart";
import "package:path/path.dart" as p;
import "package:path_provider/path_provider.dart";
import "package:shared_preferences/shared_preferences.dart";
import "../models/book.dart";
import "../models/local_tts.dart";
import "abogen_local_service.dart";

class LocalTtsService {
  LocalTtsService._();

  static const MethodChannel _channel = MethodChannel("ai_audiobook/local_tts");
  static const String _modeKey = "local_tts_generation_mode";
  static const String _globalVoiceKey = "local_tts_global_voice";
  static const String _bookVoicePrefix = "local_tts_book_voice_";
  static const String _chapterVoicePrefix = "local_tts_chapter_voice_";

  static final StreamController<Map<String, dynamic>> _progressController =
      StreamController<Map<String, dynamic>>.broadcast();

  static Stream<Map<String, dynamic>> get progressStream =>
      _progressController.stream;

  static List<VoicePack> defaultVoicePacks() => const [
        VoicePack(
          packId: "ios_system_zh",
          displayName: "iPhone 系统中文离线语音",
          modelVersion: "ios-avspeech",
          language: "zh-CN",
          sizeBytes: 0,
          downloadUrl: "",
          sha256: "",
          isDownloaded: true,
          progress: 1,
        ),
      ];

  static List<TtsVoice> fallbackVoices() => const [
        TtsVoice(
          voiceId: "zh_female_warm",
          displayName: "温柔女声",
          language: "zh-CN",
          gender: TtsVoiceGender.female,
          description: "适合都市、言情和轻松小说的自然旁白。",
          previewText: "你好，我会用温柔清晰的声音为你朗读这本书。",
          isDownloaded: true,
          isDefault: true,
          modelVersion: "ios-avspeech",
          packId: "ios_system_zh",
          recommended: true,
        ),
        TtsVoice(
          voiceId: "zh_male_story",
          displayName: "沉稳男声",
          language: "zh-CN",
          gender: TtsVoiceGender.male,
          description: "适合悬疑、历史和长篇叙事。",
          previewText: "夜色渐深，故事从这一刻正式开始。",
          isDownloaded: true,
          isDefault: false,
          modelVersion: "ios-avspeech",
          packId: "ios_system_zh",
          recommended: true,
        ),
        TtsVoice(
          voiceId: "en_female_clear",
          displayName: "English Female",
          language: "en-US",
          gender: TtsVoiceGender.female,
          description: "Clear English narration for bilingual books.",
          previewText: "This is a short preview for English narration.",
          isDownloaded: true,
          isDefault: false,
          modelVersion: "ios-avspeech",
          packId: "ios_system_zh",
        ),
        TtsVoice(
          voiceId: "en_male_clear",
          displayName: "English Male",
          language: "en-US",
          gender: TtsVoiceGender.male,
          description: "Balanced male voice for English chapters.",
          previewText: "The audiobook is ready to continue offline.",
          isDownloaded: true,
          isDefault: false,
          modelVersion: "ios-avspeech",
          packId: "ios_system_zh",
        ),
      ];

  static Future<void> initializeTtsEngine() async {
    try {
      await _channel.invokeMethod("initializeTtsEngine");
    } on MissingPluginException {
      if (Platform.isIOS) rethrow;
    }
  }

  static Future<List<TtsVoice>> getAvailableVoices() async {
    final local = fallbackVoices();
    final downloaded = await AbogenLocalService.downloadedVoiceIds();
    final kokoro = AbogenLocalService.kokoroVoices(downloaded: downloaded);
    try {
      final raw =
          await _channel.invokeMethod<List<dynamic>>("getAvailableVoices");
      final native = (raw ?? [])
          .whereType<Map>()
          .map((e) => TtsVoice.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      if (native.isEmpty) return local;
      final known = {for (final v in local) v.voiceId: v};
      return [
        ...kokoro,
        ...local,
        ...native.where((v) => !known.containsKey(v.voiceId)),
      ];
    } on MissingPluginException {
      return [...kokoro, ...local];
    }
  }

  static Future<List<VoicePack>> getInstalledVoicePacks() async {
    final kokoroPacks = await AbogenLocalService.voicePacks();
    try {
      final raw =
          await _channel.invokeMethod<List<dynamic>>("getInstalledVoicePacks");
      final native = (raw ?? [])
          .whereType<Map>()
          .map((e) => VoicePack.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      if (native.isNotEmpty) return [...kokoroPacks, ...native];
    } on MissingPluginException {
      // Android/web still show the built-in management UI.
    }
    return [...kokoroPacks, ...defaultVoicePacks()];
  }

  static Future<void> downloadVoicePack(VoicePack pack) async {
    if (pack.isDownloaded || pack.downloadUrl.isEmpty) return;
    if (pack.packId == AbogenLocalService.kokoroPackId) {
      await AbogenLocalService.downloadCoreModel();
      await AbogenLocalService.downloadRecommendedVoices();
      return;
    }
    await _channel.invokeMethod("downloadVoicePack", pack.toJson());
  }

  static Future<void> downloadVoice(TtsVoice voice) async {
    if (voice.backend == TtsBackend.kokoro) {
      await AbogenLocalService.downloadVoice(voice);
    }
  }

  static Future<List<VoiceFormula>> getVoiceFormulas() =>
      AbogenLocalService.loadFormulas();

  static Future<void> saveVoiceFormulas(List<VoiceFormula> formulas) =>
      AbogenLocalService.saveFormulas(formulas);

  static Future<String> previewVoice(TtsVoice voice) async {
    if (voice.backend == TtsBackend.kokoro && !voice.isDownloaded) {
      await AbogenLocalService.downloadVoice(voice);
    }
    final dir = await _bookDir(0);
    final output = p.join(dir.path, "preview_${voice.voiceId}.wav");
    final path = await _generateSpeechNative(
      text: voice.previewText,
      voiceId: voice.voiceId,
      speed: 1,
      volume: 1,
      pitch: 1,
      outputPath: output,
      chapterId: 0,
      segmentId: "preview_${voice.voiceId}",
    );
    return path;
  }

  static Future<List<TtsSegment>> generateBook({
    required BookDetail book,
    String? sourceText,
    required String voiceId,
    double speed = 1,
    double volume = 1,
    double pitch = 1,
    VoiceFormula? voiceFormula,
    SubtitleMode subtitleMode = SubtitleMode.sentence,
    void Function(double progress, String label)? onProgress,
  }) async {
    await initializeTtsEngine();
    final texts = _textsForBook(book, sourceText: sourceText);
    final segments = AbogenLocalService.chunkBookText(
      bookId: book.id,
      texts: texts,
      settings: AbogenGenerationSettings(
        voiceId: voiceId,
        voiceFormula: voiceFormula,
        subtitleMode: subtitleMode,
        speed: speed,
        volume: volume,
        pitch: pitch,
      ),
    );
    final result = <TtsSegment>[];
    double cursor = 0;

    for (var i = 0; i < segments.length; i++) {
      final seg = segments[i].copyWith(
        generationStatus: LocalGenerationStatus.generating,
        startTime: cursor,
      );
      final progress = i / segments.length;
      onProgress?.call(progress, "正在生成第 ${i + 1}/${segments.length} 段");
      _progressController.add({
        "bookId": book.id,
        "progress": progress,
        "segmentId": seg.segmentId
      });

      final dir = await _bookDir(book.id);
      final output = p.join(dir.path, "${seg.segmentId}.wav");
      final audioPath = await _generateSpeechNative(
        text: seg.normalizedText,
        voiceId: seg.voiceId,
        speed: speed,
        volume: volume,
        pitch: pitch,
        outputPath: output,
        chapterId: seg.chapterId,
        segmentId: seg.segmentId,
      );
      final duration =
          await _probeDuration(audioPath, seg.normalizedText, speed);
      final completed = seg.copyWith(
        audioPath: audioPath,
        duration: duration,
        startTime: cursor,
        endTime: cursor + duration,
        generationStatus: LocalGenerationStatus.ready,
      );
      result.add(completed);
      cursor += duration;
      await saveSegments(book.id, result);
    }

    onProgress?.call(1, "本地生成完成");
    _progressController
        .add({"bookId": book.id, "progress": 1, "status": "completed"});
    await saveSegments(
        book.id,
        result
            .map((e) =>
                e.copyWith(generationStatus: LocalGenerationStatus.completed))
            .toList());
    return getSegments(book.id);
  }

  static Future<void> cancelGeneration(int bookId) async {
    try {
      await _channel.invokeMethod("cancelGeneration", {"bookId": bookId});
    } on MissingPluginException {
      return;
    }
  }

  static Future<void> pauseGeneration(int bookId) async {
    try {
      await _channel.invokeMethod("pauseGeneration", {"bookId": bookId});
    } on MissingPluginException {
      return;
    }
  }

  static Future<void> resumeGeneration(int bookId) async {
    try {
      await _channel.invokeMethod("resumeGeneration", {"bookId": bookId});
    } on MissingPluginException {
      return;
    }
  }

  static Future<void> deleteGeneratedAudio(int bookId) async {
    final dir = await _bookDir(bookId);
    if (await dir.exists()) await dir.delete(recursive: true);
  }

  static Future<List<TtsSegment>> getSegments(int bookId) async {
    final manifest = await _segmentsFile(bookId);
    if (!await manifest.exists()) return [];
    final raw = jsonDecode(await manifest.readAsString());
    return (raw as List)
        .map((e) => TtsSegment.fromJson(Map<String, dynamic>.from(e as Map)))
        .where(
            (seg) => seg.audioPath != null && File(seg.audioPath!).existsSync())
        .toList();
  }

  static Future<void> saveSegments(
      int bookId, List<TtsSegment> segments) async {
    final file = await _segmentsFile(bookId);
    await file
        .writeAsString(jsonEncode(segments.map((e) => e.toJson()).toList()));
  }

  static Future<GenerationMode> getGenerationMode() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_modeKey);
    return GenerationMode.values
        .firstWhere((e) => e.name == value, orElse: () => GenerationMode.auto);
  }

  static Future<void> setGenerationMode(GenerationMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_modeKey, mode.name);
  }

  static Future<String> resolveVoiceId({int? bookId, int? chapterId}) async {
    final prefs = await SharedPreferences.getInstance();
    if (bookId != null && chapterId != null) {
      final chapterVoice =
          prefs.getString("$_chapterVoicePrefix${bookId}_$chapterId");
      if (chapterVoice != null) return chapterVoice;
    }
    if (bookId != null) {
      final bookVoice = prefs.getString("$_bookVoicePrefix$bookId");
      if (bookVoice != null) return bookVoice;
    }
    return prefs.getString(_globalVoiceKey) ?? "zh_female_warm";
  }

  static Future<void> setGlobalVoice(String voiceId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_globalVoiceKey, voiceId);
  }

  static Future<void> setBookVoice(int bookId, String voiceId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("$_bookVoicePrefix$bookId", voiceId);
  }

  static Future<void> setChapterVoice(
      int bookId, int chapterId, String voiceId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("$_chapterVoicePrefix${bookId}_$chapterId", voiceId);
  }

  static Future<String> readTextFile(File file) async {
    final bytes = await file.readAsBytes();
    try {
      return utf8.decode(bytes);
    } on FormatException {
      try {
        final decoded = await _channel
            .invokeMethod<String>("decodeTextFile", {"path": file.path});
        if (decoded != null && decoded.isNotEmpty) return decoded;
      } on MissingPluginException {
        // Fall through to a replacement decode so the UI never crashes.
      }
      return utf8.decode(bytes, allowMalformed: true);
    }
  }

  static Future<String> _generateSpeechNative({
    required String text,
    required String voiceId,
    required double speed,
    required double volume,
    required double pitch,
    required String outputPath,
    required int chapterId,
    required String segmentId,
  }) async {
    final result =
        await _channel.invokeMethod<Map<dynamic, dynamic>>("generateSpeech", {
      "text": text,
      "voiceId": voiceId,
      "speed": speed,
      "volume": volume,
      "pitch": pitch,
      "outputPath": outputPath,
      "chapterId": chapterId,
      "segmentId": segmentId,
    });
    final path = result?["audioPath"] as String? ?? outputPath;
    if (!File(path).existsSync()) throw StateError("本地 TTS 没有生成音频文件: $path");
    return path;
  }

  static List<String> _textsForBook(BookDetail book, {String? sourceText}) {
    if (sourceText != null && sourceText.trim().isNotEmpty) return [sourceText];
    if (book.transcript.isNotEmpty)
      return book.transcript.map((e) => e.text).toList();
    final fallback = [book.title, book.description ?? ""]
        .where((e) => e.trim().isNotEmpty)
        .join("\n\n");
    return [fallback.isEmpty ? "这本书还没有可朗读的文本。" : fallback];
  }

  static Future<double> _probeDuration(
      String path, String text, double speed) async {
    try {
      final raw =
          await _channel.invokeMethod<num>("getAudioDuration", {"path": path});
      final value = raw?.toDouble() ?? 0;
      if (value > 0) return value;
    } on MissingPluginException {
      // Fallback estimate below.
    }
    final charsPerSecond = 4.2 * speed.clamp(0.5, 2.0);
    return (text.runes.length / charsPerSecond).clamp(1.0, 120.0);
  }

  static Future<Directory> _bookDir(int bookId) async {
    final root = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(root.path, "local_tts", "book_$bookId"));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  static Future<File> _segmentsFile(int bookId) async {
    final dir = await _bookDir(bookId);
    return File(p.join(dir.path, "segments.json"));
  }
}
