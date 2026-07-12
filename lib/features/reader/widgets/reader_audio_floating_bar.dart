library;

import 'package:flutter/cupertino.dart';

/// 听书悬浮条（左下角）。当听书模式开启时显示。
///
/// 由 iOS AVSpeechSynthesizer 驱动真实播放，支持播放/暂停与前后翻页。
class ReaderAudioFloatingBar extends StatelessWidget {
  final bool listening; // 听书模式是否开启（UI 显示依据）
  final bool modelReady; // 当前平台是否支持系统语音
  final bool playing;
  final String title;
  final String statusText; // 当前真实状态文案
  final double progress; // 0..1 当前句/段落进度（真实模型接入后由 TTS 提供）
  final void Function() onPrevSentence;
  final void Function() onNextSentence;
  final void Function(double) onSeek;
  final void Function() onPlayPause;
  final void Function() onClose;

  const ReaderAudioFloatingBar({
    super.key,
    required this.listening,
    required this.modelReady,
    required this.playing,
    required this.title,
    required this.statusText,
    this.progress = 0.0,
    required this.onPrevSentence,
    required this.onNextSentence,
    required this.onSeek,
    required this.onPlayPause,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    if (!listening) return const SizedBox.shrink();
    final fg = CupertinoColors.label.resolveFrom(context);
    return SafeArea(
      top: false,
      child: Align(
        alignment: Alignment.bottomLeft,
        child: Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 86),
          padding: const EdgeInsets.fromLTRB(14, 10, 10, 8),
          decoration: BoxDecoration(
            color: CupertinoColors.systemBackground
                .resolveFrom(context)
                .withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(18),
            boxShadow: const [
              BoxShadow(
                color: Color(0x22000000),
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(CupertinoIcons.headphones, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            color: fg,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          statusText,
                          style: TextStyle(
                            color: fg.withValues(alpha: 0.6),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    onPressed: modelReady ? onPlayPause : onPlayPause,
                    child: Icon(
                      modelReady
                          ? (playing
                                ? CupertinoIcons.pause_fill
                                : CupertinoIcons.play_fill)
                          : CupertinoIcons.play,
                      size: 22,
                    ),
                  ),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    onPressed: onClose,
                    child: const Icon(CupertinoIcons.xmark, size: 18),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              // 上一段 / 进度 / 下一段
              Row(
                children: [
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    onPressed: onPrevSentence,
                    child: const Icon(CupertinoIcons.back, size: 18),
                  ),
                  Expanded(
                    child: CupertinoSlider(
                      value: progress.clamp(0.0, 1.0),
                      onChanged: onSeek,
                    ),
                  ),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    onPressed: onNextSentence,
                    child: const Icon(CupertinoIcons.forward, size: 18),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
