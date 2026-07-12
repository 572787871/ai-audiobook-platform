library;

import 'package:flutter/cupertino.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import '../services/reading_settings_service.dart';

/// 阅读设置主面板（从底部弹出），完全参考成熟小说 App：
/// 亮度 / 护眼 / 字号 / 字体 / 文字颜色 / 阅读背景 / 翻页方式 / 间距 / 更多设置 / 自动阅读。
/// 未实现项显示真实状态（功能开发中 / 暂未开放 / 暂未安装），不做假按钮。
class ReaderSettingsSheet extends StatelessWidget {
  final ReadingSettings settings;
  final void Function(ReadingSettings) onChanged;
  final void Function() onOpenSpacing;
  final void Function() onOpenMore;
  final void Function() onAutoRead;

  const ReaderSettingsSheet({
    super.key,
    required this.settings,
    required this.onChanged,
    required this.onOpenSpacing,
    required this.onOpenMore,
    required this.onAutoRead,
  });

  @override
  Widget build(BuildContext context) {
    final fg = CupertinoColors.label.resolveFrom(context);
    final line = CupertinoColors.separator.resolveFrom(context);
    return Container(
      color: CupertinoColors.systemBackground.resolveFrom(context),
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.82),
      child: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 亮度
            Row(children: [
              const Icon(CupertinoIcons.sun_max, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: CupertinoSlider(
                  value: settings.brightness,
                  min: 0.3,
                  max: 1.0,
                  onChanged: (v) => onChanged(settings.copyWith(brightness: v)),
                ),
              ),
              Text('${(settings.brightness * 100).toStringAsFixed(0)}%',
                  style: TextStyle(color: fg.withValues(alpha: 0.6), fontSize: 12)),
            ]),
            CupertinoButton(
              padding: EdgeInsets.zero,
              alignment: Alignment.centerLeft,
              onPressed: () => onChanged(settings.copyWith(eyeCare: !settings.eyeCare)),
              child: Row(children: [
                const Icon(CupertinoIcons.eye, size: 18),
                const SizedBox(width: 8),
                Text('护眼模式', style: TextStyle(color: fg)),
                const Spacer(),
                Text(settings.eyeCare ? '开' : '关',
                    style: TextStyle(color: fg.withValues(alpha: 0.6))),
              ]),
            ),
            const SizedBox(height: 8),
            // 字号
            Row(children: [
              CupertinoButton(
                minimumSize: Size.zero,
                padding: EdgeInsets.zero,
                onPressed: () => onChanged(settings.copyWith(
                    fontSize: (settings.fontSize - 1).clamp(12, 36))),
                child: const Text('A-', style: TextStyle(fontSize: 16)),
              ),
              Expanded(
                child: Center(child: Text(settings.fontSize.toStringAsFixed(0),
                    style: TextStyle(color: fg, fontSize: 18, fontWeight: FontWeight.bold))),
              ),
              CupertinoButton(
                minimumSize: Size.zero,
                padding: EdgeInsets.zero,
                onPressed: () => onChanged(settings.copyWith(
                    fontSize: (settings.fontSize + 1).clamp(12, 36))),
                child: const Text('A+', style: TextStyle(fontSize: 22)),
              ),
            ]),
            const SizedBox(height: 8),
            // 字体
            const Text('字体', style: TextStyle(fontSize: 13)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: ReaderFontOption.options.map((f) {
                final selected = f.id == settings.fontFamily;
                return CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: f.installed
                      ? () => onChanged(settings.copyWith(fontFamily: f.id))
                      : null, // 未安装不响应，真实状态由标签体现
                  child: Text(
                    f.installed ? f.label : '${f.label}（暂未安装）',
                    style: TextStyle(
                      color: f.installed
                          ? (selected ? CupertinoColors.activeBlue : fg)
                          : fg.withValues(alpha: 0.4),
                      fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                );
              }).toList(),
            ),
            Container(height: 0.5, color: line),
            const SizedBox(height: 8),
            // 文字颜色
            const Text('文字颜色', style: TextStyle(fontSize: 13)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 12,
              children: ReaderTextColor.values.map((c) {
                final selected = c == settings.textColor;
                return GestureDetector(
                  onTap: () => onChanged(settings.copyWith(textColor: c)),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: c.color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selected ? CupertinoColors.activeBlue : CupertinoColors.separator,
                        width: selected ? 3 : 1,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            Container(height: 0.5, color: line),
            const SizedBox(height: 8),
            // 阅读背景
            const Text('阅读背景', style: TextStyle(fontSize: 13)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 12,
              children: ReaderBackground.values.map((b) {
                final selected = b == settings.background;
                final custom = b == ReaderBackground.custom;
                return GestureDetector(
                  onTap: () {
                    if (custom && settings.backgroundImagePath == null) {
                      _pickBackground();
                      return;
                    }
                    onChanged(settings.copyWith(
                      background: b,
                      textColor: b.defaultText,
                    ));
                  },
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: b.color,
                      image: custom && settings.backgroundImagePath != null
                          ? DecorationImage(
                              image: FileImage(File(settings.backgroundImagePath!)),
                              fit: BoxFit.cover,
                            )
                          : null,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selected ? CupertinoColors.activeBlue : CupertinoColors.separator,
                        width: selected ? 3 : 1,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            Container(height: 0.5, color: line),
            // 自定义背景图片选择（选中"自定义"背景后可见）
            if (settings.background == ReaderBackground.custom)
              CupertinoButton(
                padding: EdgeInsets.zero,
                alignment: Alignment.centerLeft,
                onPressed: _pickBackground,
                child: Row(children: [
                  const Icon(CupertinoIcons.photo, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    settings.backgroundImagePath == null ? '选择背景图片' : '更换背景图片',
                    style: TextStyle(color: fg),
                  ),
                  const Spacer(),
                  if (settings.backgroundImagePath != null)
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      onPressed: () =>
                          onChanged(settings.copyWith(clearBackgroundImage: true)),
                      child: const Icon(CupertinoIcons.xmark_circle, size: 16),
                    ),
                ]),
              ),
            const SizedBox(height: 8),
            // 翻页方式（全部入口保留；不稳定项标“实验性”，默认不选中）
            const Text('翻页方式', style: TextStyle(fontSize: 13)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: PageAnimation.values.map((a) {
                final experimental = a != PageAnimation.slide;
                final selected = a == settings.pageAnimation;
                return CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: () => onChanged(settings.copyWith(pageAnimation: a)),
                  child: Text(
                    experimental ? '${a.label}（实验性）' : a.label,
                    style: TextStyle(
                      color: selected ? CupertinoColors.activeBlue : fg,
                      fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                      fontSize: 13,
                    ),
                  ),
                );
              }).toList(),
            ),
            Container(height: 0.5, color: line),
            // 间距设置
            CupertinoButton(
              padding: EdgeInsets.zero,
              alignment: Alignment.centerLeft,
              onPressed: onOpenSpacing,
              child: Row(children: [
                const Icon(CupertinoIcons.text_alignleft, size: 18),
                const SizedBox(width: 8),
                Text('间距设置', style: TextStyle(color: fg)),
                const Spacer(),
                const Icon(CupertinoIcons.chevron_right, size: 16),
              ]),
            ),
            // 更多设置
            CupertinoButton(
              padding: EdgeInsets.zero,
              alignment: Alignment.centerLeft,
              onPressed: onOpenMore,
              child: Row(children: [
                const Icon(CupertinoIcons.ellipsis_circle, size: 18),
                const SizedBox(width: 8),
                Text('更多设置', style: TextStyle(color: fg)),
                const Spacer(),
                const Icon(CupertinoIcons.chevron_right, size: 16),
              ]),
            ),
            // 自动阅读入口
            CupertinoButton(
              padding: EdgeInsets.zero,
              alignment: Alignment.centerLeft,
              onPressed: () {
                // 切换显示状态并驱动阅读器真实自动翻页
                onChanged(settings.copyWith(autoPage: !settings.autoPage));
                onAutoRead();
              },
              child: Row(children: [
                const Icon(CupertinoIcons.play_arrow, size: 18),
                const SizedBox(width: 8),
                Text('自动阅读', style: TextStyle(color: fg)),
                const Spacer(),
                Text(
                  settings.autoPage ? '开' : '关',
                  style: TextStyle(
                    color: settings.autoPage ? CupertinoColors.activeBlue : fg.withValues(alpha: 0.4),
                    fontSize: 12,
                  ),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickBackground() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );
    final path = result?.files.single.path;
    if (path == null) return;
    onChanged(
      settings.copyWith(background: ReaderBackground.custom, backgroundImagePath: path),
    );
  }
}
