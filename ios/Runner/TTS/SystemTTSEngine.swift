import AVFoundation
import UIKit

protocol TTSPlayable: AnyObject {
    var isPlaying: Bool { get }
    var onPageFinished: (() -> String?)? { get set }
    func speak(text: String, rate: Float)
    func pause() -> Bool
    func resume() -> Bool
    func stop()
}

@MainActor
final class SystemTTSEngine: NSObject, TTSPlayable, AVSpeechSynthesizerDelegate, ObservableObject {
    @Published var isPlaying = false
    @Published var isPaused = false
    @Published var currentSentenceIndex = 0
    @Published var totalSentences = 0
    @Published var currentSentence = ""

    var onPageFinished: (() -> String?)?

    private let synthesizer = AVSpeechSynthesizer()
    private var sentences: [String] = []
    private var rate: Float = 0.5
    private var currentText = ""

    override init() {
        super.init()
        synthesizer.delegate = self
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
    }

    func speak(text: String, rate: Float = 0.5) {
        stop()
        self.rate = rate
        currentText = text
        sentences = splitSentences(text)
        totalSentences = sentences.count
        currentSentenceIndex = 0
        speakCurrentSentence()
    }

    private func splitSentences(_ text: String) -> [String] {
        var result: [String] = []
        text.enumerateSubstrings(in: text.startIndex..., options: .bySentences) { sub, _, _, stop in
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
                speak(text: next, rate: rate)
                return
            }
            stop()
            return
        }
        let sentence = sentences[currentSentenceIndex]
        currentSentence = sentence
        let utterance = AVSpeechUtterance(string: sentence)
        utterance.rate = rate
        utterance.voice = AVSpeechSynthesisVoice.speechVoices()
            .first(where: { $0.language == "zh-CN" && $0.quality == .enhanced })
            ?? AVSpeechSynthesisVoice(language: "zh-CN")
        utterance.prefersAssistiveTechnologySettings = false
        synthesizer.speak(utterance)
        isPlaying = true
        isPaused = false
    }

    func pause() -> Bool {
        guard isPlaying, !isPaused else { return false }
        let ok = synthesizer.pauseSpeaking(at: .word)
        if ok { isPaused = true; isPlaying = false }
        return ok
    }

    func resume() -> Bool {
        guard isPaused else { return false }
        let ok = synthesizer.continueSpeaking()
        if ok { isPaused = false; isPlaying = true }
        return ok
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        isPlaying = false
        isPaused = false
        sentences = []
        currentSentenceIndex = 0
        totalSentences = 0
    }

    func nextSentence() {
        synthesizer.stopSpeaking(at: .word)
        currentSentenceIndex += 1
        speakCurrentSentence()
    }

    func prevSentence() {
        synthesizer.stopSpeaking(at: .word)
        if currentSentenceIndex > 0 { currentSentenceIndex -= 1 }
        speakCurrentSentence()
    }

    // MARK: - AVSpeechSynthesizerDelegate
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            currentSentenceIndex += 1
            if currentSentenceIndex < sentences.count {
                speakCurrentSentence()
            } else if let next = onPageFinished?() {
                speak(text: next, rate: rate)
            } else {
                isPlaying = false
            }
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in isPlaying = false; isPaused = false }
    }
}
