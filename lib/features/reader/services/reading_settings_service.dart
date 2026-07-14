import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart' show Color;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// 阅读器设置：字体大小、字体、行距、段距、边距、背景、文字色、亮度、主题、翻页方式，
/// 以及更多设置（自动翻页 / 常亮 / 音量键翻页 / 简繁 / 阅读方向 / 状态栏 / 进度显示 /
/// 章节标题 / 点击区域）。持久化到 Application Support/reader_settings.json。
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

/// 阅读背景主题（用于顶部/底部/正文底层配色）。
enum ReaderTheme { day, sepia, dark, night }

/// 翻页动画。
enum PageAnimation { none, slide, cover, scroll, curl }

/// 阅读背景色方案（七种 + 自定义）。
enum ReaderBackground {
  cream, // 米黄
  white, // 白色
  green, // 护眼绿
  blue, // 浅蓝
  gray, // 深灰
  black, // 纯黑
  custom, // 自定义（接口预留）
}

/// 正文文字颜色方案。
enum ReaderTextColor {
  brown, // 深棕
  black, // 黑色
  darkGray, // 深灰
  white, // 白色
  lightGray, // 浅灰
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

  /// 夜间模式阅读底色：纯深灰（iOS 暗色风），不纯黑，护眼。
  Color get nightBackground => const Color(0xFF1C1C1E);

  /// 夜间模式正文色：柔和浅灰，避免纯白刺眼。
  Color get nightText => const Color(0xFFD6D6D8);
}

extension PageAnimationX on PageAnimation {
  String get label {
    switch (this) {
      case PageAnimation.none:
        return '无动画';
      case PageAnimation.slide:
        return '平移';
      case PageAnimation.cover:
        return '覆盖';
      case PageAnimation.scroll:
        return '上下';
      case PageAnimation.curl:
        return '仿真';
    }
  }
}

extension ReaderBackgroundX on ReaderBackground {
  String get label {
    switch (this) {
      case ReaderBackground.cream:
        return '米黄';
      case ReaderBackground.white:
        return '白色';
      case ReaderBackground.green:
        return '护眼绿';
      case ReaderBackground.blue:
        return '浅蓝';
      case ReaderBackground.gray:
        return '深灰';
      case ReaderBackground.black:
        return '纯黑';
      case ReaderBackground.custom:
        return '自定义';
    }
  }

  /// 背景底色（自定义暂用米黄占位，接口预留）。
  Color get color {
    switch (this) {
      case ReaderBackground.cream:
        return const Color(0xFFF5ECD8);
      case ReaderBackground.white:
        return const Color(0xFFFFFFFF);
      case ReaderBackground.green:
        return const Color(0xFFC7EDCC);
      case ReaderBackground.blue:
        return const Color(0xFFDCE9F5);
      case ReaderBackground.gray:
        return const Color(0xFF2A2A2A);
      case ReaderBackground.black:
        return const Color(0xFF000000);
      case ReaderBackground.custom:
        return const Color(0xFFF5ECD8);
    }
  }

  /// 该背景下的默认正文文字色。
  ReaderTextColor get defaultText => switch (this) {
    ReaderBackground.cream => ReaderTextColor.brown,
    ReaderBackground.white => ReaderTextColor.black,
    ReaderBackground.green => ReaderTextColor.black,
    ReaderBackground.blue => ReaderTextColor.black,
    ReaderBackground.gray => ReaderTextColor.lightGray,
    ReaderBackground.black => ReaderTextColor.white,
    ReaderBackground.custom => ReaderTextColor.brown,
  };
}

extension ReaderTextColorX on ReaderTextColor {
  String get label {
    switch (this) {
      case ReaderTextColor.brown:
        return '深棕';
      case ReaderTextColor.black:
        return '黑色';
      case ReaderTextColor.darkGray:
        return '深灰';
      case ReaderTextColor.white:
        return '白色';
      case ReaderTextColor.lightGray:
        return '浅灰';
    }
  }

  Color get color {
    switch (this) {
      case ReaderTextColor.brown:
        return const Color(0xFF3A2E1A);
      case ReaderTextColor.black:
        return const Color(0xFF000000);
      case ReaderTextColor.darkGray:
        return const Color(0xFF555555);
      case ReaderTextColor.white:
        return const Color(0xFFFFFFFF);
      case ReaderTextColor.lightGray:
        return const Color(0xFF888888);
    }
  }
}

/// 可用正文字体（系统字体始终可用；其余标注是否已安装）。
class ReaderFontOption {
  const ReaderFontOption(this.id, this.label, this.installed);
  final String id;
  final String label;
  final bool installed;

  static const List<ReaderFontOption> options = [
    ReaderFontOption('system', '系统字体', true),
    ReaderFontOption('PingFang SC', '苹方', true),
    ReaderFontOption('STSongti-SC-Regular', '宋体', true),
    ReaderFontOption('STHeitiSC-Light', '黑体', true),
    ReaderFontOption('STKaitiSC-Regular', '楷体', true),
  ];

  /// 已安装字体的 fontFamily 名；未安装返回 null（UI 标“暂未安装”）。
  String? get fontFamily {
    if (!installed) return null;
    return id == 'system' ? null : id;
  }
}

class ReadingSettings {
  const ReadingSettings({
    this.fontSize = 22.0,
    this.fontFamily = 'system',
    this.fontWeight = 400,
    this.lineHeight = 1.8,
    this.paragraphSpacing = 20.0,
    this.horizontalMargin = 28.0,
    this.verticalMargin = 16.0,
    this.firstLineIndent = 2.0,
    this.pageAnimation = PageAnimation.slide,
    this.theme = ReaderTheme.sepia,
    this.background = ReaderBackground.cream,
    this.textColor = ReaderTextColor.brown,
    this.brightness = 1.0,
    this.eyeCare = false,
    this.nightPreviousTheme,
    this.autoPage = false,
    this.keepScreenOn = false,
    this.volumeKeyPage = false,
    this.traditionalChinese = false,
    this.readingDirection = false,
    this.showStatusBar = true,
    this.showProgress = true,
    this.showChapterTitle = true,
    this.tapZoneCustom = false,
    this.backgroundImagePath,
  });

  final double fontSize;
  final String fontFamily;
  final int fontWeight;
  final double lineHeight;
  final double paragraphSpacing;
  final double horizontalMargin;
  final double verticalMargin;
  final double firstLineIndent;
  final PageAnimation pageAnimation;
  final ReaderTheme theme;
  final ReaderBackground background;
  final ReaderTextColor textColor;
  final double brightness;
  final bool eyeCare;

  /// 进入夜间前记录的上一主题，再点夜间恢复用。
  final ReaderTheme? nightPreviousTheme;
  // ---- 更多设置（预留接口，UI 标“暂未开放”） ----
  final bool autoPage;
  final bool keepScreenOn;
  final bool volumeKeyPage;
  final bool traditionalChinese;
  final bool readingDirection;
  final bool showStatusBar;
  final bool showProgress;
  final bool showChapterTitle;
  final bool tapZoneCustom;

  /// 自定义背景图片本地路径（选中"阅读背景=自定义"且已选图时生效）。
  final String? backgroundImagePath;

  ReadingSettings copyWith({
    double? fontSize,
    String? fontFamily,
    int? fontWeight,
    double? lineHeight,
    double? paragraphSpacing,
    double? horizontalMargin,
    double? verticalMargin,
    double? firstLineIndent,
    PageAnimation? pageAnimation,
    ReaderTheme? theme,
    ReaderBackground? background,
    ReaderTextColor? textColor,
    double? brightness,
    bool? eyeCare,
    bool? clearNightPrevious,
    ReaderTheme? nightPreviousTheme,
    bool? autoPage,
    bool? keepScreenOn,
    bool? volumeKeyPage,
    bool? traditionalChinese,
    bool? readingDirection,
    bool? showStatusBar,
    bool? showProgress,
    bool? showChapterTitle,
    bool? tapZoneCustom,
    String? backgroundImagePath,
    bool? clearBackgroundImage,
  }) {
    return ReadingSettings(
      fontSize: fontSize ?? this.fontSize,
      fontFamily: fontFamily ?? this.fontFamily,
      fontWeight: fontWeight ?? this.fontWeight,
      lineHeight: lineHeight ?? this.lineHeight,
      paragraphSpacing: paragraphSpacing ?? this.paragraphSpacing,
      horizontalMargin: horizontalMargin ?? this.horizontalMargin,
      verticalMargin: verticalMargin ?? this.verticalMargin,
      firstLineIndent: firstLineIndent ?? this.firstLineIndent,
      pageAnimation: pageAnimation ?? this.pageAnimation,
      theme: theme ?? this.theme,
      background: background ?? this.background,
      textColor: textColor ?? this.textColor,
      brightness: brightness ?? this.brightness,
      eyeCare: eyeCare ?? this.eyeCare,
      nightPreviousTheme: clearNightPrevious == true
          ? null
          : (nightPreviousTheme ?? this.nightPreviousTheme),
      autoPage: autoPage ?? this.autoPage,
      keepScreenOn: keepScreenOn ?? this.keepScreenOn,
      volumeKeyPage: volumeKeyPage ?? this.volumeKeyPage,
      traditionalChinese: traditionalChinese ?? this.traditionalChinese,
      readingDirection: readingDirection ?? this.readingDirection,
      showStatusBar: showStatusBar ?? this.showStatusBar,
      showProgress: showProgress ?? this.showProgress,
      showChapterTitle: showChapterTitle ?? this.showChapterTitle,
      tapZoneCustom: tapZoneCustom ?? this.tapZoneCustom,
      backgroundImagePath: clearBackgroundImage == true
          ? null
          : (backgroundImagePath ?? this.backgroundImagePath),
    );
  }

  Map<String, dynamic> toJson() => {
    'fontSize': fontSize,
    'fontFamily': fontFamily,
    'fontWeight': fontWeight,
    'lineHeight': lineHeight,
    'paragraphSpacing': paragraphSpacing,
    'horizontalMargin': horizontalMargin,
    'verticalMargin': verticalMargin,
    'firstLineIndent': firstLineIndent,
    'pageAnimation': pageAnimation.name,
    'theme': theme.name,
    'background': background.name,
    'textColor': textColor.name,
    'brightness': brightness,
    'eyeCare': eyeCare,
    'nightPreviousTheme': nightPreviousTheme?.name,
    'autoPage': autoPage,
    'keepScreenOn': keepScreenOn,
    'volumeKeyPage': volumeKeyPage,
    'traditionalChinese': traditionalChinese,
    'readingDirection': readingDirection,
    'showStatusBar': showStatusBar,
    'showProgress': showProgress,
    'showChapterTitle': showChapterTitle,
    'tapZoneCustom': tapZoneCustom,
    if (backgroundImagePath != null) 'backgroundImagePath': backgroundImagePath,
  };

  factory ReadingSettings.fromJson(Map<String, dynamic> json) {
    final theme = _enum<ReaderTheme>(
      ReaderTheme.values,
      json['theme'],
      ReaderTheme.sepia,
    );
    final anim = _enum<PageAnimation>(
      PageAnimation.values,
      json['pageAnimation'],
      PageAnimation.slide,
    );
    final bg = _enum<ReaderBackground>(
      ReaderBackground.values,
      json['background'],
      ReaderBackground.cream,
    );
    final tc = _enum<ReaderTextColor>(
      ReaderTextColor.values,
      json['textColor'],
      ReaderBackground.cream.defaultText,
    );
    final nightPrev = _enumOrNull<ReaderTheme>(
      ReaderTheme.values,
      json['nightPreviousTheme'],
    );
    return ReadingSettings(
      fontSize: (json['fontSize'] as num?)?.toDouble() ?? 22.0,
      fontFamily: (json['fontFamily'] as String?) ?? 'system',
      fontWeight: (json['fontWeight'] as num?)?.toInt() ?? 400,
      lineHeight: (json['lineHeight'] as num?)?.toDouble() ?? 1.8,
      paragraphSpacing: (json['paragraphSpacing'] as num?)?.toDouble() ?? 20.0,
      horizontalMargin: (json['horizontalMargin'] as num?)?.toDouble() ?? 28.0,
      verticalMargin: (json['verticalMargin'] as num?)?.toDouble() ?? 16.0,
      firstLineIndent: (json['firstLineIndent'] as num?)?.toDouble() ?? 2.0,
      pageAnimation: anim,
      theme: theme,
      background: bg,
      textColor: tc,
      brightness: (json['brightness'] as num?)?.toDouble() ?? 1.0,
      eyeCare: (json['eyeCare'] as bool?) ?? false,
      nightPreviousTheme: nightPrev,
      autoPage: (json['autoPage'] as bool?) ?? false,
      keepScreenOn: (json['keepScreenOn'] as bool?) ?? false,
      volumeKeyPage: (json['volumeKeyPage'] as bool?) ?? false,
      traditionalChinese: (json['traditionalChinese'] as bool?) ?? false,
      readingDirection: (json['readingDirection'] as bool?) ?? false,
      showStatusBar: (json['showStatusBar'] as bool?) ?? true,
      showProgress: (json['showProgress'] as bool?) ?? true,
      showChapterTitle: (json['showChapterTitle'] as bool?) ?? true,
      tapZoneCustom: (json['tapZoneCustom'] as bool?) ?? false,
      backgroundImagePath: json['backgroundImagePath'] as String?,
    );
  }
}

T _enum<T>(List<T> values, dynamic name, T fallback) =>
    values.where((e) => e.toString().split('.').last == name).firstOrNull ??
    fallback;

T? _enumOrNull<T>(List<T> values, dynamic name) {
  if (name == null) return null;
  return values.where((e) => e.toString().split('.').last == name).firstOrNull;
}
