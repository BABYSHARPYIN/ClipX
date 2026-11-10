import Foundation

/// Source and target for one on-device translation.
///
/// The macOS 15 path must pass both languages into `TranslationSession`.
/// A nil source asks the system to identify the text, and short or mixed
/// clipboard items then show the language sheet on every tap. The choice in
/// that sheet is not remembered, so the pair is chosen here instead.
struct TranslationLanguagePair: Equatable {
    let sourceIdentifier: String
    let targetIdentifier: String

    static let simplifiedChineseIdentifier = "zh-Hans"
    static let englishIdentifier = "en"

    static let chineseToEnglish = TranslationLanguagePair(
        sourceIdentifier: simplifiedChineseIdentifier,
        targetIdentifier: englishIdentifier
    )

    static let englishToChinese = TranslationLanguagePair(
        sourceIdentifier: englishIdentifier,
        targetIdentifier: simplifiedChineseIdentifier
    )

    init(sourceIdentifier: String, targetIdentifier: String) {
        self.sourceIdentifier = sourceIdentifier
        self.targetIdentifier = targetIdentifier
    }

    /// Rebuilds a pair that was stored earlier. Unknown identifiers are dropped
    /// so a stale value cannot be passed to TranslationSession.
    init?(storedSource: String, storedTarget: String) {
        switch (storedSource, storedTarget) {
        case (Self.simplifiedChineseIdentifier, Self.englishIdentifier),
             (Self.englishIdentifier, Self.simplifiedChineseIdentifier):
            self.init(sourceIdentifier: storedSource, targetIdentifier: storedTarget)
        default:
            return nil
        }
    }
}

/// Picks Simplified Chinese ↔ English without asking the system to identify the text.
///
/// Han ranges match `TTSService.containsChinese`. Other letters, including
/// Latin, kana, hangul, and Cyrillic, use the English side of the pair: the
/// everyday direction is Chinese to English and everything else to Chinese.
/// A short mix that is not clearly either script reuses the last success.
enum TranslationPairResolver {
    static func pair(
        for text: String,
        lastSuccessful: TranslationLanguagePair?
    ) -> TranslationLanguagePair {
        let counted = counts(in: text)
        switch hint(counted) {
        case .chinese:
            return .chineseToEnglish
        case .nonChinese:
            return .englishToChinese
        case .uncertain:
            if let lastSuccessful {
                return lastSuccessful
            }
            return counted.han > 0 ? .chineseToEnglish : .englishToChinese
        }
    }

    private struct Counts {
        var han = 0
        var otherLetters = 0
    }

    private enum Hint {
        case chinese
        case nonChinese
        case uncertain
    }

    private static func hint(_ counted: Counts) -> Hint {
        let han = counted.han
        let other = counted.otherLetters
        if han == 0 && other == 0 {
            return .uncertain
        }
        if han == 0 {
            return .nonChinese
        }
        if other == 0 {
            return .chinese
        }
        // Han is at least a third of the letters: a Chinese sentence that
        // mentions an English name or token.
        if han * 2 >= other {
            return .chinese
        }
        // Other letters outnumber Han by at least four to one.
        if other >= han * 4 {
            return .nonChinese
        }
        return .uncertain
    }

    private static func counts(in text: String) -> Counts {
        var counted = Counts()
        for scalar in text.unicodeScalars {
            if isHan(scalar) {
                counted.han += 1
            } else if scalar.properties.isAlphabetic {
                counted.otherLetters += 1
            }
        }
        return counted
    }

    /// Same ranges as `TTSService.containsChinese`.
    private static func isHan(_ scalar: Unicode.Scalar) -> Bool {
        (0x4E00...0x9FFF).contains(scalar.value)
            || (0x3400...0x4DBF).contains(scalar.value)
    }
}

enum TranslationPairMemory {
    static let sourceKey = "translation_last_source"
    static let targetKey = "translation_last_target"

    static func load(from defaults: UserDefaults = .standard) -> TranslationLanguagePair? {
        guard
            let source = defaults.string(forKey: sourceKey),
            let target = defaults.string(forKey: targetKey)
        else { return nil }
        return TranslationLanguagePair(storedSource: source, storedTarget: target)
    }

    static func save(_ pair: TranslationLanguagePair, to defaults: UserDefaults = .standard) {
        defaults.set(pair.sourceIdentifier, forKey: sourceKey)
        defaults.set(pair.targetIdentifier, forKey: targetKey)
    }
}
