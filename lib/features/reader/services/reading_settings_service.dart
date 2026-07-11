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
  /// 同时预热默认缓存，使 [get] 在测试环境下直接同步返回，
  /// 不触发 `File.exists()`（该调用在 flutter test 的 binding 下会挂起）。
  void setDirForTest(Directory dir) {
    _dir = dir;
    _file = File(p.join(dir.path, 'reader_settings.json'));
    _cache = const ReadingSettings();
  }

  /// 测试用：直接写入内存缓存，不写磁盘、不访问 path_provider。
  void setSettingsForTest(ReadingSettings settings) {
    _cache = settings;
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

/// 翻页动画。
enum PageAnimation {
  none,
  slide,
  curl,
  cover,
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

extension PageAnimationX on PageAnimation {
  String get label {
    switch (this) {
      case PageAnimation.none:
        return '无动画';
      case PageAnimation.slide:
        return '滑动';
      case PageAnimation.curl:
        return '仿真';
      case PageAnimation.cover:
        return '覆盖';
    }
  }
}

class ReadingSettings {
  const ReadingSettings({
    this.fontSize = 18.0,
    this.fontFamily = 'system',
    this.fontWeight = 400,
    this.lineHeight = 1.6,
    this.paragraphSpacing = 12.0,
    this.horizontalMargin = 20.0,
    this.pageAnimation = PageAnimation.slide,
    this.theme = ReaderTheme.day,
  });

  final double fontSize;
  final String fontFamily;
  final int fontWeight;
  final double lineHeight;
  final double paragraphSpacing;
  final double horizontalMargin;
  final PageAnimation pageAnimation;
  final ReaderTheme theme;

  ReadingSettings copyWith({
    double? fontSize,
    String? fontFamily,
    int? fontWeight,
    double? lineHeight,
    double? paragraphSpacing,
    double? horizontalMargin,
    PageAnimation? pageAnimation,
    ReaderTheme? theme,
  }) {
    return ReadingSettings(
      fontSize: fontSize ?? this.fontSize,
      fontFamily: fontFamily ?? this.fontFamily,
      fontWeight: fontWeight ?? this.fontWeight,
      lineHeight: lineHeight ?? this.lineHeight,
      paragraphSpacing: paragraphSpacing ?? this.paragraphSpacing,
      horizontalMargin: horizontalMargin ?? this.horizontalMargin,
      pageAnimation: pageAnimation ?? this.pageAnimation,
      theme: theme ?? this.theme,
    );
  }

  Map<String, dynamic> toJson() => {
        'fontSize': fontSize,
        'fontFamily': fontFamily,
        'fontWeight': fontWeight,
        'lineHeight': lineHeight,
        'paragraphSpacing': paragraphSpacing,
        'horizontalMargin': horizontalMargin,
        'pageAnimation': pageAnimation.name,
        'theme': theme.name,
      };

  factory ReadingSettings.fromJson(Map<String, dynamic> json) {
    final themeStr = json['theme'] as String?;
    final theme = ReaderTheme.values.where((e) => e.name == themeStr).firstOrNull ??
        ReaderTheme.day;
    final animStr = json['pageAnimation'] as String?;
    final pageAnimation =
        PageAnimation.values.where((e) => e.name == animStr).firstOrNull ??
            PageAnimation.slide;
    return ReadingSettings(
      fontSize: (json['fontSize'] as num?)?.toDouble() ?? 18.0,
      fontFamily: (json['fontFamily'] as String?) ?? 'system',
      fontWeight: (json['fontWeight'] as num?)?.toInt() ?? 400,
      lineHeight: (json['lineHeight'] as num?)?.toDouble() ?? 1.6,
      paragraphSpacing: (json['paragraphSpacing'] as num?)?.toDouble() ?? 12.0,
      horizontalMargin: (json['horizontalMargin'] as num?)?.toDouble() ?? 20.0,
      pageAnimation: pageAnimation,
      theme: theme,
    );
  }
}
