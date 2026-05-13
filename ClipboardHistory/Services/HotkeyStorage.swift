import AppKit

struct HotkeyStorage {
    struct Hotkey: Codable {
        var keyCode: UInt16
        var char: String
        var modifiersRaw: UInt

        var modifiers: NSEvent.ModifierFlags {
            NSEvent.ModifierFlags(rawValue: modifiersRaw)
        }
    }

    static func load() -> Hotkey {
        guard let data = UserDefaults.standard.data(forKey: "hotkey"),
              let hk = try? JSONDecoder().decode(Hotkey.self, from: data)
        else {
            return .defaultKey
        }
        return hk
    }

    static func save(keyCode: UInt16, char: Character, modifiers: NSEvent.ModifierFlags) {
        let hk = Hotkey(
            keyCode: keyCode,
            char: String(char),
            modifiersRaw: modifiers.rawValue
        )
        if let data = try? JSONEncoder().encode(hk) {
            UserDefaults.standard.set(data, forKey: "hotkey")
        }
    }

    static func resetToDefault() {
        save(keyCode: 9, char: "V", modifiers: [.command, .shift])
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: "hotkey")
    }
}

extension HotkeyStorage.Hotkey {
    static var defaultKey: Self {
        .init(keyCode: 9, char: "V", modifiersRaw: NSEvent.ModifierFlags([.command, .shift]).rawValue)
    }
}
