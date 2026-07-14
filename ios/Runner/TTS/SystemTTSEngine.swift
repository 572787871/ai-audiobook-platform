import AVFoundation
import UIKit

// MARK: - TTS Panel View
struct TTSPanelView: View {
    @ObservedObject var engine: ReaderEngine
    @ObservedObject var ttsCoordinator: TTSCoordinator
    @Binding var settings: TTSSettings
    @Environment(\.dismiss) private var dismiss
    @State private var timerText = "关闭"
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Book info
                VStack(spacing: 4) {
                    Text(engine.currentChapterTitle)
                        .font(.headline)
                    if !ttsCoordinator.currentSentence.isEmpty {
                        Text(ttsCoordinator.currentSentence)
                            .font(.body)
                            .foregroundColor(.secondary)
                            .lineLimit(3)
                            .padding(.horizontal)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.accentColor.opacity(0.1))
                            .cornerRadius(8)
                            .padding(.horizontal)
                    }
                }
                .padding(.top)
                
                Spacer()
                
                // Playback controls
                HStack(spacing: 40) {
                    Button(action: { ttsCoordinator.prevSentence() }) {
                        Image(systemName: "backward.fill")
                            .font(.title2)
                    }
                    .disabled(ttsCoordinator.playbackState == .stopped)
                    
                    Button(action: {
                        switch ttsCoordinator.playbackState {
                        case .stopped:
                            ttsCoordinator.attach(reader: engine)
                            ttsCoordinator.speakCurrentPage(reader: engine)
                        case .playing:
                            ttsCoordinator.pause()
                        case .paused:
                            ttsCoordinator.resume()
                        }
                    }) {
                        Image(systemName: ttsCoordinator.playbackState == .playing
                              ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.accentColor)
                    }
                    
                    Button(action: { ttsCoordinator.nextSentence() }) {
                        Image(systemName: "forward.fill")
                            .font(.title2)
                    }
                    .disabled(ttsCoordinator.playbackState == .stopped)
                }
                
                // Rate slider
                VStack(spacing: 8) {
                    HStack {
                        Text("语速")
                            .font(.caption)
                        Slider(value: $settings.rate, in: 0.3...0.8) { _ in
                            ttsCoordinator.setRate(settings.rate)
                        }
                        Image(systemName: "hare")
                            .font(.caption)
                    }
                    .padding(.horizontal, 40)
                    
                    // Pitch
                    HStack {
                        Text("音调")
                            .font(.caption)
                        Slider(value: $settings.pitchMultiplier, in: 0.5...1.5)
                        Image(systemName: "music.note")
                            .font(.caption)
                    }
                    .padding(.horizontal, 40)
                }
                
                // Timer
                HStack {
                    Text("定时关闭")
                        .font(.caption)
                    Picker("", selection: $settings.timerMinutes) {
                        Text("关闭").tag(0)
                        Text("15分钟").tag(15)
                        Text("30分钟").tag(30)
                        Text("60分钟").tag(60)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 250)
                }
                .padding(.horizontal, 20)
                
                // Sentence progress
                if ttsCoordinator.totalSentences > 0 {
                    Text("\(ttsCoordinator.currentSentenceIndex + 1)/\(ttsCoordinator.totalSentences)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .navigationTitle("听书")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("关闭") {
                        ttsCoordinator.stop()
                        dismiss()
                    }
                }
            }
            .onDisappear {
                if ttsCoordinator.playbackState != .stopped {
                    ttsCoordinator.stop()
                }
            }
        }
    }
}
