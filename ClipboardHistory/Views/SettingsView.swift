import SwiftUI
import AppKit
import ServiceManagement

struct SettingsView: View {
    @EnvironmentObject var locale: LocaleManager
    @ObservedObject private var tts = TTSService.shared

    // Hotkey state
    @State private var modifiers: [String] = []
    @State private var keyChar: String = ""
    @State private var isRecording: Bool = false
    private var monitorRef = MonitorRef()

    private class MonitorRef { var handler: Any? }

    // Auto-start state
    @State private var launchAtLogin: Bool = SMAppService.mainApp.status == .enabled

    var body: some View {
        TabView {
            generalTab
                .tabItem {
                    Label(locale.tr("settings.general"), systemImage: "gear")
                }

            speechTab
                .tabItem {
                    Label(locale.tr("settings.speech"), systemImage: "speaker.wave.2")
                }
        }
        .frame(width: 440, height: 360)
        .onAppear { loadCurrentHotkey() }
        .onDisappear {
            endRecording()
            tts.stop()
        }
    }

    // MARK: - General

    private var generalTab: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        ForEach(modifiers, id: \.self) { m in
                            Text(m)
                                .font(.system(size: 13, weight: .medium))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.accentColor.opacity(0.15))
                                .cornerRadius(4)
                        }

                        Text(keyChar.isEmpty ? "?" : keyChar)
                            .font(.system(size: 13, weight: .bold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(isRecording ? Color.accentColor.opacity(0.3) : Color.secondary.opacity(0.15))
                            .cornerRadius(4)
                    }

                    HStack(spacing: 8) {
                        Button(isRecording ? locale.tr("hotkey.recording") : locale.tr("hotkey.record")) {
                            startRecording()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .disabled(isRecording)

                        Button(locale.tr("hotkey.reset")) {
                            HotkeyStorage.resetToDefault()
                            loadCurrentHotkey()
                            NotificationCenter.default.post(name: .hotkeyChanged, object: nil)
                        }
                        .buttonStyle(.borderless)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)

                        Button(locale.tr("hotkey.clear")) {
                            HotkeyStorage.clear()
                            loadCurrentHotkey()
                            NotificationCenter.default.post(name: .hotkeyChanged, object: nil)
                        }
                        .buttonStyle(.borderless)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 4)
            } header: {
                Text(locale.tr("settings.hotkey"))
            }

            Section {
                Toggle(isOn: $launchAtLogin) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(locale.tr("settings.launchAtLogin"))
                        Text(locale.tr("settings.launchAtLogin.desc"))
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
                .onChange(of: launchAtLogin) { _, newValue in
                    setLaunchAtLogin(newValue)
                }
            } header: {
                Text(locale.tr("settings.startup"))
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Speech

    private var speechTab: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(locale.tr("settings.speech.rate"))
                        Spacer()
                        Text(rateLabel)
                            .foregroundColor(.secondary)
                            .monospacedDigit()
                    }
                    Slider(value: $tts.rate, in: TTSService.rateRange)
                }

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(locale.tr("settings.speech.pitch"))
                        Spacer()
                        Text(pitchLabel)
                            .foregroundColor(.secondary)
                            .monospacedDigit()
                    }
                    Slider(value: $tts.pitch, in: TTSService.pitchRange)
                }
            } header: {
                Text(locale.tr("settings.speech.params"))
            }

            Section {
                if tts.chineseVoices.isEmpty {
                    Text(locale.tr("settings.speech.noVoice"))
                        .foregroundColor(.secondary)
                } else {
                    Picker(locale.tr("settings.speech.voiceZh"), selection: $tts.voiceIdentifierZh) {
                        ForEach(tts.chineseVoices) { voice in
                            Text(voice.displayName).tag(voice.id)
                        }
                    }
                }

                if tts.englishVoices.isEmpty {
                    Text(locale.tr("settings.speech.noVoice"))
                        .foregroundColor(.secondary)
                } else {
                    Picker(locale.tr("settings.speech.voiceEn"), selection: $tts.voiceIdentifierEn) {
                        ForEach(tts.englishVoices) { voice in
                            Text(voice.displayName).tag(voice.id)
                        }
                    }
                }
            } header: {
                Text(locale.tr("settings.speech.voice"))
            }

            Section {
                HStack(spacing: 10) {
                    Button {
                        if tts.isSpeaking {
                            tts.stop()
                        } else {
                            tts.preview(preferChinese: true)
                        }
                    } label: {
                        Label(
                            tts.isSpeaking ? locale.tr("settings.speech.stop") : locale.tr("settings.speech.previewZh"),
                            systemImage: tts.isSpeaking ? "stop.fill" : "speaker.wave.2.fill"
                        )
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)

                    Button {
                        if tts.isSpeaking {
                            tts.stop()
                        } else {
                            tts.preview(preferChinese: false)
                        }
                    } label: {
                        Label(
                            tts.isSpeaking ? locale.tr("settings.speech.stop") : locale.tr("settings.speech.previewEn"),
                            systemImage: tts.isSpeaking ? "stop.fill" : "speaker.wave.2"
                        )
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Spacer()

                    Button(locale.tr("settings.speech.reset")) {
                        tts.resetToDefaults()
                        tts.stop()
                    }
                    .buttonStyle(.borderless)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                }
            } header: {
                Text(locale.tr("settings.speech.preview"))
            } footer: {
                Text(locale.tr("settings.speech.hint"))
                    .font(.system(size: 11))
            }
        }
        .formStyle(.grouped)
    }

    private var rateLabel: String {
        let percent = Int((tts.rate / TTSService.defaultRate) * 100)
        return "\(percent)%"
    }

    private var pitchLabel: String {
        String(format: "%.1fx", tts.pitch)
    }

    // MARK: - Hotkey

    private func loadCurrentHotkey() {
        let stored = HotkeyStorage.load()
        if stored.keyCode == 0 {
            modifiers = []; keyChar = ""
        } else {
            modifiers = modifierNames(stored.modifiers)
            keyChar = stored.char
        }
    }

    private func startRecording() {
        isRecording = true
        monitorRef.handler = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            recordKey(event); return nil
        }
    }

    private func recordKey(_ event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        var mods: NSEvent.ModifierFlags = []
        if flags.contains(.command) { mods.insert(.command) }
        if flags.contains(.shift) { mods.insert(.shift) }
        if flags.contains(.option) { mods.insert(.option) }
        if flags.contains(.control) { mods.insert(.control) }
        guard !mods.isEmpty else { return }

        let char = event.charactersIgnoringModifiers?.uppercased() ?? ""
        modifiers = modifierNames(mods)
        keyChar = char
        HotkeyStorage.save(keyCode: event.keyCode, char: char.first ?? "V", modifiers: mods)
        NotificationCenter.default.post(name: .hotkeyChanged, object: nil)
        endRecording()
    }

    private func endRecording() {
        isRecording = false
        if let h = monitorRef.handler { NSEvent.removeMonitor(h); monitorRef.handler = nil }
    }

    private func modifierNames(_ flags: NSEvent.ModifierFlags) -> [String] {
        var names: [String] = []
        if flags.contains(.command) { names.append("⌘") }
        if flags.contains(.shift) { names.append("⇧") }
        if flags.contains(.option) { names.append("⌥") }
        if flags.contains(.control) { names.append("⌃") }
        return names
    }

    // MARK: - Auto-start

    private func setLaunchAtLogin(_ enable: Bool) {
        do {
            if enable {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}
