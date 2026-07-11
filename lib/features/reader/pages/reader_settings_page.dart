library;

import 'package:flutter/cupertino.dart';
import '../services/reading_settings_service.dart';

/// 阅读设置页（独立页面）：字体/字号/字重/行距/段距/边距/主题/翻页方式，全部实时生效。
class ReaderSettingsPage extends StatefulWidget {
  final ReadingSettings settings;
  final void Function(ReadingSettings) onChanged;

  const ReaderSettingsPage({
    super.key,
    required this.settings,
    required this.onChanged,
  });

  @override
  State<ReaderSettingsPage> createState() => _ReaderSettingsPageState();
}

class _ReaderSettingsPageState extends State<ReaderSettingsPage> {
  late ReadingSettings _s;

  @override
  void initState() {
    super.initState();
    _s = widget.settings;
  }

  void _update(ReadingSettings next) {
    _s = next;
    widget.onChanged(next);
    setState(() {});
  }

  String _animLabel(PageAnimation a) {
    switch (a) {
      case PageAnimation.none:
        return '无动画';
      case PageAnimation.slide:
        return '滑动';
      case PageAnimation.cover:
        return '覆盖';
      case PageAnimation.scroll:
        return '滚动';
      case PageAnimation.curl:
        return '仿真';
    }
  }

  @override
  Widget build(BuildContext context) {
    final themes = ReaderTheme.values;
    final animations = const [
      PageAnimation.slide,
      PageAnimation.cover,
      PageAnimation.scroll,
      PageAnimation.none,
      PageAnimation.curl,
    ];
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('阅读设置'),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Text('完成'),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(children: [
              const Text('字号'),
              CupertinoButton(
                onPressed: () => _update(_s.copyWith(fontSize: (_s.fontSize - 1).clamp(12, 36))),
                child: const Icon(CupertinoIcons.minus_circle),
              ),
              Text(_s.fontSize.toStringAsFixed(0)),
              CupertinoButton(
                onPressed: () => _update(_s.copyWith(fontSize: (_s.fontSize + 1).clamp(12, 36))),
                child: const Icon(CupertinoIcons.plus_circle),
              ),
            ]),
            Row(children: [
              const Text('行距'),
              Expanded(
                child: CupertinoSlider(
                  value: _s.lineHeight,
                  min: 1.0,
                  max: 2.4,
                  onChanged: (v) => _update(_s.copyWith(lineHeight: v)),
                ),
              ),
              Text(_s.lineHeight.toStringAsFixed(1)),
            ]),
            Row(children: [
              const Text('字重'),
              Expanded(
                child: CupertinoSlider(
                  value: _s.fontWeight.toDouble(),
                  min: 300,
                  max: 700,
                  divisions: 4,
                  onChanged: (v) => _update(_s.copyWith(fontWeight: v.round())),
                ),
              ),
            ]),
            Row(children: [
              const Text('段距'),
              Expanded(
                child: CupertinoSlider(
                  value: _s.paragraphSpacing,
                  min: 0,
                  max: 32,
                  onChanged: (v) => _update(_s.copyWith(paragraphSpacing: v)),
                ),
              ),
            ]),
            Row(children: [
              const Text('边距'),
              Expanded(
                child: CupertinoSlider(
                  value: _s.horizontalMargin,
                  min: 8,
                  max: 48,
                  onChanged: (v) => _update(_s.copyWith(horizontalMargin: v)),
                ),
              ),
            ]),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: themes
                  .map((t) => CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () => _update(_s.copyWith(theme: t)),
                        child: Text(
                          t.label,
                          style: TextStyle(
                            fontWeight: _s.theme == t ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ))
                  .toList(),
            ),
            Wrap(
              spacing: 8,
              children: animations
                  .map((a) => CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () => _update(_s.copyWith(pageAnimation: a)),
                        child: Text(
                          _animLabel(a),
                          style: TextStyle(
                            fontWeight: _s.pageAnimation == a ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}
