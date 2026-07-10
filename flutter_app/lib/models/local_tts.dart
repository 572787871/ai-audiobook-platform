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
      );
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
