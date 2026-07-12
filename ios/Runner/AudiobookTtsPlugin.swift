import AVFoundation
import Flutter

/// Flutter 与 iOS 系统语音合成之间的轻量桥接。
final class AudiobookTtsPlugin: NSObject, FlutterPlugin, AVSpeechSynthesizerDelegate {
  private let synthesizer = AVSpeechSynthesizer()
  private var channel: FlutterMethodChannel?
  private var shouldReportCompletion = false

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "ai_audiobook/tts",
      binaryMessenger: registrar.messenger()
    )
    let instance = AudiobookTtsPlugin()
    instance.channel = channel
    instance.synthesizer.delegate = instance
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "speak":
      guard
        let arguments = call.arguments as? [String: Any],
        let text = arguments["text"] as? String,
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      else {
        result(FlutterError(code: "invalid_text", message: "朗读内容为空", details: nil))
        return
      }

      synthesizer.stopSpeaking(at: .immediate)
      configureAudioSession()
      let utterance = AVSpeechUtterance(string: text)
      let language = arguments["language"] as? String ?? "zh-CN"
      utterance.voice = AVSpeechSynthesisVoice(language: language)
      let requestedRate = (arguments["rate"] as? NSNumber)?.floatValue ?? 0.48
      utterance.rate = min(max(requestedRate, AVSpeechUtteranceMinimumSpeechRate),
                           AVSpeechUtteranceMaximumSpeechRate)
      utterance.preUtteranceDelay = 0.05
      shouldReportCompletion = true
      synthesizer.speak(utterance)
      result(nil)

    case "pause":
      result(synthesizer.pauseSpeaking(at: .word))

    case "resume":
      result(synthesizer.continueSpeaking())

    case "stop":
      shouldReportCompletion = false
      synthesizer.stopSpeaking(at: .immediate)
      result(nil)

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func configureAudioSession() {
    do {
      let session = AVAudioSession.sharedInstance()
      try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
      try session.setActive(true)
    } catch {
      channel?.invokeMethod("error", arguments: error.localizedDescription)
    }
  }

  func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                         didFinish utterance: AVSpeechUtterance) {
    guard shouldReportCompletion else { return }
    shouldReportCompletion = false
    channel?.invokeMethod("completed", arguments: nil)
  }
}
