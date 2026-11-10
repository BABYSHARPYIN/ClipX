import Foundation
#if !TRANSLATION_PAIR_STANDALONE
@testable import ClipboardHistory
#endif

func runTranslationPairChecks() throws {
    try checkChineseTextTranslatesToEnglish()
    try checkEnglishTextTranslatesToChinese()
    try checkShortSingleScriptTextDoesNotNeedDetection()
    try checkOtherNonChineseTextTranslatesToChinese()
    try checkMostlyChineseTextWithEnglishTokensStaysChinese()
    try checkMostlyEnglishTextWithAChineseTokenStaysEnglish()
    try checkClearDirectionIgnoresRememberedPair()
    try checkUncertainTextReusesLastSuccessfulPair()
    try checkUncertainTextHasAPairBeforeAnythingSucceeds()
    try checkRememberedPairRoundTripsAndDropsUnknownValues()
    try checkChosenPairAlwaysNamesBothLanguages()
    try checkMacOS15ButtonSuppliesBothLanguages()
    try checkImageDetailReusesTranslateControl()
    try checkPinnedRowsDoNotPaintWindowBackground()
}

func checkChineseTextTranslatesToEnglish() throws {
    try expectPair("你好世界", .chineseToEnglish, "a Chinese sentence translates into English")
    try expectPair("  你好，世界！ ", .chineseToEnglish, "Chinese punctuation does not change the direction")
    try expectPair("繁體中文", .chineseToEnglish, "traditional characters still use the Chinese side of the pair")
}

func checkEnglishTextTranslatesToChinese() throws {
    try expectPair("Hello world", .englishToChinese, "an English sentence translates into Chinese")
    try expectPair("Hello, world!", .englishToChinese, "English punctuation does not change the direction")
    try expectPair("https://example.com/clipx", .englishToChinese, "Latin text translates into Chinese")
}

func checkShortSingleScriptTextDoesNotNeedDetection() throws {
    try expectPair("OK", .englishToChinese, "a short English token still has an explicit pair")
    try expectPair("AI", .englishToChinese, "an abbreviation still has an explicit pair")
    try expectPair("好", .chineseToEnglish, "a single Chinese character still has an explicit pair")
    try expectPair("中", .chineseToEnglish, "another single Chinese character still has an explicit pair")
}

func checkOtherNonChineseTextTranslatesToChinese() throws {
    try expectPair("Bonjour", .englishToChinese, "other Latin text uses the English side of the pair")
    try expectPair("こんにちは", .englishToChinese, "kana is non-Chinese and translates toward Chinese")
    try expectPair("안녕하세요", .englishToChinese, "hangul is non-Chinese and translates toward Chinese")
    try expectPair("Привет", .englishToChinese, "Cyrillic is non-Chinese and translates toward Chinese")
}

func checkMostlyChineseTextWithEnglishTokensStaysChinese() throws {
    try expectPair(
        "请把 hello world 翻译一下",
        .chineseToEnglish,
        "a Chinese sentence with English words stays Chinese to English"
    )
    try expectPair(
        "这个 iPhone 很好用",
        .chineseToEnglish,
        "a Chinese sentence with a Latin product name stays Chinese to English"
    )
}

func checkMostlyEnglishTextWithAChineseTokenStaysEnglish() throws {
    try expectPair(
        "The meeting is great 好",
        .englishToChinese,
        "an English sentence with one Chinese character stays English to Chinese"
    )
    try expectPair(
        "Ship the build today 好",
        .englishToChinese,
        "another English sentence with one Chinese character stays English to Chinese"
    )
}

func checkClearDirectionIgnoresRememberedPair() throws {
    try expectPair(
        "你好世界",
        .chineseToEnglish,
        last: .englishToChinese,
        "clear Chinese text does not reuse an English-to-Chinese memory"
    )
    try expectPair(
        "Hello world",
        .englishToChinese,
        last: .chineseToEnglish,
        "clear English text does not reuse a Chinese-to-English memory"
    )
    try expectPair(
        "OK",
        .englishToChinese,
        last: .chineseToEnglish,
        "a short English token does not reuse the opposite memory"
    )
}

func checkUncertainTextReusesLastSuccessfulPair() throws {
    try expectPair(
        "12345",
        .chineseToEnglish,
        last: .chineseToEnglish,
        "digits reuse the last successful pair"
    )
    try expectPair(
        "12345",
        .englishToChinese,
        last: .englishToChinese,
        "digits can reuse the other successful pair"
    )
    try expectPair(
        "!!!",
        .chineseToEnglish,
        last: .chineseToEnglish,
        "punctuation reuses the last successful pair"
    )
    try expectPair(
        "   ",
        .englishToChinese,
        last: .englishToChinese,
        "blank text reuses the last successful pair"
    )
    try expectPair(
        "Hello 你好",
        .chineseToEnglish,
        last: .chineseToEnglish,
        "a short mix reuses a Chinese-to-English success"
    )
    try expectPair(
        "Hello 你好",
        .englishToChinese,
        last: .englishToChinese,
        "the same short mix reuses an English-to-Chinese success"
    )
}

func checkUncertainTextHasAPairBeforeAnythingSucceeds() throws {
    try expectPair("12345", .englishToChinese, "digits still name both languages before any success")
    try expectPair("", .englishToChinese, "empty text still names both languages")
    try expectPair("👍", .englishToChinese, "a symbol still names both languages")
    try expectPair(
        "Hello 你好",
        .chineseToEnglish,
        "a short mix with Chinese characters leans Chinese before any success"
    )
}

func checkRememberedPairRoundTripsAndDropsUnknownValues() throws {
    let suite = "clipx-translation-\(UUID().uuidString)"
    guard let defaults = UserDefaults(suiteName: suite) else {
        throw TranslationPairCheckFailure(description: "could not open a defaults suite")
    }
    defaults.removePersistentDomain(forName: suite)
    try expect(TranslationPairMemory.load(from: defaults) == nil, "nothing is remembered yet")

    TranslationPairMemory.save(.chineseToEnglish, to: defaults)
    try expect(
        TranslationPairMemory.load(from: defaults) == .chineseToEnglish,
        "a successful Chinese-to-English pair is remembered"
    )

    TranslationPairMemory.save(.englishToChinese, to: defaults)
    try expect(
        TranslationPairMemory.load(from: defaults) == .englishToChinese,
        "a later success replaces the remembered pair"
    )

    defaults.set("ja", forKey: TranslationPairMemory.sourceKey)
    defaults.set("en", forKey: TranslationPairMemory.targetKey)
    try expect(TranslationPairMemory.load(from: defaults) == nil, "an unknown stored pair is ignored")

    defaults.set(TranslationLanguagePair.englishIdentifier, forKey: TranslationPairMemory.sourceKey)
    defaults.removeObject(forKey: TranslationPairMemory.targetKey)
    try expect(TranslationPairMemory.load(from: defaults) == nil, "a half-written pair is ignored")
    defaults.removePersistentDomain(forName: suite)
}

func checkChosenPairAlwaysNamesBothLanguages() throws {
    let samples = ["你好", "Hello", "OK", "123", "Hello 你好", "", "こんにちは", "请把 hello world 翻译一下"]
    for sample in samples {
        for last in [nil, TranslationLanguagePair.chineseToEnglish, .englishToChinese] {
            let pair = TranslationPairResolver.pair(for: sample, lastSuccessful: last)
            try expect(
                pair == .chineseToEnglish || pair == .englishToChinese,
                "\(sample) resolves to the Chinese-English pair"
            )
            try expect(pair.sourceIdentifier != pair.targetIdentifier, "source and target differ for \(sample)")
        }
    }
}

func checkMacOS15ButtonSuppliesBothLanguages() throws {
    let source = try sourceFile("ClipboardHistory/Views/ClipboardTranslateButton.swift")
    try expect(
        !source.contains("source: nil"),
        "macOS 15 translation no longer leaves the source language unset"
    )
    try expect(
        !source.contains("target: nil"),
        "macOS 15 translation no longer leaves the target language unset"
    )
    try expect(
        source.contains("TranslationPairResolver.pair"),
        "the translate button uses the explicit language pair"
    )
    try expect(
        source.contains("TranslationSession.Configuration(source: source, target: target)"),
        "the session is created with both languages"
    )
    try expect(
        source.contains("TranslationPairMemory.save(pair)"),
        "a successful translation still remembers the pair"
    )
}

func checkImageDetailReusesTranslateControl() throws {
    let source = try sourceFile("ClipboardHistory/Views/ImageDetailView.swift")
    try expect(
        source.contains("ClipboardTranslateButton("),
        "recognized image text uses the shared translate control"
    )
    try expect(
        source.contains("style: .labeled"),
        "the image detail action uses the labeled translate control"
    )
    try expect(
        !source.contains("TranslationSession"),
        "image detail does not start its own translation session"
    )
    try expect(
        source.contains("translationResult"),
        "the translation is shown in the image detail view"
    )
    try expect(
        source.contains("translationControlsAvailable"),
        "the image translate action keeps the existing OS gate"
    )
}

func checkPinnedRowsDoNotPaintWindowBackground() throws {
    let source = try sourceFile("ClipboardHistory/Views/PopoverContentView.swift")
    try expect(
        !source.contains("windowBackgroundColor"),
        "pinned rows do not paint the opaque window background"
    )
    try expect(
        !source.contains("safeAreaInset"),
        "pinned rows are not an overlay that needs its own fill"
    )
    try expect(
        source.contains("pinnedItems"),
        "pinned rows stay in a fixed section"
    )
    try expect(
        source.contains("scrollItems"),
        "the rest of the history still scrolls"
    )
}

private func sourceFile(_ relativePath: String) throws -> String {
    let url = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent(relativePath)
    return try String(contentsOf: url, encoding: .utf8)
}

private func expectPair(
    _ text: String,
    _ expected: TranslationLanguagePair,
    last: TranslationLanguagePair? = nil,
    _ message: String
) throws {
    let pair = TranslationPairResolver.pair(for: text, lastSuccessful: last)
    try expect(
        pair == expected,
        "\(message); got \(pair.sourceIdentifier) -> \(pair.targetIdentifier)"
    )
}

private struct TranslationPairCheckFailure: Error, CustomStringConvertible {
    let description: String
}

private func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    if !condition() {
        throw TranslationPairCheckFailure(description: message)
    }
}

#if TRANSLATION_PAIR_STANDALONE
@main
enum TranslationPairCheckMain {
    static func main() {
        do {
            try runTranslationPairChecks()
            print("ok")
        } catch {
            fputs("FAIL: \(error)\n", stderr)
            exit(1)
        }
    }
}
#endif
