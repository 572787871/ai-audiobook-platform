import "dart:io";
import "package:flutter/foundation.dart";
import "../models/book.dart";
import "../models/local_tts.dart";
import "../services/local_tts_service.dart";

class LocalTtsProvider extends ChangeNotifier {
  List<TtsVoice> voices = [];
  List<VoicePack> voicePacks = [];
  List<VoiceFormula> voiceFormulas = [];
  GenerationMode mode = GenerationMode.auto;
  String defaultVoiceId = "zh_female_warm";
  bool loading = false;
  bool generating = false;
  double generationProgress = 0;
  String generationLabel = "";
  String? error;
  final Map<int, List<TtsSegment>> bookSegments = {};

  Future<void> init() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      mode = GenerationMode.local;
      await LocalTtsService.setGenerationMode(mode);
      defaultVoiceId = await LocalTtsService.resolveVoiceId();
      voicePacks = await LocalTtsService.getInstalledVoicePacks();
      voices = await LocalTtsService.getAvailableVoices();
      voiceFormulas = await LocalTtsService.getVoiceFormulas();
    } catch (e) {
      error = "本地语音初始化失败: $e";
      voices = LocalTtsService.fallbackVoices();
      voicePacks = LocalTtsService.defaultVoicePacks();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> setMode(GenerationMode value) async {
    mode = value;
    await LocalTtsService.setGenerationMode(value);
    notifyListeners();
  }

  Future<void> setDefaultVoice(String voiceId) async {
    defaultVoiceId = voiceId;
    await LocalTtsService.setGlobalVoice(voiceId);
    await _refreshVoices();
  }

  Future<void> setBookVoice(int bookId, String voiceId) async {
    await LocalTtsService.setBookVoice(bookId, voiceId);
    notifyListeners();
  }

  Future<void> setChapterVoice(
      int bookId, int chapterId, String voiceId) async {
    await LocalTtsService.setChapterVoice(bookId, chapterId, voiceId);
    notifyListeners();
  }

  Future<String?> previewVoice(TtsVoice voice) async {
    error = null;
    notifyListeners();
    try {
      final path = await LocalTtsService.previewVoice(voice);
      voices = voices
          .map((v) => v.voiceId == voice.voiceId
              ? v.copyWith(previewAudioPath: path)
              : v)
          .toList();
      notifyListeners();
      return path;
    } catch (e) {
      error = "试听失败: $e";
      notifyListeners();
      return null;
    }
  }

  Future<void> downloadVoice(TtsVoice voice) async {
    if (voice.isDownloaded) return;
    error = null;
    notifyListeners();
    try {
      await LocalTtsService.downloadVoice(voice);
      await _refreshVoices();
    } catch (e) {
      error = "音色下载失败: $e";
      notifyListeners();
    }
  }

  Future<void> downloadVoicePack(VoicePack pack) async {
    if (pack.isDownloaded) return;
    error = null;
    voicePacks = voicePacks
        .map((p) => p.packId == pack.packId ? p.copyWith(progress: 0.02) : p)
        .toList();
    notifyListeners();
    try {
      await LocalTtsService.downloadVoicePack(pack);
      voicePacks = await LocalTtsService.getInstalledVoicePacks();
      await _refreshVoices();
    } catch (e) {
      error = "语音包下载失败: $e";
      voicePacks = voicePacks
          .map((p) =>
              p.packId == pack.packId ? p.copyWith(errorMessage: error) : p)
          .toList();
      notifyListeners();
    }
  }

  Future<List<TtsSegment>> loadSegments(int bookId) async {
    final segments = await LocalTtsService.getSegments(bookId);
    bookSegments[bookId] = segments;
    notifyListeners();
    return segments;
  }

  Future<bool> hasPlayableLocalAudio(int bookId) async {
    final segments = await loadSegments(bookId);
    return segments
        .any((s) => s.audioPath != null && File(s.audioPath!).existsSync());
  }

  Future<List<TtsSegment>> generateBook({
    required BookDetail book,
    String? sourceText,
    String? voiceId,
    double speed = 1,
    double volume = 1,
    double pitch = 1,
    VoiceFormula? voiceFormula,
    SubtitleMode subtitleMode = SubtitleMode.sentence,
  }) async {
    generating = true;
    generationProgress = 0;
    generationLabel = "准备本地语音引擎";
    error = null;
    notifyListeners();
    try {
      final resolvedVoice =
          voiceId ?? await LocalTtsService.resolveVoiceId(bookId: book.id);
      final result = await LocalTtsService.generateBook(
        book: book,
        sourceText: sourceText,
        voiceId: resolvedVoice,
        speed: speed,
        volume: volume,
        pitch: pitch,
        voiceFormula: voiceFormula,
        subtitleMode: subtitleMode,
        onProgress: (progress, label) {
          generationProgress = progress;
          generationLabel = label;
          notifyListeners();
        },
      );
      bookSegments[book.id] = result;
      generationProgress = 1;
      generationLabel = "本地生成完成";
      return result;
    } catch (e) {
      error = "本地生成失败: $e";
      generationLabel = error!;
      rethrow;
    } finally {
      generating = false;
      notifyListeners();
    }
  }

  Future<void> cancelGeneration(int bookId) async {
    await LocalTtsService.cancelGeneration(bookId);
    generating = false;
    generationLabel = "已取消";
    notifyListeners();
  }

  Future<void> pauseGeneration(int bookId) async {
    await LocalTtsService.pauseGeneration(bookId);
    generationLabel = "已暂停";
    notifyListeners();
  }

  Future<void> resumeGeneration(int bookId) async {
    await LocalTtsService.resumeGeneration(bookId);
    generationLabel = "继续生成";
    notifyListeners();
  }

  Future<void> deleteGeneratedAudio(int bookId) async {
    await LocalTtsService.deleteGeneratedAudio(bookId);
    bookSegments.remove(bookId);
    notifyListeners();
  }

  Future<void> _refreshVoices() async {
    voices = await LocalTtsService.getAvailableVoices();
    defaultVoiceId = await LocalTtsService.resolveVoiceId();
    voicePacks = await LocalTtsService.getInstalledVoicePacks();
    notifyListeners();
  }
}
