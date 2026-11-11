import Carbon
import AppKit
import ApplicationServices
import Darwin

/// Live Accessibility trust for this signed ClipX binary.
/// Normal launch writes `accessibility-status` under Application Support
/// (`trusted` or `not_trusted`). `scripts/install.sh` waits for that file.
/// `ClipX --accessibility-status` prints the same word and exits 0 or 2,
/// without showing UI or the system prompt.
enum AccessibilityTrust {
    static func exitIfStatusRequested() {
        guard CommandLine.arguments.contains("--accessibility-status") else { return }
        let trusted = AXIsProcessTrusted()
        let line = trusted ? "trusted\n" : "not_trusted\n"
        _ = line.withCString { bytes in
            write(STDOUT_FILENO, bytes, strlen(bytes))
        }
        Darwin.exit(Int32(trusted ? 0 : 2))
    }

    /// `~/Library/Application Support/ClipboardHistory/accessibility-status`
    /// This path is part of the install script contract.
    static func recordForRunningApp() {
        let trusted = AXIsProcessTrusted()
        guard let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first else { return }
        let directory = appSupport.appendingPathComponent("ClipboardHistory", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let line = trusted ? "trusted\n" : "not_trusted\n"
        try? line.write(
            to: directory.appendingPathComponent("accessibility-status"),
            atomically: true,
            encoding: .utf8
        )
    }
}

final class GlobalHotkeyMonitor {
    private let onActivate: () -> Void
    private var hotkeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?

    init(onActivate: @escaping () -> Void) {
        self.onActivate = onActivate
    }

    func start() {
        if !AXIsProcessTrusted() {
            AXIsProcessTrustedWithOptions([
                kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true
            ] as CFDictionary)
        }

        let hk = HotkeyStorage.load()
        guard hk.keyCode != 0 else { return }

        let mods = carbonMods(hk.modifiers)
        let id = EventHotKeyID(signature: 0x434C4958, id: 1) // "CLIX"

        var ref: EventHotKeyRef?
        guard RegisterEventHotKey(UInt32(hk.keyCode), mods, id, GetEventDispatcherTarget(), 0, &ref) == noErr,
              let ref else { return }
        hotkeyRef = ref

        // Use a static trampoline
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        var spec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let handler: EventHandlerUPP = { (_, event, ptr) -> OSStatus in
            var hkID = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID), nil,
                MemoryLayout<EventHotKeyID>.size, nil, &hkID)
            if hkID.id == 1, let ptr {
                let monitor = Unmanaged<GlobalHotkeyMonitor>.fromOpaque(ptr).takeUnretainedValue()
                DispatchQueue.main.async { monitor.onActivate() }
            }
            return noErr
        }
        InstallEventHandler(GetEventDispatcherTarget(), handler, 1, &spec, selfPtr, &handlerRef)
    }

    func stop() {
        if let r = hotkeyRef { UnregisterEventHotKey(r); hotkeyRef = nil }
        if let h = handlerRef { RemoveEventHandler(h); handlerRef = nil }
    }

    deinit { stop() }

    private func carbonMods(_ f: NSEvent.ModifierFlags) -> UInt32 {
        var m: UInt32 = 0
        if f.contains(.command) { m |= UInt32(cmdKey) }
        if f.contains(.shift)   { m |= UInt32(shiftKey) }
        if f.contains(.option)  { m |= UInt32(optionKey) }
        if f.contains(.control) { m |= UInt32(controlKey) }
        return m
    }
}
