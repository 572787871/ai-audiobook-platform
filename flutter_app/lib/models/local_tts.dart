enum GenerationMode { auto, local, cloud }

enum LocalGenerationStatus {
  waiting,
  preparingModel,
  downloadingModel,
  generating,
  ready,
  playing,
  paused,
  completed,
  cancelled,
  failed,
}

enum TtsVoiceGender { male, female, neutral }

enum TtsBackend { iosSystem, kokoro }

enum SubtitleMode { sentence, paragraph }

class VoicePack {
  final String packId;
  final String displayName;
  final String modelVersion;
  final String language;
  final int sizeBytes;
  final String downloadUrl;
  final String sha256;
  final bool isDownloaded;
  final double progress;
  final String? localPath;
  final String? errorMessage;

  const VoicePack({
    required this.packId,
    required this.displayName,
    required this.modelVersion,
    required this.language,
    required this.sizeBytes,
    required this.downloadUrl,
    required this.sha256,
    this.isDownloaded = false,
    this.progress = 0,
    this.localPath,
    this.errorMessage,
  });

  VoicePack copyWith({
    bool? isDownloaded,
    double? progress,
    String? localPath,
    String? errorMessage,
  }) {
    return VoicePack(
      packId: packId,
      displayName: displayName,
      modelVersion: modelVersion,
      language: language,
      sizeBytes: sizeBytes,
      downloadUrl: downloadUrl,
      sha256: sha256,
      isDownloaded: isDownloaded ?? this.isDownloaded,
      progress: progress ?? this.progress,
      localPath: localPath ?? this.localPath,
      errorMessage: errorMessage,
    );
  }

  Map<String, dynamic> toJson() => {
        "packId": packId,
        "displayName": displayName,
        "modelVersion": modelVersion,
        "language": language,
        "sizeBytes": sizeBytes,
        "downloadUrl": downloadUrl,
        "sha256": sha256,
        "isDownloaded": isDownloaded,
        "progress": progress,
        "localPath": localPath,
        "errorMessage": errorMessage,
      };

  factory VoicePack.fromJson(Map<String, dynamic> json) => VoicePack(
        packId: json["packId"] as String,
        displayName: json["displayName"] as String,
        modelVersion: json["modelVersion"] as String,
        language: json["language"] as String,
        sizeBytes: json["sizeBytes"] as int? ?? 0,
        downloadUrl: json["downloadUrl"] as String? ?? "",
        sha256: json["sha256"] as String? ?? "",
        isDownloaded: json["isDownloaded"] as bool? ?? false,
        progress: (json["progress"] as num?)?.toDouble() ?? 0,
        localPath: json["localPath"] as String?,
        errorMessage: json["errorMessage"] as String?,
      );
}

class TtsVoice {
  final String voiceId;
  final String displayName;
  final String language;
  final TtsVoiceGender gender;
  final String description;
  final String previewText;
  final String? previewAudioPath;
  final bool isDownloaded;
  final bool isDefault;
  final String modelVersion;
  final String packId;
  final bool recommended;
  final TtsBackend backend;
  final String? grade;
  final String? sha256Prefix;
  final String? langCode;

  const TtsVoice({
    required this.voiceId,
    required this.displayName,
    required this.language,
    required this.gender,
    required this.description,
    required this.previewText,
    this.previewAudioPath,
    required this.isDownloaded,
    required this.isDefault,
    required this.modelVersion,
    required this.packId,
    this.recommended = false,
    this.backend = TtsBackend.iosSystem,
    this.grade,
    this.sha256Prefix,
    this.langCode,
  });

  TtsVoice copyWith({
    String? previewAudioPath,
    bool? isDownloaded,
    bool? isDefault,
  }) {
    return TtsVoice(
      voiceId: voiceId,
      displayName: displayName,
      language: language,
      gender: gender,
      description: description,
      previewText: previewText,
      previewAudioPath: previewAudioPath ?? this.previewAudioPath,
      isDownloaded: isDownloaded ?? this.isDownloaded,
      isDefault: isDefault ?? this.isDefault,
      modelVersion: modelVersion,
      packId: packId,
      recommended: recommended,
      backend: backend,
      grade: grade,
      sha256Prefix: sha256Prefix,
      langCode: langCode,
    );
  }

  Map<String, dynamic> toJson() => {
        "voiceId": voiceId,
        "displayName": displayName,
        "language": language,
        "gender": gender.name,
        "description": description,
        "previewText": previewText,
        "previewAudioPath": previewAudioPath,
        "isDownloaded": isDownloaded,
        "isDefault": isDefault,
        "modelVersion": modelVersion,
        "packId": packId,
        "recommended": recommended,
        "backend": backend.name,
        "grade": grade,
        "sha256Prefix": sha256Prefix,
        "langCode": langCode,
      };

  factory TtsVoice.fromJson(Map<String, dynamic> json) => TtsVoice(
        voiceId: json["voiceId"] as String,
        displayName: json["displayName"] as String,
        language: json["language"] as String? ?? "zh-CN",
        gender: TtsVoiceGender.values.firstWhere(
          (e) => e.name == json["gender"],
          orElse: () => TtsVoiceGender.neutral,
        ),
        description: json["description"] as String? ?? "",
        previewText: json["previewText"] as String? ?? "这是试听声音。",
        previewAudioPath: json["previewAudioPath"] as String?,
        isDownloaded: json["isDownloaded"] as bool? ?? false,
        isDefault: json["isDefault"] as bool? ?? false,
        modelVersion: json["modelVersion"] as String? ?? "",
        packId: json["packId"] as String? ?? "system",
        recommended: json["recommended"] as bool? ?? false,
        backend: TtsBackend.values.firstWhere(
          (e) => e.name == json["backend"],
          orElse: () => TtsBackend.iosSystem,
        ),
        grade: json["grade"] as String?,
        sha256Prefix: json["sha256Prefix"] as String?,
        langCode: json["langCode"] as String?,
      );
}

class VoiceFormulaPart {
  final String voiceId;
  final double weight;

  const VoiceFormulaPart({required this.voiceId, required this.weight});

  Map<String, dynamic> toJson() => {
        "voiceId": voiceId,
        "weight": weight,
      };

  factory VoiceFormulaPart.fromJson(Map<String, dynamic> json) =>
      VoiceFormulaPart(
        voiceId: json["voiceId"] as String,
        weight: (json["weight"] as num?)?.toDouble() ?? 1,
      );
}

class VoiceFormula {
  final String formulaId;
  final String displayName;
  final String language;
  final List<VoiceFormulaPart> parts;
  final bool isDefault;
  final DateTime createdAt;

  const VoiceFormula({
    required this.formulaId,
    required this.displayName,
    required this.language,
    required this.parts,
    this.isDefault = false,
    required this.createdAt,
  });

  String get abogenFormula => parts
      .where((part) => part.weight > 0)
      .map((part) => "${part.voiceId}*${part.weight.toStringAsFixed(2)}")
      .join(" + ");

  String get primaryVoiceId {
    if (parts.isEmpty) return "";
    final sorted = [...parts]..sort((a, b) => b.weight.compareTo(a.weight));
    return sorted.first.voiceId;
  }

  VoiceFormula copyWith({
    String? displayName,
    List<VoiceFormulaPart>? parts,
    bool? isDefault,
  }) {
    return VoiceFormula(
      formulaId: formulaId,
      displayName: displayName ?? this.displayName,
      language: language,
      parts: parts ?? this.parts,
      isDefault: isDefault ?? this.isDefault,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        "formulaId": formulaId,
        "displayName": displayName,
        "language": language,
        "parts": parts.map((e) => e.toJson()).toList(),
        "isDefault": isDefault,
        "createdAt": createdAt.toIso8601String(),
      };

  factory VoiceFormula.fromJson(Map<String, dynamic> json) => VoiceFormula(
        formulaId: json["formulaId"] as String,
        displayName: json["displayName"] as String? ?? "自定义音色",
        language: json["language"] as String? ?? "zh-CN",
        parts: (json["parts"] as List? ?? [])
            .whereType<Map>()
            .map((e) => VoiceFormulaPart.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        isDefault: json["isDefault"] as bool? ?? false,
        createdAt: DateTime.tryParse(json["createdAt"] as String? ?? "") ??
            DateTime.now(),
      );
}

class AbogenGenerationSettings {
  final String voiceId;
  final String? voiceProfileId;
  final VoiceFormula? voiceFormula;
  final SubtitleMode subtitleMode;
  final int maxChunkChars;
  final double speed;
  final double volume;
  final double pitch;

  const AbogenGenerationSettings({
    required this.voiceId,
    this.voiceProfileId,
    this.voiceFormula,
    this.subtitleMode = SubtitleMode.sentence,
    this.maxChunkChars = 180,
    this.speed = 1,
    this.volume = 1,
    this.pitch = 1,
  });
}

class TtsSegment {
  final String segmentId;
  final int bookId;
  final int chapterId;
  final String originalText;
  final String normalizedText;
  final String? audioPath;
  final double duration;
  final double startTime;
  final double endTime;
  final String voiceId;
  final String? voiceProfileId;
  final String? voiceFormula;
  final String speakerId;
  final String level;
  final LocalGenerationStatus generationStatus;
  final String? errorMessage;

  const TtsSegment({
    required this.segmentId,
    required this.bookId,
    required this.chapterId,
    required this.originalText,
    required this.normalizedText,
    this.audioPath,
    this.duration = 0,
    this.startTime = 0,
    this.endTime = 0,
    required this.voiceId,
    this.voiceProfileId,
    this.voiceFormula,
    this.speakerId = "narrator",
    this.level = "sentence",
    this.generationStatus = LocalGenerationStatus.waiting,
    this.errorMessage,
  });

  TtsSegment copyWith({
    String? audioPath,
    double? duration,
    double? startTime,
    double? endTime,
    LocalGenerationStatus? generationStatus,
    String? errorMessage,
    String? voiceProfileId,
    String? voiceFormula,
  }) {
    return TtsSegment(
      segmentId: segmentId,
      bookId: bookId,
      chapterId: chapterId,
      originalText: originalText,
      normalizedText: normalizedText,
      audioPath: audioPath ?? this.audioPath,
      duration: duration ?? this.duration,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      voiceId: voiceId,
      voiceProfileId: voiceProfileId ?? this.voiceProfileId,
      voiceFormula: voiceFormula ?? this.voiceFormula,
      speakerId: speakerId,
      level: level,
      generationStatus: generationStatus ?? this.generationStatus,
      errorMessage: errorMessage,
    );
  }

  Map<String, dynamic> toJson() => {
        "segmentId": segmentId,
        "bookId": bookId,
        "chapterId": chapterId,
        "originalText": originalText,
        "normalizedText": normalizedText,
        "audioPath": audioPath,
        "duration": duration,
        "startTime": startTime,
        "endTime": endTime,
        "voiceId": voiceId,
        "voiceProfileId": voiceProfileId,
        "voiceFormula": voiceFormula,
        "speakerId": speakerId,
        "level": level,
        "generationStatus": generationStatus.name,
        "errorMessage": errorMessage,
      };

  factory TtsSegment.fromJson(Map<String, dynamic> json) => TtsSegment(
        segmentId: json["segmentId"] as String,
        bookId: json["bookId"] as int,
        chapterId: json["chapterId"] as int? ?? 0,
        originalText: json["originalText"] as String? ?? "",
        normalizedText: json["normalizedText"] as String? ?? "",
        audioPath: json["audioPath"] as String?,
        duration: (json["duration"] as num?)?.toDouble() ?? 0,
        startTime: (json["startTime"] as num?)?.toDouble() ?? 0,
        endTime: (json["endTime"] as num?)?.toDouble() ?? 0,
        voiceId: json["voiceId"] as String? ?? "",
        voiceProfileId: json["voiceProfileId"] as String?,
        voiceFormula: json["voiceFormula"] as String?,
        speakerId: json["speakerId"] as String? ?? "narrator",
        level: json["level"] as String? ?? "sentence",
        generationStatus: LocalGenerationStatus.values.firstWhere(
          (e) => e.name == json["generationStatus"],
          orElse: () => LocalGenerationStatus.waiting,
        ),
        errorMessage: json["errorMessage"] as String?,
      );
}

class BookVoiceSettings {
  final int? bookId;
  final int? chapterId;
  final String narratorVoiceId;
  final String? maleCharacterVoiceId;
  final String? femaleCharacterVoiceId;
  final Map<String, String> roleVoiceMappings;
  final GenerationMode mode;

  const BookVoiceSettings({
    this.bookId,
    this.chapterId,
    required this.narratorVoiceId,
    this.maleCharacterVoiceId,
    this.femaleCharacterVoiceId,
    this.roleVoiceMappings = const {},
    this.mode = GenerationMode.auto,
  });

  Map<String, dynamic> toJson() => {
        "bookId": bookId,
        "chapterId": chapterId,
        "narratorVoiceId": narratorVoiceId,
        "maleCharacterVoiceId": maleCharacterVoiceId,
        "femaleCharacterVoiceId": femaleCharacterVoiceId,
        "roleVoiceMappings": roleVoiceMappings,
        "mode": mode.name,
      };

  factory BookVoiceSettings.fromJson(Map<String, dynamic> json) =>
      BookVoiceSettings(
        bookId: json["bookId"] as int?,
        chapterId: json["chapterId"] as int?,
        narratorVoiceId: json["narratorVoiceId"] as String? ?? "zh_female_warm",
        maleCharacterVoiceId: json["maleCharacterVoiceId"] as String?,
        femaleCharacterVoiceId: json["femaleCharacterVoiceId"] as String?,
        roleVoiceMappings:
            Map<String, String>.from(json["roleVoiceMappings"] as Map? ?? {}),
        mode: GenerationMode.values.firstWhere(
          (e) => e.name == json["mode"],
          orElse: () => GenerationMode.auto,
        ),
      );
}
