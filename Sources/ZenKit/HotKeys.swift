import AppKit
import Carbon.HIToolbox

// グローバルホットキーの共通レジストリ。
// Carbonのイベントハンドラは1本だけ張り、hotkey ID でアクションに振り分ける。
public enum HotKeys {
    private static var installed = false
    private static var actions: [UInt32: () -> Void] = [:]
    private static var refs: [UInt32: EventHotKeyRef] = [:]
    private static var specs: [UInt32: String] = [:]

    public static func register(id: UInt32, spec: String, action: @escaping () -> Void) {
        if !installed {
            var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                          eventKind: UInt32(kEventHotKeyPressed))
            InstallEventHandler(GetApplicationEventTarget(), { _, event, _ -> OSStatus in
                var hkID = EventHotKeyID()
                GetEventParameter(event, EventParamName(kEventParamDirectObject),
                                  EventParamType(typeEventHotKeyID), nil,
                                  MemoryLayout<EventHotKeyID>.size, nil, &hkID)
                let id = hkID.id
                DispatchQueue.main.async { HotKeys.actions[id]?() }
                return noErr
            }, 1, &eventType, nil, nil)
            installed = true
        }
        actions[id] = action
        specs[id] = spec
        registerRef(id: id, spec: spec)
    }

    private static func registerRef(id: UInt32, spec: String) {
        if let old = refs[id] {
            UnregisterEventHotKey(old)
            refs[id] = nil
        }
        let (keyCode, modifiers) = parse(spec)
        var ref: EventHotKeyRef?
        RegisterEventHotKey(keyCode, modifiers,
                            EventHotKeyID(signature: OSType(0x6D62_6364), id: id),
                            GetApplicationEventTarget(), 0, &ref)
        if let ref { refs[id] = ref }
    }

    // ホットキー録画中などに一時停止/再開する（登録内容は保持）
    public static func pauseAll() {
        for (id, ref) in refs { UnregisterEventHotKey(ref); refs[id] = nil }
        refs.removeAll()
    }

    public static func resumeAll() {
        for (id, spec) in specs { registerRef(id: id, spec: spec) }
    }

    static let keyCodes: [String: Int] = [
        "space": kVK_Space, "grave": kVK_ANSI_Grave, "escape": kVK_Escape,
        "return": kVK_Return, "tab": kVK_Tab,
        "comma": kVK_ANSI_Comma, "period": kVK_ANSI_Period, "slash": kVK_ANSI_Slash,
        "semicolon": kVK_ANSI_Semicolon, "minus": kVK_ANSI_Minus, "equal": kVK_ANSI_Equal,
        "f1": kVK_F1, "f2": kVK_F2, "f3": kVK_F3, "f4": kVK_F4,
        "f5": kVK_F5, "f6": kVK_F6, "f7": kVK_F7, "f8": kVK_F8,
        "f9": kVK_F9, "f10": kVK_F10, "f11": kVK_F11, "f12": kVK_F12,
        "0": kVK_ANSI_0, "1": kVK_ANSI_1, "2": kVK_ANSI_2, "3": kVK_ANSI_3,
        "4": kVK_ANSI_4, "5": kVK_ANSI_5, "6": kVK_ANSI_6, "7": kVK_ANSI_7,
        "8": kVK_ANSI_8, "9": kVK_ANSI_9,
        "a": kVK_ANSI_A, "b": kVK_ANSI_B, "c": kVK_ANSI_C, "d": kVK_ANSI_D,
        "e": kVK_ANSI_E, "f": kVK_ANSI_F, "g": kVK_ANSI_G, "h": kVK_ANSI_H,
        "i": kVK_ANSI_I, "j": kVK_ANSI_J, "k": kVK_ANSI_K, "l": kVK_ANSI_L,
        "m": kVK_ANSI_M, "n": kVK_ANSI_N, "o": kVK_ANSI_O, "p": kVK_ANSI_P,
        "q": kVK_ANSI_Q, "r": kVK_ANSI_R, "s": kVK_ANSI_S, "t": kVK_ANSI_T,
        "u": kVK_ANSI_U, "v": kVK_ANSI_V, "w": kVK_ANSI_W, "x": kVK_ANSI_X,
        "y": kVK_ANSI_Y, "z": kVK_ANSI_Z,
    ]

    static let keyNames: [Int: String] = Dictionary(uniqueKeysWithValues: keyCodes.map { ($1, $0) })

    static func isFunctionKey(_ name: String) -> Bool {
        name.count >= 2 && name.hasPrefix("f") && Int(name.dropFirst()) != nil
    }

    // "option-space" のような文字列を (keyCode, modifiers) に変換
    static func parse(_ spec: String) -> (UInt32, UInt32) {
        var mods: UInt32 = 0
        var key: UInt32 = UInt32(kVK_Space)
        var keyName = "space"
        for part in spec.lowercased().split(separator: "-").map(String.init) {
            switch part {
            case "command", "cmd": mods |= UInt32(cmdKey)
            case "option", "opt", "alt": mods |= UInt32(optionKey)
            case "control", "ctrl": mods |= UInt32(controlKey)
            case "shift": mods |= UInt32(shiftKey)
            default:
                if let code = keyCodes[part] { key = UInt32(code); keyName = part }
            }
        }
        // Fキー以外の修飾キー無しは通常入力を乗っ取ってしまうので保険をかける
        if mods == 0 && !isFunctionKey(keyName) {
            mods = UInt32(optionKey)
        }
        return (key, mods)
    }

    // 押されたキーイベントを "shift-command-space" 形式へ。割り当て不可なら nil
    public static func spec(keyCode: UInt16, flags: NSEvent.ModifierFlags) -> String? {
        guard let name = keyNames[Int(keyCode)], name != "escape" else { return nil }
        var parts: [String] = []
        if flags.contains(.control) { parts.append("control") }
        if flags.contains(.option)  { parts.append("option") }
        if flags.contains(.shift)   { parts.append("shift") }
        if flags.contains(.command) { parts.append("command") }
        // ⌘/⌥/⌃ が無い組み合わせは通常入力と衝突する（Fキーだけ例外）
        let strong = flags.contains(.command) || flags.contains(.option) || flags.contains(.control)
        if !strong && !isFunctionKey(name) { return nil }
        parts.append(name)
        return parts.joined(separator: "-")
    }

    // "shift-command-space" → "⇧⌘Space" のような表示用文字列
    public static func displayName(_ spec: String) -> String {
        var mods = ""
        var key = ""
        for part in spec.lowercased().split(separator: "-").map(String.init) {
            switch part {
            case "control", "ctrl": mods += "⌃"
            case "option", "opt", "alt": mods += "⌥"
            case "shift": mods += "⇧"
            case "command", "cmd": mods += "⌘"
            default: key = part
            }
        }
        let keyLabel: String
        switch key {
        case "space": keyLabel = "Space"
        case "grave": keyLabel = "`"
        case "escape": keyLabel = "⎋"
        case "return": keyLabel = "↩"
        case "tab": keyLabel = "⇥"
        case "comma": keyLabel = ","
        case "period": keyLabel = "."
        case "slash": keyLabel = "/"
        case "semicolon": keyLabel = ";"
        case "minus": keyLabel = "-"
        case "equal": keyLabel = "="
        default: keyLabel = key.uppercased()
        }
        return mods + keyLabel
    }

    // メニュー項目のショートカット表示用（Fキーなどは nil）
    public static func menuKeyEquivalent(for spec: String) -> (String, NSEvent.ModifierFlags)? {
        var flags: NSEvent.ModifierFlags = []
        var key: String?
        for part in spec.lowercased().split(separator: "-").map(String.init) {
            switch part {
            case "control", "ctrl": flags.insert(.control)
            case "option", "opt", "alt": flags.insert(.option)
            case "shift": flags.insert(.shift)
            case "command", "cmd": flags.insert(.command)
            default:
                switch part {
                case "space": key = " "
                case "grave": key = "`"
                case "comma": key = ","
                case "period": key = "."
                case "slash": key = "/"
                case "semicolon": key = ";"
                case "minus": key = "-"
                case "equal": key = "="
                case "return": key = "\r"
                case "tab": key = "\t"
                default:
                    if part.count == 1 { key = part } else { return nil }
                }
            }
        }
        guard let key else { return nil }
        return (key, flags)
    }
}
