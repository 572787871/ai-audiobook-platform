import AVFoundation
import SwiftUI
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

// MARK: - TTS Coordinator
@MainActor
final class TTSCoordinator: ObservableObject {
    @Published var playbackState: TTSPlaybackState = .stopped
    @Published var currentSentenceIndex = 0
    @Published var totalSentences = 0
    @Published var currentSentence = ""
    
    private let engine = SpeechEngine()
    private var sentences: [String] = []
    private var settings = TTSSettings()
    private weak var readerEngine: ReaderEngine?
    
    var onPageFinished: (() -> String?)?
    
    func attach(reader: ReaderEngine) {
        readerEngine = reader
        engine.onPageFinished = { [weak self] in
            guard let self = self, let reader = self.readerEngine else { return nil }
            if reader.nextPage() {
                return reader.plainText(for: reader.currentPage)
            }
            return nil
        }
    }
    
    func speak(text: String, settings: TTSSettings) {
        stop()
        self.settings = settings
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
        currentSentence = sentences[currentSentenceIndex]
        engine.speak(sentences[currentSentenceIndex], rate: settings.rate, pitch: settings.pitchMultiplier)
        playbackState = .playing
    }
    
    func pause() { engine.pause(); playbackState = .paused }
    func resume() { engine.resume(); playbackState = .playing }
    
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
        currentSentenceIndex = min(currentSentenceIndex + 1, max(0, sentences.count - 1))
        speakCurrentSentence()
    }
    
    func prevSentence() {
        engine.stop()
        currentSentenceIndex = max(0, currentSentenceIndex - 1)
        speakCurrentSentence()
    }
    
    func setRate(_ rate: Float) { settings.rate = rate }
}

// MARK: - Speech Engine (AVSpeechSynthesizer Wrapper)
@MainActor
final class SpeechEngine: NSObject, AVSpeechSynthesizerDelegate {
    private let synthesizer = AVSpeechSynthesizer()
    var onPageFinished: (() -> String?)?
    
    override init() {
        super.init()
        synthesizer.delegate = self
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
    }
    
    func speak(_ text: String, rate: Float = 0.5, pitch: Float = 1.0) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = rate
        utterance.pitchMultiplier = pitch
        utterance.voice = AVSpeechSynthesisVoice.speechVoices()
            .first(where: { $0.language == "zh-CN" && $0.quality == .enhanced })
            ?? AVSpeechSynthesisVoice(language: "zh-CN")
        synthesizer.speak(utterance)
    }
    
    func pause() { synthesizer.pauseSpeaking(at: .word) }
    func resume() { synthesizer.continueSpeaking() }
    func stop() { synthesizer.stopSpeaking(at: .immediate) }
    
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in self.onPageFinished?() }
    }
}

// MARK: - TTS Panel View
struct TTSPanelView: View {
    @ObservedObject var engine: ReaderEngine
    @ObservedObject var ttsCoordinator: TTSCoordinator
    @Binding var settings: TTSSettings
    @Environment(\.dismiss) private var dismiss
    @State private var timerMinutes = 0
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(spacing: 4) {
                    Text(engine.currentChapterTitle)
                        .font(.headline)
                    if !ttsCoordinator.currentSentence.isEmpty {
                        Text(ttsCoordinator.currentSentence)
                            .font(.body)
                            .foregroundColor(.secondary)
                            .lineLimit(3)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.accentColor.opacity(0.1))
                            .cornerRadius(8)
                            .padding(.horizontal)
                    }
                }
                .padding(.top)
                
                Spacer()
                
                HStack(spacing: 40) {
                    Button(action: { ttsCoordinator.prevSentence() }) {
                        Image(systemName: "backward.fill").font(.title2)
                    }
                    .disabled(ttsCoordinator.playbackState == .stopped)
                    
                    Button(action: {
                        switch ttsCoordinator.playbackState {
                        case .stopped:
                            ttsCoordinator.attach(reader: engine)
                            ttsCoordinator.speakCurrentPage(reader: engine)
                        case .playing: ttsCoordinator.pause()
                        case .paused: ttsCoordinator.resume()
                        }
                    }) {
                        Image(systemName: ttsCoordinator.playbackState == .playing
                              ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.accentColor)
                    }
                    
                    Button(action: { ttsCoordinator.nextSentence() }) {
                        Image(systemName: "forward.fill").font(.title2)
                    }
                    .disabled(ttsCoordinator.playbackState == .stopped)
                }
                
                VStack(spacing: 8) {
                    HStack {
                        Text("语速").font(.caption)
                        Slider(value: $settings.rate, in: 0.3...0.8) { _ in
                            ttsCoordinator.setRate(settings.rate)
                        }
                        Image(systemName: "hare").font(.caption)
                    }
                    .padding(.horizontal, 40)
                    
                    HStack {
                        Text("音调").font(.caption)
                        Slider(value: $settings.pitchMultiplier, in: 0.5...1.5)
                        Image(systemName: "music.note").font(.caption)
                    }
                    .padding(.horizontal, 40)
                    
                    HStack {
                        Text("定时关闭").font(.caption)
                        Picker("", selection: $timerMinutes) {
                            Text("关闭").tag(0)
                            Text("15分钟").tag(15)
                            Text("30分钟").tag(30)
                            Text("60分钟").tag(60)
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 250)
                    }
                    .padding(.horizontal, 20)
                }
                
                if ttsCoordinator.totalSentences > 0 {
                    Text("\(ttsCoordinator.currentSentenceIndex + 1)/\(ttsCoordinator.totalSentences)")
                        .font(.caption).foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .navigationTitle("听书")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("关闭") { ttsCoordinator.stop(); dismiss() }
                }
            }
            .onDisappear {
                if ttsCoordinator.playbackState != .stopped { ttsCoordinator.stop() }
            }
        }
    }
}
