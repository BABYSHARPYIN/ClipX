import Carbon
import AppKit
import ApplicationServices

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
