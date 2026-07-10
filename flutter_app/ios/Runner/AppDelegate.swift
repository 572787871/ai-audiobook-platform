import Flutter
import UIKit
import AVFoundation

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    if let controller = window?.rootViewController as? FlutterViewController {
      LocalTtsPlugin.register(with: controller.binaryMessenger)
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "LocalTtsPlugin") {
      LocalTtsPlugin.register(with: registrar.messenger())
    }
  }
}

final class LocalTtsPlugin: NSObject {
  private static var instances: [LocalTtsPlugin] = []
  private let channel: FlutterMethodChannel
  private let synthesizer = AVSpeechSynthesizer()
  private var cancelled = false

  static func register(with messenger: FlutterBinaryMessenger) {
    instances.append(LocalTtsPlugin(messenger: messenger))
  }

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "ai_audiobook/local_tts", binaryMessenger: messenger)
    super.init()
    synthesizer.delegate = self
    channel.setMethodCallHandler(handle)
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "initializeTtsEngine":
      configureAudioSession()
      result(["engine": "ios-avspeech", "ready": true])
    case "getAvailableVoices":
      result(availableVoices())
    case "getInstalledVoicePacks":
      result([[
        "packId": "ios_system_zh",
        "displayName": "iPhone 系统中文离线语音",
        "modelVersion": "ios-avspeech",
        "language": "zh-CN/en-US",
        "sizeBytes": 0,
        "downloadUrl": "",
        "sha256": "",
        "isDownloaded": true,
        "progress": 1.0
      ]])
    case "generateSpeech":
      guard let args = call.arguments as? [String: Any],
            let text = args["text"] as? String,
            let outputPath = args["outputPath"] as? String else {
        result(FlutterError(code: "bad_args", message: "缺少 text 或 outputPath", details: nil))
        return
      }
      let voiceId = args["voiceId"] as? String ?? "zh_female_warm"
      let speed = args["speed"] as? Double ?? 1.0
      let volume = args["volume"] as? Double ?? 1.0
      let pitch = args["pitch"] as? Double ?? 1.0
      generateSpeech(text: text, voiceId: voiceId, speed: speed, volume: volume, pitch: pitch, outputPath: outputPath, result: result)
    case "getAudioDuration":
      guard let args = call.arguments as? [String: Any],
            let path = args["path"] as? String else {
        result(0)
        return
      }
      result(audioDuration(path: path))
    case "decodeTextFile":
      guard let args = call.arguments as? [String: Any],
            let path = args["path"] as? String else {
        result("")
        return
      }
      result(decodeTextFile(path: path))
    case "cancelGeneration":
      cancelled = true
      synthesizer.stopSpeaking(at: .immediate)
      result(true)
    case "pauseGeneration":
      result(synthesizer.pauseSpeaking(at: .word))
    case "resumeGeneration":
      result(synthesizer.continueSpeaking())
    case "previewVoice":
      // 系统语音试听：直接 speak 出声（不走写文件），立即发声、可停止。
      guard let args = call.arguments as? [String: Any],
            let text = args["text"] as? String else {
        result(FlutterError(code: "bad_args", message: "缺少 text", details: nil))
        return
      }
      let voiceId = args["voiceId"] as? String ?? "zh_female_warm"
      let backend = args["backend"] as? String ?? "system"
      if backend == "kokoro" {
        // Kokoro 试听仍需生成文件后由 Dart 侧 just_audio 播放
        let dir = self.kokoroCacheDir()
        let out = (dir as NSString).appendingPathComponent("preview_\(voiceId).wav")
        self.generateSpeech(text: text, voiceId: voiceId, speed: 1.0, volume: 1.0, pitch: 1.0, outputPath: out, result: result)
      } else {
        self.previewSpeak(text: text, voiceId: voiceId, result: result)
      }
    case "downloadVoicePack":
      // Kokoro 模型/音色下载：由 Dart 侧 KokoroModelManager 实现（含 HTTP 状态码与 SHA 校验）。
      result(FlutterError(code: "use_dart_downloader", message: "请使用 Dart 侧 KokoroModelManager 下载", details: nil))
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func configureAudioSession() {
    do {
      try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
      try AVAudioSession.sharedInstance().setActive(true)
    } catch {
      NSLog("LocalTTS audio session failed: \(error)")
    }
  }

  private func availableVoices() -> [[String: Any]] {
    let voices = AVSpeechSynthesisVoice.speechVoices()
      .filter { $0.language.hasPrefix("zh") || $0.language.hasPrefix("en") }
      .prefix(24)
    var result = voices.map { voice -> [String: Any] in
      let gender = speechGender(voice)
      return [
        "voiceId": voice.identifier,
        "displayName": displayName(voice),
        "language": voice.language,
        "gender": gender,
        "description": voice.quality == .enhanced ? "系统增强语音，适合长时间听书。" : "系统离线语音，适合本地生成。",
        "previewText": voice.language.hasPrefix("zh") ? "这是本地离线试听声音。" : "This is an offline voice preview.",
        "isDownloaded": true,
        "isDefault": false,
        "modelVersion": "ios-avspeech",
        "packId": "ios_system_zh",
        "recommended": voice.language.hasPrefix("zh")
      ]
    }
    result.insert(contentsOf: [
      [
        "voiceId": "zh_female_warm",
        "displayName": "温柔女声",
        "language": "zh-CN",
        "gender": "female",
        "description": "适合都市、言情和轻松小说的自然旁白。",
        "previewText": "你好，我会用温柔清晰的声音为你朗读这本书。",
        "isDownloaded": true,
        "isDefault": true,
        "modelVersion": "ios-avspeech",
        "packId": "ios_system_zh",
        "recommended": true
      ],
      [
        "voiceId": "zh_male_story",
        "displayName": "沉稳男声",
        "language": "zh-CN",
        "gender": "male",
        "description": "适合悬疑、历史和长篇叙事。",
        "previewText": "夜色渐深，故事从这一刻正式开始。",
        "isDownloaded": true,
        "isDefault": false,
        "modelVersion": "ios-avspeech",
        "packId": "ios_system_zh",
        "recommended": true
      ]
    ], at: 0)
    return result
  }

  private func generateSpeech(text: String, voiceId: String, speed: Double, volume: Double, pitch: Double, outputPath: String, result: @escaping FlutterResult) {
    cancelled = false
    configureAudioSession()
    DispatchQueue.global(qos: .userInitiated).async {
      let url = URL(fileURLWithPath: outputPath)
      do {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        if FileManager.default.fileExists(atPath: outputPath) {
          try FileManager.default.removeItem(at: url)
        }

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = self.resolveVoice(voiceId: voiceId)
        utterance.rate = Float(max(0.35, min(0.62, 0.5 * speed)))
        utterance.volume = Float(max(0.0, min(1.0, volume)))
        utterance.pitchMultiplier = Float(max(0.5, min(2.0, pitch)))

        var audioFile: AVAudioFile?
        var writeError: Error?
        let semaphore = DispatchSemaphore(value: 0)

        self.synthesizer.write(utterance) { buffer in
          guard let pcm = buffer as? AVAudioPCMBuffer else {
            semaphore.signal()
            return
          }
          if pcm.frameLength == 0 {
            semaphore.signal()
            return
          }
          do {
            if audioFile == nil {
              audioFile = try AVAudioFile(forWriting: url, settings: pcm.format.settings)
            }
            try audioFile?.write(from: pcm)
          } catch {
            writeError = error
            self.synthesizer.stopSpeaking(at: .immediate)
            semaphore.signal()
          }
        }

        _ = semaphore.wait(timeout: .now() + max(30, Double(text.count) * 0.35))
        if self.cancelled {
          throw NSError(domain: "LocalTTS", code: -999, userInfo: [NSLocalizedDescriptionKey: "用户已取消生成"])
        }
        if let writeError {
          throw writeError
        }
        if !FileManager.default.fileExists(atPath: outputPath) {
          throw NSError(domain: "LocalTTS", code: -2, userInfo: [NSLocalizedDescriptionKey: "音频文件未生成"])
        }
        DispatchQueue.main.async {
          result(["audioPath": outputPath, "duration": self.audioDuration(path: outputPath), "engine": "ios-avspeech"])
        }
      } catch {
        DispatchQueue.main.async {
          result(FlutterError(code: "tts_failed", message: error.localizedDescription, details: nil))
        }
      }
    }
  }

  // 直接朗读试听，立即从扬声器发声。
  private func previewSpeak(text: String, voiceId: String, result: @escaping FlutterResult) {
    cancelled = false
    configureAudioSession()
    let utterance = AVSpeechUtterance(string: text)
    utterance.voice = resolveVoice(voiceId: voiceId)
    utterance.rate = 0.5
    utterance.volume = 1.0
    utterance.pitchMultiplier = 1.0
    synthesizer.stopSpeaking(at: .immediate)
    synthesizer.speak(utterance)
    DispatchQueue.main.async {
      result(["engine": "ios-avspeech", "previewing": true])
    }
  }

  // Kokoro 模型缓存目录（Documents/kokoro）。
  private func kokoroCacheDir() -> String {
    let base = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first!
    let dir = (base as NSString).appendingPathComponent("kokoro")
    try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
    return dir
  }

  private func resolveVoice(voiceId: String) -> AVSpeechSynthesisVoice? {
    if voiceId.hasPrefix("com.apple.") {
      return AVSpeechSynthesisVoice(identifier: voiceId)
    }
    let voices = AVSpeechSynthesisVoice.speechVoices()
    let zhVoices = voices.filter { $0.language.hasPrefix("zh") }
    let enUSVoices = voices.filter { $0.language.hasPrefix("en-US") }
    let enGBVoices = voices.filter { $0.language.hasPrefix("en-GB") }
    let lower = voiceId.lowercased()

    if lower.hasPrefix("af_") || lower.hasPrefix("bf_") || lower.hasPrefix("en_female") {
      let pool = lower.hasPrefix("bf_") ? enGBVoices : enUSVoices
      if let female = pool.first(where: { speechGender($0) == "female" }) { return female }
      if let fallback = pool.first { return fallback }
    }
    if lower.hasPrefix("am_") || lower.hasPrefix("bm_") || lower.hasPrefix("en_male") {
      let pool = lower.hasPrefix("bm_") ? enGBVoices : enUSVoices
      if let male = pool.first(where: { speechGender($0) == "male" }) { return male }
      if let fallback = pool.first { return fallback }
    }
    if lower.hasPrefix("zm_") || lower.contains("male") {
      if let male = zhVoices.first(where: { speechGender($0) == "male" }) { return male }
    }
    if lower.hasPrefix("zf_") || lower.contains("female") {
      if let female = zhVoices.first(where: { speechGender($0) == "female" }) { return female }
    }
    return AVSpeechSynthesisVoice(language: "zh-CN") ?? zhVoices.first
  }

  private func audioDuration(path: String) -> Double {
    do {
      let file = try AVAudioFile(forReading: URL(fileURLWithPath: path))
      let sampleRate = file.processingFormat.sampleRate
      guard sampleRate > 0 else { return 0 }
      return Double(file.length) / sampleRate
    } catch {
      return 0
    }
  }

  private func decodeTextFile(path: String) -> String {
    guard let data = FileManager.default.contents(atPath: path) else { return "" }
    let gb18030 = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue)))
    for encoding in [String.Encoding.utf8, .utf16, .utf16LittleEndian, .utf16BigEndian, gb18030, .isoLatin1] {
      if let text = String(data: data, encoding: encoding) {
        return text
      }
    }
    return String(decoding: data, as: UTF8.self)
  }

  private func displayName(_ voice: AVSpeechSynthesisVoice) -> String {
    if voice.name.isEmpty { return voice.identifier }
    if voice.language.hasPrefix("zh") { return "\(voice.name) 中文" }
    return voice.name
  }

  private func speechGender(_ voice: AVSpeechSynthesisVoice) -> String {
    if #available(iOS 13.0, *) {
      switch voice.gender {
      case .male: return "male"
      case .female: return "female"
      default: return "neutral"
      }
    }
    return "neutral"
  }
}

extension LocalTtsPlugin: AVSpeechSynthesizerDelegate {}
