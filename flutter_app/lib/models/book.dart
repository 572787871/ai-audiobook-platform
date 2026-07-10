/// 有声书模型
class Book {
  final int id;
  final int userId;
  final String title;
  final String? author;
  final String? description;
  final String? coverUrl;
  final String? audioUrl;
  final double? audioDuration;
  final String? sourceFilePath;
  final int? sourceFileSize;
  final String status;
  final String createdAt;
  final String updatedAt;

  Book({
    required this.id,
    required this.userId,
    required this.title,
    this.author,
    this.description,
    this.coverUrl,
    this.audioUrl,
    this.audioDuration,
    this.sourceFilePath,
    this.sourceFileSize,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Book.fromJson(Map<String, dynamic> json) {
    return Book(
      id: json["id"] as int,
      userId: json["user_id"] as int,
      title: json["title"] as String,
      author: json["author"] as String?,
      description: json["description"] as String?,
      coverUrl: json["cover_url"] as String?,
      audioUrl: json["audio_url"] as String?,
      audioDuration: (json["audio_duration"] as num?)?.toDouble(),
      sourceFilePath: json["source_file_path"] as String?,
      sourceFileSize: json["source_file_size"] as int?,
      status: json["status"] as String? ?? "pending",
      createdAt: json["created_at"] as String? ?? "",
      updatedAt: json["updated_at"] as String? ?? "",
    );
  }

  Map<String, dynamic> toJson() => {
        "id": id,
        "user_id": userId,
        "title": title,
        "author": author,
        "description": description,
        "cover_url": coverUrl,
        "audio_url": audioUrl,
        "audio_duration": audioDuration,
        "source_file_path": sourceFilePath,
        "source_file_size": sourceFileSize,
        "status": status,
        "created_at": createdAt,
        "updated_at": updatedAt,
      };

  Book copyWith({
    String? audioUrl,
    double? audioDuration,
    String? status,
    String? updatedAt,
  }) {
    return Book(
      id: id,
      userId: userId,
      title: title,
      author: author,
      description: description,
      coverUrl: coverUrl,
      audioUrl: audioUrl ?? this.audioUrl,
      audioDuration: audioDuration ?? this.audioDuration,
      sourceFilePath: sourceFilePath,
      sourceFileSize: sourceFileSize,
      status: status ?? this.status,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// 章节
class Chapter {
  final int index;
  final String title;
  final double start;
  final double end;

  Chapter({
    required this.index,
    required this.title,
    required this.start,
    required this.end,
  });

  factory Chapter.fromJson(Map<String, dynamic> json) {
    return Chapter(
      index: json["index"] as int,
      title: json["title"] as String,
      start: (json["start"] as num).toDouble(),
      end: (json["end"] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        "index": index,
        "title": title,
        "start": start,
        "end": end,
      };
}

/// 字幕行
class TranscriptLine {
  final double start;
  final double end;
  final String text;

  TranscriptLine({
    required this.start,
    required this.end,
    required this.text,
  });

  factory TranscriptLine.fromJson(Map<String, dynamic> json) {
    return TranscriptLine(
      start: (json["start"] as num).toDouble(),
      end: (json["end"] as num).toDouble(),
      text: json["text"] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        "start": start,
        "end": end,
        "text": text,
      };
}

/// 有声书详情（含章节和字幕）
class BookDetail extends Book {
  final List<Chapter> chapters;
  final List<TranscriptLine> transcript;
  final int? wordCount;
  final String? totalDuration;

  BookDetail({
    required super.id,
    required super.userId,
    required super.title,
    super.author,
    super.description,
    super.coverUrl,
    super.audioUrl,
    super.audioDuration,
    super.sourceFilePath,
    super.sourceFileSize,
    required super.status,
    required super.createdAt,
    required super.updatedAt,
    required this.chapters,
    required this.transcript,
    this.wordCount,
    this.totalDuration,
  });

  factory BookDetail.fromJson(Map<String, dynamic> json) {
    return BookDetail(
      id: json["id"] as int,
      userId: json["user_id"] as int,
      title: json["title"] as String,
      author: json["author"] as String?,
      description: json["description"] as String?,
      coverUrl: json["cover_url"] as String?,
      audioUrl: json["audio_url"] as String?,
      audioDuration: (json["audio_duration"] as num?)?.toDouble(),
      sourceFilePath: json["source_file_path"] as String?,
      sourceFileSize: json["source_file_size"] as int?,
      status: json["status"] as String? ?? "pending",
      createdAt: json["created_at"] as String? ?? "",
      updatedAt: json["updated_at"] as String? ?? "",
      chapters: ((json["chapters"] as List?) ?? [])
          .map((e) => Chapter.fromJson(e as Map<String, dynamic>))
          .toList(),
      transcript: ((json["transcript"] as List?) ?? [])
          .map((e) => TranscriptLine.fromJson(e as Map<String, dynamic>))
          .toList(),
      wordCount: json["word_count"] as int?,
      totalDuration: json["total_duration"] as String? ??
          (json["audio_duration"]?.toString()),
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        ...super.toJson(),
        "chapters": chapters.map((e) => e.toJson()).toList(),
        "transcript": transcript.map((e) => e.toJson()).toList(),
        "word_count": wordCount,
        "total_duration": totalDuration,
      };
}
