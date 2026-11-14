import Foundation
import AVFoundation
import Observation

/// 繁體中文Turn-by-Turn 語音播報服務（AVSpeechSynthesizer）
@Observable
@MainActor
final class VoiceGuidanceService: NSObject, AVSpeechSynthesizerDelegate {
    private let synthesizer = AVSpeechSynthesizer()

    var isMuted: Bool = false {
        didSet {
            if isMuted {
                stopSpeaking()
            }
        }
    }

    private(set) var isSpeaking: Bool = false
    private(set) var lastSpokenText: String = ""

    override init() {
        super.init()
        synthesizer.delegate = self
        configureAudioSession()
    }

    private func configureAudioSession() {
        #if os(iOS)
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .voicePrompt, options: [.duckOthers, .interruptSpokenAudioAndMixWithOthers])
            try session.setActive(true, options: [])
        } catch {
            // 模擬器或無音訊權限環境下靜默略過
        }
        #endif
    }

    func speak(_ text: String, interruptCurrent: Bool = false) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        lastSpokenText = trimmed
        guard !isMuted else { return }

        if interruptCurrent && synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }

        let utterance = AVSpeechUtterance(string: trimmed)
        utterance.voice = AVSpeechSynthesisVoice(language: "zh-TW") ?? AVSpeechSynthesisVoice(language: "zh-Hant")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 1.04
        utterance.pitchMultiplier = 1.02
        utterance.volume = 0.95

        synthesizer.speak(utterance)
    }

    func stopSpeaking() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        isSpeaking = false
    }

    // MARK: - AVSpeechSynthesizerDelegate

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        Task { @MainActor [weak self] in
            self?.isSpeaking = true
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor [weak self] in
            self?.isSpeaking = false
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor [weak self] in
            self?.isSpeaking = false
        }
    }
}
