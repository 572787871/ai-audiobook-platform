import 'dart:io';

import 'package:flutter/services.dart';

/// iOS 系统听书服务。
///
/// 使用 AVSpeechSynthesizer，离线可用且不依赖第三方模型。原生端完成一页
/// 朗读后通过 [onCompleted] 通知阅读器继续翻页。
class AudiobookTtsService {
  AudiobookTtsService._() {
    _channel.setMethodCallHandler(_handleNativeCall);
  }

  static final AudiobookTtsService instance = AudiobookTtsService._();
  static const MethodChannel _channel = MethodChannel('ai_audiobook/tts');

  Future<void> Function()? onCompleted;
  void Function(String message)? onError;

  bool get isSupported => Platform.isIOS;

  Future<void> speak(String text, {double rate = 0.48}) async {
    if (!isSupported || text.trim().isEmpty) return;
    await _channel.invokeMethod<void>('speak', <String, Object>{
      'text': text,
      'rate': rate,
      'language': 'zh-CN',
    });
  }

  Future<bool> pause() async {
    if (!isSupported) return false;
    return await _channel.invokeMethod<bool>('pause') ?? false;
  }

  Future<bool> resume() async {
    if (!isSupported) return false;
    return await _channel.invokeMethod<bool>('resume') ?? false;
  }

  Future<void> stop() async {
    if (!isSupported) return;
    await _channel.invokeMethod<void>('stop');
  }

  Future<void> _handleNativeCall(MethodCall call) async {
    switch (call.method) {
      case 'completed':
        await onCompleted?.call();
        return;
      case 'error':
        onError?.call(call.arguments?.toString() ?? '语音播放失败');
        return;
    }
  }

  void detach() {
    onCompleted = null;
    onError = null;
  }
}
