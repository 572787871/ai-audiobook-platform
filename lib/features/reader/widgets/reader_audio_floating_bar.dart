library;

import 'package:flutter/cupertino.dart';

/// 听书悬浮条（左下角）。当听书模式开启时显示。
///
/// 真实接口预留：play / pause / stop / previousSentence / nextSentence /
/// setRate / setVoice。当前 Kokoro 未完成时，点击播放必须显示真实提示
/// 「本地听书模型尚未准备」，不允许伪造播放、不启动假计时器。
class ReaderAudioFloatingBar extends StatelessWidget {
  final bool listening; // 听书模式是否开启（UI 显示依据）
  final bool modelReady; // 本地听书模型是否就绪（Kokoro）
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
          margin: const EdgeInsets.only(left: 12, bottom: 84),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: CupertinoColors.systemBackground.resolveFrom(context).withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [
              BoxShadow(color: Color(0x22000000), blurRadius: 6, offset: Offset(0, 2)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(CupertinoIcons.music_note_2, size: 20),
                  const SizedBox(width: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 160),
                    child: Text(
                      statusText,
                      style: TextStyle(color: fg, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    onPressed: modelReady ? onPlayPause : onPlayPause,
                    child: Icon(
                      modelReady
                          ? (listening ? CupertinoIcons.pause : CupertinoIcons.play)
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
