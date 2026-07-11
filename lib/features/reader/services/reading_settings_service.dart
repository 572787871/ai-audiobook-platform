import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// 阅读器设置：字体大小、字体、行距、段距、背景主题。
/// 持久化到 Application Support/reader_settings.json。
class ReadingSettingsService {
  ReadingSettingsService._();

  static ReadingSettingsService? _instance;
  static ReadingSettingsService get instance =>
      _instance ??= ReadingSettingsService._();

  Directory? _dir;
  File? _file;
  ReadingSettings? _cache;

  /// 测试注入目录，避免访问 path_provider。
  void setDirForTest(Directory dir) {
    _dir = dir;
    _file = File(p.join(dir.path, 'reader_settings.json'));
    _cache = null;
  }

  void resetForTest() {
    _dir = null;
    _file = null;
    _cache = null;
  }

  Future<Directory> _getDir() async {
    if (_dir != null) return _dir!;
    Directory appSupport;
    try {
      appSupport = await getApplicationSupportDirectory();
    } catch (_) {
      appSupport = Directory.systemTemp;
    }
    final dir = Directory(p.join(appSupport.path, 'reader'));
    if (!await dir.exists()) await dir.create(recursive: true);
    _dir = dir;
    _file = File(p.join(dir.path, 'reader_settings.json'));
    return dir;
  }

  Future<ReadingSettings> get() async {
    if (_cache != null) return _cache!;
    final dir = await _getDir();
    final f = _file ?? File(p.join(dir.path, 'reader_settings.json'));
    if (await f.exists()) {
      try {
        final json = jsonDecode(await f.readAsString());
        if (json is Map<String, dynamic>) {
          _cache = ReadingSettings.fromJson(json);
          return _cache!;
        }
      } catch (_) {}
    }
    _cache = const ReadingSettings();
    return _cache!;
  }

  Future<void> save(ReadingSettings settings) async {
    final dir = await _getDir();
    final f = _file ?? File(p.join(dir.path, 'reader_settings.json'));
    await f.writeAsString(jsonEncode(settings.toJson()));
    _cache = settings;
  }
}

/// 阅读背景主题。
enum ReaderTheme {
  day,
  sepia,
  dark,
  night,
}

extension ReaderThemeX on ReaderTheme {
  String get label {
    switch (this) {
      case ReaderTheme.day:
        return '白天';
      case ReaderTheme.sepia:
        return '米黄';
      case ReaderTheme.dark:
        return '深色';
      case ReaderTheme.night:
        return '夜间';
    }
  }
}

class ReadingSettings {
  const ReadingSettings({
    this.fontSize = 18.0,
    this.fontFamily = 'system',
    this.lineHeight = 1.6,
    this.paragraphSpacing = 12.0,
    this.theme = ReaderTheme.day,
  });

  final double fontSize;
  final String fontFamily;
  final double lineHeight;
  final double paragraphSpacing;
  final ReaderTheme theme;

  ReadingSettings copyWith({
    double? fontSize,
    String? fontFamily,
    double? lineHeight,
    double? paragraphSpacing,
    ReaderTheme? theme,
  }) {
    return ReadingSettings(
      fontSize: fontSize ?? this.fontSize,
      fontFamily: fontFamily ?? this.fontFamily,
      lineHeight: lineHeight ?? this.lineHeight,
      paragraphSpacing: paragraphSpacing ?? this.paragraphSpacing,
      theme: theme ?? this.theme,
    );
  }

  Map<String, dynamic> toJson() => {
        'fontSize': fontSize,
        'fontFamily': fontFamily,
        'lineHeight': lineHeight,
        'paragraphSpacing': paragraphSpacing,
        'theme': theme.name,
      };

  factory ReadingSettings.fromJson(Map<String, dynamic> json) {
    final themeStr = json['theme'] as String?;
    final theme = ReaderTheme.values.where((e) => e.name == themeStr).firstOrNull ??
        ReaderTheme.day;
    return ReadingSettings(
      fontSize: (json['fontSize'] as num?)?.toDouble() ?? 18.0,
      fontFamily: (json['fontFamily'] as String?) ?? 'system',
      lineHeight: (json['lineHeight'] as num?)?.toDouble() ?? 1.6,
      paragraphSpacing: (json['paragraphSpacing'] as num?)?.toDouble() ?? 12.0,
      theme: theme,
    );
  }
}
