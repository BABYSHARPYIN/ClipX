import SwiftUI
import AppKit

extension Notification.Name {
    static let hotkeyChanged = Notification.Name("hotkeyChanged")
}

struct HotkeySettingsView: View {
    @EnvironmentObject var locale: LocaleManager
    @State private var modifiers: [String] = []
    @State private var keyChar: String = ""
    @State private var keyCode: UInt16 = 0
    @State private var isRecording: Bool = false
    private var monitorRef = MonitorRef()

    private class MonitorRef { var handler: Any? }

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "keyboard")
                .font(.system(size: 32))
                .foregroundColor(.accentColor)

            Text(locale.tr("hotkey.title"))
                .font(.system(size: 14, weight: .semibold))

            Text(locale.tr("hotkey.desc"))
                .font(.system(size: 11))
                .foregroundColor(.secondary)

            HStack(spacing: 8) {
                ForEach(modifiers, id: \.self) { m in
                    Text(m)
                        .font(.system(size: 12, weight: .medium))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.accentColor.opacity(0.15))
                        .cornerRadius(4)
                }

                Text(keyChar.isEmpty ? "?" : keyChar)
                    .font(.system(size: 12, weight: .bold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(isRecording ? Color.accentColor.opacity(0.3) : Color.secondary.opacity(0.15))
                    .cornerRadius(4)
                    .animation(.easeInOut(duration: 0.3), value: isRecording)
            }

            Button(isRecording ? locale.tr("hotkey.recording") : locale.tr("hotkey.record")) {
                startRecording()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .disabled(isRecording)

            HStack(spacing: 4) {
                Button(locale.tr("hotkey.reset")) {
                    HotkeyStorage.resetToDefault()
                    loadCurrent()
                    NotificationCenter.default.post(name: .hotkeyChanged, object: nil)
                }
                .buttonStyle(.plain)
                .font(.system(size: 11))
                .foregroundColor(.secondary)

                Button(locale.tr("hotkey.clear")) {
                    HotkeyStorage.clear()
                    loadCurrent()
                    NotificationCenter.default.post(name: .hotkeyChanged, object: nil)
                }
                .buttonStyle(.plain)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            }
        }
        .padding(24)
        .frame(width: 300)
        .onAppear { loadCurrent() }
        .onDisappear { endRecording() }
    }

    private func loadCurrent() {
        let stored = HotkeyStorage.load()
        if stored.keyCode == 0 {
            modifiers = []; keyChar = ""; keyCode = 0
        } else {
            modifiers = modifierNames(stored.modifiers)
            keyChar = stored.char
            keyCode = stored.keyCode
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
        keyCode = event.keyCode
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
}
