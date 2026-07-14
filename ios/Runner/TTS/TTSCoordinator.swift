import AVFoundation
import UIKit

// MARK: - TTS Settings
struct TTSSettings {
    var rate: Float = 0.5
    var pitchMultiplier: Float = 1.0
    var voiceId: String?
    var timerMinutes: Int = 0
}

// MARK: - TTS Playback State
enum TTSPlaybackState {
    case stopped
    case playing
    case paused
}

// MARK: - TTSCoordinator
@MainActor
final class TTSCoordinator: ObservableObject {
    @Published var playbackState: TTSPlaybackState = .stopped
    @Published var currentSentenceIndex = 0
    @Published var totalSentences = 0
    @Published var currentSentence = ""
    @Published var highlightRange: NSRange?
    
    private let engine = SystemTTSEngine()
    private var sentences: [String] = []
    private var currentText: String = ""
    private var settings = TTSSettings()
    private weak var readerEngine: ReaderEngine?
    
    var onPageFinished: (() -> String?)?
    
    func attach(reader: ReaderEngine) {
        readerEngine = reader
        engine.onPageFinished = { [weak self] in
            guard let self = self else { return nil }
            // Auto-advance to next page
            if reader.nextPage() {
                return reader.plainText(for: reader.currentPage)
            }
            return nil
        }
    }
    
    func speak(text: String, settings: TTSSettings) {
        stop()
        self.settings = settings
        self.currentText = text
        sentences = splitSentences(text)
        totalSentences = sentences.count
        currentSentenceIndex = 0
        playbackState = .playing
        speakCurrentSentence()
    }
    
    func speakCurrentPage(reader: ReaderEngine) {
        let text = reader.plainText(for: reader.currentPage)
        speak(text: text, settings: settings)
    }
    
    private func splitSentences(_ text: String) -> [String] {
        var result: [String] = []
        text.enumerateSubstrings(in: text.startIndex..., options: .bySentences) { sub, _, _, _ in
            if let s = sub?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty {
                result.append(s)
            }
        }
        if result.isEmpty { result = [text] }
        return result
    }
    
    private func speakCurrentSentence() {
        guard currentSentenceIndex < sentences.count else {
            if let next = onPageFinished?() {
                speak(text: next, settings: settings)
                return
            }
            stop()
            return
        }
        
        let sentence = sentences[currentSentenceIndex]
        currentSentence = sentence
        
        let utterance = AVSpeechUtterance(string: sentence)
        utterance.rate = settings.rate
        utterance.pitchMultiplier = settings.pitchMultiplier
        utterance.voice = AVSpeechSynthesisVoice.speechVoices()
            .first(where: { $0.language == "zh-CN" && $0.quality == .enhanced })
            ?? AVSpeechSynthesisVoice(language: "zh-CN")
        
        engine.speakCurrent(utterance)
        playbackState = .playing
    }
    
    func pause() {
        engine.pause()
        playbackState = .paused
    }
    
    func resume() {
        engine.resume()
        playbackState = .playing
    }
    
    func stop() {
        engine.stop()
        playbackState = .stopped
        sentences = []
        currentSentenceIndex = 0
        totalSentences = 0
        currentSentence = ""
    }
    
    func nextSentence() {
        engine.stop()
        currentSentenceIndex += 1
        speakCurrentSentence()
    }
    
    func prevSentence() {
        engine.stop()
        if currentSentenceIndex > 0 { currentSentenceIndex -= 1 }
        speakCurrentSentence()
    }
    
    func setRate(_ rate: Float) {
        settings.rate = rate
        if playbackState == .playing {
            // Will take effect on next utterance
        }
    }
}

// MARK: - SystemTTSEngine (AVSpeechSynthesizer Wrapper)
@MainActor
final class SystemTTSEngine: NSObject, AVSpeechSynthesizerDelegate {
    private let synthesizer = AVSpeechSynthesizer()
    var onPageFinished: (() -> String?)?
    var onFinish: (() -> Void)?
    var onCancel: (() -> Void)?
    
    override init() {
        super.init()
        synthesizer.delegate = self
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
    }
    
    func speakCurrent(_ utterance: AVSpeechUtterance) {
        synthesizer.speak(utterance)
    }
    
    func pause() {
        synthesizer.pauseSpeaking(at: .word)
    }
    
    func resume() {
        synthesizer.continueSpeaking()
    }
    
    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
    }
    
    // MARK: - AVSpeechSynthesizerDelegate
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.onFinish?()
        }
    }
    
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.onCancel?()
        }
    }
    
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, willSpeakRangeOfSpeechString characterRange: NSRange, utterance: AVSpeechUtterance) {
        Task { @MainActor in
            // Could track range for highlighting
        }
    }
}
