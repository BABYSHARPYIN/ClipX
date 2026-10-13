import Foundation
import AVFoundation
import Combine

struct TTSVoiceOption: Identifiable, Hashable {
    let id: String
    let name: String
    let language: String

    var displayName: String {
        "\(name) (\(language))"
    }
}

@MainActor
final class TTSService: NSObject, ObservableObject {
    static let shared = TTSService()

    static let defaultRate: Float = AVSpeechUtteranceDefaultSpeechRate
    static let defaultPitch: Float = 1.0
    static let rateRange: ClosedRange<Float> = 0.30...0.65
    static let pitchRange: ClosedRange<Float> = 0.5...2.0

    private static let rateKey = "tts_rate"
    private static let pitchKey = "tts_pitch"
    private static let voiceZhKey = "tts_voice_zh"
    private static let voiceEnKey = "tts_voice_en"

    @Published private(set) var speakingText: String?

    @Published var rate: Float {
        didSet { UserDefaults.standard.set(rate, forKey: Self.rateKey) }
    }

    @Published var pitch: Float {
        didSet { UserDefaults.standard.set(pitch, forKey: Self.pitchKey) }
    }

    @Published var voiceIdentifierZh: String {
        didSet { UserDefaults.standard.set(voiceIdentifierZh, forKey: Self.voiceZhKey) }
    }

    @Published var voiceIdentifierEn: String {
        didSet { UserDefaults.standard.set(voiceIdentifierEn, forKey: Self.voiceEnKey) }
    }

    var isSpeaking: Bool { speakingText != nil }

    private let synthesizer = AVSpeechSynthesizer()

    private override init() {
        if UserDefaults.standard.object(forKey: Self.rateKey) != nil {
            rate = Self.clamp(UserDefaults.standard.float(forKey: Self.rateKey), to: Self.rateRange)
        } else {
            rate = Self.defaultRate
        }

        if UserDefaults.standard.object(forKey: Self.pitchKey) != nil {
            pitch = Self.clamp(UserDefaults.standard.float(forKey: Self.pitchKey), to: Self.pitchRange)
        } else {
            pitch = Self.defaultPitch
        }

        voiceIdentifierZh = UserDefaults.standard.string(forKey: Self.voiceZhKey) ?? ""
        voiceIdentifierEn = UserDefaults.standard.string(forKey: Self.voiceEnKey) ?? ""

        super.init()
        synthesizer.delegate = self
        normalizeStoredVoices()
    }

    var chineseVoices: [TTSVoiceOption] {
        voices(matchingPrefix: "zh")
    }

    var englishVoices: [TTSVoiceOption] {
        voices(matchingPrefix: "en")
    }

    func speak(_ text: String, preferChinese: Bool? = nil) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }

        let useChinese = preferChinese ?? Self.containsChinese(trimmed)
        let utterance = AVSpeechUtterance(string: trimmed)
        utterance.voice = resolveVoice(preferChinese: useChinese)
        utterance.rate = rate
        utterance.pitchMultiplier = pitch

        speakingText = trimmed
        synthesizer.speak(utterance)
    }

    func preview(preferChinese: Bool) {
        let sample = preferChinese
            ? "你好，这是 ClipX 语音朗读试听。"
            : "Hello, this is a ClipX speech preview."
        speak(sample, preferChinese: preferChinese)
    }

    func stop() {
        guard synthesizer.isSpeaking || speakingText != nil else { return }
        synthesizer.stopSpeaking(at: .immediate)
        speakingText = nil
    }

    func toggle(_ text: String, preferChinese: Bool? = nil) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if speakingText == trimmed {
            stop()
        } else {
            speak(trimmed, preferChinese: preferChinese)
        }
    }

    func isSpeaking(_ text: String) -> Bool {
        speakingText == text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func resetToDefaults() {
        rate = Self.defaultRate
        pitch = Self.defaultPitch
        voiceIdentifierZh = Self.defaultVoiceIdentifier(prefix: "zh") ?? ""
        voiceIdentifierEn = Self.defaultVoiceIdentifier(prefix: "en") ?? ""
    }

    static func containsChinese(_ text: String) -> Bool {
        text.unicodeScalars.contains { scalar in
            (0x4E00...0x9FFF).contains(scalar.value)
                || (0x3400...0x4DBF).contains(scalar.value)
        }
    }

    // MARK: - Private

    private func voices(matchingPrefix prefix: String) -> [TTSVoiceOption] {
        AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.lowercased().hasPrefix(prefix) }
            .map { TTSVoiceOption(id: $0.identifier, name: $0.name, language: $0.language) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func resolveVoice(preferChinese: Bool) -> AVSpeechSynthesisVoice? {
        let preferredID = preferChinese ? voiceIdentifierZh : voiceIdentifierEn
        if !preferredID.isEmpty,
           let voice = AVSpeechSynthesisVoice(identifier: preferredID) {
            return voice
        }

        if preferChinese {
            return AVSpeechSynthesisVoice(language: "zh-CN")
                ?? AVSpeechSynthesisVoice(language: "zh-Hans")
                ?? chineseVoices.first.flatMap { AVSpeechSynthesisVoice(identifier: $0.id) }
        }

        return AVSpeechSynthesisVoice(language: "en-US")
            ?? AVSpeechSynthesisVoice(language: "en-GB")
            ?? englishVoices.first.flatMap { AVSpeechSynthesisVoice(identifier: $0.id) }
    }

    private func normalizeStoredVoices() {
        if voiceIdentifierZh.isEmpty || AVSpeechSynthesisVoice(identifier: voiceIdentifierZh) == nil {
            voiceIdentifierZh = Self.defaultVoiceIdentifier(prefix: "zh") ?? ""
        }
        if voiceIdentifierEn.isEmpty || AVSpeechSynthesisVoice(identifier: voiceIdentifierEn) == nil {
            voiceIdentifierEn = Self.defaultVoiceIdentifier(prefix: "en") ?? ""
        }
    }

    private static func defaultVoiceIdentifier(prefix: String) -> String? {
        let preferredLang = prefix == "zh" ? ["zh-CN", "zh-Hans", "zh-TW", "zh-HK"] : ["en-US", "en-GB", "en-AU"]
        let voices = AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.lowercased().hasPrefix(prefix) }

        for lang in preferredLang {
            if let match = voices.first(where: { $0.language.caseInsensitiveCompare(lang) == .orderedSame }) {
                return match.identifier
            }
        }
        return voices.first?.identifier
    }

    private static func clamp(_ value: Float, to range: ClosedRange<Float>) -> Float {
        min(max(value, range.lowerBound), range.upperBound)
    }
}

extension TTSService: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didFinish utterance: AVSpeechUtterance
    ) {
        Task { @MainActor in
            self.speakingText = nil
        }
    }

    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didCancel utterance: AVSpeechUtterance
    ) {
        Task { @MainActor in
            self.speakingText = nil
        }
    }
}
