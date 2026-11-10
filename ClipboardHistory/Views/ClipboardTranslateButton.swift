import SwiftUI
#if canImport(Translation)
import Translation
#endif

/// Translate control for clipboard text and recognized image text.
/// Uses the on-device Translation framework when the SDK and OS provide it,
/// and shows nothing otherwise.
/// On macOS 15 and later, the session is given an explicit Chinese/English
/// pair so the system language sheet is not shown.
struct ClipboardTranslateButton: View {
    enum Style {
        /// Icon on a history row.
        case icon
        /// Bordered label beside the other image-detail actions.
        case labeled
    }

    let text: String
    var style: Style = .icon
    @Binding var isVisible: Bool
    @Binding var isWorking: Bool
    @Binding var result: String?
    @Binding var failed: Bool

    var body: some View {
        #if canImport(Translation)
        if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            SystemTranslateButton(
                text: text,
                style: style,
                isVisible: $isVisible,
                isWorking: $isWorking,
                result: $result,
                failed: $failed
            )
        }
        #else
        EmptyView()
        #endif
    }
}

private struct TranslateIconLabel: View {
    var active: Bool

    var body: some View {
        Image(systemName: "translate")
            .font(.system(size: 11))
            .foregroundColor(active ? Color.accentColor : Color.secondary)
            .frame(width: 24, height: 24)
            .contentShape(Rectangle())
    }
}

private struct TranslateLabeledLabel: View {
    var active: Bool
    @EnvironmentObject private var locale: LocaleManager

    var body: some View {
        Label(locale.tr("row.translate"), systemImage: "translate")
            .font(.system(size: 12))
            .foregroundColor(active ? Color.accentColor : Color.primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
    }
}

private struct TranslateControlChrome: ViewModifier {
    let style: ClipboardTranslateButton.Style

    @ViewBuilder
    func body(content: Content) -> some View {
        switch style {
        case .icon:
            content.buttonStyle(.plain)
        case .labeled:
            content
                .buttonStyle(.bordered)
                .controlSize(.small)
        }
    }
}

@ViewBuilder
private func translateControlLabel(
    style: ClipboardTranslateButton.Style,
    active: Bool
) -> some View {
    switch style {
    case .icon:
        TranslateIconLabel(active: active)
    case .labeled:
        TranslateLabeledLabel(active: active)
    }
}

#if canImport(Translation)
private struct SystemTranslateButton: View {
    let text: String
    let style: ClipboardTranslateButton.Style
    @Binding var isVisible: Bool
    @Binding var isWorking: Bool
    @Binding var result: String?
    @Binding var failed: Bool

    var body: some View {
        #if compiler(>=6.0)
        if #available(macOS 15.0, *) {
            InlineTranslateButton(
                text: text,
                style: style,
                isVisible: $isVisible,
                isWorking: $isWorking,
                result: $result,
                failed: $failed
            )
        } else if #available(macOS 14.4, *) {
            SystemTranslationPopoverButton(text: text, style: style)
        }
        #else
        if #available(macOS 14.4, *) {
            SystemTranslationPopoverButton(text: text, style: style)
        }
        #endif
    }
}

@available(macOS 14.4, *)
private struct SystemTranslationPopoverButton: View {
    let text: String
    let style: ClipboardTranslateButton.Style
    @EnvironmentObject private var locale: LocaleManager
    @State private var isPresented = false

    var body: some View {
        Button {
            isPresented = true
        } label: {
            translateControlLabel(style: style, active: isPresented)
        }
        .modifier(TranslateControlChrome(style: style))
        .help(locale.tr("row.translate"))
        // macOS 14.4's translationPresentation(isPresented:text:) cannot take a
        // source or target. The system identifies the language itself and can
        // still show its language sheet. Explicit pairs are macOS 15+.
        .translationPresentation(isPresented: $isPresented, text: text)
    }
}

#if compiler(>=6.0)
@available(macOS 15.0, *)
private struct InlineTranslateButton: View {
    let text: String
    let style: ClipboardTranslateButton.Style
    @Binding var isVisible: Bool
    @Binding var isWorking: Bool
    @Binding var result: String?
    @Binding var failed: Bool

    @EnvironmentObject private var locale: LocaleManager
    @State private var configuration: TranslationSession.Configuration?
    @State private var activePair: TranslationLanguagePair?

    var body: some View {
        Button {
            if isVisible {
                isVisible = false
                return
            }
            isVisible = true
            guard result == nil else { return }
            failed = false
            isWorking = true
            beginTranslation()
        } label: {
            translateControlLabel(style: style, active: isVisible)
        }
        .modifier(TranslateControlChrome(style: style))
        .help(locale.tr("row.translate"))
        .translationTask(configuration) { session in
            guard configuration != nil else { return }
            let source = text
            let pair = await MainActor.run { activePair }
            do {
                let response = try await session.translate(source)
                let translated = response.targetText.trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
                await MainActor.run {
                    if translated.isEmpty {
                        result = nil
                        failed = true
                    } else {
                        result = translated
                        failed = false
                        if let pair {
                            TranslationPairMemory.save(pair)
                        }
                    }
                    isWorking = false
                }
            } catch {
                await MainActor.run {
                    result = nil
                    isWorking = false
                    failed = true
                }
            }
        }
    }

    private func beginTranslation() {
        let pair = TranslationPairResolver.pair(
            for: text,
            lastSuccessful: TranslationPairMemory.load()
        )
        activePair = pair
        let source = Self.translationLanguage(for: pair.sourceIdentifier)
        let target = Self.translationLanguage(for: pair.targetIdentifier)
        // A new configuration value with the same languages does not rerun the
        // task, so a retry invalidates the existing one after refreshing them.
        if var config = configuration {
            config.source = source
            config.target = target
            config.invalidate()
            configuration = config
        } else {
            configuration = TranslationSession.Configuration(source: source, target: target)
        }
    }

    private static func translationLanguage(for identifier: String) -> Locale.Language {
        if identifier == TranslationLanguagePair.simplifiedChineseIdentifier {
            return Locale.Language(languageCode: .chinese, script: .hanSimplified)
        }
        return Locale.Language(languageCode: .english)
    }
}
#endif
#endif
