import AVFoundation
import Foundation
import MediaPlayer
import Observation
import UIKit

enum NarrationPlaybackState: Equatable {
  case stopped
  case playing
  case paused
}

struct NarrationSegment: Identifiable, Equatable {
  let id: Int
  let text: String
  let sourceRange: NSRange
}

/// Paragraph-first chunking adapted from Yuedu Reader's TTSTextChunker.
enum NarrationTextChunker {
  static func split(_ text: String, startingAtUTF16Offset offset: Int, targetLength: Int = 1200) -> [NarrationSegment] {
    let source = text as NSString
    let startOffset = min(max(0, offset), source.length)
    guard startOffset < source.length else { return [] }
    let suffix = source.substring(from: startOffset)
    let suffixSource = suffix as NSString
    var ranges: [NSRange] = []
    var cursor = 0
    let cap = max(1, targetLength)
    while cursor < suffixSource.length {
      let remaining = NSRange(location: cursor, length: suffixSource.length - cursor)
      let newline = suffixSource.rangeOfCharacter(from: .newlines, options: [], range: remaining)
      let rawCappedEnd = min(suffixSource.length, cursor + cap)
      let composedRange = suffixSource.rangeOfComposedCharacterSequences(
        for: NSRange(location: cursor, length: rawCappedEnd - cursor)
      )
      let cappedEnd = min(suffixSource.length, NSMaxRange(composedRange))
      let end: Int
      if newline.location != NSNotFound, newline.location < cappedEnd {
        end = NSMaxRange(newline)
      } else {
        end = cappedEnd
      }
      appendTrimmedRange(NSRange(location: cursor, length: end - cursor), source: suffixSource, to: &ranges)
      cursor = end
    }

    return ranges.enumerated().map { index, range in
      let absolute = NSRange(location: startOffset + range.location, length: range.length)
      return NarrationSegment(id: index, text: source.substring(with: absolute), sourceRange: absolute)
    }
  }

  private static func appendTrimmedRange(_ range: NSRange, source: NSString, to ranges: inout [NSRange]) {
    guard range.length > 0 else { return }
    var start = range.location
    var end = NSMaxRange(range)
    let whitespace = CharacterSet.whitespacesAndNewlines
    while start < end,
          source.substring(with: NSRange(location: start, length: 1)).unicodeScalars.allSatisfy(whitespace.contains) {
      start += 1
    }
    while start < end,
          source.substring(with: NSRange(location: end - 1, length: 1)).unicodeScalars.allSatisfy(whitespace.contains) {
      end -= 1
    }
    guard start < end else { return }
    let trimmed = NSRange(location: start, length: end - start)
    let spoken = source.substring(with: trimmed)
    let hasSpeech = spoken.unicodeScalars.contains { CharacterSet.letters.contains($0) || CharacterSet.decimalDigits.contains($0) }
    if !hasSpeech, let last = ranges.indices.last {
      ranges[last] = NSUnionRange(ranges[last], trimmed)
    } else if hasSpeech {
      ranges.append(trimmed)
    }
  }
}

@Observable
final class NarrationController: NSObject, AVSpeechSynthesizerDelegate, @unchecked Sendable {
  private let synthesizer = AVSpeechSynthesizer()
  private var segments: [NarrationSegment] = []
  private var activeUtterance: AVSpeechUtterance?
  private var sleepTimer: Timer?
  private var remoteCommandsRegistered = false
  private(set) var bookTitle = ""
  private(set) var playbackState: NarrationPlaybackState = .stopped
  private(set) var currentSegmentIndex = 0
  private(set) var currentSegmentText = ""
  private(set) var sleepMinutes = 0
  var speechRate: Float
  var voiceIdentifier: String
  var onSegmentChanged: ((NarrationSegment) -> Void)?
  var onFinished: (() -> Void)?

  var isPlaying: Bool { playbackState == .playing }
  var totalSegments: Int { segments.count }
  var progress: Double {
    guard segments.count > 1 else { return segments.isEmpty ? 0 : 1 }
    return Double(currentSegmentIndex) / Double(segments.count - 1)
  }

  override init() {
    let savedRate = UserDefaults.standard.double(forKey: "reader.tts.rate")
    speechRate = savedRate > 0 ? Float(savedRate) : AVSpeechUtteranceDefaultSpeechRate
    voiceIdentifier = UserDefaults.standard.string(forKey: "reader.tts.voice") ?? ""
    super.init()
    synthesizer.delegate = self
    configureRemoteCommands()
  }

  deinit {
    removeRemoteCommands()
  }

  func start(text: String, title: String, fromUTF16Offset offset: Int) {
    stop(deactivateSession: false)
    segments = NarrationTextChunker.split(text, startingAtUTF16Offset: offset)
    guard !segments.isEmpty else { return }
    bookTitle = title
    currentSegmentIndex = 0
    activateAudioSession()
    speakCurrentSegment()
  }

  func toggle() {
    switch playbackState {
    case .playing: pause()
    case .paused: resume()
    case .stopped: break
    }
  }

  func pause() {
    guard playbackState == .playing else { return }
    _ = synthesizer.pauseSpeaking(at: .word)
    playbackState = .paused
    updateNowPlaying()
  }

  func resume() {
    guard playbackState == .paused else { return }
    playbackState = .playing
    if synthesizer.isPaused {
      _ = synthesizer.continueSpeaking()
    } else {
      speakCurrentSegment()
    }
    updateNowPlaying()
  }

  func stop() { stop(deactivateSession: true) }

  func shutdown() {
    stop()
    removeRemoteCommands()
  }

  func skipForward() { seek(to: currentSegmentIndex + 1) }
  func skipBackward() { seek(to: currentSegmentIndex - 1) }

  func seek(to index: Int) {
    guard !segments.isEmpty else { return }
    let target = min(max(0, index), segments.count - 1)
    let shouldPlay = playbackState == .playing
    activeUtterance = nil
    synthesizer.stopSpeaking(at: .immediate)
    currentSegmentIndex = target
    publishCurrentSegment()
    if shouldPlay {
      speakCurrentSegment()
    } else {
      playbackState = .paused
      updateNowPlaying()
    }
  }

  func seek(toProgress progress: Double) {
    guard !segments.isEmpty else { return }
    seek(to: Int((progress.clamped(to: 0...1) * Double(segments.count - 1)).rounded()))
  }

  func updateRate(_ rate: Float) {
    speechRate = min(max(rate, AVSpeechUtteranceMinimumSpeechRate), AVSpeechUtteranceMaximumSpeechRate)
    UserDefaults.standard.set(Double(speechRate), forKey: "reader.tts.rate")
    guard playbackState != .stopped else { return }
    let wasPlaying = playbackState == .playing
    activeUtterance = nil
    synthesizer.stopSpeaking(at: .immediate)
    if wasPlaying { speakCurrentSegment() }
  }

  func updateVoice(_ identifier: String) {
    voiceIdentifier = identifier
    UserDefaults.standard.set(identifier, forKey: "reader.tts.voice")
    guard playbackState == .playing else { return }
    activeUtterance = nil
    synthesizer.stopSpeaking(at: .immediate)
    speakCurrentSegment()
  }

  func setSleepTimer(minutes: Int) {
    sleepTimer?.invalidate()
    sleepTimer = nil
    sleepMinutes = max(0, minutes)
    guard sleepMinutes > 0 else { return }
    sleepTimer = Timer.scheduledTimer(withTimeInterval: Double(sleepMinutes * 60), repeats: false) { [weak self] _ in
      self?.stop()
    }
  }

  func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
    guard utterance === activeUtterance else { return }
    playbackState = .playing
    publishCurrentSegment()
  }

  func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
    guard utterance === activeUtterance else { return }
    activeUtterance = nil
    let next = currentSegmentIndex + 1
    if next < segments.count {
      currentSegmentIndex = next
      speakCurrentSegment()
    } else {
      stop()
      onFinished?()
    }
  }

  func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
    guard utterance === activeUtterance else { return }
    activeUtterance = nil
  }

  private func speakCurrentSegment() {
    guard segments.indices.contains(currentSegmentIndex) else { return }
    let segment = segments[currentSegmentIndex]
    let utterance = AVSpeechUtterance(string: segment.text)
    utterance.rate = speechRate
    utterance.voice = selectedVoice(for: segment.text)
    utterance.preUtteranceDelay = 0
    utterance.postUtteranceDelay = 0
    activeUtterance = utterance
    playbackState = .playing
    publishCurrentSegment()
    synthesizer.speak(utterance)
  }

  private func selectedVoice(for text: String) -> AVSpeechSynthesisVoice? {
    if !voiceIdentifier.isEmpty, let selected = AVSpeechSynthesisVoice(identifier: voiceIdentifier) {
      return selected
    }
    let containsCJK = text.unicodeScalars.contains { (0x3400...0x9fff).contains(Int($0.value)) }
    return AVSpeechSynthesisVoice(language: containsCJK ? "zh-CN" : Locale.current.identifier.replacingOccurrences(of: "_", with: "-"))
  }

  private func publishCurrentSegment() {
    guard segments.indices.contains(currentSegmentIndex) else { return }
    let segment = segments[currentSegmentIndex]
    currentSegmentText = segment.text
    onSegmentChanged?(segment)
    updateNowPlaying()
  }

  private func activateAudioSession() {
    do {
      let session = AVAudioSession.sharedInstance()
      try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
      try session.setActive(true)
    } catch {
      // AVSpeechSynthesizer can still speak when session activation is unavailable.
    }
  }

  private func configureRemoteCommands() {
    guard !remoteCommandsRegistered else { return }
    remoteCommandsRegistered = true
    let commands = MPRemoteCommandCenter.shared()
    commands.playCommand.isEnabled = true
    commands.pauseCommand.isEnabled = true
    commands.togglePlayPauseCommand.isEnabled = true
    commands.nextTrackCommand.isEnabled = true
    commands.previousTrackCommand.isEnabled = true
    commands.stopCommand.isEnabled = true
    commands.playCommand.addTarget(self, action: #selector(remotePlay(_:)))
    commands.pauseCommand.addTarget(self, action: #selector(remotePause(_:)))
    commands.togglePlayPauseCommand.addTarget(self, action: #selector(remoteToggle(_:)))
    commands.nextTrackCommand.addTarget(self, action: #selector(remoteNext(_:)))
    commands.previousTrackCommand.addTarget(self, action: #selector(remotePrevious(_:)))
    commands.stopCommand.addTarget(self, action: #selector(remoteStop(_:)))
    UIApplication.shared.beginReceivingRemoteControlEvents()
  }

  private func removeRemoteCommands() {
    guard remoteCommandsRegistered else { return }
    remoteCommandsRegistered = false
    let commands = MPRemoteCommandCenter.shared()
    commands.playCommand.removeTarget(self)
    commands.pauseCommand.removeTarget(self)
    commands.togglePlayPauseCommand.removeTarget(self)
    commands.nextTrackCommand.removeTarget(self)
    commands.previousTrackCommand.removeTarget(self)
    commands.stopCommand.removeTarget(self)
    UIApplication.shared.endReceivingRemoteControlEvents()
  }

  @objc private func remotePlay(_ event: MPRemoteCommandEvent) -> MPRemoteCommandHandlerStatus {
    guard playbackState == .paused else { return .commandFailed }
    resume()
    return .success
  }

  @objc private func remotePause(_ event: MPRemoteCommandEvent) -> MPRemoteCommandHandlerStatus {
    guard playbackState == .playing else { return .commandFailed }
    pause()
    return .success
  }

  @objc private func remoteToggle(_ event: MPRemoteCommandEvent) -> MPRemoteCommandHandlerStatus {
    guard playbackState != .stopped else { return .commandFailed }
    toggle()
    return .success
  }

  @objc private func remoteNext(_ event: MPRemoteCommandEvent) -> MPRemoteCommandHandlerStatus {
    guard currentSegmentIndex + 1 < segments.count else { return .commandFailed }
    skipForward()
    return .success
  }

  @objc private func remotePrevious(_ event: MPRemoteCommandEvent) -> MPRemoteCommandHandlerStatus {
    guard currentSegmentIndex > 0 else { return .commandFailed }
    skipBackward()
    return .success
  }

  @objc private func remoteStop(_ event: MPRemoteCommandEvent) -> MPRemoteCommandHandlerStatus {
    guard playbackState != .stopped else { return .commandFailed }
    stop()
    return .success
  }

  private func stop(deactivateSession: Bool) {
    activeUtterance = nil
    if synthesizer.isSpeaking || synthesizer.isPaused { synthesizer.stopSpeaking(at: .immediate) }
    playbackState = .stopped
    currentSegmentText = ""
    segments.removeAll()
    currentSegmentIndex = 0
    sleepTimer?.invalidate()
    sleepTimer = nil
    sleepMinutes = 0
    MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    if deactivateSession { try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation) }
  }

  private func updateNowPlaying() {
    guard playbackState != .stopped else { return }
    MPNowPlayingInfoCenter.default().nowPlayingInfo = [
      MPMediaItemPropertyTitle: bookTitle,
      MPMediaItemPropertyArtist: "听书 AI",
      MPMediaItemPropertyAlbumTitle: currentSegmentText,
      MPNowPlayingInfoPropertyPlaybackRate: playbackState == .playing ? 1.0 : 0.0,
      MPNowPlayingInfoPropertyPlaybackQueueIndex: currentSegmentIndex,
      MPNowPlayingInfoPropertyPlaybackQueueCount: segments.count,
    ]
  }
}

private extension Comparable {
  func clamped(to range: ClosedRange<Self>) -> Self {
    min(max(self, range.lowerBound), range.upperBound)
  }
}
